import PKHeXCore
import SwiftUI

struct BoxGridView: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 84), spacing: 8, alignment: .top)]

    private var location: SlotLocation {
        guard case .slots(let location) = store.selectedSidebarItem else { return .party }
        return location
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<location.slotCount(in: saveFile), id: \.self) { slot in
                    SlotTile(
                        pkm: location.slot(slot, in: saveFile),
                        isSelected: store.selectedSlot == slot
                    )
                    .onTapGesture { store.selectedSlot = slot }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .navigationTitle(location.title)
    }
}

private struct SlotTile: View {
    let pkm: PKM?
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.08))
            .overlay {
                if let pkm {
                    SpriteImage(fileName: pkm.spriteFileName)
                        .padding(4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct SpriteImage: View {
    let fileName: String

    var body: some View {
        if let nsImage = NSImage(named: fileName) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}
