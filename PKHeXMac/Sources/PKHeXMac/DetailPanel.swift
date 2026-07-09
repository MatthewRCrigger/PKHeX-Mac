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

    /// Writes a mutated `pkm` back into its slot, since each `PKM` handle is a snapshot
    /// deserialized fresh from the save's byte buffer — edits made on it are otherwise discarded
    /// the next time this panel re-reads the slot (e.g. on the next SwiftUI re-render).
    private func commit(_ pkm: PKM) {
        guard case .slots(let location) = store.selectedSidebarItem, let slot = store.selectedSlot else { return }
        switch location {
        case .party: saveFile.setPartySlot(pkm, index: slot)
        case .box(let box): saveFile.setSlot(pkm, box: box, slot: slot)
        }
        store.markDirty()
        refreshToken += 1
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
                    commit(pkm)
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
            commit(pkm)
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
                        commit(pkm)
                    }
                    .frame(width: 90, alignment: .leading)
                    StatValueField(prefix: "EV", value: Int(pkm.ev(stat)), range: 0...252) { newValue in
                        pkm.setEV(stat, to: Int32(newValue))
                        commit(pkm)
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private func movesSection(for pkm: PKM) -> some View {
        let options = moveOptions(for: pkm)
        VStack(alignment: .leading, spacing: 6) {
            Text("Moves").font(.headline)
            ForEach(0..<4, id: \.self) { index in
                let move = pkm.move(index)
                HStack {
                    Picker("", selection: Binding(
                        get: { move },
                        set: { newValue in
                            guard newValue != move else { return }
                            pkm.setMove(index, to: newValue)
                            commit(pkm)
                        }
                    )) {
                        ForEach(options, id: \.self) { moveID in
                            Text(moveID == 0 ? "—" : PokemonNames.move(moveID)).tag(moveID)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160, alignment: .leading)
                    if move != 0 {
                        Text("PP \(pkm.movePP(index))/\(pkm.movePPMax(index))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    /// Legal moves for `pkm`, plus its current 4 moves and a "—" placeholder so the picker always
    /// contains whatever is currently equipped even if legality analysis wouldn't otherwise permit it.
    private func moveOptions(for pkm: PKM) -> [UInt16] {
        var options = Set(pkm.legalMoves)
        options.formUnion(pkm.moves)
        options.insert(0)
        return options.sorted { $0 == 0 ? true : $1 == 0 ? false : PokemonNames.move($0) < PokemonNames.move($1) }
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
