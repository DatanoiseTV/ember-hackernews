import Foundation
import Observation

/// How top-level comment threads are ordered in a discussion.
enum CommentSort: String, CaseIterable, Identifiable, Codable {
    case ranked   // HN's default ranking, as Algolia returns it
    case newest
    case oldest

    var id: String { rawValue }
    var title: String {
        switch self {
        case .ranked: "Default"
        case .newest: "Newest"
        case .oldest: "Oldest"
        }
    }
    var systemImage: String {
        switch self {
        case .ranked: "sparkles"
        case .newest: "arrow.down"
        case .oldest: "arrow.up"
        }
    }
}

/// Loads and manages the comment thread for a story, including collapse state.
@MainActor
@Observable
final class StoryDetailViewModel {
    let item: HNItem
    private(set) var comments: [FlatComment] = []
    private(set) var phase: LoadPhase = .loading
    private(set) var resolvedItem: HNItem

    private(set) var collapsed: Set<Int> = []
    /// When set, this author's top-level threads float to the top (like the web).
    var floatAuthor: String?
    /// How top-level threads are ordered.
    var sort: CommentSort = .ranked
    /// Source of locally-posted comments not yet indexed by Algolia.
    var pendingStore: PendingCommentStore?
    private let service: HNServicing

    init(item: HNItem, service: HNServicing = LiveHNService.shared) {
        self.item = item
        self.resolvedItem = item
        self.service = service
    }

    /// Comments reordered by the chosen sort, with the floated author's threads
    /// lifted to the top. Top-level subtrees are kept intact throughout.
    var orderedComments: [FlatComment] {
        guard floatAuthor != nil || sort != .ranked else { return comments }

        // Group the flat list into top-level threads (a depth-0 node + its kids).
        var threads: [[FlatComment]] = []
        for comment in comments {
            if comment.depth == 0 || threads.isEmpty {
                threads.append([comment])
            } else {
                threads[threads.count - 1].append(comment)
            }
        }

        func rootDate(_ thread: [FlatComment]) -> Date {
            thread.first?.date ?? .distantPast
        }
        switch sort {
        case .ranked:
            break // keep HN's order
        case .newest:
            threads.sort { rootDate($0) > rootDate($1) }
        case .oldest:
            threads.sort { rootDate($0) < rootDate($1) }
        }

        if let floatAuthor {
            let mine = threads.filter { $0.first?.author == floatAuthor }
            let rest = threads.filter { $0.first?.author != floatAuthor }
            threads = mine + rest
        }
        return threads.flatMap { $0 }
    }

    /// Comments with any descendants of a collapsed node filtered out.
    var visibleComments: [FlatComment] {
        var result: [FlatComment] = []
        var hideBelow: Int?
        for comment in orderedComments {
            if let depth = hideBelow {
                if comment.depth > depth { continue }
                hideBelow = nil
            }
            result.append(comment)
            if collapsed.contains(comment.id) { hideBelow = comment.depth }
        }
        return result
    }

    var commentCount: Int { comments.count }

    func isCollapsed(_ id: Int) -> Bool { collapsed.contains(id) }

    func toggleCollapse(_ id: Int) {
        if collapsed.contains(id) {
            collapsed.remove(id)
        } else {
            collapsed.insert(id)
        }
    }

    var topLevelIDs: [Int] { comments.filter { $0.depth == 0 }.map(\.id) }

    var allTopLevelCollapsed: Bool {
        let tops = topLevelIDs
        return !tops.isEmpty && tops.allSatisfy { collapsed.contains($0) }
    }

    func toggleCollapseAll() {
        if allTopLevelCollapsed {
            collapsed.removeAll()
        } else {
            collapsed = Set(topLevelIDs)
        }
    }

    func load() async {
        if comments.isEmpty { phase = .loading }
        do {
            let tree = try await service.commentTree(for: item.id)
            var flat = tree.flattenComments()
            // Drop pending comments Algolia has now indexed; merge the rest in so
            // a just-posted comment stays visible despite Algolia's indexing lag.
            if let pendingStore {
                pendingStore.reconcile(storyID: item.id,
                                       against: flat.map { (author: $0.author, body: $0.html) })
                pendingStore.reconcileEdits(against: Dictionary(flat.map { ($0.id, $0.html) },
                                                               uniquingKeysWith: { a, _ in a }))
                flat = flat.map { c in
                    guard let edit = pendingStore.edit(for: c.id) else { return c }
                    return FlatComment(id: c.id, author: c.author, html: Self.plainToHTML(edit.text),
                                       date: c.date, depth: c.depth, descendantCount: c.descendantCount,
                                       isDeleted: c.isDeleted, isPending: true)
                }
                flat = Self.mergePending(flat, pending: pendingStore.forStory(item.id))
            }
            comments = flat
            // Algolia may carry fields the feed item lacked (text, points).
            resolvedItem = merge(item, with: tree)
            phase = .loaded
        } catch {
            if comments.isEmpty {
                phase = .failed((error as? HNError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    /// Insert pending comments into the flattened tree: top-level ones are
    /// appended; replies go directly under their parent (if still present).
    static func mergePending(_ flat: [FlatComment], pending: [PendingComment]) -> [FlatComment] {
        guard !pending.isEmpty else { return flat }
        var result = flat
        for p in pending.sorted(by: { $0.createdAt < $1.createdAt }) {
            let row = FlatComment(
                id: p.id, author: p.author, html: Self.plainToHTML(p.text),
                date: p.createdAt, depth: 0, descendantCount: 0,
                isDeleted: false, isPending: true
            )
            if let idx = result.firstIndex(where: { $0.id == p.parentID }) {
                let child = FlatComment(
                    id: p.id, author: p.author, html: row.html, date: p.createdAt,
                    depth: result[idx].depth + 1, descendantCount: 0,
                    isDeleted: false, isPending: true
                )
                result.insert(child, at: idx + 1)
            } else {
                result.append(row) // top-level, or parent not in view
            }
        }
        return result
    }

    /// Minimal source→HTML for an optimistic preview (real render arrives on refresh).
    static func plainToHTML(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return escaped
            .components(separatedBy: "\n\n")
            .map { "<p>\($0.replacingOccurrences(of: "\n", with: " "))</p>" }
            .joined()
    }

    private func merge(_ base: HNItem, with tree: AlgoliaItem) -> HNItem {
        var merged = base
        if merged.text == nil { merged.text = tree.text }
        if merged.url == nil { merged.url = tree.url }
        if merged.title == nil { merged.title = tree.title }
        if merged.score == nil { merged.score = tree.points }
        if merged.by == nil { merged.by = tree.author }
        return merged
    }
}
