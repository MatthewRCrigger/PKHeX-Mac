import PKHeXCore
import SwiftUI

struct TrainerView: View {
    @EnvironmentObject private var store: SaveStore
    let saveFile: SaveFile

    @State private var genderIndex = 0
    @State private var refreshToken = 0

    var body: some View {
        Form {
            Section("Trainer") {
                EditableTextField(
                    "OT Name",
                    value: saveFile.otName,
                    maxLength: saveFile.maxOTNameLength
                ) { newValue in
                    saveFile.otName = newValue
                    store.markDirty()
                    refreshForm()
                }
                Picker("Gender", selection: $genderIndex) {
                    Text("Male").tag(0)
                    Text("Female").tag(1)
                }
                .onChange(of: genderIndex) { _, newValue in
                    saveFile.trainerGender = UInt8(newValue)
                    store.markDirty()
                }
                EditableNumberField(
                    label: "Trainer ID",
                    value: Int(saveFile.tid),
                    range: 0...65535
                ) { newValue in
                    saveFile.tid = UInt16(newValue)
                    store.markDirty()
                    refreshForm()
                }
                EditableNumberField(
                    label: "Secret ID",
                    value: Int(saveFile.sid),
                    range: 0...65535
                ) { newValue in
                    saveFile.sid = UInt16(newValue)
                    store.markDirty()
                    refreshForm()
                }
            }
            Section("Progress") {
                EditableNumberField(
                    label: "Money",
                    value: Int(saveFile.money),
                    range: 0...saveFile.maxMoney
                ) { newValue in
                    saveFile.money = UInt32(newValue)
                    store.markDirty()
                    refreshForm()
                }
                LabeledContent("Played Time", value: "\(saveFile.playedHours)h \(saveFile.playedMinutes)m")
                LabeledContent("Generation", value: "Gen \(saveFile.generation)")
            }
        }
        .id(refreshToken)
        .formStyle(.grouped)
        .frame(maxWidth: 480)
        .navigationTitle("Trainer")
        .onAppear { genderIndex = Int(saveFile.trainerGender) }
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
