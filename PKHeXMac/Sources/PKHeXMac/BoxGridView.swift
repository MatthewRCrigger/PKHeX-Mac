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
                            isSelected: store.selectedSlot == slot && !isSelecting,
                            isSelecting: isSelecting,
                            isChecked: selectedIndices.contains(slot),
                            accent: accentStore.accent
                        )
                        .onTapGesture {
                            handleTap(slot: slot, pkm: pkm)
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
            } else {
                Text("Click a slot to inspect · empty slot to add")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
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
        if pkm != nil {
            store.selectedSlot = slot
        } else {
            pickerTarget = PickerTarget(location: location, slot: slot)
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
            .disabled(true)
            .help("Not yet available: there is no API to clear a slot to empty in this build, so Release cannot be safely implemented yet.")

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

    /// Release currently has no safe implementation: `SaveFile.setSlot`/`setPartySlot` both require
    /// a non-nil `PKM`, and there is no exposed "clear slot" API in PKHeXCore/CPKHeXNative. Rather
    /// than fake success or crash, this is left as a documented no-op (button is disabled above).
    private func releaseSelected() {
        // Intentionally not implemented — see doc comment above.
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
        store.selectedSlot = target.slot
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
                            .onTapGesture {
                                guard pkm != nil else { return }
                                store.selectedSidebarItem = .slots(.party)
                                store.selectedSlot = index
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

    private var partyColumns: [GridItem] { [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)] }

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
                            isSelected: store.selectedSlot == index,
                            accent: accentStore.accent
                        )
                        .onTapGesture {
                            let pkm = saveFile.partySlot(index)
                            if pkm != nil {
                                store.selectedSlot = index
                            } else {
                                pickerTarget = PickerTarget(location: .party, slot: index)
                            }
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
                        SpriteImage(fileName: pkm.spriteFileName)
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
                        SpriteImage(fileName: pkm.spriteFileName)
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
                        SpriteImage(fileName: pkm.spriteFileName)
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
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .fill(pkm.heldItem == 0 ? Color.white.opacity(0.15) : accent.color)
                                .frame(width: 8, height: 8)
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
