import Foundation

/// A Hacker News item: story, comment, job, poll, or poll option.
/// Mirrors the Firebase API shape; most fields are optional because the API
/// omits them depending on the item kind and state.
struct HNItem: Codable, Identifiable, Hashable {
    let id: Int
    var deleted: Bool?
    var type: String?
    var by: String?
    var time: Int?
    var text: String?
    var dead: Bool?
    var parent: Int?
    var poll: Int?
    var kids: [Int]?
    var url: String?
    var score: Int?
    var title: String?
    var parts: [Int]?
    var descendants: Int?
}

extension HNItem {
    enum Kind: String {
        case story, comment, job, poll, pollopt, unknown
    }

    var kind: Kind { Kind(rawValue: type ?? "") ?? .unknown }

    var date: Date? {
        time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var points: Int { score ?? 0 }
    var commentCount: Int { descendants ?? 0 }
    var author: String { by ?? "unknown" }
    var displayTitle: String { title ?? "(untitled)" }
    var isDead: Bool { dead ?? false }
    var isDeleted: Bool { deleted ?? false }

    /// External article URL, if this story links out.
    var articleURL: URL? {
        guard let url, let u = URL(string: url) else { return nil }
        return u
    }

    /// Bare host for display, e.g. "github.com" (drops a leading "www.").
    var host: String? {
        guard let host = articleURL?.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Canonical Hacker News thread URL.
    var hnURL: URL {
        URL(string: "https://news.ycombinator.com/item?id=\(id)")!
    }

    /// A self/text post (Ask HN, etc.) has body text and no outbound link.
    var isTextPost: Bool { articleURL == nil && (text?.isEmpty == false) }
}
