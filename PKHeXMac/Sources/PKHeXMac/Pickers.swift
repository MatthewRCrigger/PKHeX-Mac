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
