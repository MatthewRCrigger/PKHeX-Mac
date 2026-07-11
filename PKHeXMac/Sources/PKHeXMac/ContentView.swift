import AppKit
import PKHeXCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        Group {
            if let saveFile = store.saveFile {
                NavigationSplitView {
                    BoxSidebar(saveFile: saveFile)
                } content: {
                    switch store.selectedSidebarItem {
                    case .trainer:
                        TrainerView(saveFile: saveFile)
                            .navigationSplitViewColumnWidth(min: 480, ideal: 700)
                    case .bag:
                        BagView(saveFile: saveFile)
                            .navigationSplitViewColumnWidth(min: 480, ideal: 700)
                    case .slots:
                        BoxGridView(saveFile: saveFile)
                            .navigationSplitViewColumnWidth(min: 420, ideal: 560)
                    }
                } detail: {
                    switch store.selectedSidebarItem {
                    case .trainer, .bag:
                        EmptyView()
                    case .slots:
                        DetailPanel(saveFile: saveFile)
                            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
                    }
                }
            } else {
                EmptyStateView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// MARK: - Sidebar

private struct BoxSidebar: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarRow(
                        systemImage: "person.crop.circle",
                        title: "Trainer",
                        isActive: store.selectedSidebarItem == .trainer
                    ) {
                        store.selectedSidebarItem = .trainer
                    }
                    SidebarRow(
                        systemImage: "bag",
                        title: "Bag",
                        isActive: store.selectedSidebarItem == .bag
                    ) {
                        store.selectedSidebarItem = .bag
                    }

                    Text("STORAGE")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 10)
                        .padding(.leading, 11)
                        .padding(.bottom, 6)

                    SidebarRow(
                        systemImage: "person.3",
                        title: "Party",
                        trailingCount: saveFile.partyCount,
                        isActive: store.selectedSidebarItem == .slots(.party)
                    ) {
                        store.selectedSidebarItem = .slots(.party)
                    }

                    ForEach(0..<saveFile.boxCount, id: \.self) { box in
                        SidebarRow(
                            swatchIndex: box,
                            title: saveFile.boxName(box),
                            trailingCount: saveFile.boxSlotCount,
                            isActive: store.selectedSidebarItem == .slots(.box(box))
                        ) {
                            store.selectedSidebarItem = .slots(.box(box))
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.top, 12)
            }

            SidebarFooter(saveFile: saveFile)
        }
        .background(Theme.bgPanel)
        .navigationSplitViewColumnWidth(min: 160, ideal: 186)
        .onChange(of: store.selectedSidebarItem) { _, _ in store.selectedSlot = nil }
    }
}

/// A single sidebar navigation row (Trainer / Bag / Party / Box). Either pass `systemImage` for an
/// SF Symbol leading glyph, or `swatchIndex` to draw a colored box swatch square instead.
private struct SidebarRow: View {
    @EnvironmentObject private var accentStore: AccentStore

    var systemImage: String?
    var swatchIndex: Int?
    let title: String
    var trailingCount: Int?
    let isActive: Bool
    let action: () -> Void

    private static let swatchPalette: [Color] = [
        Color(hex: 0x3FD0C9), Color(hex: 0x4D90D5), Color(hex: 0x5BBF7A),
        Color(hex: 0xFF9F43), Color(hex: 0xF76D9C), Color(hex: 0x8B7CFF),
        Color(hex: 0xE0B34D), Color(hex: 0xC85B8E),
    ]

    var body: some View {
        let accent = accentStore.accent

        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .regular))
                        .frame(width: 15, height: 15)
                } else if let swatchIndex {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Self.swatchPalette[swatchIndex % Self.swatchPalette.count])
                        .frame(width: 9, height: 9)
                }
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailingCount {
                    Text("\(trailingCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isActive ? accent.bright : Color.white.opacity(0.78))
            .background(isActive ? accent.soft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accent.color)
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar footer

/// Pinned to the bottom of the sidebar: trainer identity, the accent-color control, and the Save
/// button. Moved out of the title bar per the Circuit spec.
private struct SidebarFooter: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile
    @State private var showAccentPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                TrainerAvatar(size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(saveFile.otName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)
                    Text("Gen \(saveFile.generation)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)

                AccentSwatchButton(isPresented: $showAccentPopover)
            }
            .padding(.horizontal, 6)

            SaveButton()
        }
        .padding(.horizontal, 2)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.5)
        }
    }
}

/// 28px accent-gradient circle with a person glyph — the trainer avatar shown in the sidebar
/// footer. Reusable elsewhere (e.g. the Trainer screen header uses a larger version of the same
/// idea).
struct TrainerAvatar: View {
    @EnvironmentObject private var accentStore: AccentStore
    var size: CGFloat = 28

    var body: some View {
        let accent = accentStore.accent.color
        Circle()
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.9), accent.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
    }
}

/// The 28px swatch button in the sidebar footer that opens the accent picker popover upward.
private struct AccentSwatchButton: View {
    @EnvironmentObject private var accentStore: AccentStore
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(accentStore.accent.color)
                .frame(width: 14, height: 14)
                .frame(width: 28, height: 28)
                .background(Theme.bgElevated2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Accent color")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            AccentSwatchPopover()
        }
    }
}

/// Popover content: a row of accent swatch circles. Clicking one sets `AccentStore.accent`.
private struct AccentSwatchPopover: View {
    @EnvironmentObject private var accentStore: AccentStore

    var body: some View {
        HStack(spacing: 9) {
            ForEach(AccentColor.allCases) { option in
                Button {
                    accentStore.accent = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if accentStore.accent == option {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                    .padding(-2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
}

/// Full-width Save button living in the sidebar footer: "Saved" (muted) when clean, "Save •"
/// (accent fill) when `SaveStore.hasUnsavedChanges` is true.
private struct SaveButton: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore

    var body: some View {
        let accent = accentStore.accent

        Button {
            store.save()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(store.hasUnsavedChanges ? "Save •" : "Saved")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(store.hasUnsavedChanges ? accent.onAccent : Color.white.opacity(0.45))
            .background(store.hasUnsavedChanges ? accent.color : Theme.bgElevated2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!store.hasUnsavedChanges)
        .help(store.hasUnsavedChanges ? "Save changes to disk" : "No unsaved changes")
    }
}

// MARK: - Start / empty state

private struct EmptyStateView: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x1C2226), Theme.bgContent],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(spacing: 14) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)

                    VStack(spacing: 6) {
                        (
                            Text("PKHeX ")
                                .foregroundStyle(Theme.textPrimary)
                            + Text("Mac")
                                .foregroundStyle(accentStore.accent.color)
                        )
                        .font(.system(size: 26, weight: .heavy))

                        Text("Save editor for Pokémon, Generations 1–7")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                DropZone()

                RecentList()

                Text("A backup is written automatically before your first save · v3.0 · Gen 1–7")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 640)
            .padding(40)
        }
    }
}

/// A poké-ball drawn with plain SwiftUI shapes: top/bottom split, a thin band, and a small
/// white-ringed center circle. No image assets required. Reusable anywhere a brand mark is needed.
struct PokeballEmblem: View {
    @EnvironmentObject private var accentStore: AccentStore
    var size: CGFloat = 42

    var body: some View {
        let accent = accentStore.accent.color
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0x2A2E35), location: 0),
                            .init(color: Color(hex: 0x2A2E35), location: 0.5),
                            .init(color: accent, location: 0.5),
                            .init(color: accent, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
                )

            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size, height: size * 0.07)

            Circle()
                .fill(Theme.bgContent)
                .overlay(
                    Circle().strokeBorder(Color(hex: 0xEEF2F4), lineWidth: 2.5)
                )
                .frame(width: size * 0.31, height: size * 0.31)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct DropZone: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore
    @State private var isTargeted = false

    var body: some View {
        let accent = accentStore.accent.color

        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(accent)

            VStack(spacing: 5) {
                Text("Drop a save file to begin")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(".sav · .dsv · .dat · .bin · .gci and more")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            HStack(spacing: 12) {
                Button {
                    store.presentOpenPanel()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Open Save…")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .foregroundStyle(accentStore.accent.onAccent)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o", modifiers: .command)

                Text("⌘O")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(34)
        .background(accent.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? accent.opacity(0.8) : accent.opacity(0.4),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    store.load(from: url)
                }
            }
            return true
        }
    }
}

/// Static placeholder rows — there is no recent-files persistence layer yet, so this is a stub
/// illustrating the intended layout rather than real data.
private struct RecentList: View {
    private struct Recent {
        let color: Color
        let fileName: String
        let subtitle: String
        let timestamp: String
    }

    private let items: [Recent] = [
        Recent(color: Color(hex: 0x3FD0C9), fileName: "DAWN.sav", subtitle: "Platinum · Gen 4", timestamp: "2 days ago"),
        Recent(color: Color(hex: 0xE0B34D), fileName: "GOLD.sav", subtitle: "Crystal · Gen 2", timestamp: "last week"),
    ]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 2)

                VStack(spacing: 2) {
                    ForEach(items, id: \.fileName) { item in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(item.color)
                                .frame(width: 9, height: 9)
                            Text(item.fileName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(width: 128, alignment: .leading)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(item.timestamp)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.35))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.bgPanel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SaveStore())
        .environmentObject(AccentStore())
}
