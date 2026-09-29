import AppKit
import PKHeXCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            GridFrame {
                VStack(spacing: 0) {
                    TitleStrip()
                    HRule(color: Theme.line300)

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
                                .frame(width: 200)

                            VRule(color: Theme.line300)

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
                                VRule(color: Theme.line300)
                                DetailPanel(saveFile: saveFile)
                                    .frame(width: 340)
                            }
                        }
                    } else {
                        EmptyStateView()
                    }

                    HRule(color: Theme.line300)
                    StatusBar()
                }
                .background(Theme.void)
            }
            .padding(4)

            DialogHost()
        }
        .background(WindowConfigurator())
    }
}

extension SaveFile {
    /// Count of occupied item slots across every pouch — shown next to Bag in the sidebar.
    fileprivate var bagItemKindCount: Int {
        loadBag()?.pouches.reduce(0) { $0 + $1.occupiedSlotCount } ?? 0
    }
}

// MARK: - Window chrome

/// Configures the hosting `NSWindow` for GRID's own chrome: transparent title bar, black
/// background, native traffic lights hidden (the title strip draws outlined ones that drive the
/// same window actions).
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .black
            window.isMovableByWindowBackground = false
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A view that lets the window be dragged by mouse-down anywhere on it.
private struct WindowDragArea: NSViewRepresentable {
    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 36 pt title bar: outlined traffic lights, centered wordmark, ghost settings button.
private struct TitleStrip: View {
    var body: some View {
        ZStack {
            WindowDragArea()

            Wordmark(size: 14, tracking: 3.92)

            HStack {
                TrafficLights()
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.ink200)
                        .frame(width: 28, height: 28)
                        .hoverFill()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
    }
}

/// "PKHEX MAC": amber "PKHEX" and ink "MAC", Rajdhani 600 with wide tracking.
struct Wordmark: View {
    var size: CGFloat
    var tracking: CGFloat

    var body: some View {
        (
            Text("PKHEX ").foregroundColor(Theme.amber)
            + Text("MAC").foregroundColor(Theme.ink100)
        )
        .font(Theme.sans(size, .semibold))
        .tracking(tracking)
    }
}

/// Three 12 pt outline circles standing in for the (hidden) native window buttons.
private struct TrafficLights: View {
    @State private var window: NSWindow?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            light(color: Theme.line200, symbol: "xmark") { window?.performClose(nil) }
            light(color: Theme.line300, symbol: "minus") { window?.miniaturize(nil) }
            light(color: Theme.line300, symbol: "plus") { window?.zoom(nil) }
        }
        .onHover { isHovering = $0 }
        .background(WindowFinder(window: $window))
    }

    private func light(color: Color, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .strokeBorder(color, lineWidth: 1)
                .frame(width: 12, height: 12)
                .overlay {
                    if isHovering {
                        Image(systemName: symbol)
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(color)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct WindowFinder: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if window !== nsView.window { window = nsView.window }
        }
    }
}

// MARK: - Sidebar

private struct BoxSidebar: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saveFile.gameName.uppercased())
                    .font(Theme.sans(16, .semibold))
                    .tracking(1.92)
                    .foregroundStyle(Theme.ink100)
                    .lineLimit(1)
                Text("generation \(saveFile.generation)")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.ink300)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SidebarRow(
                        systemImage: "person",
                        title: "Trainer",
                        isActive: store.selectedSidebarItem == .trainer
                    ) {
                        store.selectedSidebarItem = .trainer
                    }
                    SidebarRow(
                        systemImage: "folder",
                        title: "Bag",
                        trailingText: pad(saveFile.bagItemKindCount, 2),
                        isActive: store.selectedSidebarItem == .bag
                    ) {
                        store.selectedSidebarItem = .bag
                    }

                    SectionHeader("Storage")
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    SidebarRow(
                        systemImage: "square.stack.3d.up",
                        title: "Party",
                        trailingText: pad(saveFile.partyCount),
                        isActive: store.selectedSidebarItem == .slots(.party)
                    ) {
                        store.selectedSidebarItem = .slots(.party)
                    }

                    ForEach(0..<saveFile.boxCount, id: \.self) { box in
                        SidebarRow(
                            systemImage: "cylinder.split.1x2",
                            title: "Box \(pad(box + 1, 2))",
                            trailingText: "\(pad(saveFile.boxOccupiedSlotCount(box), 2))/\(pad(saveFile.boxSlotCount, 2))",
                            isActive: store.selectedSidebarItem == .slots(.box(box))
                        ) {
                            store.selectedSidebarItem = .slots(.box(box))
                        }
                    }
                }
            }

            SidebarFooter()
        }
        .background(Theme.void)
        .onChange(of: store.selectedSidebarItem) { _, _ in store.inspectedSlot = nil }
    }
}

/// A single sidebar navigation row: 36 tall, icon, caps label, trailing mono count. The active row
/// is amber with black text; a 2 pt edge marker slot is always reserved so rows don't shift.
private struct SidebarRow: View {
    var systemImage: String
    let title: String
    var trailingText: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 16, height: 16)
                Text(title.uppercased())
                    .font(Theme.sans(14, .semibold))
                    .tracking(1.68)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailingText {
                    Text(trailingText)
                        .font(Theme.mono(12, bold: isActive))
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isActive ? Theme.inkInvert : Theme.ink200)
            .hoverFill(base: isActive ? Theme.amber : .clear, hover: isActive ? Theme.amber : Theme.surface3)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isActive ? Theme.inkInvert : .clear)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar footer

/// Pinned to the bottom of the sidebar: a square Open icon button and the full-width write button.
private struct SidebarFooter: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        HStack(spacing: 8) {
            GridIconButton(systemImage: "folder", size: 36, help: "Open a different save file… (⌘O)") {
                store.presentOpenPanel()
            }

            GridButton(
                store.hasUnsavedChanges ? "Write .sav" : "Saved",
                store.hasUnsavedChanges ? .primary : .secondary,
                size: .md,
                systemImage: "square.and.arrow.down",
                fullWidth: true
            ) {
                store.save()
            }
            .disabled(!store.hasUnsavedChanges)
            .help(store.hasUnsavedChanges ? "Write changes to disk (⌘S)" : "No unsaved changes")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { HRule(color: Theme.line300) }
    }
}

// MARK: - Status bar

/// 28 pt mono status line: path ··· clipboard · generation · box · save state.
private struct StatusBar: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        HStack(spacing: 10) {
            if let saveFile = store.saveFile {
                Text(store.displayPath ?? "untitled")
                    .lineLimit(1)
                    .truncationMode(.middle)
                DottedLeader()
                if let clip = store.copiedPKM {
                    Text("clip · \((clip.nickname.isEmpty ? clip.speciesName : clip.nickname).lowercased())")
                        .foregroundStyle(Theme.cyan)
                        .lineLimit(1)
                    separator
                }
                Text("gen\(saveFile.generation) · \(saveFile.gameName.lowercased())")
                    .lineLimit(1)
                if let location = boxSummary(saveFile) {
                    separator
                    Text(location)
                }
                separator
                saveState
            } else {
                Text("no save loaded")
                DottedLeader()
                Text("gen 1–7")
            }
        }
        .font(Theme.mono(12))
        .foregroundStyle(Theme.ink300)
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private var separator: some View {
        Text("|").foregroundStyle(Theme.line300)
    }

    private func boxSummary(_ saveFile: SaveFile) -> String? {
        guard case .slots(let location) = store.selectedSidebarItem else { return nil }
        switch location {
        case .party:
            return "party \(pad(saveFile.partyCount))/006"
        case .box(let box):
            return "box\(pad(box + 1, 2)) \(pad(saveFile.boxOccupiedSlotCount(box)))/\(pad(saveFile.boxSlotCount))"
        }
    }

    @ViewBuilder
    private var saveState: some View {
        HStack(spacing: 6) {
            if store.hasUnsavedChanges {
                StatusDot(color: Theme.amber)
                Text("unsaved \(pad(store.changeCount))").foregroundStyle(Theme.amber)
            } else if let receipt = store.lastWrite {
                StatusDot(color: Theme.green)
                Text("written \(Self.timeFormatter.string(from: receipt.date))\(receipt.backupWritten ? " · .bak written" : "")")
                    .foregroundStyle(Theme.green)
            } else {
                StatusDot(color: Theme.green)
                Text("synced").foregroundStyle(Theme.green)
            }
        }
        .lineLimit(1)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Dialogs

/// Renders the window-level GRID dialogs: discard-changes, release-confirm, and error.
private struct DialogHost: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        if let request = store.releaseRequest {
            GridScrim {
                GridDialog(
                    title: "Release",
                    qualifier: "Pokémon",
                    isDanger: true,
                    message: "Release \(pad(request.count)) Pokémon from \(request.locationName)? This is permanent once the save is written."
                ) {
                    GridButton("Cancel", .secondary) { store.releaseRequest = nil }
                        .keyboardShortcut(.cancelAction)
                    GridButton("Release", .dangerSolid) {
                        store.releaseRequest = nil
                        request.perform()
                    }
                }
            }
        } else if store.pendingOpen != nil {
            GridScrim {
                GridDialog(
                    title: "Discard",
                    qualifier: "Changes",
                    isDanger: true,
                    message: "Opening a different save file discards \(pad(store.changeCount)) unsaved changes to this one."
                ) {
                    GridButton("Cancel", .secondary) { store.cancelPendingOpen() }
                        .keyboardShortcut(.cancelAction)
                    GridButton("Discard", .dangerSolid) { store.confirmPendingOpen() }
                }
            }
        } else if let message = store.errorMessage {
            GridScrim {
                GridDialog(title: "Error", message: message) {
                    GridButton("OK", .primary) { store.errorMessage = nil }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

// MARK: - Start / empty state

private struct EmptyStateView: View {
    @AppStorage("backupBeforeWriting") private var backupBeforeWriting = true

    var body: some View {
        ZStack {
            Theme.void
            GraphPaper()

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Wordmark(size: 40, tracking: 11.2)
                    Text("Save editor for Pokémon, generations 1–7.")
                        .font(Theme.sans(18, .regular))
                        .foregroundStyle(Theme.ink200)
                }

                DropZone()

                Text(
                    backupBeforeWriting
                        ? "backup written automatically before first save · gen 1–7"
                        : "gen 1–7"
                )
                .font(Theme.mono(12))
                .foregroundStyle(Theme.ink300)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 640)
            .padding(40)
        }
    }
}

private struct DropZone: View {
    @EnvironmentObject private var store: SaveStore
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.cyan)

            VStack(spacing: 6) {
                GridText("Drop a save file to begin", .nav, color: Theme.ink100)
                Text(".sav · .dsv · .dat · .bin · .gci and more")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.ink300)
            }

            HStack(spacing: 10) {
                GridButton("Open Save…", .primary, size: .lg) {
                    store.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                KeyCap(label: "⌘")
                KeyCap(label: "O")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .background(Theme.surface1)
        .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
        .padding(4)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isTargeted ? Theme.cyan : Theme.line200,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
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
        .environmentObject(PanelProfileStore())
        .environmentObject(DragRegistry())
}
