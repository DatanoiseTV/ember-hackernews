import SwiftUI
import WebKit

/// A write/login action performed on HN's own website inside a logged-in
/// `WKWebView`. Using HN's real forms avoids scraping the expiring `fnid`/`hmac`
/// nonces and lets HN render any captcha / 2FA / validation itself.
enum HNWebTask: Identifiable {
    case login
    /// Web fallback for posting when the native composer is rejected.
    case reply(parentID: Int, storyID: Int)
    case submit
    /// Fallback: open an item's page so the user can act manually (e.g. vote
    /// when the native path fails).
    case item(itemID: Int)

    var id: String {
        switch self {
        case .login: "login"
        case .reply(let p, _): "reply-\(p)"
        case .submit: "submit"
        case .item(let i): "item-\(i)"
        }
    }

    var title: String {
        switch self {
        case .login: "Sign in to Hacker News"
        case .reply: "Reply"
        case .submit: "New Submission"
        case .item: "Hacker News"
        }
    }

    var url: URL {
        switch self {
        case .login:
            return URL(string: "https://news.ycombinator.com/login?goto=news")!
        case .reply(let parentID, let storyID):
            let goto = "item?id=\(storyID)".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return URL(string: "https://news.ycombinator.com/reply?id=\(parentID)&goto=\(goto)")!
        case .submit:
            return URL(string: "https://news.ycombinator.com/submit")!
        case .item(let itemID):
            return URL(string: "https://news.ycombinator.com/item?id=\(itemID)")!
        }
    }
}

/// Presents `HNWebTask` in a themed sheet, detecting success from navigation and
/// reporting it back so the caller can capture the session and/or refresh.
struct HNWebSheet: View {
    let task: HNWebTask
    @Environment(AccountStore.self) private var account
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Called once the task is detected as completed successfully.
    var onSuccess: () -> Void = {}

    var body: some View {
        NavigationStack {
            HNWebView(url: task.url, dataStore: account.dataStore) { url in
                Task { await handle(url) }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .tint(settings.accent.color)
        }
    }

    /// Interpret each finished navigation. Success criteria differ per task.
    private func handle(_ url: URL?) async {
        guard let url else { return }
        let path = url.path
        let isItem = path.hasSuffix("/item") || path == "item"
        let isLoginPage = path.contains("login")

        switch task {
        case .login:
            // Signed in once the cookie exists and we've left the login page.
            if !isLoginPage, await account.captureSessionIfPresent() {
                onSuccess()
                dismiss()
            }
        case .reply:
            // The reply form lives at /reply; success redirects to the item page.
            if isItem {
                onSuccess()
                dismiss()
            }
        case .submit:
            // After submitting, HN leaves /submit (to /newest or the new item).
            if !path.contains("submit") && (isItem || path.contains("newest")) {
                onSuccess()
                dismiss()
            }
        case .item:
            // Manual fallback — the user dismisses when done.
            break
        }
    }
}

/// Thin `WKWebView` wrapper bound to a shared persistent data store, reporting
/// each finished navigation's URL.
private struct HNWebView: UIViewRepresentable {
    let url: URL
    let dataStore: WKWebsiteDataStore
    let onNavigate: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onNavigate: onNavigate) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        // HN's login fields lack autocomplete hints, so WKWebView won't offer
        // saved passwords (unlike SFSafariViewController). Tag them at document
        // start so iOS Password AutoFill recognises the form.
        let tagFields = WKUserScript(
            source: """
            (function(){
              var a = document.querySelector('input[name="acct"]');
              if(a){ a.setAttribute('autocomplete','username'); a.setAttribute('type','text'); }
              var p = document.querySelector('input[name="pw"]');
              if(p){ p.setAttribute('autocomplete','current-password'); }
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(tagFields)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onNavigate: (URL?) -> Void
        init(onNavigate: @escaping (URL?) -> Void) { self.onNavigate = onNavigate }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onNavigate(webView.url)
        }
    }
}
