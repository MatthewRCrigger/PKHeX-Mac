import PKHeXCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        Group {
            if let saveFile = store.saveFile {
                NavigationSplitView {
                    BoxSidebar(saveFile: saveFile)
                } content: {
                    switch store.selectedSidebarItem {
                    case .trainer:
                        TrainerView(saveFile: saveFile)
                    case .bag:
                        BagView(saveFile: saveFile)
                    case .slots:
                        BoxGridView(saveFile: saveFile)
                    }
                } detail: {
                    switch store.selectedSidebarItem {
                    case .trainer, .bag:
                        EmptyView()
                    case .slots:
                        DetailPanel(saveFile: saveFile)
                            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
                    }
                }
            } else {
                EmptyStateView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Save File Open")
                .font(.title2.weight(.medium))
            Button("Open Save…") { store.presentOpenPanel() }
                .keyboardShortcut("o", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct BoxSidebar: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    var body: some View {
        List(selection: $store.selectedSidebarItem) {
            Label("Trainer", systemImage: "person.crop.circle")
                .tag(SidebarSelection.trainer)
            Label("Bag", systemImage: "bag")
                .tag(SidebarSelection.bag)
            Section {
                Label("Party (\(saveFile.partyCount))", systemImage: "person.3")
                    .tag(SidebarSelection.slots(.party))
                ForEach(0..<saveFile.boxCount, id: \.self) { box in
                    Text("Box \(box + 1)")
                        .tag(SidebarSelection.slots(.box(box)))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        .onChange(of: store.selectedSidebarItem) { _, _ in store.selectedSlot = nil }
    }
}

#Preview {
    ContentView()
        .environmentObject(SaveStore())
}
