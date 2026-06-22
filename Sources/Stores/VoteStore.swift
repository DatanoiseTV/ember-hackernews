import Foundation
import Observation

/// Remembers which items the signed-in user has upvoted, so the optimistic
/// "voted" state survives navigation and relaunch (HN's API doesn't expose it).
/// Backed by `UserDefaults`, bounded so it can't grow without limit.
@Observable
final class VoteStore {
    private(set) var votedIDs: Set<Int> = []

    private let defaults: UserDefaults
    private let key = "votes.upvotedIDs"
    private let maxEntries = 5_000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let array = defaults.array(forKey: key) as? [Int] {
            votedIDs = Set(array)
        }
    }

    func hasVoted(_ id: Int) -> Bool { votedIDs.contains(id) }

    func markVoted(_ id: Int) {
        guard !votedIDs.contains(id) else { return }
        votedIDs.insert(id)
        persist()
    }

    /// Revert an optimistic vote that failed to land.
    func unmarkVoted(_ id: Int) {
        guard votedIDs.contains(id) else { return }
        votedIDs.remove(id)
        persist()
    }

    func clear() {
        votedIDs = []
        persist()
    }

    private func persist() {
        var array = Array(votedIDs)
        if array.count > maxEntries {
            array = Array(array.sorted(by: >).prefix(maxEntries))
            votedIDs = Set(array)
        }
        defaults.set(array, forKey: key)
    }
}
