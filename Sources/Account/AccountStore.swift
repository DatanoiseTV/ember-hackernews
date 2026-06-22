import Foundation
import WebKit

/// Single source of truth for the optional Hacker News session.
///
/// The session lives as one cookie (`user`) captured by a `WKWebView` login and
/// mirrored into two places so both worlds are authenticated from one sign-in:
/// - the Keychain (durable, secure) and the shared `URLSession` cookie store
///   (native upvotes), and
/// - the persistent `WKWebsiteDataStore` (web reply / submit / login).
///
/// No password is ever read or stored — only the resulting session cookie.
@MainActor
@Observable
final class AccountStore {
    static let host = "news.ycombinator.com"
    static let base = URL(string: "https://news.ycombinator.com")!

    private static let cookieName = "user"
    private static let kcCookie = "hn.session.cookie"
    private static let kcUser = "hn.session.username"

    /// Logged-in username, or `nil` when signed out. Drives every write affordance.
    private(set) var username: String?
    var isSignedIn: Bool { username != nil }

    /// Shared, persistent web data store used by every account `WKWebView`.
    let dataStore: WKWebsiteDataStore = .default()
    /// Cookie-backed session used for native upvotes.
    let session: URLSession
    private let cookieStorage: HTTPCookieStorage

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        cookieStorage = .shared
        session = URLSession(configuration: config)
    }

    /// Restore a previously captured session into both cookie stores on launch.
    func restore() async {
        guard let value = Keychain.get(Self.kcCookie), let cookie = makeCookie(value) else { return }
        cookieStorage.setCookie(cookie)
        await dataStore.httpCookieStore.setCookie(cookie)
        username = Keychain.get(Self.kcUser)
    }

    /// Inspect the web data store after a login navigation; if the `user` cookie
    /// is present, persist and mirror it. Returns `true` once signed in.
    @discardableResult
    func captureSessionIfPresent() async -> Bool {
        let cookies = await dataStore.httpCookieStore.allCookies()
        guard let userCookie = cookies.first(where: {
            $0.name == Self.cookieName && $0.domain.contains("ycombinator")
        }) else { return false }

        Keychain.set(userCookie.value, for: Self.kcCookie)
        cookieStorage.setCookie(userCookie)
        let name = deriveUsername(from: userCookie.value)
        if let name { Keychain.set(name, for: Self.kcUser) }
        username = name ?? "Signed in"
        return true
    }

    /// Tear down the session everywhere: Keychain, URLSession, and web store.
    func signOut() async {
        username = nil
        Keychain.delete(Self.kcCookie)
        Keychain.delete(Self.kcUser)
        cookieStorage.cookies(for: Self.base)?.forEach(cookieStorage.deleteCookie)
        let store = dataStore.httpCookieStore
        for cookie in await store.allCookies() where cookie.domain.contains("ycombinator") {
            await store.deleteCookie(cookie)
        }
    }

    // MARK: Helpers

    private func makeCookie(_ value: String) -> HTTPCookie? {
        HTTPCookie(properties: [
            .domain: Self.host,
            .path: "/",
            .name: Self.cookieName,
            .value: value,
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 60 * 60 * 24 * 365),
        ])
    }

    /// HN's `user` cookie value is `username&token`; the first field is the name.
    private func deriveUsername(from value: String) -> String? {
        let decoded = value.removingPercentEncoding ?? value
        guard let first = decoded.split(separator: "&").first else { return nil }
        let name = String(first)
        return name.isEmpty ? nil : name
    }
}
