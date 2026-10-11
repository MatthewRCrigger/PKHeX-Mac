import SwiftUI

@main
struct PKHeXMacApp: App {
    // Shared across every window (like PanelProfileStore) — SaveStore is deliberately NOT here, since
    // each window needs its own independently-loaded save. See DragRegistry's docs for why
    // cross-window drag-and-drop needs an app-wide coordinator despite that per-window split.
    @StateObject private var profileStore = PanelProfileStore()
    @StateObject private var dragRegistry = DragRegistry()
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.saveStore) private var focusedStore
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        // `id: "save"` + a fresh SaveStore per resolved scene is what gives every new window (via
        // openWindow(id: "save") below, or the system's own Cmd+N/Dock "New Window") its own
        // independent save — opening a file in one window never affects another's.
        WindowGroup(id: "save") {
            SaveWindow()
                .environmentObject(profileStore)
                .environmentObject(dragRegistry)
                .tint(Theme.amber)
                .preferredColorScheme(.dark)
                // Sidebar (200) + content min (420) + inspector (340) + frame chrome — the window
                // can never be resized narrower than what the fixed-width sidebar/inspector panes
                // and the content pane's own min width require (see ContentView's HStack layout).
                #if os(macOS)
                .frame(minWidth: 990, minHeight: 640)
                .onAppear {
                    // Wired here (rather than at struct init) since `openWindow` only becomes
                    // valid once resolved from a real scene's environment.
                    appDelegate.openNewWindow = { openWindow(id: "save") }
                }
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") { openWindow(id: "save") }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Save…") { focusedStore?.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(focusedStore == nil)
            }
            CommandGroup(after: .saveItem) {
                Button("Save") { focusedStore?.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(focusedStore?.hasUnsavedChanges != true)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(profileStore)
                .preferredColorScheme(.dark)
        }
        #endif
    }
}

/// Hosts one window's independent `SaveStore` and publishes it as the scene's focused value so the
/// app-level ⌘O/⌘S commands act on whichever window is currently key (see `FocusedSaveStore.swift`).
private struct SaveWindow: View {
    @StateObject private var store = SaveStore()

    var body: some View {
        ContentView()
            .environmentObject(store)
            .focusedSceneValue(\.saveStore, store)
            .onOpenURL { url in
                store.openFromFinder(url)
            }
    }
}
