import AppKit
import PKHeXCore
import SwiftUI

/// A slot grid the box/party views can browse — as opposed to whole-page sidebar destinations
/// like Trainer or Bag, which have no slot grid at all.
enum SlotLocation: Hashable {
    case party
    case box(Int)

    func slotCount(in saveFile: SaveFile) -> Int {
        switch self {
        case .party: return 6
        case .box: return saveFile.boxSlotCount
        }
    }

    func slot(_ index: Int, in saveFile: SaveFile) -> PKM? {
        switch self {
        case .party: return saveFile.partySlot(index)
        case .box(let box): return saveFile.slot(box: box, slot: index)
        }
    }

    var title: String {
        switch self {
        case .party: return "Party"
        case .box(let box): return "Box \(box + 1)"
        }
    }
}

/// Everything selectable in the sidebar.
enum SidebarSelection: Hashable {
    case trainer
    case bag
    case slots(SlotLocation)
}

@MainActor
final class SaveStore: ObservableObject {
    @Published private(set) var saveFile: SaveFile?
    @Published var selectedSidebarItem: SidebarSelection = .trainer
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
            let newSaveFile = try SaveFile(data: data)
            saveFile = newSaveFile
            loadedURL = url
            selectedSidebarItem = .trainer
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
