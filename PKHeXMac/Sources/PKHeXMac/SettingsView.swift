import SwiftUI

/// Circuit-redesign Settings / Preferences window (design spec §10).
///
/// Host in a `Settings { }` Scene, sized to the spec's 760×560 preferences window. Only the
/// "Appearance" category is fully built out per spec; the remaining categories are placeholders
/// pending their own design passes.
struct SettingsView: View {
    @EnvironmentObject private var accentStore: AccentStore

    private enum Category: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case editing = "Editing"
        case filesAndBackups = "Files & backups"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .appearance: return "paintbrush.fill"
            case .editing: return "square.and.pencil"
            case .filesAndBackups: return "externaldrive.fill"
            case .shortcuts: return "keyboard"
            case .about: return "info.circle.fill"
            }
        }
    }

    @State private var selectedCategory: Category = .appearance

    var body: some View {
        HStack(spacing: 0) {
            categoryRail
            Divider().overlay(Theme.hairline)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bgContent)
        }
        .frame(width: 760, height: 560)
        .background(Theme.bgPanel)
    }

    // MARK: Category rail

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SETTINGS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ForEach(Category.allCases) { category in
                categoryRow(category)
            }

            Spacer()
        }
        .frame(width: 172)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bgPanel)
    }

    private func categoryRow(_ category: Category) -> some View {
        let isActive = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 9) {
                Image(systemName: category.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isActive ? accentStore.accent.bright : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? accentStore.accent.soft : Color.clear)
            )
            .padding(.horizontal, 6)
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
            ComingSoonView(category: selectedCategory.rawValue)
        }
    }
}

// MARK: - Placeholder for unbuilt categories

private struct ComingSoonView: View {
    let category: String

    var body: some View {
        VStack(spacing: 8) {
            Text(category)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Coming soon")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Appearance category

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var accentStore: AccentStore

    // UI-only prefs (persisted, but not yet consumed by any other view in the app).
    @AppStorage("reflectShinyPalette") private var reflectShinyPalette = true
    @AppStorage("showTileBadges") private var showTileBadges = true
    @AppStorage("boxTileSize") private var boxTileSize = "M"

    // Files quick prefs (persisted, but not yet consumed elsewhere). Defaults per spec: on/on/off.
    @AppStorage("backupBeforeWriting") private var backupBeforeWriting = true
    @AppStorage("confirmBeforeReleasing") private var confirmBeforeReleasing = true
    @AppStorage("reopenLastSaveOnLaunch") private var reopenLastSaveOnLaunch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                accentSection
                displaySection
                filesSection
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Accent color

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ACCENT COLOR")

            card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(AccentColor.allCases) { option in
                            accentSwatch(option)
                        }
                        customSwatchSlot
                        Spacer()
                    }
                    Text("This is the primary theming control — it re-tints selection fills, focus rings, IV bars, toggles, and the Save button across the app.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(15)
            }
        }
    }

    private func accentSwatch(_ option: AccentColor) -> some View {
        let isSelected = accentStore.accent == option
        return Button {
            accentStore.accent = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .strokeBorder(Theme.bgPanel, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(option.color, lineWidth: isSelected ? 2 : 0)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.rawValue.capitalized))
    }

    /// Spec calls for a dashed "+" custom-swatch slot, but there's no persistence support for
    /// arbitrary custom colors beyond the fixed `AccentColor` cases yet — shown but disabled
    /// rather than faking a working color picker.
    private var customSwatchSlot: some View {
        Circle()
            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .foregroundStyle(Theme.textTertiary)
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            )
            .opacity(0.5)
            .help("Custom accent colors aren't supported yet")
            .disabled(true)
    }

    // MARK: Display toggles

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DISPLAY")

            card {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Reflect shiny palette on sprites",
                        isOn: $reflectShinyPalette
                    )
                    divider
                    toggleRow(
                        title: "Type & held-item badges on tiles",
                        isOn: $showTileBadges
                    )
                    divider
                    row {
                        rowLabel("Box tile size")
                        Spacer()
                        tileSizeSegmentedControl
                    }
                }
            }
        }
    }

    private var tileSizeSegmentedControl: some View {
        HStack(spacing: 2) {
            tileSizeSegment(title: "S")
            tileSizeSegment(title: "M")
            tileSizeSegment(title: "L")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.bgElevated1)
        )
    }

    private func tileSizeSegment(title: String) -> some View {
        let isActive = boxTileSize == title
        return Button {
            boxTileSize = title
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? accentStore.accent.onAccent : Theme.textSecondary)
                .frame(width: 28, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control - 2, style: .continuous)
                        .fill(isActive ? accentStore.accent.color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Files quick prefs

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FILES & BACKUPS")

            card {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Back up save before writing",
                        isOn: $backupBeforeWriting
                    )
                    divider
                    toggleRow(
                        title: "Confirm before releasing Pokémon",
                        isOn: $confirmBeforeReleasing
                    )
                    divider
                    toggleRow(
                        title: "Reopen last save on launch",
                        isOn: $reopenLastSaveOnLaunch
                    )
                }
            }
        }
    }

    // MARK: Shared building blocks

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        row {
            rowLabel(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(accentStore.accent.color)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .fill(Theme.bgPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 0.5)
        )
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
    }
}
