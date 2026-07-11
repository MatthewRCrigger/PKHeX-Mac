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
                .frame(minWidth: 900, minHeight: 600)
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
