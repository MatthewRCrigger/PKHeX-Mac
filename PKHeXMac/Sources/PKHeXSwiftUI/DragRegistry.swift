import CoreTransferable
import Foundation
import PKHeXCore
import SwiftUI

/// Identifies an in-flight box/party slot drag session. Carried across the drag as a plain string
/// (its `id`), then resolved back to the live source through `DragRegistry` — dragging the PKM's
/// raw bytes isn't necessary since both windows live in the same process, and a live reference lets
/// the drop side ask the *destination* save to convert the PKM to its own generation/format (see
/// `SaveFile.convertForTransfer`), matching how PKHeX.WinForms resolves a cross-window drop against
/// the destination window's save.
///
/// Uses `ProxyRepresentation` over a plain `public.plain-text` string rather than a custom
/// `CodableRepresentation`/exported UTI: a custom UTI needs its own `NSItemProvider` decode path
/// negotiated through the system drag pasteboard, which failed cross-window in testing
/// (`NSCocoaErrorDomain` 3072 / `NSCoderReadCorruptError` — the encoded payload never successfully
/// round-tripped). A plain string over a well-known system type sidesteps that entirely.
struct SlotDragToken: Transferable, Hashable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { $0.id.uuidString }, importing: { SlotDragToken(id: UUID(uuidString: $0) ?? UUID()) })
    }
}

/// One in-flight drag's source: which save/slot the dragged Pokemon came from, so a successful drop
/// elsewhere can clear it (a "move"), and a drop that converts formats knows which save to read the
/// pre-conversion PKM from.
struct SlotDragSource {
    let saveFile: SaveFile
    let location: SlotLocation
    let slot: Int
    /// Clears the source slot once the drop has been placed successfully. `nil` for drags that
    /// shouldn't remove the original (not currently used, but keeps `DragRegistry` correct if a
    /// "duplicate on drop" modifier is added later).
    let clearSource: () -> Void
}

/// App-wide (not per-window) registry mapping a `SlotDragToken.id` to its live `SlotDragSource`,
/// for the duration of a single drag gesture. SwiftUI's `.draggable`/`.dropDestination` only pass
/// the `Transferable` value itself across a drop, so the live save/slot reference this needs has to
/// travel out-of-band — shared via `@EnvironmentObject` the same way `AccentStore` is shared across
/// every window.
@MainActor
final class DragRegistry: ObservableObject {
    private var sources: [UUID: SlotDragSource] = [:]

    func begin(saveFile: SaveFile, location: SlotLocation, slot: Int, clearSource: @escaping () -> Void) -> SlotDragToken {
        let id = UUID()
        sources[id] = SlotDragSource(saveFile: saveFile, location: location, slot: slot, clearSource: clearSource)
        return SlotDragToken(id: id)
    }

    func source(for token: SlotDragToken) -> SlotDragSource? {
        sources[token.id]
    }

    /// Called once a drop has been fully handled (accepted or rejected) so the registry doesn't
    /// keep a `SaveFile`/closure alive past the gesture that created it.
    func end(_ token: SlotDragToken) {
        sources.removeValue(forKey: token.id)
    }
}

extension View {
    /// Makes this slot draggable (a no-op if `pkm` is nil — empty slots aren't drag sources).
    /// Dragging registers the live source with `registry` and hands off only a small token, so the
    /// drop side — possibly a different window's save, of a different generation — can look up the
    /// real `PKM`/`SaveFile` and run `SaveFile.convertForTransfer` against its own format. The
    /// `draggable(_:)` payload is `@autoclosure`, so `registry.begin` only actually runs once a drag
    /// gesture starts, not on every view body evaluation.
    @ViewBuilder
    func dragSource(
        _ pkm: PKM?,
        location: SlotLocation,
        slot: Int,
        saveFile: SaveFile,
        registry: DragRegistry
    ) -> some View {
        if pkm != nil {
            self.draggable(registry.begin(saveFile: saveFile, location: location, slot: slot) {
                switch location {
                case .party: saveFile.clearPartySlot(slot)
                case .box(let box): saveFile.clearSlot(box: box, slot: slot)
                }
            })
        } else {
            self
        }
    }

    /// Accepts a dropped `SlotDragToken`, converting the source Pokemon to `saveFile`'s format
    /// (see `SaveFile.convertForTransfer`) and placing it into `location`/`slot`, then clearing the
    /// drag's source slot — a move, matching PKHeX.WinForms' default drag behavior. Rejects (with
    /// `store.errorMessage` set) if no legal conversion path exists, or silently ignores a drop of
    /// unrelated/stale data.
    func dropTarget(
        location: SlotLocation,
        slot: Int,
        saveFile: SaveFile,
        store: SaveStore,
        registry: DragRegistry
    ) -> some View {
        dropDestination(for: SlotDragToken.self) { tokens, _ in
            guard let token = tokens.first, let source = registry.source(for: token) else { return false }
            defer { registry.end(token) }

            // Dropping a slot onto itself (or an empty slot back onto itself) is a no-op, not a
            // self-clearing delete.
            if source.saveFile === saveFile, source.location == location, source.slot == slot {
                return false
            }

            guard let pkm = source.location.slot(source.slot, in: source.saveFile) else { return false }
            guard store.receiveDroppedPKM(pkm, into: location, slot: slot) else { return false }
            source.clearSource()
            return true
        }
    }
}
