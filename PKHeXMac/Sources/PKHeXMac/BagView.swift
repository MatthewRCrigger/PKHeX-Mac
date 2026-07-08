import PKHeXCore
import SwiftUI

@MainActor
final class BagStore: ObservableObject {
    @Published var bag: Bag?
    @Published var selectedPouchIndex = 0
    private weak var saveFile: SaveFile?

    func load(from saveFile: SaveFile) {
        self.saveFile = saveFile
        bag = saveFile.loadBag()
        selectedPouchIndex = 0
    }

    /// Commits the in-memory bag snapshot back into the save so it's included when the save is written.
    func commit() {
        guard let bag, let saveFile else { return }
        bag.commit(to: saveFile)
    }
}

struct BagView: View {
    let saveFile: SaveFile
    @StateObject private var bagStore = BagStore()

    var body: some View {
        Group {
            if let bag = bagStore.bag {
                HSplitView {
                    List(selection: $bagStore.selectedPouchIndex) {
                        ForEach(Array(bag.pouches.enumerated()), id: \.offset) { index, pouch in
                            Text(pouch.type.displayName)
                                .tag(index)
                        }
                    }
                    .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)

                    if bagStore.selectedPouchIndex < bag.pouches.count {
                        PouchView(pouch: bag.pouches[bagStore.selectedPouchIndex], onChange: bagStore.commit)
                            .frame(minWidth: 360)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Bag")
        .onAppear { bagStore.load(from: saveFile) }
    }
}

private struct PouchView: View {
    let pouch: Pouch
    let onChange: () -> Void
    @State private var refreshToken = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(0..<pouch.slotCount, id: \.self) { slot in
                    ItemRow(pouch: pouch, slot: slot, onChange: {
                        onChange()
                        refreshToken += 1
                    })
                }
            }
            .id(refreshToken)
        }
        .background(.background)
    }
}

private struct ItemRow: View {
    let pouch: Pouch
    let slot: Int
    let onChange: () -> Void

    @State private var countText: String = ""

    private var itemIndex: Int { pouch.itemIndex(slot) }

    var body: some View {
        HStack {
            Text(itemIndex == 0 ? "—" : PokemonNames.item(UInt16(itemIndex)))
                .frame(minWidth: 160, alignment: .leading)
                .foregroundStyle(itemIndex == 0 ? .secondary : .primary)
            Spacer()
            if itemIndex != 0 {
                TextField("Qty", text: $countText)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        if let count = Int(countText) {
                            pouch.setItem(slot, itemIndex: itemIndex, count: count)
                            onChange()
                        }
                    }
                Button(role: .destructive) {
                    pouch.setItem(slot, itemIndex: 0, count: 0)
                    onChange()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(slot.isMultiple(of: 2) ? Color.gray.opacity(0.05) : Color.clear)
        .onAppear { countText = String(pouch.itemCount(slot)) }
    }
}
