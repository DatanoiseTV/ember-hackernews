import Foundation
import Observation

/// A comment the user just posted that Algolia hasn't indexed yet. Persisted so
/// it survives navigation/relaunch, shown inline in the thread until the real
/// one appears (then dropped). Works around Algolia's few-minute indexing lag.
struct PendingComment: Codable, Identifiable, Hashable {
    let id: Int          // temporary negative id, unique per pending comment
    let storyID: Int
    let parentID: Int    // == storyID for a top-level comment
    let author: String
    let text: String     // raw source the user typed
    let createdAt: Date
}

/// An edit the user just saved that Algolia hasn't re-indexed yet, so the new
/// text can replace the stale rendered comment until the real update appears.
struct PendingEdit: Codable, Identifiable, Hashable {
    let commentID: Int
    let text: String
    let createdAt: Date
    var id: Int { commentID }
}

@Observable
final class PendingCommentStore {
    private(set) var pending: [PendingComment] = []
    private(set) var edits: [PendingEdit] = []

    private let defaults: UserDefaults
    private let key = "pending.comments"
    private let editsKey = "pending.edits"
    /// Give up showing a pending change after this long (assume it landed or failed).
    private let maxAge: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PendingComment].self, from: data) {
            pending = decoded.filter { Date().timeIntervalSince($0.createdAt) < maxAge }
        }
        if let data = defaults.data(forKey: editsKey),
           let decoded = try? JSONDecoder().decode([PendingEdit].self, from: data) {
            edits = decoded.filter { Date().timeIntervalSince($0.createdAt) < maxAge }
        }
    }

    func add(storyID: Int, parentID: Int, author: String, text: String) {
        let id = (pending.map(\.id).min() ?? 0) - 1 // unique decreasing negative id
        pending.append(PendingComment(id: id, storyID: storyID, parentID: parentID,
                                      author: author, text: text, createdAt: Date()))
        persist()
    }

    func addEdit(commentID: Int, text: String) {
        edits.removeAll { $0.commentID == commentID }
        edits.append(PendingEdit(commentID: commentID, text: text, createdAt: Date()))
        persist()
    }

    func forStory(_ storyID: Int) -> [PendingComment] {
        pending.filter { $0.storyID == storyID }
    }

    func edit(for commentID: Int) -> PendingEdit? {
        edits.first { $0.commentID == commentID }
    }

    /// Drop pending comments for this story whose text now appears for real, or
    /// that have aged out.
    func reconcile(storyID: Int, against realTexts: [(author: String, body: String)]) {
        let realKeys = Set(realTexts.map { Self.matchKey(author: $0.author, body: $0.body) })
        pending.removeAll { p in
            guard p.storyID == storyID else { return false }
            if Date().timeIntervalSince(p.createdAt) >= maxAge { return true }
            return realKeys.contains(Self.matchKey(author: p.author, body: p.text))
        }
        persist()
    }

    /// Drop pending edits whose new text now appears in the real comment, or that
    /// have aged out. `realByID` maps comment id → its current rendered html.
    func reconcileEdits(against realByID: [Int: String]) {
        edits.removeAll { e in
            if Date().timeIntervalSince(e.createdAt) >= maxAge { return true }
            guard let body = realByID[e.commentID] else { return false } // not in view; keep
            return Self.matchKey(author: "", body: body) == Self.matchKey(author: "", body: e.text)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: key)
        }
        if let data = try? JSONEncoder().encode(edits) {
            defaults.set(data, forKey: editsKey)
        }
    }

    /// Loose identity for a comment: author + a normalised prefix of its text,
    /// so HN's rendered HTML can be matched against the raw source we posted.
    static func matchKey(author: String, body: String) -> String {
        let stripped = body.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let normalized = stripped.lowercased().filter { $0.isLetter || $0.isNumber }
        return author.lowercased() + "|" + String(normalized.prefix(60))
    }
}
