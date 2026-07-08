import PKHeXCore
import SwiftUI

struct TrainerView: View {
    let saveFile: SaveFile

    @State private var otName: String = ""
    @State private var tid: String = ""
    @State private var sid: String = ""
    @State private var money: String = ""
    @State private var genderIndex = 0

    var body: some View {
        Form {
            Section("Trainer") {
                TextField("OT Name", text: $otName)
                    .onSubmit { saveFile.otName = otName }
                Picker("Gender", selection: $genderIndex) {
                    Text("Male").tag(0)
                    Text("Female").tag(1)
                }
                .onChange(of: genderIndex) { _, newValue in
                    saveFile.trainerGender = UInt8(newValue)
                }
                TextField("Trainer ID", text: $tid)
                    .onSubmit { commitID() }
                TextField("Secret ID", text: $sid)
                    .onSubmit { commitID() }
            }
            Section("Progress") {
                TextField("Money", text: $money)
                    .onSubmit { commitMoney() }
                LabeledContent("Played Time", value: "\(saveFile.playedHours)h \(saveFile.playedMinutes)m")
                LabeledContent("Generation", value: "Gen \(saveFile.generation)")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480)
        .navigationTitle("Trainer")
        .onAppear(perform: reload)
    }

    private func reload() {
        otName = saveFile.otName
        tid = String(saveFile.tid)
        sid = String(saveFile.sid)
        money = String(saveFile.money)
        genderIndex = Int(saveFile.trainerGender)
    }

    private func commitID() {
        if let value = UInt16(tid) { saveFile.tid = value }
        if let value = UInt16(sid) { saveFile.sid = value }
    }

    private func commitMoney() {
        guard let value = UInt32(money) else { return }
        saveFile.money = min(value, UInt32(saveFile.maxMoney))
    }
}
