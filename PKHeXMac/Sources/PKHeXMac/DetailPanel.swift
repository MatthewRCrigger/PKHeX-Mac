import PKHeXCore
import SwiftUI

private enum InspectorTab: String, CaseIterable {
    case summary = "Summary"
    case stats = "Stats"
    case moves = "Moves"
    case met = "Met"
    case trainer = "Trainer"
}

/// A single horizontal line, meant to be stroked with a dashed `StrokeStyle` — used for the
/// nickname field's dashed underline per the Circuit spec.
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

struct DetailPanel: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore
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

                        switch activeTab {
                        case .summary: summaryTab(for: pkm)
                        case .stats: statsTab(for: pkm)
                        case .moves: movesTab(for: pkm)
                        case .met: metTab(for: pkm)
                        case .trainer: trainerTab(for: pkm)
                        }
                    }
                }
                .id(refreshToken)
            } else if store.inspectedSlot != nil {
                VStack(spacing: 6) {
                    Text("Empty slot")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(store.copiedPKM != nil ? "⌘V to paste, or right-click to add a Pokémon" : "Right-click to add a Pokémon")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .multilineTextAlignment(.center)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a Pokémon to inspect and edit")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bgPanel)
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
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $isBallPickerPresented) {
            if let pkm {
                BallPickerSheet(pkm: pkm) { newBall in
                    pkm.ball = newBall
                    commit(pkm)
                    isBallPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $isHeldItemPickerPresented) {
            if let pkm {
                HeldItemPickerSheet(pkm: pkm) { newItem in
                    pkm.heldItem = newItem
                    commit(pkm)
                    isHeldItemPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $isNaturePickerPresented) {
            if let pkm {
                NaturePickerSheet(pkm: pkm) { newNature in
                    pkm.nature = newNature
                    commit(pkm)
                    isNaturePickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $isAbilityPickerPresented) {
            if let pkm {
                AbilityPickerSheet(pkm: pkm) { newIndex in
                    pkm.setAbilityIndex(newIndex)
                    commit(pkm)
                    isAbilityPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $metLocationPickerPresented) {
            if let pkm {
                LocationPickerSheet(pkm: pkm, egg: false) { newLocation in
                    pkm.metLocation = newLocation
                    commit(pkm)
                    metLocationPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $eggLocationPickerPresented) {
            if let pkm {
                LocationPickerSheet(pkm: pkm, egg: true) { newLocation in
                    pkm.eggLocation = newLocation
                    commit(pkm)
                    eggLocationPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
        .sheet(isPresented: $isMemoryPickerPresented) {
            if let pkm, let target = memoryPickerTarget {
                MemoryPickerSheet(pkm: pkm, target: target) {
                    commit(pkm)
                    isMemoryPickerPresented = false
                }
                .environmentObject(accentStore)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(for pkm: PKM) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Theme.bgElevated1)
                    .frame(width: 74, height: 66)
                ArtworkImage(pkm: pkm)
                    .padding(9)
                    .frame(width: 74, height: 66)
                if pkm.isShiny {
                    VStack {
                        HStack {
                            Spacer()
                            Text("★")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.shinyStar)
                        }
                        Spacer()
                    }
                    .frame(width: 74, height: 66)
                    .padding(3)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                NicknameField(pkm: pkm) { newValue in
                    pkm.nickname = newValue
                    commit(pkm)
                }
                Text(metaLine(for: pkm))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 5) {
                    ForEach(pkm.types, id: \.self) { typeID in
                        TypeBadge(typeID: typeID)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

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

    // MARK: - Legality banner

    /// Legality banner: collapsed to a one-line summary by default, expandable (tap) into a
    /// per-issue list built from `PKM.legalityResults` — each issue shows its category and message,
    /// with a "Fix" button wherever `applyLegalityFix` has a quick-fix for that category. There's
    /// no general "make legal" engine in PKHeX.Core (that's a separate closed-source tool, not part
    /// of this library) — only a curated set of common, unambiguous repairs is offered.
    @ViewBuilder
    private func legalityBanner(for pkm: PKM) -> some View {
        let isLegal = pkm.isLegal
        let issues = pkm.legalityResults.filter { $0.isIssue }

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !isLegal { isLegalityExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isLegal ? Theme.legalDot : Theme.warnIcon)
                        .frame(width: 7, height: 7)
                    Text(isLegal ? "Legal" : "\(issues.count) issue\(issues.count == 1 ? "" : "s")")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isLegal ? Theme.legalText : Theme.warnText)
                    Text(isLegal ? "passes all checks" : (issues.first?.message ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    if !isLegal {
                        Image(systemName: isLegalityExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLegal)

            if isLegalityExpanded && !isLegal {
                VStack(spacing: 6) {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        legalityIssueRow(issue, pkm: pkm)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(isLegal ? Theme.legalFill : Theme.warnFill)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isLegal ? Theme.legalBorder : Theme.warnBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func legalityIssueRow(_ issue: PKM.LegalityResult, pkm: PKM) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(categoryName(for: issue.identifier))
                .font(.system(size: 10, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 68, alignment: .leading)
            Text(issue.message)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if hasQuickFix(for: issue.identifier) {
                Button("Fix") {
                    guard let index = pkm.legalityResults.firstIndex(where: {
                        $0.identifier == issue.identifier && $0.message == issue.message
                    }) else { return }
                    pkm.applyLegalityFix(at: index, saveFile: saveFile)
                    commit(pkm)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentStore.accent.bright)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accentStore.accent.soft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
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
        HStack(spacing: 2) {
            ForEach(InspectorTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(activeTab == tab ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(activeTab == tab ? Theme.bgElevated3 : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                    .onTapGesture { activeTab = tab }
            }
        }
        .padding(3)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Summary tab

    @ViewBuilder
    private func summaryTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                levelCard(for: pkm)
                heldItemCard(for: pkm)
            }

            HStack(spacing: 10) {
                natureCard(for: pkm)
                abilityCard(for: pkm)
            }

            HStack(spacing: 10) {
                ballCard(for: pkm)
                if pkm.partyStatsPresent {
                    statusCard(for: pkm)
                } else {
                    infoCard(label: "STATUS", value: "—")
                        .opacity(0.55)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    /// Status condition card (burned/paralyzed/asleep/frozen/poisoned/none) — battle/field state,
    /// only meaningful for party Pokemon (`partyStatsPresent`). Box-stored Pokemon show a dimmed
    /// "—" placeholder in this same slot instead, so Ball/Status keep occupying a stable two-column
    /// row alongside each other exactly like Nature/Ability, rather than the layout reflowing.
    /// Uses a plain Button + popover (not `Menu`) so the card renders with exactly the same
    /// icon/label/value layout as the Ball card — `Menu`'s own button chrome (icon sizing,
    /// trailing disclosure indicator) overrides a custom label's layout, which broke the intended
    /// visual match.
    @ViewBuilder
    private func statusCard(for pkm: PKM) -> some View {
        Button {
            isStatusPickerPresented = true
        } label: {
            infoCard(label: "STATUS", value: pkm.status.displayName) {
                // Reserve the icon's space even when there's no status, matching the Ball card's
                // fixed-size icon well, so the two cards line up regardless of content.
                StatusIcon(status: pkm.status)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isStatusPickerPresented, arrowEdge: .top) {
            StatusPickerPopover(current: pkm.status) { condition in
                guard condition != pkm.status else { isStatusPickerPresented = false; return }
                pkm.status = condition
                commit(pkm)
                isStatusPickerPresented = false
            }
        }
    }

    /// Level card: same label/value layout as Nature/Ability, with the value replaced by an
    /// inline editable field rather than a modal — a level is a small number best edited directly,
    /// unlike Ball/Held Item/Status which pick from a large or fixed option set.
    @ViewBuilder
    private func levelCard(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LEVEL")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            LevelField(level: Int(pkm.level)) { newValue in
                pkm.level = UInt8(newValue)
                commit(pkm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    /// Nature card: same plain label/value layout as Ability, tappable to open a picker that
    /// visualizes the increased/decreased-stat grid (see `NaturePickerSheet`).
    @ViewBuilder
    private func natureCard(for pkm: PKM) -> some View {
        Button {
            isNaturePickerPresented = true
        } label: {
            infoCard(label: "NATURE", value: pkm.natureName)
        }
        .buttonStyle(.plain)
    }

    /// Ability card: same plain label/value layout as Nature, tappable to open a picker listing
    /// this species/form's selectable ability slots (see `AbilityPickerSheet`). Disabled when
    /// `abilityCount == 0` (Gen 1-2 entities have no ability concept).
    @ViewBuilder
    private func abilityCard(for pkm: PKM) -> some View {
        Button {
            isAbilityPickerPresented = true
        } label: {
            infoCard(label: "ABILITY", value: pkm.abilityName)
        }
        .buttonStyle(.plain)
        .disabled(pkm.abilityCount == 0)
        .help(pkm.abilityCount == 0 ? "This Pokémon's format has no selectable abilities." : "")
    }

    /// Held item card: same icon-well layout as Ball/Status, tappable to open a held-item picker.
    @ViewBuilder
    private func heldItemCard(for pkm: PKM) -> some View {
        Button {
            isHeldItemPickerPresented = true
        } label: {
            infoCard(label: "HELD ITEM", value: pkm.heldItem == 0 ? "None" : pkm.heldItemName) {
                if pkm.heldItem != 0 {
                    ItemIconImage(itemID: Int(pkm.heldItem))
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Poké Ball card: shows the caught-in ball's icon and name, tappable to open a picker.
    /// Gen 1/2 saves (`format` 1/2) predate the Ball byte in PKHeX.Core's data model — `PKM.Ball`
    /// is a hardcoded no-op there, so the card is shown disabled with an explanatory note instead
    /// of a picker that would silently do nothing.
    @ViewBuilder
    private func ballCard(for pkm: PKM) -> some View {
        Button {
            guard pkm.supportsBall else { return }
            isBallPickerPresented = true
        } label: {
            infoCard(
                label: "BALL",
                value: pkm.supportsBall ? pkm.ballName : "Not tracked",
                dimmed: !pkm.supportsBall
            ) {
                BallIcon(ball: pkm.ball)
            }
        }
        .buttonStyle(.plain)
        .disabled(!pkm.supportsBall)
        .help(pkm.supportsBall ? "" : "Gen 1/2 saves don't track which Ball a Pokémon was caught in.")
    }

    @ViewBuilder
    private func infoCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    /// Nature/Ability-style card with a leading icon well — used by Ball and Status so they form a
    /// matching two-column row. The icon well always reserves its space (fixed 26x26 frame) even
    /// when `icon` renders nothing (e.g. status = none), so the Ball/Status row never reflows
    /// depending on whether either has content.
    @ViewBuilder
    private func infoCard<Icon: View>(label: String, value: String, dimmed: Bool = false, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.bgElevated3)
                .frame(width: 26, height: 26)
                .overlay {
                    icon()
                        .padding(4)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(dimmed ? Theme.textTertiary : Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .opacity(dimmed ? 0.55 : 1)
    }

    // MARK: - Stats tab

    @ViewBuilder
    private func statsTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STAT")
                    .frame(width: 56, alignment: .leading)
                Text("IV · 0–31")
                Spacer()
                Text("EV")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Theme.textTertiary)

            VStack(spacing: 10) {
                ForEach(Stat.allCases, id: \.self) { stat in
                    HStack(alignment: .center, spacing: 8) {
                        Text(label(for: stat))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textPrimary.opacity(0.7))
                            .frame(width: 56, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.bgElevated1)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(accentStore.accent.color)
                                    .frame(width: proxy.size.width * CGFloat(pkm.iv(stat)) / 31)
                            }
                        }
                        .frame(height: 6)

                        StatValueField(prefix: "IV", value: Int(pkm.iv(stat)), range: 0...31) { newValue in
                            pkm.setIV(stat, to: Int32(newValue))
                            commit(pkm)
                        }
                        Text("·")
                            .foregroundStyle(Theme.textTertiary)
                        StatValueField(prefix: "EV", value: Int(pkm.ev(stat)), range: 0...252) { newValue in
                            pkm.setEV(stat, to: Int32(newValue))
                            commit(pkm)
                        }
                        .frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 11.5, design: .monospaced))
                }
            }

            HStack {
                Text("EV total")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(evTotal(pkm)) / 510")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentStore.accent.bright)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private func evTotal(_ pkm: PKM) -> Int {
        Stat.allCases.reduce(0) { $0 + Int(pkm.ev($1)) }
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

    // MARK: - Moves tab

    @ViewBuilder
    private func movesTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap a move to replace it")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 2)

            ForEach(0..<4, id: \.self) { index in
                let move = pkm.move(index)
                HStack {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 9, height: 9)
                        Text(move == 0 ? "—" : PokemonNames.move(move))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    if move != 0 {
                        Text("\(pkm.movePP(index))/\(pkm.movePPMax(index))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.bgElevated1)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
                .onTapGesture { movePickerSlot = index }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    // MARK: - Met tab

    /// Met/Egg info tab: where/when/how a Pokémon was obtained. Gen 1 (`format == 1`) predates
    /// this system entirely (no met location, level, or egg concept), so the whole section renders
    /// as a dimmed placeholder there rather than a set of controls that would silently no-op.
    @ViewBuilder
    private func metTab(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if pkm.format < 2 {
                Text("Gen 1 doesn't track Met/Egg info.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                metInfoSection(for: pkm)
                if pkm.supportsIsEgg {
                    eggInfoSection(for: pkm)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func metInfoSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MET INFO")

            Button {
                metLocationPickerPresented = true
            } label: {
                infoCard(label: "MET LOCATION", value: pkm.metLocation == 0 ? "—" : pkm.metLocationName)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                metLevelCard(for: pkm)
                if pkm.supportsMetDate {
                    metDateCard(for: pkm)
                } else {
                    infoCard(label: "MET DATE", value: "—")
                        .opacity(0.55)
                }
            }

            fatefulEncounterCard(for: pkm)
        }
    }

    @ViewBuilder
    private func eggInfoSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EGG INFO")

            isEggCard(for: pkm)

            if pkm.supportsEggLocation {
                Button {
                    eggLocationPickerPresented = true
                } label: {
                    infoCard(label: "EGG LOCATION", value: pkm.eggLocation == 0 ? "—" : pkm.eggLocationName)
                }
                .buttonStyle(.plain)
                .disabled(!pkm.isEgg && !pkm.wasEgg)

                eggDateCard(for: pkm)
                    .disabled(!pkm.isEgg && !pkm.wasEgg)
                    .opacity(pkm.isEgg || pkm.wasEgg ? 1 : 0.55)
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Theme.textTertiary)
    }

    /// Met Level card: same inline-editable-field layout as the Summary tab's Level card.
    @ViewBuilder
    private func metLevelCard(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MET LEVEL")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            StatValueField(prefix: "Lv", value: Int(pkm.metLevel), range: 0...100) { newValue in
                pkm.metLevel = UInt8(newValue)
                commit(pkm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private func metDateCard(for pkm: PKM) -> some View {
        Button {
            isMetDatePickerPresented = true
        } label: {
            infoCard(label: "MET DATE", value: dateString(pkm.metDate))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isMetDatePickerPresented, arrowEdge: .top) {
            DatePickerPopover(components: pkm.metDate) { newDate in
                pkm.metDate = newDate
                commit(pkm)
                isMetDatePickerPresented = false
            }
        }
    }

    @ViewBuilder
    private func eggDateCard(for pkm: PKM) -> some View {
        Button {
            isEggDatePickerPresented = true
        } label: {
            infoCard(label: "EGG DATE", value: dateString(pkm.eggDate))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isEggDatePickerPresented, arrowEdge: .top) {
            DatePickerPopover(components: pkm.eggDate) { newDate in
                pkm.eggDate = newDate
                commit(pkm)
                isEggDatePickerPresented = false
            }
        }
    }

    /// Fateful Encounter toggle: not every format tracks this (see `PKM.fatefulEncounter`'s
    /// abstract-on-every-concrete-class status), but it's harmless to show/toggle universally once
    /// `format >= 2`, matching how the field is stored consistently from Gen 3 onward and is simply
    /// always-false on Gen 2 (which predates the flag).
    @ViewBuilder
    private func fatefulEncounterCard(for pkm: PKM) -> some View {
        Button {
            pkm.fatefulEncounter.toggle()
            commit(pkm)
        } label: {
            HStack {
                infoCard(label: "FATEFUL ENCOUNTER", value: pkm.fatefulEncounter ? "Yes" : "No")
            }
        }
        .buttonStyle(.plain)
    }

    /// Is-Egg toggle: flips the whole entity into/out of egg state via `PKM.isEgg`'s setter, which
    /// (native-side) also renames to the egg name, resets the hatch counter, and clears the Met
    /// Date — see `pkhex_pkm_set_is_egg`'s remarks for exactly what that entails.
    @ViewBuilder
    private func isEggCard(for pkm: PKM) -> some View {
        Button {
            pkm.isEgg.toggle()
            commit(pkm)
        } label: {
            infoCard(label: "IS EGG", value: pkm.isEgg ? "Yes" : "No")
        }
        .buttonStyle(.plain)
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
    /// disabled) on earlier formats, matching how the Met tab hides Egg Info on formats that don't
    /// support it.
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
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func originalTrainerSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("ORIGINAL TRAINER")
                Spacer()
                Button("Reset to My Trainer") {
                    pkm.resetOriginalTrainerToSaveTrainer(saveFile)
                    commit(pkm)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentStore.accent.bright)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OT NAME")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    OTNameField(pkm: pkm) { newValue in
                        pkm.originalTrainerName = newValue
                        commit(pkm)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.bgElevated1)
                .clipShape(RoundedRectangle(cornerRadius: 9))

                otGenderCard(for: pkm)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAINER ID")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    StatValueField(prefix: "", value: Int(pkm.tid16), range: 0...65535) { newValue in
                        pkm.tid16 = UInt16(newValue)
                        commit(pkm)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.bgElevated1)
                .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    Text("SECRET ID")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    StatValueField(prefix: "", value: Int(pkm.sid16), range: 0...65535) { newValue in
                        pkm.sid16 = UInt16(newValue)
                        commit(pkm)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.bgElevated1)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("OT FRIENDSHIP")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                StatValueField(prefix: "", value: Int(pkm.originalTrainerFriendship), range: 0...255) { newValue in
                    pkm.originalTrainerFriendship = UInt8(newValue)
                    commit(pkm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(Theme.bgElevated1)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    @ViewBuilder
    private func otGenderCard(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OT GENDER")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 6) {
                genderButton(title: "♂", isActive: pkm.originalTrainerGender == 0) {
                    pkm.originalTrainerGender = 0
                    commit(pkm)
                }
                genderButton(title: "♀", isActive: pkm.originalTrainerGender == 1) {
                    pkm.originalTrainerGender = 1
                    commit(pkm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func genderButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? accentStore.accent.onAccent : Theme.textSecondary)
                .frame(width: 28, height: 24)
                .background(isActive ? accentStore.accent.color : Theme.bgElevated3)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    /// Handling Trainer section: hidden UI entirely (not shown-but-disabled) when the Pokémon has
    /// never been traded — matches PKHeX.WinForms' `ToggleHandlerVisibility`, which only reveals
    /// the HT groupbox once `HandlingTrainerName` is non-empty. Shows an explanatory placeholder
    /// with a way to seed HT data for testing/manual editing instead.
    @ViewBuilder
    private func handlingTrainerSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("HANDLING TRAINER")
                Spacer()
                currentHandlerToggle(for: pkm)
            }

            if !pkm.hasHandlingTrainer {
                Text("This Pokémon hasn't been traded — no Handling Trainer is set.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HT NAME")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                        HTNameField(pkm: pkm) { newValue in
                            pkm.handlingTrainerName = newValue
                            commit(pkm)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(Theme.bgElevated1)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HT GENDER")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                        HStack(spacing: 6) {
                            genderButton(title: "♂", isActive: pkm.handlingTrainerGender == 0) {
                                pkm.handlingTrainerGender = 0
                                commit(pkm)
                            }
                            genderButton(title: "♀", isActive: pkm.handlingTrainerGender == 1) {
                                pkm.handlingTrainerGender = 1
                                commit(pkm)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(Theme.bgElevated1)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("HT FRIENDSHIP")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    StatValueField(prefix: "", value: Int(pkm.handlingTrainerFriendship), range: 0...255) { newValue in
                        pkm.handlingTrainerFriendship = UInt8(newValue)
                        commit(pkm)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.bgElevated1)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    /// "OT"/"HT" segmented toggle for `PKM.currentHandler` — who currently holds the Pokémon.
    private func currentHandlerToggle(for pkm: PKM) -> some View {
        HStack(spacing: 2) {
            Button("OT") {
                pkm.currentHandler = 0
                commit(pkm)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(pkm.currentHandler == 0 ? accentStore.accent.onAccent : Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pkm.currentHandler == 0 ? accentStore.accent.color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button("HT") {
                pkm.currentHandler = 1
                commit(pkm)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(pkm.currentHandler == 1 ? accentStore.accent.onAccent : Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pkm.currentHandler == 1 ? accentStore.accent.color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(2)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Memories section: OT memory card (if supported) and HT memory card (if supported and the
    /// Pokémon has an HT), each tappable into a `MemoryPickerSheet`. Also offers "Clear" and, for
    /// HT, a one-tap "Set Trade Memory" suggestion mirroring PKHeX.WinForms' own trade-memory
    /// convenience helper rather than requiring hand-picked Intensity/Feeling values.
    @ViewBuilder
    private func memoriesSection(for pkm: PKM) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("MEMORIES")
                Spacer()
                Button("Clear All") {
                    pkm.clearMemories()
                    commit(pkm)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentStore.accent.bright)
            }

            if pkm.supportsOriginalTrainerMemory {
                memoryCard(title: "OT MEMORY", memoryID: pkm.originalTrainerMemory, pkm: pkm) {
                    memoryPickerTarget = .originalTrainer
                    isMemoryPickerPresented = true
                }
            }

            if pkm.supportsHandlingTrainerMemory && pkm.hasHandlingTrainer {
                memoryCard(title: "HT MEMORY", memoryID: pkm.handlingTrainerMemory, pkm: pkm) {
                    memoryPickerTarget = .handlingTrainer
                    isMemoryPickerPresented = true
                }
                Button("Suggest Trade Memory") {
                    pkm.setTradeMemoryHT()
                    commit(pkm)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func memoryCard(title: String, memoryID: UInt8, pkm: PKM, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                Text(memoryID == 0 ? "No memory" : pkm.memoryLine(memoryID))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(Theme.bgElevated1)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

/// Which trainer's memory a `MemoryPickerSheet` is editing.
enum MemoryTarget {
    case originalTrainer
    case handlingTrainer
}

/// Editable OT Name field: same styling convention as `LevelField`/`NicknameField`.
private struct OTNameField: View {
    let pkm: PKM
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("OT Name", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .focused($isFocused)
            .onSubmit { commit() }
            .onAppear { draft = pkm.originalTrainerName }
            .onChange(of: pkm.originalTrainerName) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: draft) { _, newValue in
                let max = pkm.maxOriginalTrainerNameLength
                if max > 0, newValue.count > max {
                    draft = String(newValue.prefix(max))
                }
            }
    }

    private func commit() {
        guard draft != pkm.originalTrainerName else { return }
        onCommit(draft)
    }
}

/// Editable HT Name field: same styling convention as `OTNameField`.
private struct HTNameField: View {
    let pkm: PKM
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("HT Name", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .focused($isFocused)
            .onSubmit { commit() }
            .onAppear { draft = pkm.handlingTrainerName }
            .onChange(of: pkm.handlingTrainerName) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        guard draft != pkm.handlingTrainerName else { return }
        onCommit(draft)
    }
}

/// Editable nickname field: 17pt bold with a dashed underline, matching the Circuit spec's
/// inspector header field. Commits on Enter or loss of focus.
private struct NicknameField: View {
    let pkm: PKM
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Nickname", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .focused($isFocused)
            .onSubmit { commit() }
            .onAppear { draft = pkm.nickname }
            .onChange(of: pkm.nickname) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: draft) { _, newValue in
                let max = pkm.maxNicknameLength
                if max > 0, newValue.count > max {
                    draft = String(newValue.prefix(max))
                }
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                DashedLine()
                    .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
    }

    private func commit() {
        guard draft != pkm.nickname else { return }
        onCommit(draft)
    }
}

/// Compact level field used alongside the 1-100 slider in the Summary tab.
private struct LevelField: View {
    let level: Int
    let onCommit: (Int) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Lv", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.textPrimary)
            .focused($isFocused)
            .onSubmit { commit() }
            .onAppear { draft = String(level) }
            .onChange(of: level) { _, newValue in
                if !isFocused { draft = String(newValue) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        guard let parsed = Int(draft) else { draft = String(level); return }
        let clamped = min(max(parsed, 1), 100)
        draft = String(clamped)
        if clamped != level {
            onCommit(clamped)
        }
    }
}

/// Small popover list for the Status card — only 6 options, so a full picker sheet (like the
/// Ball/species/item/move pickers) would be disproportionate.
private struct StatusPickerPopover: View {
    @EnvironmentObject private var accentStore: AccentStore
    let current: StatusCondition
    let onChoose: (StatusCondition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(StatusCondition.allCases, id: \.self) { condition in
                let isSelected = condition == current
                Button {
                    onChoose(condition)
                } label: {
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.bgElevated3)
                            .frame(width: 22, height: 22)
                            .overlay {
                                StatusIcon(status: condition)
                                    .padding(3)
                            }
                        Text(condition.displayName)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? accentStore.accent.bright : Theme.textPrimary)
                        Spacer(minLength: 12)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentStore.accent.color)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isSelected ? accentStore.accent.soft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 190)
    }
}
