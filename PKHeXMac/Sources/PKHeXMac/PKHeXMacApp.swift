import SwiftUI

@main
struct PKHeXMacApp: App {
    @StateObject private var store = SaveStore()
    @StateObject private var accentStore = AccentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(accentStore)
                .tint(accentStore.accent.color)
                .preferredColorScheme(.dark)
                // Sidebar (186) + content min (420) + inspector (336) = 942 — the window can
                // never be resized narrower than what the fixed-width sidebar/inspector panes and
                // the content pane's own min width require (see ContentView's HStack layout).
                .frame(minWidth: 942, minHeight: 600)
                .onOpenURL { url in
                    store.openFromFinder(url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Save…") { store.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Save") { store.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.hasUnsavedChanges)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(accentStore)
                .preferredColorScheme(.dark)
        }
    }
}
