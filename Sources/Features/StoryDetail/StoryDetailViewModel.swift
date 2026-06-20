import Foundation
import Observation

/// Loads and manages the comment thread for a story, including collapse state.
@MainActor
@Observable
final class StoryDetailViewModel {
    let item: HNItem
    private(set) var comments: [FlatComment] = []
    private(set) var phase: LoadPhase = .loading
    private(set) var resolvedItem: HNItem

    private(set) var collapsed: Set<Int> = []
    private let service: HNServicing

    init(item: HNItem, service: HNServicing = LiveHNService.shared) {
        self.item = item
        self.resolvedItem = item
        self.service = service
    }

    /// Comments with any descendants of a collapsed node filtered out.
    var visibleComments: [FlatComment] {
        var result: [FlatComment] = []
        var hideBelow: Int?
        for comment in comments {
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
            comments = tree.flattenComments()
            // Algolia may carry fields the feed item lacked (text, points).
            resolvedItem = merge(item, with: tree)
            phase = .loaded
        } catch {
            if comments.isEmpty {
                phase = .failed((error as? HNError)?.errorDescription ?? error.localizedDescription)
            }
        }
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
