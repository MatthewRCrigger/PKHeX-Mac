import SwiftUI

/// GRID Settings / Preferences window (spec §9), hosted in a `Settings { }` scene at 760 × 560.
/// Only "Appearance" has content; the other categories say "No settings yet."
struct SettingsView: View {
    private enum Category: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case editing = "Editing"
        case filesAndBackups = "Files & backups"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .appearance: return "eye"
            case .editing: return "terminal"
            case .filesAndBackups: return "externaldrive"
            case .shortcuts: return "square"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedCategory: Category = .appearance

    var body: some View {
        GridFrame {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    GridText("Settings", .nav)
                    Spacer()
                }
                .frame(height: 36)
                HRule(color: Theme.line300)

                HStack(spacing: 0) {
                    rail
                        .frame(width: 180)
                    VRule(color: Theme.line300)
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.void)
        }
        .padding(4)
        .frame(width: 760, height: 560)
        .background(Theme.void)
    }

    // MARK: Category rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Settings")
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(Category.allCases) { category in
                categoryRow(category)
            }
            Spacer()
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let isActive = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 16)
                Text(category.rawValue.uppercased())
                    .font(Theme.sans(14, .semibold))
                    .tracking(1.68)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
            }
            .foregroundStyle(isActive ? Theme.inkInvert : Theme.ink200)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .hoverFill(base: isActive ? Theme.amber : .clear, hover: isActive ? Theme.amber : Theme.surface3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch selectedCategory {
        case .appearance:
            AppearanceSettingsView()
        case .editing, .filesAndBackups, .shortcuts, .about:
            VStack(spacing: 8) {
                GridText(selectedCategory.rawValue, .nav)
                Text("No settings yet.")
                    .font(Theme.sans(14, .regular))
                    .foregroundStyle(Theme.ink300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Appearance category

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var profileStore: PanelProfileStore

    // UI prefs (persisted; consumed by the box grid).
    @AppStorage("reflectShinyPalette") private var reflectShinyPalette = true
    @AppStorage("showTileBadges") private var showTileBadges = true
    @AppStorage("boxTileSize") private var boxTileSize = "M"

    // Files quick prefs. Defaults per spec: on / on / off.
    @AppStorage("backupBeforeWriting") private var backupBeforeWriting = true
    @AppStorage("confirmBeforeReleasing") private var confirmBeforeReleasing = true
    @AppStorage("reopenLastSaveOnLaunch") private var reopenLastSaveOnLaunch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                profileSection
                displaySection
                filesSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Panel profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Panel", qualifier: "Profile")

            HStack(spacing: 12) {
                ForEach(PanelProfile.allCases) { option in
                    ProfileCard(option: option, isSelected: profileStore.profile == option) {
                        profileStore.profile = option
                    }
                }
            }

            Text("Sets panel border weight, corners and frame gap across the app. Colour is fixed: amber marks selection.")
                .font(Theme.sans(14, .regular))
                .foregroundStyle(Theme.ink300)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Display")

            toggleRow("Reflect shiny palette on sprites", isOn: $reflectShinyPalette)
            HRule(color: Theme.line400)
            toggleRow("Type & level codes on tiles", isOn: $showTileBadges)
            HRule(color: Theme.line400)
            settingRow("Box tile size") {
                GridSegmented(
                    options: [("S", "S"), ("M", "M"), ("L", "L")],
                    selection: $boxTileSize,
                    size: .sm,
                    fixedWidth: 40
                )
            }
        }
    }

    // MARK: Files & backups

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Files & backups")

            toggleRow("Back up save before writing", isOn: $backupBeforeWriting)
            HRule(color: Theme.line400)
            toggleRow("Confirm before releasing Pokémon", isOn: $confirmBeforeReleasing)
            HRule(color: Theme.line400)
            toggleRow("Reopen last save on launch", isOn: $reopenLastSaveOnLaunch)
        }
    }

    // MARK: Rows

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Theme.sans(16, .medium))
                .foregroundStyle(Theme.ink100)
        }
        .toggleStyle(GridSwitchStyle())
        .frame(minHeight: 44)
    }

    private func settingRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title)
                .font(Theme.sans(16, .medium))
                .foregroundStyle(Theme.ink100)
            Spacer()
            control()
        }
        .frame(minHeight: 44)
    }
}

/// A selectable card previewing a panel profile as a miniature double frame.
private struct ProfileCard: View {
    let option: PanelProfile
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let tint = isSelected ? Theme.amber : Theme.line200
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                miniFrame(tint: tint)
                    .frame(height: 64)

                HStack(spacing: 8) {
                    GridText(option.title, .label, color: isSelected ? Theme.amber : Theme.ink100)
                    DottedLeader()
                    Text("\(Int(option.borderWidth)) pt · \(Int(option.outerRadius))/\(Int(option.innerRadius))")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.ink300)
                }
            }
            .padding(12)
            .background(isSelected ? Theme.amberFill : (isHovering ? Theme.surface3 : Theme.surface1))
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.amber : (isHovering ? Theme.line200 : Theme.line300), lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }

    private func miniFrame(tint: Color) -> some View {
        let w = option.borderWidth
        let g = option.frameGap
        return ZStack {
            RoundedRectangle(cornerRadius: option.outerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: w)
            RoundedRectangle(cornerRadius: option.innerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: w)
                .padding(w + g)
        }
    }
}
