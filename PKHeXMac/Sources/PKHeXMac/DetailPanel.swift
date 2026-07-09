import PKHeXCore
import SwiftUI

struct DetailPanel: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    @State private var refreshToken = 0

    private var pkm: PKM? {
        guard case .slots(let location) = store.selectedSidebarItem, let slot = store.selectedSlot else { return nil }
        return location.slot(slot, in: saveFile)
    }

    var body: some View {
        Group {
            if let pkm {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(for: pkm)
                        nicknameField(for: pkm)
                        legalityBadge(for: pkm)
                        statsSection(for: pkm)
                        movesSection(for: pkm)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(refreshToken)
            } else {
                Text("Select a Pokémon")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.background)
    }

    @ViewBuilder
    private func header(for pkm: PKM) -> some View {
        HStack(spacing: 12) {
            SpriteImage(fileName: pkm.spriteFileName)
                .frame(width: 68, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(pkm.speciesName)
                    .font(.title3.weight(.semibold))
                EditableNumberField(label: "Level", value: Int(pkm.level), range: 1...100) { newValue in
                    pkm.level = UInt8(newValue)
                    refreshToken += 1
                }
                Text(pkm.natureName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func nicknameField(for pkm: PKM) -> some View {
        EditableTextField(
            "Nickname",
            value: pkm.nickname,
            maxLength: pkm.maxNicknameLength
        ) { newValue in
            pkm.nickname = newValue
            refreshToken += 1
        }
    }

    @ViewBuilder
    private func legalityBadge(for pkm: PKM) -> some View {
        Label(pkm.isLegal ? "Legal" : "Flagged", systemImage: pkm.isLegal ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(pkm.isLegal ? .green : .orange)
            .font(.callout.weight(.medium))
    }

    @ViewBuilder
    private func statsSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IVs / EVs").font(.headline)
            ForEach(Stat.allCases, id: \.self) { stat in
                HStack {
                    Text(label(for: stat)).frame(width: 90, alignment: .leading)
                    StatValueField(prefix: "IV", value: Int(pkm.iv(stat)), range: 0...31) { newValue in
                        pkm.setIV(stat, to: Int32(newValue))
                        refreshToken += 1
                    }
                    .frame(width: 90, alignment: .leading)
                    StatValueField(prefix: "EV", value: Int(pkm.ev(stat)), range: 0...252) { newValue in
                        pkm.setEV(stat, to: Int32(newValue))
                        refreshToken += 1
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private func movesSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Moves").font(.headline)
            ForEach(0..<4, id: \.self) { index in
                let move = pkm.move(index)
                HStack {
                    Text(move == 0 ? "—" : PokemonNames.move(move))
                        .frame(width: 140, alignment: .leading)
                    if move != 0 {
                        Text("PP \(pkm.movePP(index))/\(pkm.movePPMax(index))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func label(for stat: Stat) -> String {
        switch stat {
        case .hp: return "HP"
        case .attack: return "Attack"
        case .defense: return "Defense"
        case .specialAttack: return "Sp. Atk"
        case .specialDefense: return "Sp. Def"
        case .speed: return "Speed"
        }
    }
}
