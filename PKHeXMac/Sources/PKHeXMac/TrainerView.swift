import PKHeXCore
import SwiftUI

struct TrainerView: View {
    @EnvironmentObject private var store: SaveStore
    @EnvironmentObject private var accentStore: AccentStore
    let saveFile: SaveFile

    @State private var genderIndex = 0
    @State private var refreshToken = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                identitySection
                progressSection
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgContent)
        .id(refreshToken)
        .navigationTitle("Trainer")
        .onAppear { genderIndex = Int(saveFile.trainerGender) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentStore.accent.color, accentStore.accent.color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(accentStore.accent.onAccent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(saveFile.otName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(saveFile.tid) · \(saveFile.sid) · Gen \(saveFile.generation)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)

                integrityPill
            }

            Spacer()
        }
    }

    private var integrityPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Save integrity OK")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Theme.legalText)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Theme.legalDot.opacity(0.1))
        )
        .padding(.top, 2)
    }

    // MARK: Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("IDENTITY")

            card {
                row {
                    rowLabel("OT Name")
                    Spacer()
                    EditableTextField(
                        "OT Name",
                        value: saveFile.otName,
                        maxLength: saveFile.maxOTNameLength
                    ) { newValue in
                        saveFile.otName = newValue
                        store.markDirty()
                        refreshForm()
                    }
                    .labelsHidden()
                }
                divider

                row {
                    rowLabel("Gender")
                    Spacer()
                    genderSegmentedControl
                }
                divider

                row {
                    rowLabel("Trainer ID")
                    Spacer()
                    EditableNumberField(
                        label: "Trainer ID",
                        value: Int(saveFile.tid),
                        range: 0...65535
                    ) { newValue in
                        saveFile.tid = UInt16(newValue)
                        store.markDirty()
                        refreshForm()
                    }
                    .labelsHidden()
                    .monospacedDigit()
                }
                divider

                row {
                    rowLabel("Secret ID")
                    Spacer()
                    EditableNumberField(
                        label: "Secret ID",
                        value: Int(saveFile.sid),
                        range: 0...65535
                    ) { newValue in
                        saveFile.sid = UInt16(newValue)
                        store.markDirty()
                        refreshForm()
                    }
                    .labelsHidden()
                    .monospacedDigit()
                }
            }
        }
    }

    private var genderSegmentedControl: some View {
        HStack(spacing: 2) {
            genderSegment(title: "♂ Male", index: 0)
            genderSegment(title: "♀ Female", index: 1)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.bgElevated1)
        )
    }

    private func genderSegment(title: String, index: Int) -> some View {
        let isActive = genderIndex == index
        return Button {
            genderIndex = index
            saveFile.trainerGender = UInt8(index)
            store.markDirty()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? accentStore.accent.onAccent : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control - 2, style: .continuous)
                        .fill(isActive ? accentStore.accent.color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PROGRESS")

            card {
                row {
                    rowLabel("Money")
                    Spacer()
                    HStack(spacing: 8) {
                        Text("₽")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                        EditableNumberField(
                            label: "Money",
                            value: Int(saveFile.money),
                            range: 0...saveFile.maxMoney
                        ) { newValue in
                            saveFile.money = UInt32(newValue)
                            store.markDirty()
                            refreshForm()
                        }
                        .labelsHidden()
                        .monospacedDigit()
                    }
                }
                divider

                row {
                    rowLabel("Played Time")
                    Spacer()
                    Text("\(saveFile.playedHours)h \(String(format: "%02d", saveFile.playedMinutes))m")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary.opacity(0.85))
                }

                if saveFile.hasPokedex {
                    divider
                    row {
                        rowLabel("Pokédex")
                        Spacer()
                        pokedexProgress
                    }
                }
                divider

                row {
                    rowLabel("Generation")
                    Spacer()
                    Text("Gen \(saveFile.generation)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary.opacity(0.85))
                }
            }
        }
    }

    private var pokedexProgress: some View {
        HStack(spacing: 8) {
            Text("\(saveFile.dexCaughtCount) / \(saveFile.maxSpeciesID)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textSecondary.opacity(0.85))
            ProgressView(value: Double(saveFile.dexCaughtCount), total: Double(max(saveFile.maxSpeciesID, 1)))
                .progressViewStyle(.linear)
                .tint(accentStore.accent.color)
                .frame(width: 90)
        }
    }

    // MARK: Shared row/card building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .fill(Theme.bgPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 0.5)
        )
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
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
