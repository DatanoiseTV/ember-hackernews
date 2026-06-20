import SwiftUI

extension Font {
    /// Rounded brand font that still scales with Dynamic Type.
    static func brand(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

enum AppFont {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let navTitle = Font.system(.title3, design: .rounded).weight(.bold)
    static let storyTitle = Font.system(.headline).weight(.semibold)
    static let storyTitleCompact = Font.system(.subheadline).weight(.semibold)
    static let meta = Font.system(.caption).weight(.medium)
    static let metaStrong = Font.system(.caption).weight(.semibold)
    static let body = Font.system(.callout)
    static let comment = Font.system(.callout)
    static let mono = Font.system(.footnote, design: .monospaced)
}
