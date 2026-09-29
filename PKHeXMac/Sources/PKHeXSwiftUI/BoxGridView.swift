import PKHeXCore
import SwiftUI

/// Box grid + party roster + pinned party strip + multi-select mode (GRID spec §3, §4).
struct BoxGridView: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var dragRegistry: DragRegistry
    @EnvironmentObject private var profileStore: PanelProfileStore
    let saveFile: SaveFile

    @AppStorage("boxTileSize") private var boxTileSize = "M"
    @AppStorage("showTileBadges") private var showTileBadges = true

    @State private var isSelecting = false
    @State private var selectedIndices: Set<Int> = []
    @State private var pickerTarget: PickerTarget?

    private var location: SlotLocation {
        guard case .slots(let location) = store.selectedSidebarItem else { return .party }
        return location
    }

    private var isPartyView: Bool {
        if case .party = location { return true }
        return false
    }

    var body: some View {
        Group {
            if isPartyView {
                partyView
            } else {
                boxView
            }
        }
        .background(Theme.void)
        .onChange(of: store.selectedSidebarItem) {
            isSelecting = false
            selectedIndices.removeAll()
        }
        .sheet(item: $pickerTarget) { target in
            SpeciesPickerSheet(saveFile: saveFile, target: target) { species in
                choose(species: species, for: target)
            }
            .environmentObject(profileStore)
        }
        .background(slotCopyPasteShortcuts)
    }

    /// Invisible buttons carrying the Copy/Paste/Delete keyboard shortcuts for the inspected slot.
    /// Deliberately view-scoped (not app-level `.commands`) and gated by `disabled(_:)` on whether
    /// there's actually something to act on — a disabled `Button`'s `.keyboardShortcut` doesn't
    /// intercept the key, so ⌘C/⌘V/⌫ still reach a focused text field (nickname, OT name, etc.)
    /// normally when there's nothing copyable/pasteable/deletable in the box/party grid.
    @ViewBuilder
    private var slotCopyPasteShortcuts: some View {
        Group {
            Button("Copy") { store.copyInspected() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(!store.canCopyOrDeleteInspected)
            Button("Paste") { store.pasteIntoInspected() }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(!store.canPaste)
            Button("Delete") { store.deleteInspected() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!store.canDeleteInspected)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Box view

    /// S = 8, M = 6, L = 5 columns, per the tile-size preference.
    private var boxColumnCount: Int {
        switch boxTileSize {
        case "S": return 8
        case "L": return 5
        default: return 6
        }
    }

    private var boxColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: boxColumnCount)
    }

    @ViewBuilder
    private var boxView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pinnedPartyStrip

                    boxHeader

                    LazyVGrid(columns: boxColumns, spacing: 6) {
                        ForEach(0..<location.slotCount(in: saveFile), id: \.self) { slot in
                            let pkm = location.slot(slot, in: saveFile)
                            BoxTile(
                                pkm: pkm,
                                slot: slot,
                                isSelected: store.inspectedSlot == InspectedSlot(location: location, index: slot) && !isSelecting,
                                isSelecting: isSelecting,
                                isChecked: selectedIndices.contains(slot),
                                showsCodes: showTileBadges
                            )
                            .onTapGesture {
                                handleTap(slot: slot, pkm: pkm)
                            }
                            .contextMenu {
                                slotContextMenu(location: location, slot: slot, pkm: pkm)
                            }
                            .dragSource(pkm, location: location, slot: slot, saveFile: saveFile, registry: dragRegistry)
                            .dropTarget(location: location, slot: slot, saveFile: saveFile, store: store, registry: dragRegistry)
                        }
                    }
                    .padding(.horizontal, 20)

                    legendRow
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isSelecting {
                multiSelectActionBar
            }
        }
    }

    @ViewBuilder
    private var boxHeader: some View {
        HStack(spacing: 10) {
            GridText(saveFile.boxName(boxIndex ?? 0), .viewTitle)
                .lineLimit(1)

            if !isSelecting {
                HStack(spacing: 6) {
                    GridText("Box \(pad((boxIndex ?? 0) + 1, 2))", .label, color: Theme.ink300)
                    GridText(".Storage", .label, color: Theme.ink300)
                }
                .fixedSize()
            }

            DottedLeader()

            if isSelecting {
                GridBadge(text: "Selecting", color: Theme.amber, showsDot: false, solid: true)
                GridButton("Select all", .ghost, size: .sm) { selectAll() }
                GridButton("None", .ghost, size: .sm) { selectedIndices.removeAll() }
            }

            Text("\(pad(filledCount)) | \(pad(location.slotCount(in: saveFile)))")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.ink200)
                .fixedSize()

            GridButton(isSelecting ? "Done" : "Select", .secondary, size: .sm) {
                isSelecting.toggle()
                if !isSelecting { selectedIndices.removeAll() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                StatusDot(color: Theme.violet)
                Text("shiny")
            }
            HStack(spacing: 6) {
                StatusDot(color: Theme.red)
                Text("illegal")
            }
            DottedLeader()
            Text("right-click · copy / paste / delete")
        }
        .font(Theme.mono(12))
        .foregroundStyle(Theme.ink300)
    }

    private var boxIndex: Int? {
        if case .box(let index) = location { return index }
        return nil
    }

    private var filledCount: Int {
        (0..<location.slotCount(in: saveFile)).filter { location.slot($0, in: saveFile) != nil }.count
    }

    private func handleTap(slot: Int, pkm: PKM?) {
        if isSelecting {
            guard pkm != nil else { return }
            if selectedIndices.contains(slot) {
                selectedIndices.remove(slot)
            } else {
                selectedIndices.insert(slot)
            }
            return
        }
        // Selecting an empty slot (instead of immediately opening the species picker) lets it be
        // a Paste target like any other slot; use the right-click "Add Pokémon…" menu to open the
        // picker explicitly.
        store.inspectedSlot = InspectedSlot(location: location, index: slot)
    }

    @ViewBuilder
    private func slotContextMenu(location: SlotLocation, slot: Int, pkm: PKM?) -> some View {
        if pkm == nil {
            Button("Add Pokémon…") {
                pickerTarget = PickerTarget(location: location, slot: slot)
            }
            if store.copiedPKM != nil {
                Button("Paste") {
                    store.inspectedSlot = InspectedSlot(location: location, index: slot)
                    store.pasteIntoInspected()
                }
            }
        } else {
            Button("Copy") {
                store.inspectedSlot = InspectedSlot(location: location, index: slot)
                store.copyInspected()
            }
            if store.copiedPKM != nil {
                Button("Paste") {
                    store.inspectedSlot = InspectedSlot(location: location, index: slot)
                    store.pasteIntoInspected()
                }
            }
            Divider()
            let isLeadPartySlot: Bool = {
                if case .party = location, slot == 0 { return true }
                return false
            }()
            Button("Delete", role: .destructive) {
                store.inspectedSlot = InspectedSlot(location: location, index: slot)
                store.deleteInspected()
            }
            .disabled(isLeadPartySlot)
        }
    }

    private func selectAll() {
        selectedIndices = Set((0..<location.slotCount(in: saveFile)).filter { location.slot($0, in: saveFile) != nil })
    }

    // MARK: Multi-select action bar

    /// Pinned bar: `003 SELECTED ··· MOVE TO ▾ · CLONE · EXPORT · RELEASE · CANCEL`.
    @ViewBuilder
    private var multiSelectActionBar: some View {
        let hasSelection = !selectedIndices.isEmpty
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(pad(selectedIndices.count))
                    .font(Theme.mono(13, bold: true))
                    .foregroundStyle(Theme.amber)
                GridText("Selected", .label, color: Theme.ink200)
            }
            DottedLeader()

            Menu {
                ForEach(otherBoxes, id: \.index) { box in
                    Button("\(box.name) · \(pad(box.free)) free") { moveSelected(to: box.index) }
                        .disabled(box.free == 0)
                }
            } label: {
                Text("Move to \u{25BE}")
            }
            .menuStyle(.button)
            .buttonStyle(GridButtonStyle(variant: .secondary, size: .sm))
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!hasSelection)

            GridButton("Clone", .secondary, size: .sm) { cloneSelected() }
                .disabled(!hasSelection || freeSlotsHere == 0)
                .help(freeSlotsHere == 0 ? "No empty slots in this box." : "Copy the selected Pokémon into empty slots in this box.")
            GridButton("Export", .secondary, size: .sm) {}
                .disabled(true)
                .help("Not yet available: export isn't wired up in this build.")
            GridButton("Release", .danger, size: .sm) { releaseSelected() }
                .disabled(!hasSelection)
            GridButton("Cancel", .ghost, size: .sm) {
                isSelecting = false
                selectedIndices.removeAll()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Theme.void)
        .overlay(alignment: .top) { HRule(color: Theme.line300) }
    }

    private struct BoxChoice {
        let index: Int
        let name: String
        let free: Int
    }

    private var otherBoxes: [BoxChoice] {
        (0..<saveFile.boxCount).compactMap { index in
            guard index != boxIndex else { return nil }
            let free = saveFile.boxSlotCount - saveFile.boxOccupiedSlotCount(index)
            return BoxChoice(index: index, name: "Box \(pad(index + 1, 2))", free: free)
        }
    }

    private var freeSlotsHere: Int {
        saveFile.boxSlotCount - filledCount
    }

    /// Moves the selected Pokémon into the first empty slots of `target`, in order, stopping when
    /// the target box is full.
    private func moveSelected(to target: Int) {
        guard case .box(let source) = location else { return }
        var cursor = 0
        var moved = 0
        for slot in selectedIndices.sorted() {
            guard let pkm = saveFile.slot(box: source, slot: slot) else { continue }
            while cursor < saveFile.boxSlotCount, saveFile.slot(box: target, slot: cursor) != nil { cursor += 1 }
            guard cursor < saveFile.boxSlotCount else { break }
            saveFile.setSlot(pkm, box: target, slot: cursor)
            saveFile.clearSlot(box: source, slot: slot)
            moved += 1
        }
        if moved > 0 { store.markDirty() }
        store.inspectedSlot = nil
        isSelecting = false
        selectedIndices.removeAll()
    }

    /// Copies each selected Pokémon into the next empty slot of the current box.
    private func cloneSelected() {
        guard case .box(let box) = location else { return }
        var cursor = 0
        var cloned = 0
        for slot in selectedIndices.sorted() {
            guard let pkm = saveFile.slot(box: box, slot: slot) else { continue }
            while cursor < saveFile.boxSlotCount, saveFile.slot(box: box, slot: cursor) != nil { cursor += 1 }
            guard cursor < saveFile.boxSlotCount else { break }
            saveFile.setSlot(pkm, box: box, slot: cursor)
            cloned += 1
        }
        if cloned > 0 { store.markDirty() }
        selectedIndices.removeAll()
    }

    /// Clears every selected slot to empty, after a confirmation dialog when "Confirm before
    /// releasing" is on. Multi-select is box-only (see `pinnedPartyStrip`/`isPartyView`), so there's
    /// no party-slot-1 protection concern here the way there is for `SaveStore.deleteInspected()`.
    private func releaseSelected() {
        guard case .box(let box) = location, !selectedIndices.isEmpty else { return }
        let slots = selectedIndices
        let perform = {
            for slot in slots {
                saveFile.clearSlot(box: box, slot: slot)
            }
            store.markDirty()
            store.inspectedSlot = nil
            isSelecting = false
            selectedIndices.removeAll()
        }
        if UserDefaults.standard.object(forKey: "confirmBeforeReleasing") as? Bool ?? true {
            store.releaseRequest = SaveStore.ReleaseRequest(
                count: slots.count,
                locationName: "Box \(pad(box + 1, 2))",
                perform: perform
            )
        } else {
            perform()
        }
    }

    private func choose(species: UInt16, for target: PickerTarget) {
        guard let blank = saveFile.createBlankPKM(species: species) else { return }
        switch target.location {
        case .party:
            saveFile.setPartySlot(blank, index: target.slot)
        case .box(let box):
            saveFile.setSlot(blank, box: box, slot: target.slot)
        }
        store.markDirty()
        store.inspectedSlot = InspectedSlot(location: target.location, index: target.slot)
        pickerTarget = nil
    }

    // MARK: Pinned party strip

    @ViewBuilder
    private var pinnedPartyStrip: some View {
        HStack(spacing: 6) {
            GridText("Party", .label, color: Theme.ink300)
                .padding(.trailing, 6)

            ForEach(0..<6, id: \.self) { index in
                let pkm = saveFile.partySlot(index)
                MiniTile(
                    pkm: pkm,
                    isSelected: store.inspectedSlot == InspectedSlot(location: .party, index: index)
                )
                .frame(width: 52, height: 52)
                .onTapGesture {
                    // Inspect this party member (or empty slot) without navigating the
                    // content pane away from whatever box is currently open.
                    store.inspectedSlot = InspectedSlot(location: .party, index: index)
                }
                .contextMenu {
                    slotContextMenu(location: .party, slot: index, pkm: pkm)
                }
                .dragSource(pkm, location: .party, slot: index, saveFile: saveFile, registry: dragRegistry)
                .dropTarget(location: .party, slot: index, saveFile: saveFile, store: store, registry: dragRegistry)
            }

            DottedLeader()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: - Party view

    /// Two columns when the pane is wide enough (>= 300 pt each), otherwise a single full-width
    /// column so the sprite, name, meta line and type chips never truncate.
    private var partyColumns: [GridItem] { [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 12)] }

    @ViewBuilder
    private var partyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    GridText("Party", .viewTitle)
                    GridText("Active", .label, color: Theme.ink300)
                    GridText(".Team", .label, color: Theme.ink300)
                    DottedLeader()
                    Text("\(pad(saveFile.partyCount)) | 006")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.ink200)
                }

                LazyVGrid(columns: partyColumns, spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        PartyCard(
                            pkm: saveFile.partySlot(index),
                            slotIndex: index,
                            isSelected: store.inspectedSlot == InspectedSlot(location: .party, index: index)
                        )
                        .onTapGesture {
                            store.inspectedSlot = InspectedSlot(location: .party, index: index)
                        }
                        .contextMenu {
                            slotContextMenu(location: .party, slot: index, pkm: saveFile.partySlot(index))
                        }
                        .dragSource(saveFile.partySlot(index), location: .party, slot: index, saveFile: saveFile, registry: dragRegistry)
                        .dropTarget(location: .party, slot: index, saveFile: saveFile, store: store, registry: dragRegistry)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Identifies which empty slot the species picker sheet should fill.
struct PickerTarget: Identifiable {
    let location: SlotLocation
    let slot: Int
    var id: String { "\(location)-\(slot)" }
}

// MARK: - Box tile

private struct BoxTile: View {
    let pkm: PKM?
    let slot: Int
    let isSelected: Bool
    let isSelecting: Bool
    let isChecked: Bool
    let showsCodes: Bool

    @State private var isHovering = false

    private var isActive: Bool { isSelected || isChecked }

    var body: some View {
        ZStack {
            Rectangle().fill(fill)

            if let pkm {
                ArtworkImage(pkm: pkm)
                    .grayscale(pkm.isEgg ? 1 : 0)
                    .brightness(pkm.isEgg ? -0.4 : 0)
                    .padding(showsCodes ? 12 : 8)
                    .padding(.bottom, showsCodes ? 6 : 0)

                // level, top-left (shifts right when the checkbox is showing)
                VStack {
                    HStack(spacing: 0) {
                        Text("L\(pad(Int(pkm.level)))")
                            .font(Theme.mono(12))
                            .foregroundStyle(isActive ? Theme.amber : Theme.ink200)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.leading, isSelecting ? 20 : 0)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(3)

                // state dot, top-right: illegal (red) wins over shiny (violet)
                if let dot = stateDotColor(for: pkm) {
                    VStack {
                        HStack {
                            Spacer()
                            StatusDot(color: dot)
                        }
                        Spacer()
                    }
                    .padding(5)
                }

                // type codes, bottom-center
                if showsCodes {
                    VStack {
                        Spacer()
                        Text(pkm.types.map { typeCode(typeID: $0) }.joined(separator: " "))
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.ink300)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }

                // multi-select checkbox, top-left
                if isSelecting {
                    VStack {
                        HStack {
                            Rectangle()
                                .fill(isChecked ? Theme.amber : Theme.void)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Rectangle().strokeBorder(isChecked ? Theme.amber : Theme.line200, lineWidth: 1)
                                )
                                .overlay {
                                    if isChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Theme.inkInvert)
                                    }
                                }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            } else {
                Text(pad(slot + 1, 2))
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.ink400)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay { border }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }

    private var fill: Color {
        if pkm != nil && isActive { return Theme.amberFill }
        if pkm != nil { return isHovering ? Theme.surface3 : Theme.surface1 }
        return isHovering ? Theme.surface3 : .clear
    }

    @ViewBuilder
    private var border: some View {
        if pkm == nil {
            Rectangle().strokeBorder(
                isHovering ? Theme.line200 : Theme.line300,
                style: StrokeStyle(lineWidth: 1, dash: [2, 3])
            )
        } else if isActive {
            Rectangle().strokeBorder(Theme.amber, lineWidth: 2)
        } else {
            Rectangle().strokeBorder(isHovering ? Theme.line200 : Theme.line300, lineWidth: 1)
        }
    }

    private func stateDotColor(for pkm: PKM) -> Color? {
        if !pkm.isLegal { return Theme.red }
        if pkm.isShiny { return Theme.violet }
        return nil
    }
}

/// 52 x 52 tile for the pinned party strip: sprite, level bottom-right, dotted when empty.
private struct MiniTile: View {
    let pkm: PKM?
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Rectangle().fill(pkm != nil && isSelected ? Theme.amberFill : (isHovering ? Theme.surface3 : (pkm != nil ? Theme.surface1 : .clear)))

            if let pkm {
                ArtworkImage(pkm: pkm)
                    .frame(width: 40, height: 36)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(pad(Int(pkm.level)))
                            .font(Theme.mono(12))
                            .foregroundStyle(isSelected ? Theme.amber : Theme.ink200)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(2)
            }
        }
        .overlay {
            if pkm == nil {
                Rectangle().strokeBorder(Theme.line300, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            } else if isSelected {
                Rectangle().strokeBorder(Theme.amber, lineWidth: 2)
            } else {
                Rectangle().strokeBorder(isHovering ? Theme.line200 : Theme.line300, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }
}

// MARK: - Party card

private struct PartyCard: View {
    @EnvironmentObject private var profileStore: PanelProfileStore
    let pkm: PKM?
    let slotIndex: Int
    let isSelected: Bool

    @State private var isHovering = false

    private var isActive: Bool { pkm != nil && isSelected }

    var body: some View {
        let p = profileStore.profile
        VStack(alignment: .leading, spacing: 0) {
            headRow
                .padding(.horizontal, 14)
                .frame(height: 36)

            if let pkm {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack(alignment: .topTrailing) {
                            Rectangle().fill(Theme.surface2)
                            ArtworkImage(pkm: pkm)
                                .padding(8)
                            if pkm.isShiny {
                                StatusDot(color: Theme.violet).padding(5)
                            }
                        }
                        .frame(width: 72, height: 64)
                        .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(pkm.nickname.isEmpty ? pkm.speciesName : pkm.nickname)
                                .font(Theme.sans(20, .semibold))
                                .foregroundStyle(Theme.ink100)
                                .lineLimit(1)
                            Text(metaLine(for: pkm))
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.ink300)
                                .lineLimit(1)
                            TypeChips(typeIDs: pkm.types)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 8) {
                        GridText("Held", .label, color: Theme.ink300)
                        DottedLeader()
                        Text(pkm.heldItem == 0 ? "none" : pkm.heldItemName)
                            .font(Theme.sans(14, .medium))
                            .foregroundStyle(pkm.heldItem == 0 ? Theme.ink300 : Theme.ink100)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Theme.surface2)
                    .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                GridText("+ Empty · Add", .label, color: Theme.ink300)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .background(isActive ? Theme.amberFill : (isHovering ? Theme.surface3 : Theme.surface1))
        .clipShape(RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous))
        .overlay {
            if pkm == nil {
                RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous)
                    .strokeBorder(Theme.line300, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } else {
                RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous)
                    .strokeBorder(isActive ? Theme.amber : (isHovering ? Theme.line200 : Theme.line300), lineWidth: p.borderWidth)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }

    private var headRow: some View {
        HStack(spacing: 8) {
            Text(slotIndex == 0 ? "01 · lead" : pad(slotIndex + 1, 2))
                .font(Theme.mono(12))
                .foregroundStyle(isActive ? Theme.amber : Theme.ink300)
            DottedLeader()
            if let pkm {
                if pkm.isLegal {
                    GridBadge(text: "Legal", color: Theme.green)
                } else {
                    GridBadge(text: "\(pad(pkm.legalityReasons.count, 2)) issues", color: Theme.red)
                }
            }
        }
    }

    private func metaLine(for pkm: PKM) -> String {
        var parts = ["L\(pad(Int(pkm.level)))"]
        switch pkm.gender {
        case 0: parts.append("m")
        case 1: parts.append("f")
        default: break
        }
        parts.append(pkm.natureName.lowercased())
        return parts.joined(separator: " · ")
    }
}

struct SpriteImage: View {
    let fileName: String

    var body: some View {
        if let nsImage = NSImage(named: fileName) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

/// Renders the icon for a Ball value (see PKHeX.Core's Ball enum) from the generated
/// `_ball<value>` asset catalog entries (see Scripts/ — BallIcons.xcassets). Ball 0 ("None") has
/// no icon; renders nothing rather than a placeholder, same fallback behavior as `SpriteImage`.
struct BallIcon: View {
    let ball: UInt8

    var body: some View {
        if let nsImage = NSImage(named: "_ball\(ball)") {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

/// Renders a Pokemon's artwork (see `PKM.artworkFileName`), falling back through progressively
/// simpler names — then to the older, lower-coverage sprite set — when the exact generated name
/// isn't present in the shipped asset catalog (the artwork set hasn't been exhaustively verified
/// to cover every form/shiny combination; see ArtworkFileName.cs's remarks). Unlike `SpriteImage`,
/// this is not pixelated on render — the artwork set is a smoother/newer icon style, not the
/// retro in-game sprite look `SpriteImage` intentionally preserves.
struct ArtworkImage: View {
    let pkm: PKM

    var body: some View {
        if let nsImage = Self.resolvedImage(for: pkm) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }

    /// Tries, in order: the exact artwork name; the same name without a trailing shiny "s"; the
    /// same name with any "-"-prefixed form/gender suffix stripped down to "a_<species>"; then
    /// the older sprite set's name (which has its own species/shiny fallback already baked into
    /// how it's generated) as a last resort.
    private static func resolvedImage(for pkm: PKM) -> NSImage? {
        let artwork = pkm.artworkFileName
        if let image = NSImage(named: artwork) { return image }

        if artwork.hasSuffix("s") {
            let withoutShiny = String(artwork.dropLast())
            if let image = NSImage(named: withoutShiny) { return image }
        }

        let bareSpecies = "a_\(pkm.species)"
        if let image = NSImage(named: bareSpecies) { return image }

        return NSImage(named: pkm.spriteFileName)
    }
}

/// Renders the icon for a party Pokemon's status condition from the generated `StatusIcons` asset
/// catalog (see Scripts/generate_artwork_assets.py). `.none` has no icon; renders nothing rather
/// than a placeholder, same fallback behavior as `BallIcon`.
struct StatusIcon: View {
    let status: StatusCondition

    private var assetName: String? {
        switch status {
        case .none: return nil
        case .paralysis: return "sickparalyze"
        case .sleep: return "sicksleep"
        case .freeze: return "sickfrostbite"
        case .burn: return "sickburn"
        case .poison: return "sickpoison"
        }
    }

    var body: some View {
        if let assetName, let nsImage = NSImage(named: assetName) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

/// Renders an item's icon art from the `ItemIcons` asset catalog (`bitem_<id>`), falling back to
/// PKHeX's own "unknown item" placeholder (`bitem_unk`) when there's no dedicated art shipped for
/// that item ID — coverage is ~606 of ~2684 possible item IDs, so most items use the fallback.
struct ItemIconImage: View {
    let itemID: Int

    var body: some View {
        if let nsImage = NSImage(named: "bitem_\(itemID)") ?? NSImage(named: "bitem_unk") {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}
