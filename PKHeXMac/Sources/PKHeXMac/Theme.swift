import SwiftUI

/// Circuit design tokens: colors, typography, radii, and the accent theming system.
/// See design_handoff_circuit_redesign/README.md for the source spec.
enum Theme {
    // MARK: Core surfaces (dark)
    static let bgContent = Color(hex: 0x15171B)
    static let bgPanel = Color(hex: 0x191C21)
    static let bgTitlebar = Color(hex: 0x1D2026)
    static let bgElevated1 = Color(hex: 0x20242B)
    static let bgElevated2 = Color(hex: 0x262A31)
    static let bgElevated3 = Color(hex: 0x2C3138)
    static let bgTile = Color(hex: 0x1B1E24)
    static let bgTileEmpty = Color(hex: 0x191C22)
    static let bgWell = Color(hex: 0x171A1F)
    static let bgWindowVoid = Color(hex: 0x0F1013)
    static let hairline = Color.white.opacity(0.07)

    // MARK: Text
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.52)
    static let textTertiary = Color.white.opacity(0.35)

    // MARK: Status
    static let legalText = Color(hex: 0x7FE39A)
    static let legalDot = Color(hex: 0x2FD15B)
    static let legalFill = legalDot.opacity(0.10)
    static let legalBorder = legalDot.opacity(0.28)
    static let warnText = Color(hex: 0xFFBD7A)
    static let warnIcon = Color(hex: 0xFF9F43)
    static let warnFill = warnIcon.opacity(0.12)
    static let warnBorder = warnIcon.opacity(0.30)
    static let danger = Color(hex: 0xFF8080)
    static let shinyStar = Color(hex: 0xFFD34D)
    static let flagDot = Color(hex: 0xFF6B6B)

    // MARK: Radius
    enum Radius {
        static let window: CGFloat = 12
        static let panel: CGFloat = 13
        static let tile: CGFloat = 9
        static let control: CGFloat = 8
        static let pill: CGFloat = 20
        static let well: CGFloat = 10
    }

    // MARK: Type colors
    /// [fill, isTextDark]
    static func typeColor(_ typeName: String) -> (fill: Color, textOnFill: Color) {
        let key = typeName.uppercased()
        guard let (hex, dark) = typeHexes[key] else {
            return (Color.gray, .white)
        }
        return (Color(hex: hex), dark ? Color(hex: 0x1A1C20) : .white)
    }

    private static let typeHexes: [String: (UInt32, Bool)] = [
        "NORMAL": (0x9AA0A6, true), "FIRE": (0xFF7043, false), "WATER": (0x4D90D5, false),
        "GRASS": (0x63BC5A, false), "ELECTRIC": (0xF2C94C, true), "ICE": (0x7FD0D6, true),
        "FIGHTING": (0xD84F4F, false), "POISON": (0xA463C9, false), "GROUND": (0xD8A44B, false),
        "FLYING": (0x92A8DC, true), "PSYCHIC": (0xF76D9C, false), "BUG": (0xA7B820, false),
        "ROCK": (0xB8A038, false), "GHOST": (0x7A5AA0, false), "DRAGON": (0x7A6BBF, false),
        "DARK": (0x55504F, false), "STEEL": (0xA8A8C0, true), "FAIRY": (0xEF9FE0, true),
    ]

    // MARK: Pouch colors
    static func pouchColor(_ typeName: String) -> Color {
        switch typeName {
        case "Items": return Color(hex: 0x4D90D5)
        case "Medicine": return Color(hex: 0xE46B6B)
        case "Poké Balls": return Color(hex: 0xE0B34D)
        case "TMs/HMs": return Color(hex: 0x7C5EC9)
        case "Berries": return Color(hex: 0xC85B8E)
        case "Battle Items": return Color(hex: 0x5BBF7A)
        case "Key Items": return Color(hex: 0x9AA0A6)
        case "Mail": return Color(hex: 0xC9A15E)
        default: return Color(hex: 0x9AA0A6)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// The app's themeable accent color, persisted via `@AppStorage`. Applied instantly across every
/// accent-tinted surface: selection fills, focus rings, active nav, IV bars, toggles, Save button.
enum AccentColor: String, CaseIterable, Identifiable {
    case cyan, blue, green, orange, pink, purple, graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .cyan: return Color(hex: 0x3FD0C9)
        case .blue: return Color(hex: 0x4D90D5)
        case .green: return Color(hex: 0x5BBF7A)
        case .orange: return Color(hex: 0xFF9F43)
        case .pink: return Color(hex: 0xF76D9C)
        case .purple: return Color(hex: 0x8B7CFF)
        case .graphite: return Color(hex: 0x9AA0A6)
        }
    }

    /// Text/icon color for content drawn on top of a solid accent fill; picked by luminance.
    var onAccent: Color {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance > 0.58 ? Color(hex: 0x082322) : .white
    }

    /// Accent-colored text on dark backgrounds (brighter than the raw swatch for contrast).
    var bright: Color {
        color.opacity(0.92).mix(with: .white, by: 0.25)
    }

    var soft: Color { color.opacity(0.16) }
    var border: Color { color.opacity(0.35) }
}

private extension Color {
    /// Approximate color mix by blending RGB components (no `ShapeStyle` mixing API pre-macOS 15).
    func mix(with other: Color, by amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let b = NSColor(other).usingColorSpace(.deviceRGB) ?? NSColor(other)
        return Color(
            red: a.redComponent + (b.redComponent - a.redComponent) * amount,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * amount,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * amount
        )
    }
}

/// Wraps the persisted accent choice so views can read/write it via `@EnvironmentObject`
/// without every view re-deriving `@AppStorage` boilerplate.
@MainActor
final class AccentStore: ObservableObject {
    @AppStorage("accentColor") private var storedValue: String = AccentColor.cyan.rawValue

    var accent: AccentColor {
        get { AccentColor(rawValue: storedValue) ?? .cyan }
        set {
            objectWillChange.send()
            storedValue = newValue.rawValue
        }
    }
}
