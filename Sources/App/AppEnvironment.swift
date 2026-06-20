import SafariServices
import SwiftUI

// MARK: - Navigation routes

/// Pushed onto a `NavigationStack` to show a user profile.
struct UserRoute: Hashable { let username: String }

// MARK: - In-app browser

/// A URL pending presentation in an in-app Safari sheet.
struct PresentedURL: Identifiable {
    let id = UUID()
    let url: URL
    let reader: Bool
}

/// Holds the URL currently being presented in the in-app browser.
@Observable
final class LinkOpener {
    var presented: PresentedURL?
    func present(_ url: URL, reader: Bool) {
        presented = PresentedURL(url: url, reader: reader)
    }
}

/// `SFSafariViewController` wrapper for in-app reading with optional Reader mode.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var entersReaderIfAvailable = false

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(named: "AccentColor")
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// MARK: - Environment actions

extension EnvironmentValues {
    /// Opens an article URL respecting the user's in-app/system + Reader settings.
    /// Configured once at the app root where settings and `openURL` are available.
    @Entry var openArticle: (URL) -> Void = { _ in }
}
