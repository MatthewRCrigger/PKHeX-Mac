import SwiftUI

@main
struct PKHeXMacApp: App {
    @StateObject private var store = SaveStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
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
                    .disabled(store.saveFile == nil)
            }
        }
    }
}
