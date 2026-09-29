import PKHeXCore
import SwiftUI

private enum InspectorTab: String, CaseIterable {
    case summary = "Summary"
    case stats = "Stats"
    case moves = "Moves"
    case met = "Met"
    case trainer = "Trainer"
}

struct DetailPanel: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var profileStore: PanelProfileStore
    let saveFile: SaveFile

    @State private var refreshToken = 0
    @State private var activeTab: InspectorTab = .summary
    @State private var movePickerSlot: Int?
    @State private var isBallPickerPresented = false
    @State private var isStatusPickerPresented = false
    @State private var isHeldItemPickerPresented = false
    @State private var isNaturePickerPresented = false
    @State private var isAbilityPickerPresented = false
    @State private var metLocationPickerPresented = false
    @State private var eggLocationPickerPresented = false
    @State private var isMetDatePickerPresented = false
    @State private var isEggDatePickerPresented = false
    @State private var isLegalityExpanded = false
    @State private var isMemoryPickerPresented = false
    @State private var memoryPickerTarget: MemoryTarget?

    private var pkm: PKM? {
        guard let inspected = store.inspectedSlot else { return nil }
        return inspected.location.slot(inspected.index, in: saveFile)
    }

    /// Writes a mutated `pkm` back into its slot, since each `PKM` handle is a snapshot
    /// deserialized fresh from the save's byte buffer — edits made on it are otherwise discarded
    /// the next time this panel re-reads the slot (e.g. on the next SwiftUI re-render).
    private func commit(_ pkm: PKM) {
        guard let inspected = store.inspectedSlot else { return }
        switch inspected.location {
        case .party: saveFile.setPartySlot(pkm, index: inspected.index)
        case .box(let box): saveFile.setSlot(pkm, box: box, slot: inspected.index)
        }
        store.markDirty()
        refreshToken += 1
    }

    var body: some View {
        Group {
            if let pkm {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(for: pkm)
                        legalityBanner(for: pkm)
                        tabBar
                        Group {
                            switch activeTab {
                            case .summary: summaryTab(for: pkm)
                            case .stats: statsTab(for: pkm)
                            case .moves: movesTab(for: pkm)
                            case .met: metTab(for: pkm)
                            case .trainer: trainerTab(for: pkm)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                }
                .id(refreshToken)
            } else if store.inspectedSlot != nil {
                VStack(spacing: 8) {
                    GridText("Empty slot", .label, color: Theme.ink300)
                    Text(store.copiedPKM != nil ? "⌘V to paste, or right-click to add a Pokémon." : "Right-click to add a Pokémon.")
                        .font(Theme.sans(14, .regular))
                        .foregroundStyle(Theme.ink300)
                }
                .multilineTextAlignment(.center)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    GridText("No slot selected", .label, color: Theme.ink300)
                    Text("Select a Pokémon to inspect and edit.")
                        .font(Theme.sans(14, .regular))
                        .foregroundStyle(Theme.ink300)
                }
                .multilineTextAlignment(.center)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface1)
        .sheet(isPresented: Binding(
            get: { movePickerSlot != nil },
            set: { if !$0 { movePickerSlot = nil } }
        )) {
            if let pkm, let slot = movePickerSlot {
                MoveEditorSheet(pkm: pkm, slotIndex: slot) { newMove in
                    pkm.setMove(slot, to: newMove)
                    commit(pkm)
                    movePickerSlot = nil
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $isBallPickerPresented) {
            if let pkm {
                BallPickerSheet(pkm: pkm) { newBall in
                    pkm.ball = newBall
                    commit(pkm)
                    isBallPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $isHeldItemPickerPresented) {
            if let pkm {
                HeldItemPickerSheet(pkm: pkm) { newItem in
                    pkm.heldItem = newItem
                    commit(pkm)
                    isHeldItemPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $isNaturePickerPresented) {
            if let pkm {
                NaturePickerSheet(pkm: pkm) { newNature in
                    pkm.nature = newNature
                    commit(pkm)
                    isNaturePickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $isAbilityPickerPresented) {
            if let pkm {
                AbilityPickerSheet(pkm: pkm) { newIndex in
                    pkm.setAbilityIndex(newIndex)
                    commit(pkm)
                    isAbilityPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $metLocationPickerPresented) {
            if let pkm {
                LocationPickerSheet(pkm: pkm, egg: false) { newLocation in
                    pkm.metLocation = newLocation
                    commit(pkm)
                    metLocationPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $eggLocationPickerPresented) {
            if let pkm {
                LocationPickerSheet(pkm: pkm, egg: true) { newLocation in
                    pkm.eggLocation = newLocation
                    commit(pkm)
                    eggLocationPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
        .sheet(isPresented: $isMemoryPickerPresented) {
            if let pkm, let target = memoryPickerTarget {
                MemoryPickerSheet(pkm: pkm, target: target) {
                    commit(pkm)
                    isMemoryPickerPresented = false
                }
                .environmentObject(profileStore)
            }
        }
    }

    // MARK: - Header

    private var slotLocationString: String {
        guard let inspected = store.inspectedSlot else { return "" }
        let slot = pad(inspected.index + 1, 2)
        switch inspected.location {
        case .party: return "party · \(slot)"
        case .box(let box): return "box\(pad(box + 1, 2)) · \(slot)"
        }
    }

    @ViewBuilder
    private func header(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Inspect", qualifier: "PKM") {
                Text(slotLocationString)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.ink300)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Theme.surface2
                    ArtworkImage(pkm: pkm)
                        .padding(6)
                    if pkm.isShiny {
                        StatusDot(color: Theme.violet)
                            .padding(6)
                    }
                }
                .frame(width: 76, height: 68)
                .overlay(Rectangle().strokeBorder(Theme.line200, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    NicknameField(pkm: pkm) { newValue in
                        pkm.nickname = newValue
                        commit(pkm)
                    }
                    Text(metaLine(for: pkm))
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.ink200)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        TypeChips(typeIDs: pkm.types)
                        if pkm.isShiny {
                            GridBadge(text: "Shiny", color: Theme.violet, showsDot: false)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func metaLine(for pkm: PKM) -> String {
        var parts = [pkm.speciesName.lowercased(), "L\(pad(Int(pkm.level)))", pkm.natureName.lowercased()]
        switch pkm.gender {
        case 0: parts.append("m")
        case 1: parts.append("f")
        default: break
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Legality banner

    /// Legality banner: a 36 pt one-line summary, expandable (click) into a per-issue list built
    /// from `PKM.legalityResults` — each issue shows its category and message, with a "FIX" button
    /// wherever `applyLegalityFix` has a quick-fix for that category. There's no general "make
    /// legal" engine in PKHeX.Core — only a curated set of common, unambiguous repairs is offered.
    @ViewBuilder
    private func legalityBanner(for pkm: PKM) -> some View {
        let isLegal = pkm.isLegal
        let issues = pkm.legalityResults.filter { $0.isIssue }
        let tint = isLegal ? Theme.green : Theme.red

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !isLegal { isLegalityExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    StatusDot(color: tint)
                    Text(isLegal ? "LEGAL" : "\(pad(issues.count, 2)) \(issues.count == 1 ? "ISSUE" : "ISSUES")")
                        .font(Theme.sans(12, .semibold))
                        .tracking(1.44)
                        .foregroundStyle(tint)
                    Text(isLegal ? "passes all checks" : (issues.first?.message ?? ""))
                        .font(Theme.sans(14, .regular))
                        .foregroundStyle(Theme.ink200)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    if !isLegal {
                        Image(systemName: isLegalityExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Theme.ink300)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLegal)

            if isLegalityExpanded && !isLegal {
                VStack(spacing: 0) {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        HRule(color: Theme.line400)
                        legalityIssueRow(issue, pkm: pkm)
                    }
                }
            }
        }
        .background(isLegal ? Theme.greenFill : Theme.redFill)
        .overlay(Rectangle().strokeBorder(tint, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func legalityIssueRow(_ issue: PKM.LegalityResult, pkm: PKM) -> some View {
        HStack(alignment: .center, spacing: 8) {
            GridText(categoryName(for: issue.identifier), .label, color: Theme.ink300)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)
            Text(issue.message)
                .font(Theme.sans(14, .regular))
                .foregroundStyle(Theme.ink200)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasQuickFix(for: issue.identifier) {
                GridButton("Fix", .secondary, size: .sm) {
                    guard let index = pkm.legalityResults.firstIndex(where: {
                        $0.identifier == issue.identifier && $0.message == issue.message
                    }) else { return }
                    pkm.applyLegalityFix(at: index, saveFile: saveFile)
                    commit(pkm)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Uppercased category label for a legality issue's identifier (resolved through PKHeX.Core's
    /// own `CheckIdentifier` enum name, not a hardcoded ordinal table — see
    /// `PokemonNames.checkIdentifier`).
    private func categoryName(for identifier: UInt8) -> String {
        PokemonNames.checkIdentifier(identifier).uppercased()
    }

    /// Whether `PKM.applyLegalityFix` has a quick-fix for this category — keep in sync with
    /// `PkmApplyLegalityFix`'s switch in LegalityExports.cs.
    private static let quickFixCategories: Set<String> = ["Trainer", "Memory", "Handler", "Ball"]

    private func hasQuickFix(for identifier: UInt8) -> Bool {
        Self.quickFixCategories.contains(PokemonNames.checkIdentifier(identifier))
    }

    // MARK: - Tabs

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(InspectorTab.allCases, id: \.self) { tab in
                let isActive = activeTab == tab
                Button {
                    activeTab = tab
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(Theme.sans(12, .semibold))
                        .tracking(1.2)
                        .foregroundStyle(isActive ? Theme.amber : Theme.ink300)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(alignment: .bottom) {
                            if isActive { Rectangle().fill(Theme.amber).frame(height: 2) }
                        }
                        .hoverFill(isEnabled: !isActive)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { HRule(color: Theme.line300) }
        .padding(.horizontal, 16)
    }

    // MARK: - Shared cell helpers

    /// Inline mono integer field (underline style) clamped to `range`. Reverts the draft (by
    /// rebuilding the panel) when the input is unparseable or clamps back to the current value.
    private func inlineNumber(
        _ label: String, value: Int, range: ClosedRange<Int>, onCommit: @escaping (Int) -> Void
    ) -> some View {
        CommitField(
            placeholder: label, value: String(value), style: .underline, alignment: .leading,
            font: Theme.mono(16), digitsOnly: true
        ) { text in
            guard let parsed = Int(text) else { refreshToken += 1; return }
            let clamped = min(max(parsed, range.lowerBound), range.upperBound)
            if clamped != value { onCommit(clamped) } else { refreshToken += 1 }
        }
        .accessibilityLabel(label)
    }

    private func inlineText(
        _ label: String, value: String, maxLength: Int?, onCommit: @escaping (String) -> Void
    ) -> some View {
        CommitField(
            placeholder: label, value: value, style: .underline, alignment: .leading,
            font: Theme.mono(16), maxLength: (maxLength ?? 0) > 0 ? maxLength : nil, onCommit: onCommit
        )
        .accessibilityLabel(label)
    }

    private func cellRow<A: View, B: View>(@ViewBuilder _ a: () -> A, @ViewBuilder _ b: () -> B) -> some View {
        HStack(alignment: .top, spacing: 8) {
            a().frame(maxWidth: .infinity)
            b().frame(maxWidth: .infinity)
        }
    }

    /// `LABEL ······ 070 /255` row with an inline box field.
    private func friendshipRow(_ label: String, value: Int, onCommit: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            GridText(label, .label)
            DottedLeader()
            StatValueField(prefix: "", value: value, range: 0...255, width: 56, onCommit: onCommit)
            Text("/255")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.ink300)
        }
        .frame(minHeight: 36)
    }

    private func genderCell(_ label: String, value: UInt8, onChange: @escaping (UInt8) -> Void) -> some View {
        GridCell(label: label) {
            GridSegmented(
                options: [(value: 0, title: "M"), (value: 1, title: "F")],
                selection: Binding(get: { Int(value) }, set: { onChange(UInt8($0)) }),
                size: .sm
            )
        }
    }

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            GridText(title, .label, color: Theme.ink200)
        }
        .toggleStyle(GridSwitchStyle())
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Theme.surface2)
        .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
    }

    // MARK: - Summary tab

    /// Nature effect string, e.g. `+spe −spa`; empty for neutral natures.
    private func natureEffect(_ nature: UInt8) -> String {
        guard nature < 25 else { return "" }
        let names = ["atk", "def", "spe", "spa", "spd"]
        let up = Int(nature) / 5
        let down = Int(nature) % 5
        guard up != down else { return "" }
        return "+\(names[up]) −\(names[down])"
    }

    @ViewBuilder
    private func summaryTab(for pkm: PKM) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            // LEVEL: inline mono field (1–100)
            GridCell(label: "LEVEL") {
                inlineNumber("Level", value: Int(pkm.level), range: 1...100) { newValue in
                    pkm.level = UInt8(newValue)
                    commit(pkm)
                }
            }

            GridCell(
                "HELD ITEM", value: pkm.heldItem == 0 ? "None" : pkm.heldItemName, showsChevron: true
            ) { isHeldItemPickerPresented = true }

            GridCell(label: "NATURE", showsChevron: true, action: { isNaturePickerPresented = true }) {
                HStack(spacing: 8) {
                    Text(pkm.natureName)
                    let effect = natureEffect(pkm.nature)
                    if !effect.isEmpty {
                        Text(effect)
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.ink300)
                    }
                }
            }

            GridCell(
                "ABILITY", value: pkm.abilityName, showsChevron: true, isDisabled: pkm.abilityCount == 0
            ) { isAbilityPickerPresented = true }
                .help(pkm.abilityCount == 0 ? "This Pokémon's format has no selectable abilities." : "")

            GridCell(
                "BALL", value: pkm.supportsBall ? pkm.ballName : "Not tracked", showsChevron: true,
                isDisabled: !pkm.supportsBall
            ) { isBallPickerPresented = true }
                .help(pkm.supportsBall ? "" : "Gen 1/2 saves don't track which Ball a Pokémon was caught in.")

            statusCell(for: pkm)
        }
    }

    /// Status condition cell — battle/field state, only meaningful for party Pokémon
    /// (`partyStatsPresent`). Boxed Pokémon show a disabled `—` so the grid never reflows.
    @ViewBuilder
    private func statusCell(for pkm: PKM) -> some View {
        if pkm.partyStatsPresent {
            GridCell(label: "STATUS", showsChevron: true, action: { isStatusPickerPresented = true }) {
                Text(pkm.status.displayName)
                    .foregroundStyle(pkm.status == .none ? Theme.ink100 : Theme.red)
            }
            .popover(isPresented: $isStatusPickerPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                StatusPickerPopover(current: pkm.status) { condition in
                    guard condition != pkm.status else { isStatusPickerPresented = false; return }
                    pkm.status = condition
                    commit(pkm)
                    isStatusPickerPresented = false
                }
            }
        } else {
            GridCell("STATUS", value: "—", isDisabled: true)
        }
    }

    // MARK: - Stats tab

    @ViewBuilder
    private func statsTab(for pkm: PKM) -> some View {
        let total = evTotal(pkm)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                GridText("Stat", .label, color: Theme.ink300)
                    .frame(width: 44, alignment: .leading)
                GridText("IV · 00–31", .label, color: Theme.ink300)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GridText("IV", .label, color: Theme.ink300)
                    .frame(width: 40, alignment: .center)
                GridText("EV", .label, color: Theme.ink300)
                    .frame(width: 48, alignment: .center)
            }
            .frame(height: 28)
            .overlay(alignment: .bottom) { HRule(color: Theme.line300) }

            ForEach(Stat.allCases, id: \.self) { stat in
                HStack(spacing: 8) {
                    GridText(label(for: stat), .label, color: Theme.ink200)
                        .frame(width: 44, alignment: .leading)

                    GridMeter(
                        value: Double(pkm.iv(stat)), maximum: 31,
                        fill: pkm.iv(stat) == 31 ? Theme.green : Theme.line100
                    )

                    StatValueField(prefix: "IV", value: Int(pkm.iv(stat)), range: 0...31, width: 40) { newValue in
                        pkm.setIV(stat, to: Int32(newValue))
                        commit(pkm)
                    }
                    StatValueField(prefix: "EV", value: Int(pkm.ev(stat)), range: 0...252, width: 48) { newValue in
                        pkm.setEV(stat, to: Int32(newValue))
                        commit(pkm)
                    }
                }
                .frame(height: 40)
                .overlay(alignment: .bottom) { HRule(color: Theme.line400) }
            }

            KeyValueRow(
                label: "EV total", value: "\(pad(total)) | 510",
                valueColor: total > 510 ? Theme.red : Theme.ink100, mono: true
            )
            .padding(.top, 8)
        }
    }

    private func evTotal(_ pkm: PKM) -> Int {
        Stat.allCases.reduce(0) { $0 + Int(pkm.ev($1)) }
    }

    private func label(for stat: Stat) -> String {
        switch stat {
        case .hp: return "HP"
        case .attack: return "ATK"
        case .defense: return "DEF"
        case .specialAttack: return "SPA"
        case .specialDefense: return "SPD"
        case .speed: return "SPE"
        }
    }

    // MARK: - Moves tab

    @ViewBuilder
    private func movesTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a move to replace it.")
                .font(Theme.sans(14, .regular))
                .foregroundStyle(Theme.ink300)

            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    let move = pkm.move(index)
                    Button {
                        movePickerSlot = index
                    } label: {
                        HStack(spacing: 10) {
                            Text(pad(index + 1, 2))
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.ink300)
                            Text(move == 0 ? "—" : PokemonNames.move(move))
                                .font(Theme.sans(16, .medium))
                                .foregroundStyle(Theme.ink100)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if move != 0 {
                                GridChip(text: typeCode(typeID: pkm.moveType(move)))
                                Text("PP \(pad(Int(pkm.movePP(index)), 2))/\(pad(Int(pkm.movePPMax(index)), 2))")
                                    .font(Theme.mono(12))
                                    .foregroundStyle(Theme.ink200)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(Theme.ink300)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .hoverFill()
                        .overlay(alignment: .bottom) { HRule(color: Theme.line400) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Met tab

    /// Met/Egg info tab: where/when/how a Pokémon was obtained. Gen 1 (`format == 1`) predates
    /// this system entirely (no met location, level, or egg concept), so a note replaces the tab
    /// body there rather than a set of controls that would silently no-op.
    @ViewBuilder
    private func metTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if pkm.format < 2 {
                Text("Gen 1 doesn't track Met/Egg info.")
                    .font(Theme.sans(14, .regular))
                    .foregroundStyle(Theme.ink300)
            } else {
                metInfoSection(for: pkm)
                if pkm.supportsIsEgg {
                    eggInfoSection(for: pkm)
                }
            }
        }
    }

    @ViewBuilder
    private func metInfoSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Met info")

            GridCell(
                "MET LOCATION", value: pkm.metLocation == 0 ? "—" : pkm.metLocationName, showsChevron: true
            ) { metLocationPickerPresented = true }

            cellRow {
                GridCell(label: "MET LEVEL") {
                    inlineNumber("Met level", value: Int(pkm.metLevel), range: 0...100) { newValue in
                        pkm.metLevel = UInt8(newValue)
                        commit(pkm)
                    }
                }
            } _: {
                if pkm.supportsMetDate {
                    GridCell(
                        label: "MET DATE", showsChevron: true, action: { isMetDatePickerPresented = true }
                    ) {
                        Text(dateString(pkm.metDate)).font(Theme.mono(13))
                    }
                    .popover(isPresented: $isMetDatePickerPresented, arrowEdge: .top) {
                        DatePickerPopover(components: pkm.metDate) { newDate in
                            pkm.metDate = newDate
                            commit(pkm)
                            isMetDatePickerPresented = false
                        }
                        .environmentObject(profileStore)
                    }
                } else {
                    GridCell("MET DATE", value: "—", isDisabled: true)
                }
            }

            // Not every format tracks this, but it's harmless to show universally once
            // `format >= 2`; it's simply always-false on Gen 2, which predates the flag.
            switchRow("Fateful encounter", isOn: Binding(
                get: { pkm.fatefulEncounter },
                set: { pkm.fatefulEncounter = $0; commit(pkm) }
            ))
        }
    }

    @ViewBuilder
    private func eggInfoSection(for pkm: PKM) -> some View {
        let eggEnabled = pkm.isEgg || pkm.wasEgg
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Egg info")

            // Flips the whole entity into/out of egg state via `PKM.isEgg`'s setter, which
            // (native-side) also renames to the egg name, resets the hatch counter, and clears the
            // Met Date — see `pkhex_pkm_set_is_egg`'s remarks.
            switchRow("Is egg", isOn: Binding(
                get: { pkm.isEgg },
                set: { pkm.isEgg = $0; commit(pkm) }
            ))

            if pkm.supportsEggLocation {
                GridCell(
                    "EGG LOCATION", value: pkm.eggLocation == 0 ? "—" : pkm.eggLocationName,
                    showsChevron: true, isDisabled: !eggEnabled
                ) { eggLocationPickerPresented = true }

                GridCell(
                    label: "EGG DATE", showsChevron: true, isDisabled: !eggEnabled,
                    action: { isEggDatePickerPresented = true }
                ) {
                    Text(dateString(pkm.eggDate)).font(Theme.mono(13))
                }
                .popover(isPresented: $isEggDatePickerPresented, arrowEdge: .top) {
                    DatePickerPopover(components: pkm.eggDate) { newDate in
                        pkm.eggDate = newDate
                        commit(pkm)
                        isEggDatePickerPresented = false
                    }
                    .environmentObject(profileStore)
                }
            }
        }
    }

    private func dateString(_ components: DateComponents?) -> String {
        guard let components, let year = components.year, let month = components.month, let day = components.day else {
            return "—"
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Trainer tab

    /// OT/Handling Trainer + Memories tab. Every format tracks OT identity, so that section always
    /// shows; Handling Trainer and Memories are Gen 6+ mechanics and are hidden entirely (not just
    /// disabled) on earlier formats.
    @ViewBuilder
    private func trainerTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            originalTrainerSection(for: pkm)

            if pkm.supportsHandlingTrainer {
                handlingTrainerSection(for: pkm)
            }

            if pkm.supportsOriginalTrainerMemory || pkm.supportsHandlingTrainerMemory {
                memoriesSection(for: pkm)
            }
        }
    }

    @ViewBuilder
    private func originalTrainerSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Original trainer") {
                GridButton("Reset to save", .ghost, size: .sm) {
                    pkm.resetOriginalTrainerToSaveTrainer(saveFile)
                    commit(pkm)
                }
            }

            cellRow {
                GridCell(label: "OT NAME") {
                    inlineText("OT name", value: pkm.originalTrainerName, maxLength: pkm.maxOriginalTrainerNameLength) { newValue in
                        pkm.originalTrainerName = newValue
                        commit(pkm)
                    }
                }
            } _: {
                genderCell("OT GENDER", value: pkm.originalTrainerGender) { newValue in
                    pkm.originalTrainerGender = newValue
                    commit(pkm)
                }
            }

            cellRow {
                GridCell(label: "TRAINER ID") {
                    inlineNumber("Trainer ID", value: Int(pkm.tid16), range: 0...65535) { newValue in
                        pkm.tid16 = UInt16(newValue)
                        commit(pkm)
                    }
                }
            } _: {
                GridCell(label: "SECRET ID") {
                    inlineNumber("Secret ID", value: Int(pkm.sid16), range: 0...65535) { newValue in
                        pkm.sid16 = UInt16(newValue)
                        commit(pkm)
                    }
                }
            }

            friendshipRow("OT friendship", value: Int(pkm.originalTrainerFriendship)) { newValue in
                pkm.originalTrainerFriendship = UInt8(newValue)
                commit(pkm)
            }
        }
    }

    /// Handling Trainer section: shows a placeholder sentence when the Pokémon has never been
    /// traded — matches PKHeX.WinForms' `ToggleHandlerVisibility`, which only reveals the HT
    /// fields once `HandlingTrainerName` is non-empty.
    @ViewBuilder
    private func handlingTrainerSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Handling trainer") {
                currentHandlerToggle(for: pkm)
            }

            if !pkm.hasHandlingTrainer {
                Text("Not traded. No handling trainer set.")
                    .font(Theme.sans(14, .regular))
                    .foregroundStyle(Theme.ink300)
                    .padding(.vertical, 4)
            } else {
                cellRow {
                    GridCell(label: "HT NAME") {
                        inlineText("HT name", value: pkm.handlingTrainerName, maxLength: nil) { newValue in
                            pkm.handlingTrainerName = newValue
                            commit(pkm)
                        }
                    }
                } _: {
                    genderCell("HT GENDER", value: pkm.handlingTrainerGender) { newValue in
                        pkm.handlingTrainerGender = newValue
                        commit(pkm)
                    }
                }

                friendshipRow("HT friendship", value: Int(pkm.handlingTrainerFriendship)) { newValue in
                    pkm.handlingTrainerFriendship = UInt8(newValue)
                    commit(pkm)
                }
            }
        }
    }

    /// "OT | HT" segmented toggle for `PKM.currentHandler` — who currently holds the Pokémon.
    private func currentHandlerToggle(for pkm: PKM) -> some View {
        GridSegmented(
            options: [(value: 0, title: "OT"), (value: 1, title: "HT")],
            selection: Binding(
                get: { Int(pkm.currentHandler) },
                set: { pkm.currentHandler = UInt8($0); commit(pkm) }
            ),
            size: .sm
        )
    }

    /// Memories section: OT memory cell (if supported) and HT memory cell (if supported and the
    /// Pokémon has an HT), each opening a `MemoryPickerSheet`. Also offers "Clear all" and, for
    /// HT, a one-tap trade-memory suggestion mirroring PKHeX.WinForms' own convenience helper.
    @ViewBuilder
    private func memoriesSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Memories") {
                GridButton("Clear all", .ghost, size: .sm) {
                    pkm.clearMemories()
                    commit(pkm)
                }
            }

            if pkm.supportsOriginalTrainerMemory {
                memoryCell(title: "OT MEMORY", memoryID: pkm.originalTrainerMemory, pkm: pkm) {
                    memoryPickerTarget = .originalTrainer
                    isMemoryPickerPresented = true
                }
            }

            if pkm.supportsHandlingTrainerMemory && pkm.hasHandlingTrainer {
                memoryCell(title: "HT MEMORY", memoryID: pkm.handlingTrainerMemory, pkm: pkm) {
                    memoryPickerTarget = .handlingTrainer
                    isMemoryPickerPresented = true
                }
                GridButton("Suggest trade memory", .ghost, size: .sm) {
                    pkm.setTradeMemoryHT()
                    commit(pkm)
                }
            }
        }
    }

    @ViewBuilder
    private func memoryCell(title: String, memoryID: UInt8, pkm: PKM, action: @escaping () -> Void) -> some View {
        GridCell(label: title, showsChevron: true, action: action) {
            Text(memoryID == 0 ? "No memory" : pkm.memoryLine(memoryID))
                .font(Theme.sans(14, .medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Which trainer's memory a `MemoryPickerSheet` is editing.
enum MemoryTarget {
    case originalTrainer
    case handlingTrainer
}

/// Inline nickname field: Rajdhani 24/600 with a dotted underline that turns solid cyan on focus.
/// Commits on Enter or loss of focus.
private struct NicknameField: View {
    let pkm: PKM
    let onCommit: (String) -> Void

    var body: some View {
        let maxLength = pkm.maxNicknameLength
        CommitField(
            placeholder: "Nickname", value: pkm.nickname, style: .underline, alignment: .leading,
            font: Theme.sans(24, .semibold), maxLength: maxLength > 0 ? maxLength : nil, onCommit: onCommit
        )
        .accessibilityLabel("Nickname")
    }
}

/// Attached dropdown for the Status cell: square, `surface-1`, 1 pt `line-100` border, 32 pt caps
/// rows, current value amber-filled.
private struct StatusPickerPopover: View {
    let current: StatusCondition
    let onChoose: (StatusCondition) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(StatusCondition.allCases, id: \.self) { condition in
                let isSelected = condition == current
                Button {
                    onChoose(condition)
                } label: {
                    HStack {
                        Text(condition.displayName.uppercased())
                            .font(Theme.sans(14, .semibold))
                            .tracking(1.68)
                            .foregroundStyle(isSelected ? Theme.inkInvert : Theme.ink100)
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .hoverFill(base: isSelected ? Theme.amber : .clear, hover: isSelected ? Theme.amber : Theme.surface3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 190)
        .background(Theme.surface1)
        .overlay(Rectangle().strokeBorder(Theme.line100, lineWidth: 1))
    }
}
