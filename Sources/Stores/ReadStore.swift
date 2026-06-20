import Foundation
import Observation

/// Tracks which stories have been opened so the feed can dim visited items.
/// Backed by `UserDefaults`, bounded so it can't grow without limit.
@Observable
final class ReadStore {
    private(set) var readIDs: Set<Int> = []

    private let defaults: UserDefaults
    private let key = "read.storyIDs"
    private let maxEntries = 2_000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let array = defaults.array(forKey: key) as? [Int] {
            readIDs = Set(array)
        }
    }

    func isRead(_ id: Int) -> Bool { readIDs.contains(id) }

    func markRead(_ id: Int) {
        guard !readIDs.contains(id) else { return }
        readIDs.insert(id)
        persist()
    }

    func markUnread(_ id: Int) {
        guard readIDs.contains(id) else { return }
        readIDs.remove(id)
        persist()
    }

    func clear() {
        readIDs = []
        persist()
    }

    private func persist() {
        var array = Array(readIDs)
        if array.count > maxEntries {
            // Keep the most recent ids (highest values are newest on HN).
            array = Array(array.sorted(by: >).prefix(maxEntries))
            readIDs = Set(array)
        }
        defaults.set(array, forKey: key)
    }
}
