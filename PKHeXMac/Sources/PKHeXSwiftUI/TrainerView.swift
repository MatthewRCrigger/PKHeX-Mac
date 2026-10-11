import PKHeXCore
import SwiftUI

struct TrainerView: View {
    @EnvironmentObject private var store: SaveStore
    @Environment(\.isCompactLayout) private var isCompact
    let saveFile: SaveFile

    @State private var genderIndex = 0
    @State private var refreshToken = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                let panels = isCompact
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                panels {
                    identityPanel
                    progressPanel
                }
            }
            .padding(isCompact ? 12 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.void)
        .id(refreshToken)
        .navigationTitle("Trainer")
        .onAppear { genderIndex = Int(saveFile.trainerGender) }
    }

    // MARK: Hero

    private var header: some View {
        let name = saveFile.otName
        let initial = name.first.map { String($0).uppercased() } ?? "?"
        return HStack(spacing: 14) {
            Text(initial)
                .font(Theme.mono(20))
                .foregroundStyle(Theme.ink100)
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(Theme.line100, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                GridText(name, .hero)
                    .lineLimit(1)
                Text(
                    "\(pad(Int(saveFile.tid), 5)) · \(pad(Int(saveFile.sid), 5)) · gen\(saveFile.generation) · \(saveFile.gameName.lowercased())"
                )
                .font(Theme.mono(12))
                .tracking(0.24)
                .foregroundStyle(Theme.ink300)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                if isCompact {
                    GridBadge(text: "Save integrity OK", color: Theme.green)
                        .padding(.top, 6)
                }
            }

            if !isCompact {
                DottedLeader()
                GridBadge(text: "Save integrity OK", color: Theme.green)
            }
        }
    }

    // MARK: Identity

    private var identityPanel: some View {
        panel(title: "Identity", qualifier: "OT", count: 4) {
            row("OT Name") {
                EditableTextField(
                    "OT Name",
                    value: saveFile.otName,
                    maxLength: saveFile.maxOTNameLength,
                    width: 120
                ) { newValue in
                    saveFile.otName = newValue
                    store.markDirty()
                    refreshForm()
                }
            }
            divider
            row("Gender") {
                GridSegmented(
                    options: [(value: 0, title: "Male"), (value: 1, title: "Female")],
                    selection: genderBinding
                )
            }
            divider
            row("Trainer ID") {
                EditableNumberField(label: "Trainer ID", value: Int(saveFile.tid), range: 0...65535, width: 120) { newValue in
                    saveFile.tid = UInt16(newValue)
                    store.markDirty()
                    refreshForm()
                }
            }
            divider
            row("Secret ID") {
                EditableNumberField(label: "Secret ID", value: Int(saveFile.sid), range: 0...65535, width: 120) { newValue in
                    saveFile.sid = UInt16(newValue)
                    store.markDirty()
                    refreshForm()
                }
            }
        }
    }

    private var genderBinding: Binding<Int> {
        Binding(
            get: { genderIndex },
            set: { newValue in
                genderIndex = newValue
                saveFile.trainerGender = UInt8(newValue)
                store.markDirty()
            }
        )
    }

    // MARK: Progress

    private var progressPanel: some View {
        panel(title: "Progress", qualifier: "DATA", count: saveFile.hasPokedex ? 4 : 3) {
            row("Money") {
                HStack(spacing: 8) {
                    Text("₽")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.ink300)
                    EditableNumberField(label: "Money", value: Int(saveFile.money), range: 0...saveFile.maxMoney, width: 120) { newValue in
                        saveFile.money = UInt32(newValue)
                        store.markDirty()
                        refreshForm()
                    }
                }
            }
            divider
            row("Played Time") {
                Text("\(saveFile.playedHours)h \(String(format: "%02d", saveFile.playedMinutes))m")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.ink200)
            }
            if saveFile.hasPokedex {
                divider
                row("Pokédex") {
                    HStack(spacing: 10) {
                        Text("\(saveFile.dexCaughtCount) | \(saveFile.maxSpeciesID)")
                            .font(Theme.mono(13))
                            .foregroundStyle(Theme.ink200)
                        GridMeter(
                            value: Double(saveFile.dexCaughtCount),
                            maximum: Double(max(saveFile.maxSpeciesID, 1))
                        )
                        .frame(width: 80)
                    }
                }
            }
            divider
            row("Generation") {
                Text("gen\(saveFile.generation) · \(saveFile.gameName.lowercased())")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.ink200)
            }
        }
    }

    // MARK: Building blocks

    private func panel<Content: View>(
        title: String, qualifier: String, count: Int, @ViewBuilder content: () -> Content
    ) -> some View {
        GridPanel {
            VStack(spacing: 0) {
                SectionHeader(title, qualifier: qualifier, color: Theme.ink100) {
                    Text(pad(count, 2))
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.ink300)
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                HRule(color: Theme.line300)
                content()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 8) {
            GridText(label, .label, color: Theme.ink300)
            DottedLeader()
            control()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var divider: some View {
        HRule(color: Theme.line400)
    }

    /// Remounts the form (via `refreshToken`) so edited fields pick up the new value from
    /// `saveFile`. Deferred to the next runloop turn so it doesn't race AppKit's focus/click
    /// teardown of the text field that's still committing — doing it synchronously inside that
    /// callback can wedge the field's `NSTextView` mid-mouseDown and hang the app.
    private func refreshForm() {
        DispatchQueue.main.async {
            refreshToken += 1
        }
    }
}
