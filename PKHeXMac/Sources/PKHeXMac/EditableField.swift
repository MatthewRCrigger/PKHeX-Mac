import SwiftUI

/// A labeled value that toggles into an inline text field when the pencil icon is clicked.
/// Commits on Enter or on losing focus; reverts on Escape.
struct EditableTextField: View {
    let label: String
    let value: String
    /// Non-nil to show a live character counter and clamp input to this length.
    let maxLength: Int?
    let onCommit: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    init(_ label: String, value: String, maxLength: Int? = nil, onCommit: @escaping (String) -> Void) {
        self.label = label
        self.value = value
        self.maxLength = maxLength
        self.onCommit = onCommit
    }

    var body: some View {
        LabeledContent(label) {
            if isEditing {
                HStack(spacing: 6) {
                    TextField(label, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onChange(of: draft) { _, newValue in
                            if let maxLength, newValue.count > maxLength {
                                draft = String(newValue.prefix(maxLength))
                            }
                        }
                        .onSubmit { commit() }
                        .onExitCommand { cancel() }
                    if let maxLength {
                        Text("\(draft.count)/\(maxLength)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
            } else {
                HStack(spacing: 6) {
                    Text(value)
                    Button {
                        draft = value
                        isEditing = true
                        isFocused = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        if draft != value {
            onCommit(draft)
        }
    }

    private func cancel() {
        isEditing = false
    }
}

/// A compact tap-to-edit numeric value for dense tables (e.g. per-stat IV/EV rows), where
/// EditableNumberField's LabeledContent row would be too tall.
struct StatValueField: View {
    let prefix: String
    let value: Int
    let range: ClosedRange<Int>
    let onCommit: (Int) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField(prefix, text: $draft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .focused($isFocused)
                .onSubmit { commit() }
                .onExitCommand { isEditing = false }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
        } else {
            Button {
                draft = String(value)
                isEditing = true
                isFocused = true
            } label: {
                Text("\(prefix) \(value)")
            }
            .buttonStyle(.plain)
        }
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        guard let parsed = Int(draft) else { return }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        if clamped != value {
            onCommit(clamped)
        }
    }
}

/// Like `EditableTextField`, but for integer values with no length limit — e.g. Trainer ID, money.
struct EditableNumberField: View {
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    let onCommit: (Int) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent(label) {
            if isEditing {
                TextField(label, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { commit() }
                    .onExitCommand { isEditing = false }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                HStack(spacing: 6) {
                    Text(String(value))
                    Button {
                        draft = String(value)
                        isEditing = true
                        isFocused = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        guard let parsed = Int(draft) else { return }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        if clamped != value {
            onCommit(clamped)
        }
    }
}
