import PKHeXCore
import SwiftUI

struct DetailPanel: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    private var pkm: PKM? {
        guard let slot = store.selectedSlot else { return nil }
        return store.selectedLocation.slot(slot, in: saveFile)
    }

    var body: some View {
        Group {
            if let pkm {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(for: pkm)
                        legalityBadge(for: pkm)
                        statsSection(for: pkm)
                        movesSection(for: pkm)
                    }
                    .padding(16)
                }
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
            VStack(alignment: .leading) {
                Text("Species #\(pkm.species)")
                    .font(.title3.weight(.semibold))
                Text("Level \(pkm.level)")
                    .foregroundStyle(.secondary)
            }
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
                    Text("IV \(pkm.iv(stat))").frame(width: 60, alignment: .leading)
                    Text("EV \(pkm.ev(stat))")
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
                Text(pkm.move(index) == 0 ? "—" : "Move #\(pkm.move(index))")
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
