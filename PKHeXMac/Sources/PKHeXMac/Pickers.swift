import PKHeXCore
import SwiftUI

// MARK: - Species picker (§6)

/// Modal sheet for choosing a species to fill an empty box/party slot. Opened by tapping an
/// empty tile/card in `BoxGridView`. Choosing a result creates a legal blank template of that
/// species via `SaveFile.createBlankPKM` and inserts it into the target slot.
struct SpeciesPickerSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let saveFile: SaveFile
    let target: PickerTarget
    let onChoose: (UInt16) -> Void

    @State private var query = ""

    private var results: [(id: UInt16, name: String)] {
        let all = (1...max(saveFile.maxSpeciesID, 1)).map { (id: UInt16($0), name: PokemonNames.species(UInt16($0))) }
        guard !query.isEmpty else { return all }
        let lowered = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(lowered) || String($0.id).contains(lowered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Text("Add Pokémon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("to \(target.location.title) · slot \(target.slot + 1)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Theme.bgElevated2)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(accentStore.accent.color)
                    TextField("Search species or #dex…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    Text("\(results.count) results")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Theme.bgContent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accentStore.accent.color, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results, id: \.id) { entry in
                        SpeciesRow(id: entry.id, name: entry.name, saveFile: saveFile)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onChoose(entry.id)
                            }
                    }
                }
                .padding(8)

                if results.isEmpty {
                    Text("No species match \u{201c}\(query)\u{201d}.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(30)
                }
            }

            Text("New entries start from a legal blank template.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5)
                }
        }
        .frame(width: 560, height: 520)
        .background(Theme.bgTile)
    }
}

private struct SpeciesRow: View {
    let id: UInt16
    let name: String
    let saveFile: SaveFile

    // Types and the sprite file name can only be discovered by creating a real PKM of this
    // species (there is no species->types or species->sprite lookup independent of a PKM
    // instance). We create one lazily, only for rows that are actually rendered/visible, read
    // off what we need, and discard the instance immediately — it's never inserted anywhere.
    @State private var types: [UInt8] = []
    @State private var spriteFileName: String?

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgContent)
                    .frame(width: 44, height: 40)
                if let spriteFileName {
                    SpriteImage(fileName: spriteFileName)
                        .padding(4)
                        .frame(width: 44, height: 40)
                }
            }
            Text(String(format: "#%03d", id))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 40, alignment: .leading)
            Text(name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 5) {
                ForEach(types, id: \.self) { typeID in
                    TypeBadge(typeID: typeID)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            guard spriteFileName == nil, let blank = saveFile.createBlankPKM(species: id) else { return }
            types = blank.types
            spriteFileName = blank.spriteFileName
        }
    }
}

// MARK: - Move editor (§7)

/// Modal sheet for replacing one of a Pokémon's four moves. Opened by tapping a move row in
/// `DetailPanel`'s Moves tab.
struct MoveEditorSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let slotIndex: Int
    let onChoose: (UInt16) -> Void

    @State private var query = ""

    private var candidateMoves: [UInt16] {
        var options = Set(pkm.legalMoves)
        options.insert(0)
        return options.sorted { lhs, rhs in
            if lhs == 0 { return true }
            if rhs == 0 { return false }
            return PokemonNames.move(lhs) < PokemonNames.move(rhs)
        }
    }

    private var results: [UInt16] {
        guard !query.isEmpty else { return candidateMoves }
        let lowered = query.lowercased()
        return candidateMoves.filter {
            $0 == 0 ? "—".contains(lowered) : PokemonNames.move($0).lowercased().contains(lowered)
        }
    }

    private var currentMoveName: String {
        let current = pkm.move(slotIndex)
        return current == 0 ? "—" : PokemonNames.move(current)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Text("Change move \(slotIndex + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(pkm.speciesName) · replacing \(currentMoveName)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Theme.bgElevated2)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(accentStore.accent.color)
                    TextField("Search moves…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    Text("\(results.count) moves")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Theme.bgContent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accentStore.accent.color, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Column header. There's no exposed category/power/accuracy lookup API
                // (PokemonNames only resolves display names), so those columns show "—".
                HStack(spacing: 12) {
                    Text("MOVE").frame(width: 168, alignment: .leading)
                    Text("CAT").frame(width: 70, alignment: .leading)
                    Text("PWR").frame(width: 54, alignment: .trailing)
                    Text("ACC").frame(width: 54, alignment: .trailing)
                    Text("PP").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results, id: \.self) { moveID in
                        MoveRow(moveID: moveID, pkm: pkm, slotIndex: slotIndex)
                            .contentShape(Rectangle())
                            .onTapGesture { onChoose(moveID) }
                    }
                }
                .padding(8)

                if results.isEmpty {
                    Text("No moves match \u{201c}\(query)\u{201d}.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(30)
                }
            }
        }
        .frame(width: 600, height: 540)
        .background(Theme.bgTile)
    }
}

// MARK: - Nature picker

/// Modal sheet for choosing a Pokémon's nature via the increased/decreased-stat grid (row =
/// increased stat, column = decreased stat, diagonal = neutral). Opened by tapping the Nature
/// card in `DetailPanel`'s Summary tab.
///
/// The grid is built from PKHeX.Core's real nature/stat-amp data
/// (vendor/PKHeX/PKHeX.Core/Editing/NatureAmp.cs's `Table`), not hardcoded — each cell's nature is
/// derived from which stat is actually amplified/reduced for that nature, cross-checked against
/// well-known nature facts (Adamant = +Atk/-SpAtk, Timid = +Speed/-Atk, Jolly = +Speed/-SpAtk,
/// Modest = +SpAtk/-Atk, Bold = +Def/-Atk — all confirmed to match). Building the grid this way
/// (from real up/down stat pairs) rather than from raw nature-ID arithmetic matters for getting
/// the 5 neutral (diagonal) natures — Hardy/Docile/Serious/Bashful/Quirky — in the right cells.
struct NaturePickerSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (UInt8) -> Void

    private static let statLabels = ["Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]

    /// nature[up][dn] = nature ID for "increase `up`, decrease `dn`" (up == dn is neutral).
    /// Values are `up*5 + dn`, matching PKHeX.Core's `NatureAmp.CreateNatureFromAmps`.
    private static let natureID: [[UInt8]] = (0..<5).map { up in
        (0..<5).map { dn in UInt8(up * 5 + dn) }
    }

    private var currentUpDn: (up: Int, dn: Int)? {
        let n = Int(pkm.nature)
        guard n >= 0, n < 25 else { return nil }
        return (n / 5, n % 5)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Change Nature")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pkm.speciesName) · currently \(pkm.natureName)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.bgElevated2)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                gridHeaderRow
                ForEach(0..<5, id: \.self) { up in
                    gridRow(up: up)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)

            Text("Rows raise a stat 10%; columns lower a stat 10%. Diagonal natures are neutral.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5)
                }
        }
        .frame(width: 620)
        .background(Theme.bgTile)
    }

    private var gridHeaderRow: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 88, height: 1)
            ForEach(0..<5, id: \.self) { dn in
                Text("↓ \(Self.statLabels[dn])")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    private func gridRow(up: Int) -> some View {
        HStack(spacing: 4) {
            Text("↑ \(Self.statLabels[up])")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 88, alignment: .leading)

            ForEach(0..<5, id: \.self) { dn in
                let nature = Self.natureID[up][dn]
                let isNeutral = up == dn
                let isSelected = currentUpDn.map { $0.up == up && $0.dn == dn } ?? false
                Button {
                    onChoose(nature)
                } label: {
                    Text(PokemonNames.nature(nature))
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? accentStore.accent.onAccent : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected
                                ? accentStore.accent.color
                                : (isNeutral ? Theme.bgElevated3 : Theme.bgElevated1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(isSelected ? accentStore.accent.color : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Ability picker

/// Modal sheet for choosing a Pokémon's ability from its species/form's slots (Ability 1,
/// Ability 2, Hidden Ability — not every slot exists for every species/generation). Opened by
/// tapping the Ability card in `DetailPanel`'s Summary tab. Small enough (0-3 options) to show as
/// a plain vertical list of labeled rows rather than the search-filtered list pattern used by
/// `HeldItemPickerSheet`.
struct AbilityPickerSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (Int) -> Void

    private static let slotLabels = ["Ability 1", "Ability 2", "Hidden Ability"]

    private var slots: [(index: Int, id: UInt16, name: String, description: String)] {
        (0..<pkm.abilityCount).map { index in
            let id = pkm.abilityID(at: index)
            return (index: index, id: id, name: PokemonNames.ability(id), description: PokemonNames.abilityDescription(id))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Change Ability")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pkm.speciesName) · currently \(pkm.abilityName)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.bgElevated2)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(spacing: 6) {
                ForEach(slots, id: \.index) { slot in
                    let isSelected = slot.id == pkm.ability
                    Button {
                        onChoose(slot.index)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(Self.slotLabels[slot.index])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? accentStore.accent.onAccent.opacity(0.8) : Theme.textSecondary)
                                .frame(width: 110, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.name)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(isSelected ? accentStore.accent.onAccent : Theme.textPrimary)
                                if !slot.description.isEmpty {
                                    Text(slot.description)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(isSelected ? accentStore.accent.onAccent.opacity(0.85) : Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(accentStore.accent.onAccent)
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(isSelected ? accentStore.accent.color : Theme.bgElevated1)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(isSelected ? accentStore.accent.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if slots.isEmpty {
                    Text("This Pokémon's format has no selectable abilities.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 480)
        .background(Theme.bgTile)
    }
}

// MARK: - Ball picker (§8)

/// Modal sheet for choosing which Poké Ball a Pokémon was caught in. Opened by tapping the Ball
/// row in `DetailPanel`'s Summary tab. Only reachable when `PKM.supportsBall` is true (Gen 3+);
/// small enough (38 values) to show as a plain grid rather than the search-filtered list pattern
/// used by `SpeciesPickerSheet`/`MoveEditorSheet`.
struct BallPickerSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (UInt8) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Change Ball")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pkm.speciesName) · currently \(pkm.ballName)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.bgElevated2)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(UInt8(0)...37, id: \.self) { ballID in
                        BallOptionCell(ballID: ballID, isSelected: ballID == pkm.ball)
                            .contentShape(Rectangle())
                            .onTapGesture { onChoose(ballID) }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 520, height: 480)
        .background(Theme.bgTile)
    }
}

private struct BallOptionCell: View {
    @EnvironmentObject private var accentStore: AccentStore

    let ballID: UInt8
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            BallIcon(ball: ballID)
                .frame(width: 32, height: 32)
            Text(PokemonNames.ball(ballID))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(isSelected ? Theme.bgElevated3 : Theme.bgElevated1)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isSelected ? accentStore.accent.color : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Held item picker

/// Modal sheet for choosing a Pokémon's held item. Opened by tapping the Held Item card in
/// `DetailPanel`'s Summary tab. Every item id 1...`PKM.maxItemID` is offered (there's no "legal
/// held items" analyzer the way there is for moves), filtered by a search field like
/// `SpeciesPickerSheet`. Choosing "None" (id 0) clears the held item.
struct HeldItemPickerSheet: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (UInt16) -> Void

    @State private var query = ""

    private var results: [(id: UInt16, name: String)] {
        let all = [(id: UInt16(0), name: "None")]
            + (1...max(pkm.maxItemID, 1)).map { (id: $0, name: pkm.itemName($0)) }
        guard !query.isEmpty else { return all }
        let lowered = query.lowercased()
        return all.filter { $0.name.lowercased().contains(lowered) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Text("Change held item")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(pkm.speciesName) · currently \(pkm.heldItem == 0 ? "None" : pkm.heldItemName)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Theme.bgElevated2)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(accentStore.accent.color)
                    TextField("Search items…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    Text("\(results.count) results")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Theme.bgContent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accentStore.accent.color, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results, id: \.id) { entry in
                        HeldItemRow(id: entry.id, name: entry.name, isSelected: entry.id == pkm.heldItem)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onChoose(entry.id)
                            }
                    }
                }
                .padding(8)

                if results.isEmpty {
                    Text("No items match \u{201c}\(query)\u{201d}.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(30)
                }
            }
        }
        .frame(width: 560, height: 520)
        .background(Theme.bgTile)
    }
}

private struct HeldItemRow: View {
    @EnvironmentObject private var accentStore: AccentStore

    let id: UInt16
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgContent)
                    .frame(width: 34, height: 34)
                if id != 0 {
                    ItemIconImage(itemID: Int(id))
                        .padding(4)
                        .frame(width: 34, height: 34)
                }
            }
            Text(name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentStore.accent.color)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(isSelected ? accentStore.accent.soft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MoveRow: View {
    @EnvironmentObject private var accentStore: AccentStore

    let moveID: UInt16
    let pkm: PKM
    let slotIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 9, height: 9)
                Text(moveID == 0 ? "—" : PokemonNames.move(moveID))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 168, alignment: .leading)

            // No move category/power/accuracy lookup API is exposed — shown as placeholders.
            Text("—")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text("—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                .frame(width: 54, alignment: .trailing)
            Text("—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                .frame(width: 54, alignment: .trailing)
            Text(ppText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(accentStore.accent.bright)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var ppText: String {
        guard moveID != 0 else { return "—" }
        if moveID == pkm.move(slotIndex) {
            return "\(pkm.movePP(slotIndex))/\(pkm.movePPMax(slotIndex))"
        }
        return "—"
    }
}
