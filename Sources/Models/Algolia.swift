import Foundation

/// A node from the Algolia `/items/{id}` endpoint, which returns a story (or
/// comment) together with its entire nested reply tree in a single request.
/// Decoded with `.convertFromSnakeCase`.
struct AlgoliaItem: Codable, Identifiable {
    let id: Int
    var createdAtI: Int?
    var type: String?
    var author: String?
    var title: String?
    var url: String?
    var text: String?
    var points: Int?
    var parentId: Int?
    var children: [AlgoliaItem]?
}

/// A flattened comment ready for list rendering, carrying its nesting depth and
/// the number of descendants (used when a subtree is collapsed).
struct FlatComment: Identifiable, Hashable {
    let id: Int
    let author: String
    let html: String
    let date: Date?
    let depth: Int
    let descendantCount: Int
    let isDeleted: Bool
}

extension AlgoliaItem {
    var date: Date? {
        createdAtI.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// Total number of comment nodes beneath this one.
    var totalDescendants: Int {
        (children ?? []).reduce(0) { $0 + 1 + $1.totalDescendants }
    }

    /// Depth-first flatten of the reply tree into renderable rows.
    /// Skips empty deleted nodes that have no surviving children.
    func flattenComments(startDepth: Int = 0) -> [FlatComment] {
        var out: [FlatComment] = []
        func walk(_ node: AlgoliaItem, depth: Int) {
            let kids = node.children ?? []
            let deleted = (node.text == nil || node.text?.isEmpty == true)
                && node.author == nil
            // Drop fully-empty leaves; keep deleted nodes that still have replies.
            if deleted && kids.isEmpty { return }
            out.append(
                FlatComment(
                    id: node.id,
                    author: node.author ?? "[deleted]",
                    html: node.text ?? "",
                    date: node.date,
                    depth: depth,
                    descendantCount: node.totalDescendants,
                    isDeleted: deleted
                )
            )
            for child in kids { walk(child, depth: depth + 1) }
        }
        for child in children ?? [] { walk(child, depth: startDepth) }
        return out
    }
}

/// A search result row from the Algolia `/search` endpoints.
struct SearchHit: Codable, Identifiable, Hashable {
    let objectID: String
    var title: String?
    var url: String?
    var author: String?
    var points: Int?
    var numComments: Int?
    var createdAtI: Int?
    var storyText: String?

    var id: String { objectID }
    var itemID: Int? { Int(objectID) }
    var date: Date? { createdAtI.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    var host: String? {
        guard let url, let h = URL(string: url)?.host() else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
}

struct SearchResponse: Codable {
    let hits: [SearchHit]
}

enum SearchMode: String, CaseIterable, Identifiable {
    case relevance, recent
    var id: String { rawValue }
    var title: String { self == .relevance ? "Relevance" : "Recent" }
    /// Algolia path: relevance ranks by popularity, recent by date.
    var path: String { self == .relevance ? "search" : "search_by_date" }
}
