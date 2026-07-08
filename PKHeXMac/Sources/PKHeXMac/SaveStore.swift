import AppKit
import PKHeXCore
import SwiftUI

@MainActor
final class SaveStore: ObservableObject {
    @Published private(set) var saveFile: SaveFile?
    @Published var selectedBox = 0
    @Published var selectedSlot: Int?
    @Published var errorMessage: String?
    private var loadedURL: URL?

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Save File"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            saveFile = try SaveFile(data: data)
            loadedURL = url
            selectedBox = 0
            selectedSlot = nil
        } catch {
            errorMessage = "Couldn't open that file as a Pokémon save: \(error)"
        }
    }

    func save() {
        guard let saveFile, let loadedURL else { return }
        do {
            let data = try saveFile.write()
            try data.write(to: loadedURL)
        } catch {
            errorMessage = "Couldn't save: \(error)"
        }
    }
}
