import Foundation
import Observation

/// Saved stories. Full `HNItem` snapshots are persisted to a JSON file so the
/// Saved tab renders instantly and works offline.
@Observable
final class BookmarkStore {
    private(set) var items: [HNItem] = []

    private let fileURL: URL
    private var ids: Set<Int> = []

    init(filename: String = "bookmarks.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        load()
    }

    func isBookmarked(_ id: Int) -> Bool { ids.contains(id) }

    func isBookmarked(_ item: HNItem) -> Bool { ids.contains(item.id) }

    /// Toggles a bookmark. Returns true if the item is now saved.
    @discardableResult
    func toggle(_ item: HNItem) -> Bool {
        if ids.contains(item.id) {
            remove(item.id)
            return false
        } else {
            items.insert(item, at: 0)
            ids.insert(item.id)
            persist()
            return true
        }
    }

    func remove(_ id: Int) {
        items.removeAll { $0.id == id }
        ids.remove(id)
        persist()
    }

    func removeAll() {
        items = []
        ids = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HNItem].self, from: data) else { return }
        items = decoded
        ids = Set(decoded.map(\.id))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
