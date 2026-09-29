import PKHeXCore
import SwiftUI

// GRID picker sheets. Every sheet is a `PickerShell` (double frame, header, search, column header,
// rows, footer hint). Rows are `PickerRowStyle` buttons; data is mono, names are Rajdhani.

// MARK: - Shared row pieces

/// Amber mono `current` marker shown on the row that matches the value being replaced.
private struct CurrentTag: View {
    var body: some View {
        Text("current").font(Theme.mono(12)).foregroundStyle(Theme.amber)
    }
}

/// Name text in the GRID row style (Rajdhani 16/500).
private struct RowName: View {
    let text: String
    var color: Color = Theme.ink100
    var body: some View {
        Text(text).font(Theme.sans(16, .medium)).foregroundStyle(color).lineLimit(1)
    }
}

/// Mono data cell with a fixed width.
private struct MonoCell: View {
    let text: String
    var width: CGFloat
    var alignment: Alignment = .leading
    var color: Color = Theme.ink200
    var body: some View {
        Text(text)
            .font(Theme.mono(12))
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(width: width, alignment: alignment)
    }
}

/// 1 pt `line-300` bordered `surface-2` well for sprites and icons.
private struct SpriteWell<Content: View>: View {
    var width: CGFloat = 40
    var height: CGFloat = 36
    @ViewBuilder var content: Content
    var body: some View {
        ZStack { content.padding(2) }
            .frame(width: width, height: height)
            .background(Theme.surface2)
            .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
    }
}

// MARK: - Species picker

/// Modal sheet for choosing a species to fill an empty box/party slot. Opened by tapping an
/// empty tile/card in `BoxGridView`. Choosing a result creates a legal blank template of that
/// species via `SaveFile.createBlankPKM` and inserts it into the target slot.
struct SpeciesPickerSheet: View {
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

    private static func contextText(_ target: PickerTarget) -> String {
        let place: String
        switch target.location {
        case .party: place = "party"
        case .box(let index): place = "box\(pad(index + 1, 2))"
        }
        return "\(place) · slot \(pad(target.slot + 1, 2))"
    }

    var body: some View {
        let shown = results
        PickerShell(
            title: "Add", qualifier: "pokemon",
            context: Self.contextText(target),
            searchPrompt: "search species or #dex", searchText: $query, resultCount: shown.count,
            footerHint: "new entries start from a legal blank template",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Color.clear.frame(width: 40, height: 1)
                    Text("no.").frame(width: 44, alignment: .leading)
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("type").frame(width: 96, alignment: .trailing)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.id) { entry in
                        Button { onChoose(entry.id) } label: {
                            SpeciesRow(id: entry.id, name: entry.name, saveFile: saveFile)
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

private struct SpeciesRow: View {
    let id: UInt16
    let name: String
    let saveFile: SaveFile

    // Types and the sprite file name can only be discovered by creating a real PKM of this
    // species. We create one lazily for rows that are actually rendered, read off what we need,
    // and discard it immediately.
    @State private var types: [UInt8] = []
    @State private var spriteFileName: String?

    var body: some View {
        HStack(spacing: 8) {
            SpriteWell {
                if let spriteFileName { SpriteImage(fileName: spriteFileName) }
            }
            MonoCell(text: "#\(pad(Int(id)))", width: 44, color: Theme.ink300)
            RowName(text: name).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(types, id: \.self) { GridChip(text: typeCode(typeID: $0)) }
            }
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .onAppear {
            guard spriteFileName == nil, let blank = saveFile.createBlankPKM(species: id) else { return }
            types = blank.types
            spriteFileName = blank.spriteFileName
        }
    }
}

// MARK: - Move editor

/// Modal sheet for replacing one of a Pokémon's four moves. Opened by tapping a move row in
/// `DetailPanel`'s Moves tab.
struct MoveEditorSheet: View {
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

    var body: some View {
        let shown = results
        PickerShell(
            title: "Move \(pad(slotIndex + 1, 2))", qualifier: "replace",
            context: pkm.speciesName.lowercased(),
            searchPrompt: "search moves", searchText: $query, resultCount: shown.count,
            footerHint: "pp resets to max on replace",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("type").frame(width: 48, alignment: .leading)
                    Text("cat").frame(width: 36, alignment: .leading)
                    Text("pwr").frame(width: 36, alignment: .trailing)
                    Text("acc").frame(width: 36, alignment: .trailing)
                    Text("pp").frame(width: 56, alignment: .trailing)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.self) { moveID in
                        Button { onChoose(moveID) } label: {
                            MoveRow(moveID: moveID, pkm: pkm, slotIndex: slotIndex)
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

private struct MoveRow: View {
    let moveID: UInt16
    let pkm: PKM
    let slotIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                RowName(text: moveID == 0 ? "—" : PokemonNames.move(moveID))
                if moveID == pkm.move(slotIndex) { CurrentTag() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if moveID != 0 {
                    GridChip(text: typeCode(typeID: pkm.moveType(moveID)))
                } else {
                    Color.clear
                }
            }
            .frame(width: 48, alignment: .leading)

            // PKHeX.Core doesn't ship category/power/accuracy data for moves.
            MonoCell(text: "—", width: 36, color: Theme.ink300)
            MonoCell(text: "—", width: 36, alignment: .trailing, color: Theme.ink300)
            MonoCell(text: "—", width: 36, alignment: .trailing, color: Theme.ink300)
            MonoCell(text: ppText, width: 56, alignment: .trailing)
        }
    }

    private var ppText: String {
        guard moveID != 0 else { return "—" }
        if moveID == pkm.move(slotIndex) {
            return "\(pkm.movePP(slotIndex))/\(pkm.movePPMax(slotIndex))"
        }
        return "\(pkm.moveBasePP(moveID))/\(pkm.moveBasePP(moveID))"
    }
}

// MARK: - Nature picker

/// Modal sheet for choosing a Pokémon's nature. Lists all 25 with the boosted and reduced stat.
///
/// Nature IDs are `up*5 + dn` (PKHeX.Core's `NatureAmp.CreateNatureFromAmps`); equal up/down
/// indices are the five neutral natures.
struct NaturePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (UInt8) -> Void

    private static let statCodes = ["ATK", "DEF", "SPA", "SPD", "SPE"]

    var body: some View {
        PickerShell(
            title: "Nature", qualifier: "set",
            context: "\(pkm.speciesName.lowercased()) · \(pkm.natureName.lowercased())",
            footerHint: "+10% / −10% applied to stats",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("+10%").frame(width: 64, alignment: .leading)
                    Text("−10%").frame(width: 64, alignment: .leading)
                }
            },
            content: {
                ForEach(0..<25, id: \.self) { index in
                    let id = UInt8(index)
                    let up = index / 5
                    let dn = index % 5
                    let neutral = up == dn
                    Button { onChoose(id) } label: {
                        HStack(spacing: 8) {
                            HStack(spacing: 8) {
                                RowName(text: PokemonNames.nature(id))
                                if id == pkm.nature { CurrentTag() }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MonoCell(text: neutral ? "—" : "+\(Self.statCodes[up])", width: 64,
                                     color: neutral ? Theme.ink300 : Theme.ink100)
                            MonoCell(text: neutral ? "—" : "−\(Self.statCodes[dn])", width: 64,
                                     color: neutral ? Theme.ink300 : Theme.ink100)
                        }
                    }
                    .buttonStyle(PickerRowStyle())
                }
            }
        )
    }
}

// MARK: - Ability picker

/// Modal sheet for choosing a Pokémon's ability from its species/form's slots (Ability 1,
/// Ability 2, Hidden Ability — not every slot exists for every species/generation).
struct AbilityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (Int) -> Void

    /// Slots to display, collapsing duplicates: a species with one ability defined has Ability 1
    /// and Ability 2 pointing at the same ID, so only the first is shown. The selection still
    /// writes the original slot index the duplicate represents.
    private var slots: [(index: Int, id: UInt16, name: String, description: String)] {
        var seen = Set<UInt16>()
        return (0..<pkm.abilityCount).compactMap { index in
            let id = pkm.abilityID(at: index)
            guard seen.insert(id).inserted else { return nil }
            return (index: index, id: id, name: PokemonNames.ability(id), description: PokemonNames.abilityDescription(id))
        }
    }

    var body: some View {
        let shown = slots
        PickerShell(
            title: "Ability", qualifier: "set",
            context: "\(pkm.speciesName.lowercased()) · \(pkm.abilityName.lowercased())",
            footerHint: "only this species' slots are listed",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("slot").frame(width: 96, alignment: .leading)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.index) { slot in
                        Button { onChoose(slot.index) } label: {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        RowName(text: slot.name)
                                        if slot.id == pkm.ability { CurrentTag() }
                                    }
                                    if !slot.description.isEmpty {
                                        Text(slot.description)
                                            .font(Theme.sans(14, .regular))
                                            .foregroundStyle(Theme.ink300)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                MonoCell(
                                    text: slot.index >= 2 ? "hidden" : "ability \(slot.index + 1)",
                                    width: 96,
                                    color: slot.index >= 2 ? Theme.violet : Theme.ink200
                                )
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

// MARK: - Ball picker

/// Modal sheet for choosing which Poké Ball a Pokémon was caught in. Only reachable when
/// `PKM.supportsBall` is true (Gen 3+).
struct BallPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let onChoose: (UInt8) -> Void

    var body: some View {
        PickerShell(
            title: "Ball", qualifier: "set",
            context: "\(pkm.speciesName.lowercased()) · \(pkm.ballName.lowercased())",
            footerHint: "legality re-checks on assign",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Color.clear.frame(width: 32, height: 1)
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("note").frame(width: 96, alignment: .trailing)
                }
            },
            content: {
                ForEach(UInt8(0)...37, id: \.self) { ballID in
                    Button { onChoose(ballID) } label: {
                        HStack(spacing: 8) {
                            SpriteWell(width: 32, height: 32) {
                                BallIcon(ball: ballID)
                            }
                            RowName(text: PokemonNames.ball(ballID))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if ballID == pkm.ball {
                                CurrentTag()
                            } else {
                                MonoCell(text: "#\(pad(Int(ballID), 2))", width: 96, alignment: .trailing, color: Theme.ink300)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PickerRowStyle())
                }
            }
        )
    }
}

// MARK: - Held item picker

/// Modal sheet for choosing a Pokémon's held item. Every item id 1...`PKM.maxItemID` is offered,
/// filtered by a search field. Choosing "None" (id 0) clears the held item.
struct HeldItemPickerSheet: View {
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
        let shown = results
        PickerShell(
            title: "Held", qualifier: "item",
            context: "\(pkm.speciesName.lowercased()) · \(pkm.heldItem == 0 ? "none" : pkm.heldItemName.lowercased())",
            searchPrompt: "search items", searchText: $query, resultCount: shown.count,
            footerHint: "legality re-checks on assign",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Color.clear.frame(width: 34, height: 1)
                    Text("name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("current").frame(width: 64, alignment: .trailing)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.id) { entry in
                        Button { onChoose(entry.id) } label: {
                            HeldItemRow(id: entry.id, name: entry.name, isSelected: entry.id == pkm.heldItem)
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

private struct HeldItemRow: View {
    let id: UInt16
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            SpriteWell(width: 34, height: 34) {
                if id != 0 { ItemIconImage(itemID: Int(id)) }
            }
            RowName(text: name).frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if isSelected { CurrentTag() } else { Color.clear }
            }
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Met/Egg location picker

/// Modal sheet for choosing a Met or Egg Location. Options come from `PKM.locationOptions(egg:)`,
/// which mirrors PKHeX.WinForms' location combo contents (version + context partitioned).
struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let egg: Bool
    let onChoose: (UInt16) -> Void

    @State private var query = ""

    private var currentLocation: UInt16 { egg ? pkm.eggLocation : pkm.metLocation }
    private var currentName: String { egg ? pkm.eggLocationName : pkm.metLocationName }

    private var results: [(id: UInt16, name: String)] {
        let all = pkm.locationOptions(egg: egg)
        guard !query.isEmpty else { return all }
        let lowered = query.lowercased()
        return all.filter { $0.name.lowercased().contains(lowered) }
    }

    var body: some View {
        let shown = results
        PickerShell(
            title: egg ? "Egg" : "Met", qualifier: "location",
            context: "\(pkm.speciesName.lowercased()) · \(currentLocation == 0 ? "—" : currentName.lowercased())",
            searchPrompt: "search locations", searchText: $query, resultCount: shown.count,
            footerHint: "partitioned by game version",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("no.").frame(width: 56, alignment: .leading)
                    Text("location").frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.id) { entry in
                        Button { onChoose(entry.id) } label: {
                            HStack(spacing: 8) {
                                MonoCell(text: pad(Int(entry.id), 3), width: 56, color: Theme.ink300)
                                RowName(text: entry.name).frame(maxWidth: .infinity, alignment: .leading)
                                if entry.id == currentLocation { CurrentTag() }
                            }
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

// MARK: - Met/Egg date picker

/// Small popover with a graphical `DatePicker` — used by the Met Date and Egg Date cells in
/// `DetailPanel`'s Met tab. Includes a "Clear" action since an unset date is a valid state.
struct DatePickerPopover: View {
    let components: DateComponents?
    let onChoose: (DateComponents?) -> Void

    @State private var selection: Date

    init(components: DateComponents?, onChoose: @escaping (DateComponents?) -> Void) {
        self.components = components
        self.onChoose = onChoose
        let calendar = Calendar(identifier: .gregorian)
        _selection = State(initialValue: components.flatMap(calendar.date(from:)) ?? Date())
    }

    var body: some View {
        VStack(spacing: 10) {
            DatePicker("", selection: $selection, in: Date(timeIntervalSince1970: 946684800)...Date(timeIntervalSince1970: 4102358400), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Theme.amber)
                .font(Theme.mono(12))
                .onChange(of: selection) { _, newValue in
                    let calendar = Calendar(identifier: .gregorian)
                    onChoose(calendar.dateComponents([.year, .month, .day], from: newValue))
                }

            GridButton("Clear date", .secondary, size: .sm) {
                onChoose(nil)
            }
        }
        .padding(12)
        .background(Theme.surface1)
        .overlay(Rectangle().strokeBorder(Theme.line100, lineWidth: 1))
    }
}

// MARK: - Memory picker

/// Modal sheet for choosing and configuring a Memory (OT or HT depending on `target`). Two steps in
/// one sheet: pick a memory ID from a searchable list, then configure Intensity/Feeling/Variable.
struct MemoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pkm: PKM
    let target: MemoryTarget
    let onCommit: () -> Void

    @State private var query = ""
    @State private var selectedMemory: UInt8?

    private var currentMemory: UInt8 {
        target == .originalTrainer ? pkm.originalTrainerMemory : pkm.handlingTrainerMemory
    }

    private var results: [(id: UInt8, line: String)] {
        let all = pkm.memoryIDOptions.map { (id: $0, line: $0 == 0 ? "No memory" : pkm.memoryLine($0)) }
        guard !query.isEmpty else { return all }
        let lowered = query.lowercased()
        return all.filter { $0.line.lowercased().contains(lowered) }
    }

    private var titleText: String { target == .originalTrainer ? "OT Memory" : "HT Memory" }

    var body: some View {
        if let memory = selectedMemory ?? (currentMemory != 0 ? currentMemory : nil) {
            PickerShell(
                title: titleText, qualifier: "edit",
                context: pkm.speciesName.lowercased(),
                footerHint: "intensity, feeling and variable are stored with the memory",
                onClose: { dismiss() },
                content: {
                    MemoryDetailView(pkm: pkm, target: target, memoryID: memory, onBack: {
                        selectedMemory = nil
                    }, onCommit: onCommit)
                    .id(memory)
                }
            )
        } else {
            memoryList
        }
    }

    private var memoryList: some View {
        let shown = results
        return PickerShell(
            title: titleText, qualifier: "set",
            context: pkm.speciesName.lowercased(),
            searchPrompt: "search memories", searchText: $query, resultCount: shown.count,
            footerHint: "then set intensity, feeling and variable",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("id").frame(width: 40, alignment: .leading)
                    Text("memory").frame(maxWidth: .infinity, alignment: .leading)
                }
            },
            content: {
                if shown.isEmpty {
                    PickerEmptyState()
                } else {
                    ForEach(shown, id: \.id) { entry in
                        Button { selectedMemory = entry.id } label: {
                            HStack(spacing: 8) {
                                MonoCell(text: pad(Int(entry.id), 3), width: 40, color: Theme.ink300)
                                Text(entry.line)
                                    .font(Theme.sans(16, .medium))
                                    .foregroundStyle(Theme.ink100)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if entry.id == currentMemory { CurrentTag() }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PickerRowStyle())
                    }
                }
            }
        )
    }
}

/// Second step of `MemoryPickerSheet`: configure Intensity/Feeling/Variable for the chosen memory
/// ID, then commit. `Variable`'s meaning depends on `PKM.memoryVariableArgType`.
private struct MemoryDetailView: View {
    let pkm: PKM
    let target: MemoryTarget
    let memoryID: UInt8
    let onBack: () -> Void
    let onCommit: () -> Void

    @State private var intensity: Int
    @State private var feeling: Int
    @State private var variable: UInt16

    init(pkm: PKM, target: MemoryTarget, memoryID: UInt8, onBack: @escaping () -> Void, onCommit: @escaping () -> Void) {
        self.pkm = pkm
        self.target = target
        self.memoryID = memoryID
        self.onBack = onBack
        self.onCommit = onCommit
        let isCurrent = (target == .originalTrainer ? pkm.originalTrainerMemory : pkm.handlingTrainerMemory) == memoryID
        if isCurrent {
            _intensity = State(initialValue: Int(target == .originalTrainer ? pkm.originalTrainerMemoryIntensity : pkm.handlingTrainerMemoryIntensity))
            _feeling = State(initialValue: Int(target == .originalTrainer ? pkm.originalTrainerMemoryFeeling : pkm.handlingTrainerMemoryFeeling))
            _variable = State(initialValue: target == .originalTrainer ? pkm.originalTrainerMemoryVariable : pkm.handlingTrainerMemoryVariable)
        } else {
            let minIntensity = Int(pkm.memoryMinimumIntensity(memoryID))
            _intensity = State(initialValue: max(minIntensity, 1))
            _feeling = State(initialValue: 0)
            _variable = State(initialValue: 0)
        }
    }

    private var argType: UInt8 { pkm.memoryVariableArgType(memoryID) }

    private var variableName: String {
        let name = pkm.memoryVariableName(memoryID, variable: variable)
        return name.isEmpty ? "#\(variable)" : name
    }

    private var variableBinding: Binding<Int> {
        Binding(
            get: { Int(variable) },
            set: { variable = UInt16(max(0, min($0, 65535))) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview well.
            VStack(alignment: .leading, spacing: 6) {
                GridText("preview", .label, color: Theme.ink300)
                Text(memoryID == 0 ? "No memory" : pkm.memoryLine(memoryID))
                    .font(Theme.sans(16, .medium))
                    .foregroundStyle(Theme.ink100)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2)
            .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))

            if memoryID != 0 {
                VStack(spacing: 0) {
                    detailRow("intensity", note: nil) {
                        GridStepper(
                            value: $intensity,
                            range: Int(pkm.memoryMinimumIntensity(memoryID))...7,
                            digits: 1
                        )
                    }
                    detailRow("feeling", note: nil) {
                        GridStepper(value: $feeling, range: 0...23, digits: 2)
                    }
                    if argType != 0 {
                        detailRow("variable", note: variableName) {
                            GridStepper(value: variableBinding, range: 0...65535, digits: 5)
                        }
                    }
                }
                .overlay(alignment: .top) { HRule(color: Theme.line400) }
            }

            HStack(spacing: 8) {
                GridButton("◄ Choose a different memory", .ghost, action: onBack)
                Spacer()
                GridButton("Save", .primary, action: save)
            }
            .padding(.top, 4)
        }
        .padding(16)
    }

    private func detailRow<Control: View>(_ label: String, note: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 8) {
            GridText(label, .label, color: Theme.ink300)
                .frame(width: 96, alignment: .leading)
            if let note {
                Text(note)
                    .font(Theme.sans(16, .medium))
                    .foregroundStyle(Theme.ink200)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            control()
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { HRule(color: Theme.line400) }
    }

    private func save() {
        if target == .originalTrainer {
            pkm.originalTrainerMemory = memoryID
            pkm.originalTrainerMemoryIntensity = UInt8(intensity)
            pkm.originalTrainerMemoryFeeling = UInt8(feeling)
            pkm.originalTrainerMemoryVariable = variable
        } else {
            pkm.handlingTrainerMemory = memoryID
            pkm.handlingTrainerMemoryIntensity = UInt8(intensity)
            pkm.handlingTrainerMemoryFeeling = UInt8(feeling)
            pkm.handlingTrainerMemoryVariable = variable
        }
        onCommit()
    }
}
