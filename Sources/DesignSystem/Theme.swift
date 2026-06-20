import SwiftUI

// MARK: - Color utilities

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// An appearance-adaptive color built from light/dark hex values.
    init(light: UInt, dark: UInt, alpha: CGFloat = 1) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: alpha)
                : UIColor(hex: light, alpha: alpha)
        })
    }
}

// MARK: - Semantic palette

/// Centralized, appearance-adaptive design tokens. Backgrounds and surfaces are
/// hand-tuned for a warm, crafted feel; text uses system labels for correct
/// contrast and Dynamic Type behavior.
enum Theme {
    // Backgrounds
    static let background = Color(light: 0xF3F3F6, dark: 0x0B0B0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x16161C)
    static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x202028)
    static let surfacePressed = Color(light: 0xECECF1, dark: 0x24242C)

    // Lines
    static let separator = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.07)
    static let hairline = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.045)

    // Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // Accents (semantic, not the user accent)
    static let upvote = Color(light: 0xF26B1D, dark: 0xFF8A3D)
    static let positive = Color(light: 0x2E9E5B, dark: 0x46C97B)
    static let link = Color(light: 0x2A6FDB, dark: 0x69A0FF)
}

// MARK: - User-selectable accent

enum AccentTheme: String, CaseIterable, Identifiable, Codable {
    case ember, ocean, indigo, magenta, forest, graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ember: "Ember"
        case .ocean: "Ocean"
        case .indigo: "Indigo"
        case .magenta: "Magenta"
        case .forest: "Forest"
        case .graphite: "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .ember: Color(light: 0xF1610A, dark: 0xFF7A2E)
        case .ocean: Color(light: 0x0A84C4, dark: 0x36B6F0)
        case .indigo: Color(light: 0x5B53D6, dark: 0x8E86FF)
        case .magenta: Color(light: 0xD12C7E, dark: 0xFF63B0)
        case .forest: Color(light: 0x1E8E55, dark: 0x46C97B)
        case .graphite: Color(light: 0x4A4A52, dark: 0xB7B7C2)
        }
    }
}

// MARK: - Spacing, radius, layout tokens

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 18
    static let pill: CGFloat = 999
}
