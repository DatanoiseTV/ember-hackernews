import UIKit
import WebKit

/// Performs every HN write — comment, reply, edit, and vote — by driving HN's
/// own page in a hidden, logged-in `WKWebView`, never parsing security tokens:
/// - comment/edit: fill the page's `<textarea>` and `form.submit()`;
/// - vote: click HN's own upvote arrow (HN keeps the `auth` token internal).
///
/// This keeps the security token inside HN's page and reduces fragility to "the
/// textarea / vote arrow exists" — far more robust than parsing hidden inputs or
/// `auth=` links (the HTML-parsing trap that sinks scraping apps). Editing reads
/// the textarea's **raw source** (full URLs), avoiding URL-truncation on re-save.
@MainActor
final class HNWebWriter: NSObject, WKNavigationDelegate {
    enum PostError: LocalizedError {
        case formNotFound, notEditable, rejected, timedOut
        var errorDescription: String? {
            switch self {
            case .formNotFound: "Couldn't find Hacker News's form. Your session may have expired."
            case .notEditable: "This comment can no longer be edited (Hacker News locks edits after about two hours)."
            case .rejected: "Hacker News didn't accept the change. Try again, or use the browser."
            case .timedOut: "The request timed out. Check your connection and try again."
            }
        }
    }

    private enum Job {
        case submit(text: String)
        case read
        case vote(itemID: Int, up: Bool)
        case favorite(on: Bool)
    }

    private let dataStore: WKWebsiteDataStore
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String?, Error>?
    private var job: Job = .read
    private var submitted = false

    init(dataStore: WKWebsiteDataStore) {
        self.dataStore = dataStore
    }

    // MARK: Public API

    /// Post a top-level comment on `storyID`, or a reply when `parentID` is a
    /// comment id. The form lives on the item page (top-level) or `/reply`.
    func post(parentID: Int, storyID: Int, text: String) async throws {
        let formURL = URL(string: parentID == storyID
            ? "https://news.ycombinator.com/item?id=\(storyID)"
            : "https://news.ycombinator.com/reply?id=\(parentID)")!
        _ = try await run(url: formURL, job: .submit(text: text))
    }

    /// The current raw source of one of the user's own comments, for prefilling
    /// the editor. Throws `.notEditable` if HN won't serve the edit form.
    func fetchEditableSource(commentID: Int) async throws -> String {
        let url = URL(string: "https://news.ycombinator.com/edit?id=\(commentID)")!
        guard let value = try await run(url: url, job: .read) else {
            throw PostError.notEditable
        }
        return value
    }

    /// Save edited text back to one of the user's own comments.
    func editComment(commentID: Int, text: String) async throws {
        let url = URL(string: "https://news.ycombinator.com/edit?id=\(commentID)")!
        _ = try await run(url: url, job: .submit(text: text))
    }

    /// Upvote (or, with `up: false`, un-vote) an item by clicking HN's own vote
    /// arrow — HN keeps the per-item `auth` token internal, so we parse nothing.
    func vote(itemID: Int, up: Bool) async throws {
        let url = URL(string: "https://news.ycombinator.com/item?id=\(itemID)")!
        _ = try await run(url: url, job: .vote(itemID: itemID, up: up))
    }

    /// Favorite (or un-favorite) an item by clicking HN's own favorite link on
    /// the item page — the `auth` token stays in HN's link, nothing is parsed.
    func setFavorite(itemID: Int, on: Bool) async throws {
        let url = URL(string: "https://news.ycombinator.com/item?id=\(itemID)")!
        _ = try await run(url: url, job: .favorite(on: on))
    }

    // MARK: Engine

    private func run(url: URL, job: Job) async throws -> String? {
        self.job = job
        self.submitted = false
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String?, Error>) in
            continuation = cont

            let config = WKWebViewConfiguration()
            config.websiteDataStore = dataStore
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
            webView.isHidden = true
            webView.navigationDelegate = self
            attachToWindow(webView)
            self.webView = webView
            webView.load(URLRequest(url: url))

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                self?.finish(.failure(PostError.timedOut))
            }
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch job {
        case .read:
            webView.evaluateJavaScript(Self.readJS()) { [weak self] result, _ in
                self?.finish(.success(result as? String)) // nil if the textarea is absent
            }

        case .vote(let itemID, let up):
            webView.evaluateJavaScript(Self.clickVoteJS(itemID: itemID, up: up)) { [weak self] result, _ in
                guard let self else { return }
                guard (result as? String) == "ok" else {
                    self.finish(.failure(PostError.rejected)) // no arrow → not logged in / already voted
                    return
                }
                // HN's vote fires asynchronously (an image GET); give it a moment
                // to reach the server before we tear the web view down.
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(1200))
                    self?.finish(.success(nil))
                }
            }

        case .favorite(let on):
            if !submitted {
                // The favorite link navigates; click it, then the next didFinish
                // is the result. If already in the desired state, we're done.
                submitted = true
                webView.evaluateJavaScript(Self.clickFavoriteJS(on: on)) { [weak self] result, _ in
                    switch result as? String {
                    case "ok": break // wait for the navigation
                    case "already": self?.finish(.success(nil))
                    default: self?.finish(.failure(PostError.rejected))
                    }
                }
            } else {
                finish(.success(nil))
            }

        case .submit(let text):
            if !submitted {
                // First load = the form page. Fill and submit it.
                submitted = true
                webView.evaluateJavaScript(Self.fillAndSubmitJS(text: text)) { [weak self] result, _ in
                    if (result as? String) != "ok" {
                        self?.finish(.failure(PostError.formNotFound))
                    }
                    // Otherwise wait for the post-submit navigation (next didFinish).
                }
            } else {
                // Judge success by the result page's content, not its URL: HN
                // redirects different write actions to different places, so a
                // URL check produced false failures (the Octal bug). Only fail
                // if HN actually shows an error or bounces us to the login form.
                webView.evaluateJavaScript(Self.submitResultJS()) { [weak self] result, _ in
                    self?.finish((result as? String) == "fail"
                        ? .failure(PostError.rejected)
                        : .success(nil))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    // MARK: Helpers

    private func finish(_ result: Result<String?, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        webView?.removeFromSuperview()
        webView = nil
        switch result {
        case .success(let value): cont.resume(returning: value)
        case .failure(let error): cont.resume(throwing: error)
        }
    }

    private func attachToWindow(_ webView: WKWebView) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        window?.addSubview(webView)
    }

    /// Fill the page's comment/edit textarea and submit its form, leaving the
    /// `hmac` untouched. HN's comment, reply and edit pages each have exactly one
    /// textarea (search uses an input), so this is robust to form `action` names.
    static func fillAndSubmitJS(text: String) -> String {
        """
        (function(){
          var t = document.querySelector('textarea');
          if(!t){ return 'noform'; }
          var f = t.form || t.closest('form');
          if(!f){ return 'noform'; }
          t.value = \(jsStringLiteral(text));
          f.submit();
          return 'ok';
        })();
        """
    }

    /// Classify the page shown after submitting: `"fail"` only if HN bounced us
    /// to login or rendered a known error; otherwise success. Avoids guessing
    /// from the redirect URL, which differs per write action.
    static func submitResultJS() -> String {
        """
        (function(){
          if(document.querySelector('input[name="pw"]')){ return 'fail'; }
          var t = (document.body ? document.body.innerText : '').toLowerCase();
          var errors = ['unknown or expired', 'posting too fast', 'that comment is too long',
                        'please confirm', 'you can only', 'too long'];
          for(var i=0;i<errors.length;i++){ if(t.indexOf(errors[i])>=0){ return 'fail'; } }
          return 'ok';
        })();
        """
    }

    /// Click HN's own up/un-vote arrow for an item. Returns `noarrow` when the
    /// arrow is absent (not logged in, or already in that state).
    static func clickVoteJS(itemID: Int, up: Bool) -> String {
        let anchor = "\(up ? "up" : "un")_\(itemID)"
        return """
        (function(){
          var el = document.getElementById('\(anchor)');
          if(!el){ return 'noarrow'; }
          el.click();
          return 'ok';
        })();
        """
    }

    /// Click HN's own favorite/un-favorite link to reach the desired `on` state.
    /// HN shows one `fave?id=…` link whose `un=t` flag indicates current state.
    static func clickFavoriteJS(on: Bool) -> String {
        """
        (function(){
          var a = document.querySelector('a[href*="fave?id="]');
          if(!a){ return 'nolink'; }
          var isFavorited = a.href.indexOf('un=t') >= 0;
          if(isFavorited === \(on ? "true" : "false")){ return 'already'; }
          a.click();
          return 'ok';
        })();
        """
    }

    /// Read the page's textarea raw value (or `null` if absent).
    static func readJS() -> String {
        """
        (function(){
          var t = document.querySelector('textarea');
          return t ? t.value : null;
        })();
        """
    }

    /// Encode a Swift string as a safe double-quoted JS string literal.
    private static func jsStringLiteral(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(json.dropFirst().dropLast()) // strip the surrounding [ ]
    }
}
