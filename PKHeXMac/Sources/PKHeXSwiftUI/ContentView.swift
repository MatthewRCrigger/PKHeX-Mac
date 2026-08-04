import AppKit
import PKHeXCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        Group {
            if let saveFile = store.saveFile {
                // A plain HStack, not NavigationSplitView. NavigationSplitView is backed by a real
                // NSSplitViewController on macOS, which owns its dividers' draggability itself —
                // no SwiftUI-side width constraint actually disables dragging, only hints at a
                // preferred size. Worse, NSSplitViewController auto-persists dragged frame sizes
                // via AppKit's own window-identifier-derived autosave, so a user who drags the
                // sidebar to zero width gets that collapsed state restored on every future launch
                // with no in-app way back (confirmed: this happened twice in testing, and the fix
                // both times was manually deleting "NSSplitView Subview Frames..." keys from
                // `defaults`). A plain HStack has no NSSplitView anywhere in it: nothing to drag,
                // nothing for AppKit to persist, so this entire class of stuck state is impossible.
                HStack(spacing: 0) {
                    BoxSidebar(saveFile: saveFile)

                    Divider()

                    Group {
                        switch store.selectedSidebarItem {
                        case .trainer:
                            TrainerView(saveFile: saveFile)
                        case .bag:
                            BagView(saveFile: saveFile)
                        case .slots:
                            BoxGridView(saveFile: saveFile)
                        }
                    }
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

                    if case .slots = store.selectedSidebarItem {
                        Divider()
                        DetailPanel(saveFile: saveFile)
                            .frame(width: 336)
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
            VStack(alignment: .leading, spacing: 1) {
                Text(saveFile.gameName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
                Text("Generation \(saveFile.generation)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.top, 14)
            .padding(.bottom, 10)

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
                        trailingText: "\(saveFile.partyCount)",
                        isActive: store.selectedSidebarItem == .slots(.party)
                    ) {
                        store.selectedSidebarItem = .slots(.party)
                    }

                    ForEach(0..<saveFile.boxCount, id: \.self) { box in
                        SidebarRow(
                            systemImage: "shippingbox",
                            title: saveFile.boxName(box),
                            trailingText: "\(saveFile.boxOccupiedSlotCount(box)) / \(saveFile.boxSlotCount)",
                            isActive: store.selectedSidebarItem == .slots(.box(box))
                        ) {
                            store.selectedSidebarItem = .slots(.box(box))
                        }
                    }
                }
                .padding(.horizontal, 9)
            }

            SidebarFooter()
        }
        .frame(width: 186)
        .background(Theme.bgPanel)
        .onChange(of: store.selectedSidebarItem) { _, _ in store.inspectedSlot = nil }
    }
}

/// A single sidebar navigation row (Trainer / Bag / Party / Box), with a leading SF Symbol glyph.
private struct SidebarRow: View {
    @EnvironmentObject private var accentStore: AccentStore

    var systemImage: String?
    let title: String
    var trailingText: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        let accent = accentStore.accent

        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .regular))
                        .frame(width: 15, height: 15)
                }
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailingText {
                    Text(trailingText)
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

/// Pinned to the bottom of the sidebar: Open and Save buttons side by side.
private struct SidebarFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            OpenSaveButton()
            SaveButton()
        }
        .padding(.horizontal, 9)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.5)
        }
    }
}

/// Opens a different save file. Lives in the sidebar footer so it's reachable without going to
/// the File menu or quitting the app — the only other ways to switch files once one is open.
private struct OpenSaveButton: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        Button {
            store.presentOpenPanel()
        } label: {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 34, height: 30)
                .background(Theme.bgElevated2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Open a different save file… (⌘O)")
    }
}

/// Save button living in the sidebar footer: "Saved" (muted) when clean, "Save •" (accent fill)
/// when `SaveStore.hasUnsavedChanges` is true.
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
    @AppStorage("backupBeforeWriting") private var backupBeforeWriting = true

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

                Text(
                    backupBeforeWriting
                        ? "A backup is written automatically before your first save · Gen 1–7"
                        : "Gen 1–7"
                )
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

#Preview {
    ContentView()
        .environmentObject(SaveStore())
        .environmentObject(AccentStore())
}
