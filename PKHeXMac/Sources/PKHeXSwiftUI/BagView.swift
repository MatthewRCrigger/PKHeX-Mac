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
    @Environment(\.isCompactLayout) private var isCompact

    var body: some View {
        Group {
            if let bag = bagStore.bag {
                // Compact widths (iPhone) stack a horizontal pocket strip over the pouch instead
                // of the 196 pt side rail, which would leave the item list ~200 pt wide.
                let layout = isCompact
                    ? AnyLayout(VStackLayout(spacing: 0))
                    : AnyLayout(HStackLayout(spacing: 0))
                layout {
                    if isCompact {
                        PouchStrip(pouches: bag.pouches, selectedIndex: $bagStore.selectedPouchIndex)
                        HRule(color: Theme.line300)
                    } else {
                        PouchListView(
                            pouches: bag.pouches,
                            selectedIndex: $bagStore.selectedPouchIndex
                        )
                        .frame(width: 196)

                        VRule(color: Theme.line300)
                    }

                    if bagStore.selectedPouchIndex < bag.pouches.count {
                        PouchView(
                            pouch: bag.pouches[bagStore.selectedPouchIndex],
                            onChange: { bagStore.commit(); store.markDirty(); refreshToken += 1 }
                        )
                        .id(refreshToken)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Spacer()
                    }
                }
                .background(Theme.void)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.void)
            }
        }
        .navigationTitle("Bag")
        .onAppear { bagStore.load(from: saveFile) }
    }
}

/// Left-hand pouch ("pocket") rail, styled like the sidebar nav. Active pouch is amber-filled.
private struct PouchListView: View {
    let pouches: [Pouch]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Pockets")
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(Array(pouches.enumerated()), id: \.offset) { index, pouch in
                    PouchRailRow(
                        name: pouch.type.displayName,
                        count: pouch.occupiedSlotCount,
                        isActive: index == selectedIndex
                    ) {
                        selectedIndex = index
                    }
                }
            }
        }
        .background(Theme.void)
    }
}

/// Compact-width stand-in for `PouchListView`: the same rows, laid out as a scrolling tab strip.
private struct PouchStrip: View {
    let pouches: [Pouch]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(pouches.enumerated()), id: \.offset) { index, pouch in
                    PouchRailRow(
                        name: pouch.type.displayName,
                        count: pouch.occupiedSlotCount,
                        isActive: index == selectedIndex
                    ) {
                        selectedIndex = index
                    }
                    .fixedSize()
                }
            }
        }
        .background(Theme.void)
    }
}

private struct PouchRailRow: View {
    let name: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isActive ? Theme.inkInvert : Color.clear)
                    .frame(width: 2)
                HStack(spacing: 8) {
                    Text(name.uppercased())
                        .font(Theme.sans(14, .semibold))
                        .tracking(1.68)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(pad(count, 2))
                        .font(Theme.mono(12, bold: true))
                }
                .padding(.horizontal, 12)
            }
            .foregroundStyle(isActive ? Theme.inkInvert : Theme.ink200)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(isActive ? Theme.amber : (isHovering ? Theme.surface3 : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }
}

/// Lists a pouch's occupied slots, in order, followed by an "Add Item" row. Slots are kept
/// contiguous from index 0 — there are no gaps/blank slots to show, so removing an item shifts
/// every following item down one slot rather than leaving a hole behind.
private struct PouchView: View {
    let pouch: Pouch
    let onChange: () -> Void
    @EnvironmentObject private var profileStore: PanelProfileStore
    @State private var showingItemPicker = false

    private var legalItems: [(id: Int, name: String)] {
        pouch.legalItems
            .map { (id: $0, name: pouch.itemName($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: pouch name, leader, item count, "Set all 99"
            HStack(spacing: 12) {
                GridText(pouch.type.displayName, .viewTitle)
                DottedLeader()
                Text("\(pad(pouch.occupiedSlotCount, 2)) items")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.ink300)
                GridButton("Set all 99", .secondary, size: .sm) {
                    setAllTo99()
                }
                .disabled(pouch.occupiedSlotCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            GridPanel {
                VStack(spacing: 0) {
                    PickerColumnHeader {
                        Text("Item")
                        Spacer()
                        Text("Quantity")
                            .frame(width: 124, alignment: .center)
                        Spacer().frame(width: 36)
                    }

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<pouch.occupiedSlotCount, id: \.self) { slot in
                                ItemRow(
                                    pouch: pouch,
                                    slot: slot,
                                    onChange: onChange,
                                    onDelete: {
                                        pouch.removeItem(at: slot)
                                        onChange()
                                    }
                                )
                            }

                            AddItemRow(pouchName: pouch.type.displayName) {
                                showingItemPicker = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Theme.void)
        .sheet(isPresented: $showingItemPicker) {
            ItemPickerSheet(
                pouch: pouch,
                legalItems: legalItems,
                onAdd: { itemIndex in
                    pouch.addItem(itemIndex: itemIndex, count: 1)
                    onChange()
                }
            )
            .environmentObject(profileStore)
        }
    }

    private func setAllTo99() {
        for slot in 0..<pouch.occupiedSlotCount {
            let currentIndex = pouch.itemIndex(slot)
            pouch.setItem(slot, itemIndex: currentIndex, count: 99)
        }
        onChange()
    }
}

/// A row for an occupied slot: item name, a quantity stepper, and a trailing delete button.
private struct ItemRow: View {
    let pouch: Pouch
    let slot: Int
    let onChange: () -> Void
    let onDelete: () -> Void

    private var itemIndex: Int { pouch.itemIndex(slot) }
    private var count: Int { pouch.itemCount(slot) }

    var body: some View {
        HStack(spacing: 0) {
            Text(pouch.itemName(itemIndex))
                .font(Theme.sans(16, .medium))
                .foregroundStyle(Theme.ink100)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            GridStepper(
                value: Binding(get: { count }, set: { _ in }),
                range: 0...99,
                width: 124
            ) { newCount in
                setCount(newCount)
            }

            GridIconButton(systemImage: "trash", size: 28, bordered: false, hoverTint: Theme.red, help: "Remove", action: onDelete)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .overlay(alignment: .bottom) { HRule(color: Theme.line400) }
    }

    private func setCount(_ newCount: Int) {
        pouch.setItem(slot, itemIndex: itemIndex, count: newCount)
        onChange()
    }
}

private struct AddItemRow: View {
    let pouchName: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("+")
                    .font(Theme.mono(13))
                Text("Add item to \(pouchName)…".uppercased())
                    .font(Theme.sans(12, .semibold))
                    .tracking(2.16)
                Spacer()
            }
            .foregroundStyle(isHovering ? Theme.amber : Theme.ink300)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(isHovering ? Theme.surface3 : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
    }
}

/// Modal sheet for adding an item to a pouch. Filters the pouch's legal items by substring match
/// on name; choosing a result adds it at quantity 1 and dismisses.
private struct ItemPickerSheet: View {
    let pouch: Pouch
    let legalItems: [(id: Int, name: String)]
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [(id: Int, name: String)] {
        guard !query.isEmpty else { return legalItems }
        return legalItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        PickerShell(
            title: "Add",
            qualifier: "ITEM",
            context: pouch.type.displayName.lowercased(),
            searchPrompt: "item name",
            searchText: $query,
            resultCount: results.count,
            footerHint: "added to its matching pocket · qty 001",
            onClose: { dismiss() },
            columns: {
                PickerColumnHeader {
                    Text("Item")
                    Spacer()
                    Text("Pocket")
                }
            },
            content: {
                ForEach(results, id: \.id) { item in
                    Button {
                        onAdd(item.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(Theme.sans(16, .medium))
                                .foregroundStyle(Theme.ink100)
                                .lineLimit(1)
                            Spacer()
                            Text(pouch.type.displayName.lowercased())
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.ink300)
                        }
                    }
                    .buttonStyle(PickerRowStyle())
                }
                if results.isEmpty {
                    PickerEmptyState()
                }
            }
        )
    }
}
