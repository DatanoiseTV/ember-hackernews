import Foundation
import Observation

/// The signed-in user's Hacker News favorites. Cached locally so state is known
/// offline, refreshed from HN's favorites page, and toggled through HN's own
/// favorite link (via `HNWebWriter`). When signed in, this replaces the local
/// `BookmarkStore` as the Saved tab's source.
@MainActor
@Observable
final class FavoritesStore {
    /// Favorited story ids, most-recent first (HN's page order).
    private(set) var ids: [Int] = []

    private let defaults: UserDefaults
    private let key = "favorites.ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = defaults.array(forKey: key) as? [Int] ?? []
    }

    func isFavorite(_ id: Int) -> Bool { ids.contains(id) }

    /// Pull the authoritative list from HN.
    func refresh(username: String, service: HNServicing = LiveHNService.shared) async {
        if let fetched = try? await service.favoriteIDs(username: username) {
            ids = fetched
            persist()
        }
    }

    /// Optimistically toggle a favorite, reverting if HN rejects it.
    func toggle(_ itemID: Int, writer: HNWebWriter) async {
        let target = !ids.contains(itemID)
        apply(itemID, on: target)
        do {
            try await writer.setFavorite(itemID: itemID, on: target)
        } catch {
            apply(itemID, on: !target) // revert
            Haptics.warning()
        }
    }

    /// Record a favorite locally (used during migration, where the write already
    /// succeeded item-by-item).
    func markFavorite(_ id: Int) { apply(id, on: true) }

    private func apply(_ id: Int, on: Bool) {
        if on {
            if !ids.contains(id) { ids.insert(id, at: 0) }
        } else {
            ids.removeAll { $0 == id }
        }
        persist()
    }

    private func persist() { defaults.set(ids, forKey: key) }
}
