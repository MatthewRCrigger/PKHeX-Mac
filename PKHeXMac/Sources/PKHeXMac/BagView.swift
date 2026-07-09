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
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile
    @StateObject private var bagStore = BagStore()
    @State private var isPresentingAddItem = false
    @State private var refreshToken = 0

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
                        PouchView(
                            pouch: bag.pouches[bagStore.selectedPouchIndex],
                            onChange: { bagStore.commit(); store.markDirty(); refreshToken += 1 }
                        )
                        .id(refreshToken)
                        .frame(minWidth: 360)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Bag")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .disabled(bagStore.bag == nil)
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            if let bag = bagStore.bag, bagStore.selectedPouchIndex < bag.pouches.count {
                AddItemSheet(pouch: bag.pouches[bagStore.selectedPouchIndex]) {
                    bagStore.commit()
                    store.markDirty()
                    refreshToken += 1
                    isPresentingAddItem = false
                } onCancel: {
                    isPresentingAddItem = false
                }
            }
        }
        .onAppear { bagStore.load(from: saveFile) }
    }
}

private struct PouchView: View {
    let pouch: Pouch
    let onChange: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(0..<pouch.slotCount, id: \.self) { slot in
                    ItemRow(pouch: pouch, slot: slot, onChange: onChange)
                }
            }
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

/// Sheet for adding a new item to a pouch: search the pouch's legal item list, pick one, set a
/// starting quantity. Works the same whether the pouch is a Gen 1-3 style free-form bag (few
/// slots, many legal items) or a Gen 4+ style one-slot-per-item bag — either way this just finds
/// the pouch's first empty slot and assigns it.
private struct AddItemSheet: View {
    let pouch: Pouch
    let onAdd: () -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var selectedItemIndex: Int?
    @State private var countText = "1"

    private var filteredItems: [(id: Int, name: String)] {
        let all = pouch.legalItems.map { (id: $0, name: PokemonNames.item(UInt16($0))) }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Add to \(pouch.type.displayName)")
                .font(.headline)
                .padding()

            TextField("Search items…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filteredItems, id: \.id, selection: $selectedItemIndex) { item in
                Text(item.name).tag(item.id)
            }
            .frame(minHeight: 240)

            HStack {
                Text("Quantity")
                TextField("Qty", text: $countText)
                    .frame(width: 70)
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Add") {
                    guard let selectedItemIndex, let count = Int(countText) else { return }
                    pouch.addItem(itemIndex: selectedItemIndex, count: count)
                    onAdd()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedItemIndex == nil || Int(countText) == nil)
            }
            .padding()
        }
        .frame(width: 360, height: 420)
    }
}
