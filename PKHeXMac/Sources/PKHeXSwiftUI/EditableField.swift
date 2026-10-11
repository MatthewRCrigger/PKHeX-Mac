import SwiftUI

/// Always-live GRID text input that commits on Enter or on losing focus, and reverts on Escape.
/// `box` is a bordered input on `surface-2` (border turns cyan on focus); `underline` is the inline
/// style used for names (dotted underline that turns solid cyan on focus).
struct CommitField: View {
    enum Style { case box, underline }

    let placeholder: String
    let value: String
    var style: Style = .box
    var width: CGFloat?
    var alignment: TextAlignment = .trailing
    var font: Font = Theme.mono(13)
    /// Non-nil clamps input to this many characters.
    var maxLength: Int?
    /// Restricts input to ASCII digits.
    var digitsOnly = false
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $draft, prompt: Text(placeholder).foregroundColor(Theme.ink400))
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(Theme.ink100)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .padding(.horizontal, style == .box ? 10 : 0)
            .padding(.bottom, style == .underline ? 3 : 0)
            .frame(width: width, height: style == .box ? 28 : nil)
            .background(style == .box ? Theme.surface2 : .clear)
            .overlay {
                switch style {
                case .box:
                    Rectangle().strokeBorder(isFocused ? Theme.cyan : Theme.line300, lineWidth: 1)
                case .underline:
                    VStack {
                        Spacer()
                        if isFocused {
                            Rectangle().fill(Theme.cyan).frame(height: 1)
                        } else {
                            DottedLeader()
                        }
                    }
                }
            }
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onChange(of: draft) { _, newValue in
                var text = newValue
                if digitsOnly { text = text.filter { $0.isASCII && $0.isNumber } }
                if let maxLength, text.count > maxLength { text = String(text.prefix(maxLength)) }
                if text != newValue { draft = text }
            }
            .onSubmit { commit() }
            .onExitCommandIfAvailable {
                draft = value
                isFocused = false
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        if draft != value { onCommit(draft) }
    }
}

/// Inline text value (OT name, nickname). The label is only used as the placeholder/accessibility name.
struct EditableTextField: View {
    let label: String
    let value: String
    let maxLength: Int?
    var style: CommitField.Style = .box
    var width: CGFloat? = 140
    var font: Font = Theme.mono(13)
    let onCommit: (String) -> Void

    init(
        _ label: String, value: String, maxLength: Int? = nil, style: CommitField.Style = .box,
        width: CGFloat? = 140, font: Font = Theme.mono(13), onCommit: @escaping (String) -> Void
    ) {
        self.label = label
        self.value = value
        self.maxLength = maxLength
        self.style = style
        self.width = width
        self.font = font
        self.onCommit = onCommit
    }

    var body: some View {
        CommitField(
            placeholder: label, value: value, style: style, width: width, font: font,
            maxLength: maxLength, onCommit: onCommit
        )
        .accessibilityLabel(label)
    }
}

/// Compact numeric field for dense tables (per-stat IV/EV rows, IDs). Clamps to `range`.
struct StatValueField: View {
    let prefix: String
    let value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 56
    let onCommit: (Int) -> Void

    var body: some View {
        CommitField(
            placeholder: prefix, value: String(value), width: width, digitsOnly: true
        ) { text in
            guard let parsed = Int(text) else { return }
            let clamped = min(max(parsed, range.lowerBound), range.upperBound)
            if clamped != value { onCommit(clamped) }
        }
    }
}

/// Integer field with no length limit — Trainer ID, money.
struct EditableNumberField: View {
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 120
    let onCommit: (Int) -> Void

    var body: some View {
        CommitField(
            placeholder: label, value: String(value), width: width, digitsOnly: true
        ) { text in
            guard let parsed = Int(text) else { return }
            let clamped = min(max(parsed, range.lowerBound), range.upperBound)
            if clamped != value { onCommit(clamped) }
        }
        .accessibilityLabel(label)
    }
}
