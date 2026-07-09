import PKHeXCore
import SwiftUI

struct TrainerView: View {
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
                    refreshToken += 1
                }
                Picker("Gender", selection: $genderIndex) {
                    Text("Male").tag(0)
                    Text("Female").tag(1)
                }
                .onChange(of: genderIndex) { _, newValue in
                    saveFile.trainerGender = UInt8(newValue)
                }
                EditableNumberField(
                    label: "Trainer ID",
                    value: Int(saveFile.tid),
                    range: 0...65535
                ) { newValue in
                    saveFile.tid = UInt16(newValue)
                    refreshToken += 1
                }
                EditableNumberField(
                    label: "Secret ID",
                    value: Int(saveFile.sid),
                    range: 0...65535
                ) { newValue in
                    saveFile.sid = UInt16(newValue)
                    refreshToken += 1
                }
            }
            Section("Progress") {
                EditableNumberField(
                    label: "Money",
                    value: Int(saveFile.money),
                    range: 0...saveFile.maxMoney
                ) { newValue in
                    saveFile.money = UInt32(newValue)
                    refreshToken += 1
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
}
