import PKHeXCore
import SwiftUI

// Compact-width (iPhone) navigation. The regular layout's sidebar doesn't fit beside the content,
// so its sections move into a bottom dock, with the box list behind a picker sheet.

/// Bottom dock: Trainer, Bag, Party, Boxes, Save. The active section is amber-filled like the
/// sidebar's active row; Save lights amber while there are unsaved changes.
struct NavDock: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var profileStore: PanelProfileStore
    let saveFile: SaveFile

    @State private var isBoxPickerPresented = false

    private var selectedBox: Int? {
        if case .slots(.box(let box)) = store.selectedSidebarItem { return box }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            DockItem(systemImage: "person", title: "Trainer",
                     isActive: store.selectedSidebarItem == .trainer) {
                store.selectedSidebarItem = .trainer
            }
            DockItem(systemImage: "folder", title: "Bag",
                     isActive: store.selectedSidebarItem == .bag) {
                store.selectedSidebarItem = .bag
            }
            DockItem(systemImage: "square.stack.3d.up", title: "Party",
                     isActive: store.selectedSidebarItem == .slots(.party)) {
                store.selectedSidebarItem = .slots(.party)
            }
            DockItem(systemImage: "cylinder.split.1x2",
                     title: selectedBox.map { "Box \(pad($0 + 1, 2))" } ?? "Boxes",
                     isActive: selectedBox != nil) {
                isBoxPickerPresented = true
            }
            saveItem
        }
        .frame(height: 52)
        .overlay(alignment: .top) { HRule(color: Theme.line300) }
        .background(Theme.void)
        .sheet(isPresented: $isBoxPickerPresented) {
            BoxPickerSheet(saveFile: saveFile, selectedBox: selectedBox) { box in
                store.selectedSidebarItem = .slots(.box(box))
                isBoxPickerPresented = false
            }
            .environmentObject(profileStore)
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
    }

    private var saveItem: some View {
        let isDirty = store.hasUnsavedChanges
        return Button { store.save() } label: {
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .regular))
                    .frame(height: 18)
                Text(isDirty ? "Save \(pad(store.changeCount, 2))" : "Saved")
                    .font(Theme.sans(12, .semibold))
                    .tracking(1.44)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isDirty ? Theme.amber : Theme.ink400)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isDirty ? Theme.amberFill : .clear, ignoresSafeAreaEdges: [])
            .overlay(alignment: .leading) { VRule(color: Theme.line300) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isDirty)
        .accessibilityLabel(isDirty ? "Write changes to the save file" : "No unsaved changes")
    }
}

/// One dock section: icon over a caps label, amber-filled with black text when active.
private struct DockItem: View {
    let systemImage: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .regular))
                    .frame(height: 18)
                Text(title)
                    .font(Theme.sans(12, .semibold))
                    .tracking(1.44)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Theme.inkInvert : Theme.ink200)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isActive ? Theme.amber : .clear, ignoresSafeAreaEdges: [])
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Sheet listing every box as a tile (name, occupancy, fill meter). Choosing one opens it.
struct BoxPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let saveFile: SaveFile
    let selectedBox: Int?
    let onChoose: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        PickerShell(
            title: "Boxes", qualifier: "select",
            context: "\(pad(saveFile.boxCount, 2)) boxes",
            footerHint: "tap a box to open it",
            onClose: { dismiss() }
        ) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<saveFile.boxCount, id: \.self) { box in
                    BoxTile(
                        number: box + 1,
                        name: saveFile.boxName(box),
                        occupied: saveFile.boxOccupiedSlotCount(box),
                        capacity: saveFile.boxSlotCount,
                        isSelected: box == selectedBox
                    ) {
                        onChoose(box)
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct BoxTile: View {
    let number: Int
    let name: String
    let occupied: Int
    let capacity: Int
    let isSelected: Bool
    let action: () -> Void

    /// The default name ("Box 3") repeats the number already shown, so only custom names display.
    private var customName: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.lowercased() == "box \(number)" ? nil : trimmed
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    GridText("Box \(pad(number, 2))", .label, color: isSelected ? Theme.amber : Theme.ink100)
                    Spacer(minLength: 0)
                    if isSelected {
                        StatusDot(color: Theme.amber)
                    }
                }
                Text(customName ?? " ")
                    .font(Theme.sans(14, .medium))
                    .foregroundStyle(Theme.ink200)
                    .lineLimit(1)
                Text("\(pad(occupied, 2))/\(pad(capacity, 2))")
                    .font(Theme.mono(12))
                    .foregroundStyle(occupied == 0 ? Theme.ink400 : Theme.ink300)
                GridMeter(value: Double(occupied), maximum: Double(capacity),
                          fill: isSelected ? Theme.amber : Theme.line100, height: 6)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.amberFill : Theme.surface2)
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.amber : Theme.line300, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Box \(number), \(occupied) of \(capacity)")
    }
}
