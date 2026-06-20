import SwiftUI

/// Gentle press feedback for card-like tappable surfaces.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Row-style highlight that fills with a pressed surface color.
struct HighlightRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.surfacePressed : Color.clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}

extension ButtonStyle where Self == HighlightRowStyle {
    static var highlightRow: HighlightRowStyle { HighlightRowStyle() }
}
