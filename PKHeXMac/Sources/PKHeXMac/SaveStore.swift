import AppKit
import PKHeXCore
import SwiftUI

/// A slot grid the box/party views can browse — as opposed to whole-page sidebar destinations
/// like Trainer or Bag, which have no slot grid at all.
enum SlotLocation: Hashable {
    case party
    case box(Int)

    func slotCount(in saveFile: SaveFile) -> Int {
        switch self {
        case .party: return 6
        case .box: return saveFile.boxSlotCount
        }
    }

    func slot(_ index: Int, in saveFile: SaveFile) -> PKM? {
        switch self {
        case .party: return saveFile.partySlot(index)
        case .box(let box): return saveFile.slot(box: box, slot: index)
        }
    }

    var title: String {
        switch self {
        case .party: return "Party"
        case .box(let box): return "Box \(box + 1)"
        }
    }
}

/// Everything selectable in the sidebar.
enum SidebarSelection: Hashable {
    case trainer
    case bag
    case slots(SlotLocation)
}

/// A single slot the inspector is showing, identified independently of `selectedSidebarItem` —
/// e.g. selecting a party member from the pinned party strip while Box 3 is the active content
/// pane inspects that party member without navigating the content pane away from Box 3.
struct InspectedSlot: Hashable {
    var location: SlotLocation
    var index: Int
}

@MainActor
final class SaveStore: ObservableObject {
    @Published private(set) var saveFile: SaveFile?
    @Published var selectedSidebarItem: SidebarSelection = .trainer
    @Published var inspectedSlot: InspectedSlot?
    @Published var errorMessage: String?
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var lastSaveFailed = false
    /// Set by Copy (⌘C); pasted (⌘V) into the currently inspected slot. Same-generation only —
    /// there's no cross-save/cross-generation conversion, so this is only ever populated/used
    /// within a single open save.
    @Published var copiedPKM: PKM?
    private var loadedURL: URL?
    /// Set when the file at `loadedURL` has already been backed up this session (or turned out to
    /// already have a `.bak` sibling from a previous session) — so `save()` only ever backs up the
    /// pristine as-opened bytes once, not the file's own prior saved state.
    private var hasBackedUpThisLoad = false

    /// Call after any edit to a PKM, the trainer, or the bag so the UI can show unsaved-changes
    /// state and the Save button/menu item has something to act on.
    func markDirty() {
        hasUnsavedChanges = true
    }

    /// True if opening a different file should be blocked pending user confirmation, because doing
    /// so would silently discard unsaved changes to the currently open save.
    private func confirmDiscardingUnsavedChanges() -> Bool {
        guard hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "You have unsaved changes"
        alert.informativeText = "Opening a different save file will discard your unsaved changes to this one."
        alert.addButton(withTitle: "Open Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Prompts to open a different save file. If the currently open save has unsaved changes,
    /// confirms first — opening a new file discards them, there being only one save open at a time.
    func presentOpenPanel() {
        guard confirmDiscardingUnsavedChanges() else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Save File"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    /// Opens a file handed to us by the OS (double-click, Open With, drag onto the Dock icon).
    /// Same unsaved-changes guard as `presentOpenPanel`, since Finder can hand us a file at any time
    /// — including while a different save is already open with edits pending.
    func openFromFinder(_ url: URL) {
        guard confirmDiscardingUnsavedChanges() else { return }
        load(from: url)
    }

    func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let newSaveFile = try SaveFile(data: data)
            saveFile = newSaveFile
            loadedURL = url
            selectedSidebarItem = .trainer
            inspectedSlot = nil
            copiedPKM = nil
            hasUnsavedChanges = false
            lastSaveFailed = false
            hasBackedUpThisLoad = false
        } catch {
            errorMessage = "Couldn't open that file as a Pokémon save: \(error)"
        }
    }

    /// Copies the file at `loadedURL` to a `.bak` sibling (e.g. `DAWN.sav` → `DAWN.sav.bak`),
    /// preserving whatever was on disk before this session's first write. Only runs once per
    /// `load(from:)` and only if "Back up save before writing" is on in Settings; a pre-existing
    /// `.bak` from an earlier session is left as-is rather than overwritten, so backups aren't
    /// silently replaced by a second run's pristine copy.
    private func backUpIfNeeded() {
        guard !hasBackedUpThisLoad, let loadedURL else { return }
        hasBackedUpThisLoad = true
        guard UserDefaults.standard.object(forKey: "backupBeforeWriting") as? Bool ?? true else { return }
        let backupURL = loadedURL.appendingPathExtension("bak")
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try? FileManager.default.copyItem(at: loadedURL, to: backupURL)
    }

    func save() {
        guard let saveFile, let loadedURL else { return }
        backUpIfNeeded()
        do {
            let data = try saveFile.write()
            try data.write(to: loadedURL)
            hasUnsavedChanges = false
            lastSaveFailed = false
        } catch {
            errorMessage = "Couldn't save: \(error)"
            lastSaveFailed = true
        }
    }

    /// True if there's a Pokemon in the currently inspected slot to copy or delete.
    var canCopyOrDeleteInspected: Bool {
        guard let saveFile, let inspected = inspectedSlot else { return false }
        return inspected.location.slot(inspected.index, in: saveFile) != nil
    }

    /// True if a slot is inspected (empty or filled) and something's been copied to paste into it.
    var canPaste: Bool {
        inspectedSlot != nil && copiedPKM != nil
    }

    /// Party slot 1 (the lead) can never be deleted — every save format requires at least one
    /// non-empty party member, and the lead slot in particular backs the overworld sprite/battle
    /// order in every generation, so leaving it empty isn't a state the game can recover from.
    var canDeleteInspected: Bool {
        guard canCopyOrDeleteInspected, let inspected = inspectedSlot else { return false }
        if case .party = inspected.location, inspected.index == 0 { return false }
        return true
    }

    /// Copies the currently inspected slot's Pokemon (⌘C). No-op if the slot is empty.
    func copyInspected() {
        guard let saveFile, let inspected = inspectedSlot else { return }
        copiedPKM = inspected.location.slot(inspected.index, in: saveFile)
    }

    /// Pastes the last-copied Pokemon into the currently inspected slot (⌘V), overwriting
    /// whatever's there. Same-generation copy/paste only (matches the official editor): no
    /// conversion is attempted, so pasting into a save of a different generation is a no-op.
    func pasteIntoInspected() {
        guard let saveFile, let inspected = inspectedSlot, let copiedPKM else { return }
        switch inspected.location {
        case .party: saveFile.setPartySlot(copiedPKM, index: inspected.index)
        case .box(let box): saveFile.setSlot(copiedPKM, box: box, slot: inspected.index)
        }
        markDirty()
    }

    /// Deletes (clears) the currently inspected slot (⌦). Refuses to clear party slot 1 — see
    /// `canDeleteInspected`.
    func deleteInspected() {
        guard let saveFile, let inspected = inspectedSlot, canDeleteInspected else { return }
        switch inspected.location {
        case .party:
            // Deleting a party slot shifts every following member down one slot to keep the
            // party contiguous (see `clearPartySlot`), so whatever now occupies this index is a
            // different Pokemon than what was just deleted — clear the inspector rather than
            // silently show it as if the delete had no visible effect.
            saveFile.clearPartySlot(inspected.index)
            inspectedSlot = nil
        case .box(let box):
            saveFile.clearSlot(box: box, slot: inspected.index)
            inspectedSlot = nil
        }
        markDirty()
    }
}
