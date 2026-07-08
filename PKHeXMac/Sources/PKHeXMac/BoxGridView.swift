import PKHeXCore
import SwiftUI

struct BoxGridView: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<saveFile.boxSlotCount, id: \.self) { slot in
                    SlotTile(
                        pkm: saveFile.slot(box: store.selectedBox, slot: slot),
                        isSelected: store.selectedSlot == slot
                    )
                    .onTapGesture { store.selectedSlot = slot }
                }
            }
            .padding(12)
        }
        .background(.background)
        .navigationTitle("Box \(store.selectedBox + 1)")
        .onChange(of: store.selectedBox) { _, _ in store.selectedSlot = nil }
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
