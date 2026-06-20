import SwiftUI

/// Loads a site favicon for a story's domain, with a graceful globe fallback.
/// Decorative: hidden from VoiceOver and ignores Smart Invert.
struct FaviconView: View {
    let host: String?
    var size: CGFloat = 20

    private var iconURL: URL? {
        guard let host else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    var body: some View {
        Group {
            if let iconURL {
                AsyncImage(url: iconURL, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(size * 0.1)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(Theme.surfacePressed)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
        .accessibilityIgnoresInvertColors()
    }

    private var fallback: some View {
        Image(systemName: "globe")
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
    }
}
