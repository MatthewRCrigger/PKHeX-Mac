import PKHeXCore
import SwiftUI

/// Box grid + party roster + pinned party strip + multi-select mode.
/// See design_handoff_circuit_redesign/README.md sections 2, 3, 9.
struct BoxGridView: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore
    let saveFile: SaveFile

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
        .background(Theme.bgContent)
        .navigationTitle(location.title)
        .onChange(of: store.selectedSidebarItem) {
            isSelecting = false
            selectedIndices.removeAll()
        }
        .sheet(item: $pickerTarget) { target in
            SpeciesPickerSheet(saveFile: saveFile, target: target) { species in
                choose(species: species, for: target)
            }
            .environmentObject(accentStore)
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

    private var boxColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 8), count: 6) }

    @ViewBuilder
    private var boxView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pinnedPartyStrip

                boxHeader

                LazyVGrid(columns: boxColumns, spacing: 8) {
                    ForEach(0..<location.slotCount(in: saveFile), id: \.self) { slot in
                        let pkm = location.slot(slot, in: saveFile)
                        BoxTile(
                            pkm: pkm,
                            isSelected: store.inspectedSlot == InspectedSlot(location: location, index: slot) && !isSelecting,
                            isSelecting: isSelecting,
                            isChecked: selectedIndices.contains(slot),
                            accent: accentStore.accent
                        )
                        .onTapGesture {
                            handleTap(slot: slot, pkm: pkm)
                        }
                        .contextMenu {
                            slotContextMenu(location: location, slot: slot, pkm: pkm)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 92)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            if !selectedIndices.isEmpty {
                multiSelectActionBar
                    .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private var boxHeader: some View {
        HStack(spacing: 12) {
            Text(saveFile.boxName(boxIndex ?? 0))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(filledCount) / \(location.slotCount(in: saveFile))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            if isSelecting {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Selecting")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(accentStore.accent.onAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(accentStore.accent.color)
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Button("Select all") { selectAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(accentStore.accent.bright)
                Text("·").foregroundStyle(Theme.textTertiary)
                Button("None") { selectedIndices.removeAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            Button {
                isSelecting.toggle()
                if !isSelecting { selectedIndices.removeAll() }
            } label: {
                Text(isSelecting ? "Done" : "Select")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.bgElevated2)
            .foregroundStyle(Theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
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

    @ViewBuilder
    private var multiSelectActionBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("\(selectedIndices.count)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(accentStore.accent.onAccent)
                    .frame(width: 22, height: 22)
                    .background(accentStore.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("selected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.trailing, 12)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Theme.hairline).frame(width: 0.5)
            }

            actionBarButton("Move to \u{25BE}", systemImage: "arrow.up.arrow.down")
                .disabled(true)
                .help("Not yet available: moving Pokémon across boxes isn't wired up in this build.")
            actionBarButton("Clone", systemImage: "square.on.square")
                .disabled(true)
                .help("Not yet available: cloning isn't wired up in this build.")
            actionBarButton("Export", systemImage: "square.and.arrow.up")
                .disabled(true)
                .help("Not yet available: export isn't wired up in this build.")

            Button {
                releaseSelected()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "trash")
                    Text("Release")
                }
                .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.danger)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Theme.danger.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Button("Cancel") {
                isSelecting = false
                selectedIndices.removeAll()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(Theme.bgElevated2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    @ViewBuilder
    private func actionBarButton(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(Theme.textPrimary.opacity(0.85))
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Theme.bgElevated3)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    /// Clears every selected slot to empty. Multi-select is box-only (see `pinnedPartyStrip`/
    /// `isPartyView`), so there's no party-slot-1 protection concern here the way there is for
    /// `SaveStore.deleteInspected()`.
    private func releaseSelected() {
        guard case .box(let box) = location else { return }
        for slot in selectedIndices {
            saveFile.clearSlot(box: box, slot: slot)
        }
        store.markDirty()
        isSelecting = false
        selectedIndices.removeAll()
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

    @ViewBuilder
    private var pinnedPartyStrip: some View {
        if !isPartyView {
            VStack(alignment: .leading, spacing: 8) {
                Text("PARTY")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.textTertiary)

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let pkm = saveFile.partySlot(index)
                        MiniTile(pkm: pkm, accent: accentStore.accent)
                            .frame(width: 52, height: 52)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        store.inspectedSlot == InspectedSlot(location: .party, index: index)
                                            ? accentStore.accent.color : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                            .onTapGesture {
                                // Inspect this party member (or empty slot) without navigating the
                                // content pane away from whatever box is currently open.
                                store.inspectedSlot = InspectedSlot(location: .party, index: index)
                            }
                            .contextMenu {
                                slotContextMenu(location: .party, slot: index, pkm: pkm)
                            }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Party view

    /// Packs as many columns as fit at >=280pt each, so a narrow content pane falls back to a
    /// single full-width column (room for the sprite, name, meta line, and type badges to render
    /// without truncating) instead of always forcing 2 columns regardless of available width.
    private var partyColumns: [GridItem] { [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 14)] }

    @ViewBuilder
    private var partyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Party")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your active team · click to inspect")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(saveFile.partyCount) / 6")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }

                LazyVGrid(columns: partyColumns, spacing: 14) {
                    ForEach(0..<6, id: \.self) { index in
                        PartyCard(
                            pkm: saveFile.partySlot(index),
                            slotIndex: index,
                            isSelected: store.inspectedSlot == InspectedSlot(location: .party, index: index),
                            accent: accentStore.accent
                        )
                        .onTapGesture {
                            store.inspectedSlot = InspectedSlot(location: .party, index: index)
                        }
                        .contextMenu {
                            slotContextMenu(location: .party, slot: index, pkm: saveFile.partySlot(index))
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RadialGradient(
                colors: [Theme.bgPanel, Theme.bgContent],
                center: UnitPoint(x: 0.15, y: 0),
                startRadius: 0,
                endRadius: 620
            )
        )
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
    let isSelected: Bool
    let isSelecting: Bool
    let isChecked: Bool
    let accent: AccentColor

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.tile)
            .fill(pkm == nil ? Theme.bgTileEmpty : (isSelected ? Theme.bgElevated1 : Theme.bgTile))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let pkm {
                    ZStack {
                        ArtworkImage(pkm: pkm)
                            .padding(6)

                        // type dots, bottom-left
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 2) {
                                    ForEach(pkm.types, id: \.self) { typeID in
                                        Circle()
                                            .fill(Theme.typeColor(PokemonNames.type(typeID)).fill)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(4)

                        // level badge, bottom-right
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(pkm.level)")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(3)

                        // shiny star, top-right
                        if pkm.isShiny {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("★")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.shinyStar)
                                }
                                Spacer()
                            }
                            .padding(3)
                        }

                        // multi-select check circle, top-left
                        if isSelecting {
                            VStack {
                                HStack {
                                    Circle()
                                        .fill(isChecked ? accent.color : Color.clear)
                                        .overlay(
                                            Circle().strokeBorder(isChecked ? Color.clear : Color.white.opacity(0.25), lineWidth: 1.5)
                                        )
                                        .overlay {
                                            if isChecked {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .heavy))
                                                    .foregroundStyle(accent.onAccent)
                                            }
                                        }
                                        .frame(width: 16, height: 16)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(4)
                        }
                    }
                } else {
                    Text("+")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white.opacity(0.14))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tile)
                    .strokeBorder(
                        pkm == nil ? Color.white.opacity(0.18) : (isSelected ? accent.color : Color.clear),
                        style: pkm == nil ? StrokeStyle(lineWidth: 0.5, dash: [3, 3]) : StrokeStyle(lineWidth: 2)
                    )
            }
    }
}

/// 52x52 mini tile for the pinned party strip, reusing the same visual language as `BoxTile`
/// at a smaller size.
private struct MiniTile: View {
    let pkm: PKM?
    let accent: AccentColor

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(pkm == nil ? Theme.bgTileEmpty : Theme.bgTile)
            .overlay {
                if let pkm {
                    ZStack {
                        ArtworkImage(pkm: pkm)
                            .padding(4)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(pkm.level)")
                                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 2)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                        .padding(2)
                        if pkm.isShiny {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("★")
                                        .font(.system(size: 7))
                                        .foregroundStyle(Theme.shinyStar)
                                }
                                Spacer()
                            }
                            .padding(2)
                        }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        pkm == nil ? Color.white.opacity(0.18) : Color.clear,
                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 2])
                    )
            }
    }
}

// MARK: - Party card

private struct PartyCard: View {
    let pkm: PKM?
    let slotIndex: Int
    let isSelected: Bool
    let accent: AccentColor

    private var isFlagged: Bool { pkm.map { !$0.isLegal } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                if slotIndex == 0 {
                    Text("LEAD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(accent.color)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Text(String(format: "%02d", slotIndex + 1))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if let pkm {
                    legalityChip(isLegal: pkm.isLegal)
                }
            }

            if let pkm {
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Theme.bgWell)
                            .frame(width: 72, height: 64)
                        ArtworkImage(pkm: pkm)
                            .padding(8)
                            .frame(width: 72, height: 64)
                        if pkm.isShiny {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("★")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.shinyStar)
                                }
                                Spacer()
                            }
                            .frame(width: 72, height: 64)
                            .padding(3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pkm.nickname.isEmpty ? pkm.speciesName : pkm.nickname)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(metaLine(for: pkm))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 5) {
                            ForEach(pkm.types, id: \.self) { typeID in
                                TypeBadge(typeID: typeID)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.bgElevated3)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if pkm.heldItem != 0 {
                                ItemIconImage(itemID: Int(pkm.heldItem))
                                    .padding(3)
                            }
                        }
                    Text(pkm.heldItem == 0 ? "No item" : pkm.heldItemName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary.opacity(0.75))
                    Spacer()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Theme.bgWell)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                VStack {
                    Spacer()
                    Text("+")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.18))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding(15)
        .background(pkm != nil && isSelected ? Theme.bgElevated1 : Theme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    borderColor,
                    lineWidth: (isSelected || isFlagged) ? 1.5 : 0.5
                )
        }
    }

    private var borderColor: Color {
        if isSelected { return accent.color }
        if isFlagged { return Theme.warnIcon.opacity(0.5) }
        return Theme.hairline
    }

    @ViewBuilder
    private func legalityChip(isLegal: Bool) -> some View {
        Text(isLegal ? "Legal" : "\(issueCount) issue\(issueCount == 1 ? "" : "s")")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isLegal ? Theme.legalText : Theme.warnText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isLegal ? Theme.legalFill : Theme.warnFill)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isLegal ? Theme.legalBorder : Theme.warnBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var issueCount: Int { pkm?.legalityReasons.count ?? 0 }

    private func metaLine(for pkm: PKM) -> String {
        let genderSymbol: String
        switch pkm.gender {
        case 0: genderSymbol = "♂"
        case 1: genderSymbol = "♀"
        default: genderSymbol = ""
        }
        var parts = ["Lv \(pkm.level)", pkm.natureName]
        if !genderSymbol.isEmpty { parts.append(genderSymbol) }
        return parts.joined(separator: " · ")
    }
}

/// Small type-name pill, e.g. "FIRE" / "GROUND", colored via `Theme.typeColor`.
struct TypeBadge: View {
    let typeID: UInt8

    var body: some View {
        let name = PokemonNames.type(typeID).uppercased()
        let colors = Theme.typeColor(name)
        Text(name)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(colors.textOnFill)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(colors.fill)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
