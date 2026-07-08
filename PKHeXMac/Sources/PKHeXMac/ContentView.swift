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
        List(0..<saveFile.boxCount, id: \.self, selection: $store.selectedBox) { box in
            Text("Box \(box + 1)")
                .tag(box)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 140, ideal: 160)
    }
}

#Preview {
    ContentView()
        .environmentObject(SaveStore())
}
