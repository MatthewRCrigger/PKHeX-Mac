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
        .onAppear { bagStore.load(from: saveFile) }
    }
}

/// Lists a pouch's occupied slots, in order, followed by an "Add Item" row. Slots are kept
/// contiguous from index 0 — there are no gaps/blank slots to show, so removing an item shifts
/// every following item down one slot rather than leaving a hole behind.
private struct PouchView: View {
    let pouch: Pouch
    let onChange: () -> Void

    private var legalItems: [(id: Int, name: String)] {
        pouch.legalItems
            .map { (id: $0, name: PokemonNames.item(UInt16($0))) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(0..<pouch.occupiedSlotCount, id: \.self) { slot in
                    ItemRow(
                        pouch: pouch,
                        slot: slot,
                        legalItems: legalItems,
                        onChange: onChange,
                        onDelete: {
                            pouch.removeItem(at: slot)
                            onChange()
                        }
                    )
                }

                AddItemRow(
                    rowIndex: pouch.occupiedSlotCount,
                    legalItems: legalItems,
                    onAdd: { itemIndex in
                        pouch.addItem(itemIndex: itemIndex, count: 1)
                        onChange()
                    }
                )
            }
        }
        .background(.background)
    }
}

/// A row for an occupied slot: an inline dropdown bound to the slot's current item (changing the
/// selection swaps the item in place) plus a quantity field and delete button.
private struct ItemRow: View {
    let pouch: Pouch
    let slot: Int
    let legalItems: [(id: Int, name: String)]
    let onChange: () -> Void
    let onDelete: () -> Void

    @State private var countText: String = ""

    private var itemIndex: Int { pouch.itemIndex(slot) }

    var body: some View {
        HStack {
            Picker("", selection: Binding(
                get: { itemIndex },
                set: { newIndex in
                    pouch.setItem(slot, itemIndex: newIndex, count: pouch.itemCount(slot))
                    onChange()
                }
            )) {
                ForEach(legalItems, id: \.id) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .labelsHidden()
            .frame(minWidth: 160, alignment: .leading)

            Spacer()

            TextField("Qty", text: $countText)
                .frame(width: 70)
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    if let count = Int(countText) {
                        pouch.setItem(slot, itemIndex: itemIndex, count: count)
                        onChange()
                    }
                }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(slot.isMultiple(of: 2) ? Color.gray.opacity(0.05) : Color.clear)
        .onAppear { countText = String(pouch.itemCount(slot)) }
    }
}

/// Trailing row appended after every occupied slot: an inline dropdown with no current selection
/// ("Add Item…" placeholder). Picking an item appends it straight into the pouch's first empty
/// slot — no extra confirmation step.
private struct AddItemRow: View {
    let rowIndex: Int
    let legalItems: [(id: Int, name: String)]
    let onAdd: (Int) -> Void

    @State private var selection: Int?

    var body: some View {
        HStack {
            Picker("", selection: Binding(
                get: { selection },
                set: { newIndex in
                    if let newIndex {
                        onAdd(newIndex)
                    }
                    selection = nil
                }
            )) {
                Text("Add Item…").tag(Int?.none)
                ForEach(legalItems, id: \.id) { item in
                    Text(item.name).tag(Int?.some(item.id))
                }
            }
            .labelsHidden()
            .frame(minWidth: 160, alignment: .leading)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rowIndex.isMultiple(of: 2) ? Color.gray.opacity(0.05) : Color.clear)
    }
}
