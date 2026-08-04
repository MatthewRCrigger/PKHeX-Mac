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
                HStack(spacing: 0) {
                    PouchListView(
                        pouches: bag.pouches,
                        selectedIndex: $bagStore.selectedPouchIndex
                    )
                    .frame(width: 190)

                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 0.5)

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
                .background(Theme.bgContent)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgContent)
            }
        }
        .navigationTitle("Bag")
        .onAppear { bagStore.load(from: saveFile) }
    }
}

/// Left-hand pouch ("pocket") list. Active pouch gets an accent-soft fill and accent text.
private struct PouchListView: View {
    let pouches: [Pouch]
    @Binding var selectedIndex: Int
    @EnvironmentObject private var accentStore: AccentStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("POCKETS")
                    .font(.system(size: 10.5, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 11)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ForEach(Array(pouches.enumerated()), id: \.offset) { index, pouch in
                    let isActive = index == selectedIndex
                    Button {
                        selectedIndex = index
                    } label: {
                        HStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.pouchColor(pouch.type.displayName))
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 6, height: 6)
                            }
                            Text(pouch.type.displayName)
                                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                                .foregroundStyle(isActive ? accentStore.accent.color : Theme.textPrimary)
                            Spacer()
                            Text("\(pouch.occupiedSlotCount)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? accentStore.accent.soft : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(9)
        }
        .background(Theme.bgContent)
    }
}

/// Lists a pouch's occupied slots, in order, followed by an "Add Item" row. Slots are kept
/// contiguous from index 0 — there are no gaps/blank slots to show, so removing an item shifts
/// every following item down one slot rather than leaving a hole behind.
private struct PouchView: View {
    let pouch: Pouch
    let onChange: () -> Void
    @EnvironmentObject private var accentStore: AccentStore
    @State private var showingItemPicker = false

    private var legalItems: [(id: Int, name: String)] {
        pouch.legalItems
            .map { (id: $0, name: pouch.itemName($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: pouch name + count + "Set all to 99"
            HStack(spacing: 12) {
                Text(pouch.type.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pouch.occupiedSlotCount) / \(pouch.slotCount) slots")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    setAllTo99()
                } label: {
                    Text("Set all to 99")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentStore.accent.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentStore.accent.soft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(accentStore.accent.border, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(pouch.occupiedSlotCount == 0)
                .opacity(pouch.occupiedSlotCount == 0 ? 0.4 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }

            // Column headers
            HStack {
                Text("ITEM")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("QUANTITY")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 120, alignment: .center)
                Spacer().frame(width: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<pouch.occupiedSlotCount, id: \.self) { slot in
                        ItemRow(
                            pouch: pouch,
                            slot: slot,
                            zebra: slot.isMultiple(of: 2),
                            onChange: onChange,
                            onDelete: {
                                pouch.removeItem(at: slot)
                                onChange()
                            }
                        )
                    }

                    Button {
                        showingItemPicker = true
                    } label: {
                        HStack(spacing: 11) {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Text("+")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textTertiary)
                                )
                            Text("Add item to \(pouch.type.displayName)…")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.bgContent)
        .sheet(isPresented: $showingItemPicker) {
            ItemPickerSheet(
                pouch: pouch,
                legalItems: legalItems,
                onAdd: { itemIndex in
                    pouch.addItem(itemIndex: itemIndex, count: 1)
                    onChange()
                }
            )
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

/// A row for an occupied slot: item name, a centered quantity stepper, and a trailing delete button.
private struct ItemRow: View {
    let pouch: Pouch
    let slot: Int
    let zebra: Bool
    let onChange: () -> Void
    let onDelete: () -> Void

    private var itemIndex: Int { pouch.itemIndex(slot) }
    private var count: Int { pouch.itemCount(slot) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Theme.bgElevated1)
                        .frame(width: 30, height: 30)
                    ItemIconImage(itemID: itemIndex)
                        .padding(4)
                        .frame(width: 30, height: 30)
                }
                Text(pouch.itemName(itemIndex))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                StepperButton(symbol: "−") {
                    setCount(max(0, count - 1))
                }
                Text("\(count)")
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, alignment: .center)
                StepperButton(symbol: "+") {
                    setCount(min(99, count + 1))
                }
            }
            .frame(width: 120, alignment: .center)

            HStack {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 40, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(zebra ? Color.white.opacity(0.02) : Color.clear)
    }

    private func setCount(_ newCount: Int) {
        pouch.setItem(slot, itemIndex: itemIndex, count: newCount)
        onChange()
    }
}

private struct StepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.bgElevated1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

/// Modal sheet for adding an item to a pouch (spec §8 "Item picker"). Filters the pouch's legal
/// items by substring match on name; choosing a result adds it at quantity 1 and dismisses.
private struct ItemPickerSheet: View {
    let pouch: Pouch
    let legalItems: [(id: Int, name: String)]
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accentStore: AccentStore
    @State private var query = ""

    private var results: [(id: Int, name: String)] {
        guard !query.isEmpty else { return legalItems }
        return legalItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("Add item")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("to \(pouch.type.displayName)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Theme.bgElevated2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(accentStore.accent.color)
                    TextField("Search items…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(results.count) matches")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.bgContent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentStore.accent.color, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(accentStore.accent.soft, lineWidth: 3)
                        .padding(-3)
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results, id: \.id) { item in
                        Button {
                            onAdd(item.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.bgContent)
                                        .frame(width: 34, height: 34)
                                    ItemIconImage(itemID: item.id)
                                        .padding(4)
                                        .frame(width: 34, height: 34)
                                }
                                Text(item.name)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(pouch.type.displayName.uppercased())
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.white.opacity(0.08))
                                    )
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HoverableRowButtonStyle(hoverColor: accentStore.accent.soft))
                    }

                    if results.isEmpty {
                        Text("No items match \u{201C}\(query)\u{201D}.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(30)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 380)

            Text("Items are added to their matching pocket, quantity 1.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5)
                }
        }
        .frame(width: 560)
        .background(Theme.bgElevated1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A borderless button style that tints its background on hover, matching the picker's
/// `style-hover="background:var(--asoft)"` row treatment from the design spec.
private struct HoverableRowButtonStyle: ButtonStyle {
    let hoverColor: Color
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? hoverColor : Color.clear)
            )
            .onHover { isHovering = $0 }
    }
}
