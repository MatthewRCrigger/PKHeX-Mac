import PKHeXCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SaveStore

    var body: some View {
        Group {
            if let saveFile = store.saveFile {
                NavigationSplitView {
                    BoxSidebar(saveFile: saveFile)
                } detail: {
                    HSplitView {
                        BoxGridView(saveFile: saveFile)
                            .frame(minWidth: 420)
                        DetailPanel(saveFile: saveFile)
                            .frame(minWidth: 280, idealWidth: 320)
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
        List(selection: $store.selectedLocation) {
            Label("Party (\(saveFile.partyCount))", systemImage: "person.3")
                .tag(SlotLocation.party)
            ForEach(0..<saveFile.boxCount, id: \.self) { box in
                Text("Box \(box + 1)")
                    .tag(SlotLocation.box(box))
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        .onChange(of: store.selectedLocation) { _, _ in store.selectedSlot = nil }
    }
}

#Preview {
    ContentView()
        .environmentObject(SaveStore())
}
