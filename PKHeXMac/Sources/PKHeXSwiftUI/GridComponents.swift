import PKHeXCore
import SwiftUI

// GRID component kit. Every screen builds on these so the visual language lives in one place.
// Rules of thumb: one amber accent meaning "selected"; colour only ever means state; controls are
// always square; radius exists only on panels, 2 pt chips and status dots; 1 pt lines everywhere.

// MARK: - Text

/// A string in one of the GRID text styles (caps styles are uppercased and tracked).
struct GridText: View {
    let text: String
    let style: Theme.TextStyle
    var color: Color = Theme.ink100

    init(_ text: String, _ style: Theme.TextStyle = .body, color: Color = Theme.ink100) {
        self.text = text
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(style.isCaps ? text.uppercased() : text)
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }
}

extension View {
    /// Space Mono data styling: 12 pt (floor) with the system's slight tracking.
    func dataFont(_ size: CGFloat = 12, bold: Bool = false, color: Color = Theme.ink200) -> some View {
        font(Theme.mono(size, bold: bold))
            .tracking(0.24)
            .foregroundStyle(color)
    }
}

/// Zero-padded, tabular number formatting used across the UI (`L072`, `008 | 030`).
func pad(_ value: Int, _ width: Int = 3) -> String {
    String(format: "%0\(width)d", value)
}

// MARK: - Hover

/// Fill that steps to `surface-3` on hover, with the system's 80 ms linear transition.
struct HoverFill: ViewModifier {
    var base: Color = .clear
    var hover: Color = Theme.surface3
    var isEnabled = true
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(isHovering && isEnabled ? hover : base)
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : Theme.hoverAnimation, value: isHovering)
    }
}

extension View {
    func hoverFill(base: Color = .clear, hover: Color = Theme.surface3, isEnabled: Bool = true) -> some View {
        modifier(HoverFill(base: base, hover: hover, isEnabled: isEnabled))
    }
}

// MARK: - Lines, leaders, frames

/// 1 pt dotted line that fills the space between a label and its value.
struct DottedLeader: View {
    var color: Color = Theme.line300

    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [1, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .offset(y: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// 1 pt solid horizontal rule.
struct HRule: View {
    var color: Color = Theme.line300
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// 1 pt solid vertical rule.
struct VRule: View {
    var color: Color = Theme.line300
    var body: some View {
        Rectangle().fill(color).frame(width: 1)
    }
}

/// Small status dot (6 pt).
struct StatusDot: View {
    var color: Color
    var size: CGFloat = 6
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

/// Faint 32 pt graph paper used behind the Start screen.
struct GraphPaper: View {
    var cell: CGFloat = 32
    var color: Color = Theme.line400

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += cell
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += cell
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// The GRID signature: outer stroke, a gap of void, inner stroke. One per window, sheet or dialog.
struct GridFrame<Content: View>: View {
    @EnvironmentObject private var profileStore: PanelProfileStore
    var color: Color = Theme.line100
    var fill: Color = Theme.void
    @ViewBuilder var content: Content

    var body: some View {
        let p = profileStore.profile
        let w = p.borderWidth
        let g = p.frameGap
        ZStack {
            fill
                .clipShape(RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous))
            content
                .clipShape(RoundedRectangle(cornerRadius: max(p.innerRadius - w, 0), style: .continuous))
                .padding(2 * w + g)
            RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous)
                .strokeBorder(color, lineWidth: w)
            RoundedRectangle(cornerRadius: p.innerRadius, style: .continuous)
                .strokeBorder(color, lineWidth: w)
                .padding(w + g)
        }
    }
}

/// A bordered panel (round or sharp per the panel profile) on `surface-1`.
struct GridPanel<Content: View>: View {
    @EnvironmentObject private var profileStore: PanelProfileStore
    var border: Color = Theme.line200
    var fill: Color = Theme.surface1
    @ViewBuilder var content: Content

    var body: some View {
        let p = profileStore.profile
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: p.outerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: p.borderWidth)
            )
    }
}

/// `TITLE .QUALIFIER ······· trailing`. The qualifier is dimmed; the leader fills the middle.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var qualifier: String?
    var color: Color = Theme.ink300
    @ViewBuilder var trailing: Trailing

    init(_ title: String, qualifier: String? = nil, color: Color = Theme.ink300, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.qualifier = qualifier
        self.color = color
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            GridText(title, .label, color: color)
            if let qualifier {
                GridText(".\(qualifier)", .label, color: Theme.ink300)
            }
            DottedLeader()
            trailing
        }
        .frame(minHeight: 28)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, qualifier: String? = nil, color: Color = Theme.ink300) {
        self.init(title, qualifier: qualifier, color: color) { EmptyView() }
    }
}

/// `LABEL ········· value` row with a dotted leader between them.
struct KeyValueRow: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.ink100
    var mono = false

    var body: some View {
        HStack(spacing: 8) {
            GridText(label, .label)
            DottedLeader()
            Text(value)
                .font(mono ? Theme.mono(13) : Theme.sans(16, .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(minHeight: 36)
    }
}

// MARK: - Buttons

enum GridButtonVariant { case primary, secondary, ghost, danger, dangerSolid }
enum GridControlSize {
    case sm, md, lg
    var height: CGFloat { self == .sm ? 28 : (self == .md ? 36 : 44) }
    var padding: CGFloat { self == .sm ? 10 : (self == .md ? 14 : 20) }
}

/// Square GRID button. Amber primary, outlined secondary, ghost, and red danger variants.
struct GridButtonStyle: ButtonStyle {
    var variant: GridButtonVariant = .secondary
    var size: GridControlSize = .md
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        GridButtonBody(configuration: configuration, variant: variant, size: size, fullWidth: fullWidth)
    }
}

private struct GridButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let variant: GridButtonVariant
    let size: GridControlSize
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.sans(14, .semibold))
            .tracking(1.68)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, size.padding)
            .frame(height: size.height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(fill(pressed: pressed))
            .overlay(Rectangle().strokeBorder(border, lineWidth: 1))
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : Theme.hoverAnimation, value: isHovering)
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.ink400 }
        switch variant {
        case .primary, .dangerSolid: return Theme.inkInvert
        case .secondary: return Theme.ink100
        case .ghost: return isHovering ? Theme.ink100 : Theme.ink200
        case .danger: return Theme.red
        }
    }

    private func fill(pressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        switch variant {
        case .primary: return pressed ? Theme.amber.mix(black: 0.25) : Theme.amber
        case .dangerSolid: return pressed ? Theme.red.mix(black: 0.25) : Theme.red
        case .secondary, .ghost, .danger:
            return pressed ? Theme.surface2 : (isHovering ? Theme.surface3 : .clear)
        }
    }

    private var border: Color {
        guard isEnabled else { return Theme.line400 }
        switch variant {
        case .primary: return Theme.amber
        case .dangerSolid, .danger: return Theme.red
        case .secondary: return isHovering ? Theme.line100 : Theme.line200
        case .ghost: return .clear
        }
    }
}

/// Convenience: `GridButton("Open Save…", .primary) { … }`, optionally with a leading SF Symbol.
struct GridButton: View {
    let title: String
    var variant: GridButtonVariant = .secondary
    var size: GridControlSize = .md
    var systemImage: String?
    var fullWidth = false
    let action: () -> Void

    init(
        _ title: String, _ variant: GridButtonVariant = .secondary, size: GridControlSize = .md,
        systemImage: String? = nil, fullWidth: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .regular))
                }
                Text(title)
            }
        }
        .buttonStyle(GridButtonStyle(variant: variant, size: size, fullWidth: fullWidth))
    }
}

/// Square outlined icon button (36 by default).
struct GridIconButton: View {
    let systemImage: String
    var size: CGFloat = 36
    var bordered = true
    var hoverTint: Color = Theme.ink100
    var help: String?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isEnabled ? (isHovering ? hoverTint : Theme.ink200) : Theme.ink400)
                .frame(width: size, height: size)
                .background(isHovering && isEnabled ? Theme.surface3 : .clear)
                .overlay(
                    Rectangle().strokeBorder(
                        bordered ? (isEnabled ? (isHovering ? Theme.line100 : Theme.line200) : Theme.line400) : .clear,
                        lineWidth: 1
                    )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)
        .help(help ?? "")
    }
}

/// 28 pt outlined key, e.g. `⌘` `O`.
struct KeyCap: View {
    let label: String
    var body: some View {
        Text(label)
            .font(Theme.mono(12))
            .foregroundStyle(Theme.ink200)
            .frame(width: 28, height: 28)
            .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
    }
}

// MARK: - Badges & chips

/// Outlined state badge, optionally with a leading dot: `● LEGAL`, `● 02 ISSUES`, `SHINY`.
struct GridBadge: View {
    let text: String
    var color: Color = Theme.green
    var showsDot = true
    var solid = false

    var body: some View {
        HStack(spacing: 6) {
            if showsDot { StatusDot(color: solid ? Theme.inkInvert : color) }
            Text(text.uppercased())
                .font(Theme.sans(12, .semibold))
                .tracking(1.44)
                .foregroundStyle(solid ? Theme.inkInvert : color)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(solid ? color : color.opacity(0.12))
        .overlay(Rectangle().strokeBorder(color, lineWidth: 1))
        .fixedSize()
    }
}

/// Mono code chip inside a 1 pt `line-300` border with 2 pt radius: `GRD`.
struct GridChip: View {
    let text: String
    var color: Color = Theme.ink200
    var border: Color = Theme.line300

    var body: some View {
        Text(text)
            .font(Theme.mono(12))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(border, lineWidth: 1))
            .fixedSize()
    }
}

/// Three-letter type code for a type name ("Ground" → "GRD").
func typeCode(_ typeName: String) -> String {
    let codes: [String: String] = [
        "NORMAL": "NRM", "FIRE": "FIR", "WATER": "WTR", "GRASS": "GRS", "ELECTRIC": "ELC",
        "ICE": "ICE", "FIGHTING": "FGT", "POISON": "PSN", "GROUND": "GRD", "FLYING": "FLY",
        "PSYCHIC": "PSY", "BUG": "BUG", "ROCK": "RCK", "GHOST": "GHO", "DRAGON": "DRG",
        "DARK": "DRK", "STEEL": "STL", "FAIRY": "FRY",
    ]
    let key = typeName.uppercased()
    return codes[key] ?? String(key.prefix(3))
}

func typeCode(typeID: UInt8) -> String {
    typeCode(PokemonNames.type(typeID))
}

/// A row of type chips for a Pokémon's types.
struct TypeChips: View {
    let typeIDs: [UInt8]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(typeIDs, id: \.self) { GridChip(text: typeCode(typeID: $0)) }
        }
    }
}

// MARK: - Inputs

/// Mono text input on `surface-2` with a 1 pt border that turns cyan on focus.
struct GridTextField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat?
    var alignment: TextAlignment = .leading
    var onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.ink400))
            .textFieldStyle(.plain)
            .font(Theme.mono(13))
            .foregroundStyle(Theme.ink100)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .padding(.horizontal, 10)
            .frame(width: width, height: 28)
            .background(Theme.surface2)
            .overlay(Rectangle().strokeBorder(isFocused ? Theme.cyan : Theme.line300, lineWidth: 1))
            .onSubmit { onSubmit?() }
            .animation(Theme.hoverAnimation, value: isFocused)
    }
}

/// Square switch: amber track and black knob when on.
struct GridSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Rectangle()
                        .fill(configuration.isOn ? Theme.amber : Theme.surface2)
                        .frame(width: 36, height: 20)
                        .overlay(Rectangle().strokeBorder(configuration.isOn ? Theme.amber : Theme.line300, lineWidth: 1))
                    Rectangle()
                        .fill(configuration.isOn ? Theme.inkInvert : Theme.ink300)
                        .frame(width: 12, height: 12)
                        .padding(.horizontal, 4)
                }
                .animation(Theme.hoverAnimation, value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Segmented control: amber fill and black text on the selected segment.
struct GridSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var size: GridControlSize = .sm
    var fixedWidth: CGFloat?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isOn = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(Theme.sans(14, .semibold))
                        .tracking(1.68)
                        .textCase(.uppercase)
                        .foregroundStyle(isOn ? Theme.inkInvert : Theme.ink200)
                        .padding(.horizontal, size.padding)
                        .frame(width: fixedWidth, height: size.height - 2)
                        .frame(maxWidth: fixedWidth == nil ? nil : fixedWidth)
                        .background(isOn ? Theme.amber : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < options.count - 1 { VRule() }
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
        .fixedSize()
    }
}

/// `− 030 +` numeric stepper: 28 pt cells around a mono value.
struct GridStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    var width: CGFloat = 124
    var digits = 3
    var onChange: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", delta: -1)
            VRule()
            Text(pad(value, digits))
                .font(Theme.mono(13))
                .foregroundStyle(Theme.ink100)
                .frame(maxWidth: .infinity)
            VRule()
            stepButton("plus", delta: 1)
        }
        .frame(width: width, height: 28)
        .overlay(Rectangle().strokeBorder(Theme.line300, lineWidth: 1))
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        let next = min(max(value + delta, range.lowerBound), range.upperBound)
        return Button {
            guard next != value else { return }
            value = next
            onChange?(next)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(next == value ? Theme.ink400 : Theme.ink200)
                .frame(width: 28, height: 28)
                .hoverFill(isEnabled: next != value)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Bar meter: 1 pt `line-300` track, 1 pt inset, fill in `line-100` (or a signal color).
struct GridMeter: View {
    var value: Double
    var maximum: Double
    var fill: Color = Theme.line100
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let inner = max(proxy.size.width - 4, 0)
            let fraction = maximum > 0 ? min(max(value / maximum, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle().strokeBorder(Theme.line300, lineWidth: 1)
                Rectangle()
                    .fill(fill)
                    .frame(width: inner * fraction, height: max(height - 4, 0))
                    .padding(.leading, 2)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Cells

/// Inspector cell: caps label over a value, on `surface-2` with a 1 pt border. Clickable cells
/// show a chevron and take the hover state.
struct GridCell<Value: View>: View {
    let label: String
    var showsChevron = false
    var isDisabled = false
    var action: (() -> Void)?
    @ViewBuilder var value: Value

    @State private var isHovering = false

    var body: some View {
        let interactive = action != nil && !isDisabled
        let content = VStack(alignment: .leading, spacing: 4) {
            HStack {
                GridText(label, .label, color: isDisabled ? Theme.ink400 : Theme.ink300)
                Spacer(minLength: 4)
                if showsChevron && !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Theme.ink300)
                }
            }
            value
                .font(Theme.sans(16, .medium))
                .foregroundStyle(isDisabled ? Theme.ink400 : Theme.ink100)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering && interactive ? Theme.surface3 : Theme.surface2)
        .overlay(
            Rectangle().strokeBorder(
                isDisabled ? Theme.line400 : (isHovering && interactive ? Theme.line200 : Theme.line300),
                lineWidth: 1
            )
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(Theme.hoverAnimation, value: isHovering)

        if let action, !isDisabled {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

extension GridCell where Value == Text {
    init(_ label: String, value: String, showsChevron: Bool = false, isDisabled: Bool = false, action: (() -> Void)? = nil) {
        self.label = label
        self.showsChevron = showsChevron
        self.isDisabled = isDisabled
        self.action = action
        self.value = Text(value)
    }
}

// MARK: - Sheets & dialogs

/// The shared shell for every picker sheet: double frame, header, optional search field, column
/// header, scrolling rows, and footer hint. The sheet itself is a native `.sheet`; this fills it.
struct PickerShell<Columns: View, Content: View>: View {
    let title: String
    var qualifier: String?
    var context: String?
    var searchPrompt = "search"
    var searchText: Binding<String>?
    var resultCount: Int?
    var footerHint: String
    var onClose: () -> Void
    @ViewBuilder var columns: Columns
    @ViewBuilder var content: Content

    var body: some View {
        GridFrame {
            VStack(spacing: 0) {
                header
                if let searchText {
                    PickerSearchField(prompt: searchPrompt, text: searchText, count: resultCount)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                columns
                ScrollView {
                    LazyVStack(spacing: 0) { content }
                }
                .frame(maxHeight: .infinity)
                footer
            }
            .background(Theme.surface1)
        }
        .frame(width: 600, height: 560)
        .background(Theme.void)
        .presentationBackground(Theme.void)
    }

    private var header: some View {
        HStack(spacing: 8) {
            GridText(title, .label, color: Theme.ink100)
            if let qualifier { GridText(".\(qualifier)", .label, color: Theme.ink300) }
            DottedLeader()
            if let context {
                Text(context).font(Theme.mono(12)).foregroundStyle(Theme.ink300).lineLimit(1)
            }
            GridIconButton(systemImage: "xmark", size: 28, bordered: false, action: onClose)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 44)
    }

    private var footer: some View {
        HStack {
            Text(footerHint).font(Theme.mono(12)).foregroundStyle(Theme.ink300)
            Spacer()
            Text("esc · close").font(Theme.mono(12)).foregroundStyle(Theme.ink300)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .overlay(alignment: .top) { HRule(color: Theme.line300) }
    }
}

extension PickerShell where Columns == EmptyView {
    init(
        title: String, qualifier: String? = nil, context: String? = nil, searchPrompt: String = "search",
        searchText: Binding<String>? = nil, resultCount: Int? = nil, footerHint: String,
        onClose: @escaping () -> Void, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.qualifier = qualifier
        self.context = context
        self.searchPrompt = searchPrompt
        self.searchText = searchText
        self.resultCount = resultCount
        self.footerHint = footerHint
        self.onClose = onClose
        self.columns = EmptyView()
        self.content = content()
    }
}

/// Column header line for a picker: caps `ink-300` with a bottom hairline. Pass cells sized to
/// match the row columns.
struct PickerColumnHeader<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 8) { content }
            .font(Theme.sans(12, .semibold))
            .tracking(2.16)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink300)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .overlay(alignment: .bottom) { HRule(color: Theme.line300) }
    }
}

/// Search field with a cyan 1 pt border, cyan icon, mono input and a mono result count.
struct PickerSearchField: View {
    var prompt = "search"
    @Binding var text: String
    var count: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.cyan)
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(Theme.ink400))
                .textFieldStyle(.plain)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.ink100)
                .focused($isFocused)
            if let count {
                Text(pad(count)).font(Theme.mono(12)).foregroundStyle(Theme.ink300)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Theme.surface2)
        .overlay(Rectangle().strokeBorder(Theme.cyan, lineWidth: 1))
        .onAppear { isFocused = true }
    }
}

/// Row style for picker rows: min 44 tall, `line-400` separator, `surface-3` hover.
struct PickerRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PickerRowBody(configuration: configuration)
    }

    private struct PickerRowBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var isHovering = false
        var body: some View {
            configuration.label
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isHovering || configuration.isPressed ? Theme.surface3 : .clear)
                .overlay(alignment: .bottom) { HRule(color: Theme.line400) }
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
                .animation(Theme.hoverAnimation, value: isHovering)
        }
    }
}

/// "NO MATCHES" placeholder for empty picker results.
struct PickerEmptyState: View {
    var body: some View {
        GridText("No matches", .label, color: Theme.ink300)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

/// Red or neutral double-frame dialog (440 wide) shown over a scrim by `GridDialogHost`.
struct GridDialog<Actions: View>: View {
    let title: String
    var qualifier: String?
    var isDanger = false
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        GridFrame(color: isDanger ? Theme.red : Theme.line100) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    if isDanger {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.red)
                    }
                    GridText(title, .label, color: isDanger ? Theme.red : Theme.ink100)
                    if let qualifier { GridText(".\(qualifier)", .label, color: Theme.ink300) }
                    DottedLeader()
                }
                Text(message)
                    .font(Theme.sans(16, .regular))
                    .foregroundStyle(Theme.ink200)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer()
                    actions
                }
            }
            .padding(20)
            .background(Theme.surface1)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Dimming scrim (with the system's one 2 px blur) that centers a dialog and swallows clicks.
struct GridScrim<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Theme.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            content
        }
    }
}

// MARK: - Color helper

extension Color {
    /// Blends toward black by `amount` (0–1). Used for the "one step darker" pressed state.
    func mix(black amount: Double) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        #if os(macOS)
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        ns.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif
        return Color(red: red * (1 - amount), green: green * (1 - amount), blue: blue * (1 - amount))
    }
}
