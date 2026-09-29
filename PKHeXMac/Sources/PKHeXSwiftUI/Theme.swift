import AppKit
import CoreText
import SwiftUI

/// GRID design tokens: true-black surfaces, hairline strokes, one amber "selected" accent, and
/// signal colors that only ever mean state. See design_handoff_grid/README.md.
enum Theme {
    // MARK: Surfaces
    static let void = Color(hex: 0x000000)
    static let surface1 = Color(hex: 0x060809)
    static let surface2 = Color(hex: 0x0C1013)
    static let surface3 = Color(hex: 0x141A1E)
    static let scrim = Color.black.opacity(0.78)

    // MARK: Lines
    static let line100 = Color(hex: 0xD6EAF2)
    static let line200 = Color(hex: 0x8FA8B4)
    static let line300 = Color(hex: 0x4A5A63)
    static let line400 = Color(hex: 0x202A2F)

    // MARK: Ink
    static let ink100 = Color(hex: 0xE4F2F8)
    static let ink200 = Color(hex: 0xA8BCC6)
    static let ink300 = Color(hex: 0x6B7C85)
    /// Disabled only.
    static let ink400 = Color(hex: 0x47555C)
    static let inkInvert = Color.black

    // MARK: Signals
    /// Selected / primary action.
    static let amber = Color(hex: 0xF6C56A)
    /// Focus / live.
    static let cyan = Color(hex: 0x5FCDF3)
    /// Legal / synced / IV 31.
    static let green = Color(hex: 0x5EDCA9)
    /// Illegal / destructive.
    static let red = Color(hex: 0xF1604C)
    /// Shiny / hidden ability.
    static let violet = Color(hex: 0xE6A6F2)

    static let amberFill = amber.opacity(0.12)
    static let cyanFill = cyan.opacity(0.12)
    static let greenFill = green.opacity(0.12)
    static let redFill = red.opacity(0.14)
    static let violetFill = violet.opacity(0.12)

    // MARK: Fonts

    /// Registers the bundled Rajdhani + Space Mono faces for this process. Call once at launch.
    static func registerFonts() {
        let names = [
            "Rajdhani-Regular", "Rajdhani-Medium", "Rajdhani-SemiBold", "Rajdhani-Bold",
            "SpaceMono-Regular", "SpaceMono-Bold",
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Rajdhani: anything a person wrote (labels, names, body).
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        let face: String
        switch weight {
        case .bold, .heavy, .black: face = "Rajdhani-Bold"
        case .semibold: face = "Rajdhani-SemiBold"
        case .regular, .light, .thin, .ultraLight: face = "Rajdhani-Regular"
        default: face = "Rajdhani-Medium"
        }
        return .custom(face, fixedSize: max(size, 12))
    }

    /// Space Mono: anything a machine emitted (levels, IDs, counts, paths, PP, IVs).
    static func mono(_ size: CGFloat = 12, bold: Bool = false) -> Font {
        .custom(bold ? "SpaceMono-Bold" : "SpaceMono-Regular", fixedSize: max(size, 12))
    }

    // MARK: Text styles
    enum TextStyle {
        /// Caps label, tab, section header: 12/600, 0.18em.
        case label
        /// Nav row, menu item: 14/600, 0.12em.
        case nav
        /// View title (LEGENDS, PARTY): 20/600, 0.12em.
        case viewTitle
        /// Inspector nickname: 24/600.
        case nickname
        /// Trainer name hero: 32/600, 0.04em.
        case hero
        /// Values, names in rows: 16/500.
        case value
        /// Body / hint: 14/400.
        case body

        var font: Font {
            switch self {
            case .label: return Theme.sans(12, .semibold)
            case .nav: return Theme.sans(14, .semibold)
            case .viewTitle: return Theme.sans(20, .semibold)
            case .nickname: return Theme.sans(24, .semibold)
            case .hero: return Theme.sans(32, .semibold)
            case .value: return Theme.sans(16, .medium)
            case .body: return Theme.sans(14, .regular)
            }
        }

        var tracking: CGFloat {
            switch self {
            case .label: return 2.16
            case .nav: return 1.68
            case .viewTitle: return 2.4
            case .hero: return 1.28
            case .nickname, .value, .body: return 0
            }
        }

        var isCaps: Bool {
            switch self {
            case .label, .nav, .viewTitle, .hero: return true
            case .nickname, .value, .body: return false
            }
        }
    }

    // MARK: Motion
    /// 80 ms linear on color/background/border changes and nothing else.
    static let hoverAnimation = Animation.linear(duration: 0.08)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Panel profile

/// GRID's one configurable dimension: how panels are drawn. Replaces the old accent color.
enum PanelProfile: String, CaseIterable, Identifiable {
    case round, sharp

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    /// Panel border weight.
    var borderWidth: CGFloat { self == .round ? 2 : 1 }
    var outerRadius: CGFloat { self == .round ? 8 : 0 }
    var innerRadius: CGFloat { self == .round ? 4 : 0 }
    /// Void gap between the two strokes of a double frame.
    var frameGap: CGFloat { self == .round ? 4 : 5 }
    var titleSize: CGFloat { self == .round ? 14 : 12 }
}

/// Persists the chosen panel profile and publishes changes so every panel redraws live.
@MainActor
final class PanelProfileStore: ObservableObject {
    @AppStorage("panelProfile") private var storedValue: String = PanelProfile.round.rawValue

    var profile: PanelProfile {
        get { PanelProfile(rawValue: storedValue) ?? .round }
        set {
            objectWillChange.send()
            storedValue = newValue.rawValue
        }
    }
}
