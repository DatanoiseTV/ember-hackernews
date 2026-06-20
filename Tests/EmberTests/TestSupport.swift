import Foundation
@testable import Ember

enum TestSupport {
    static func defaults() -> (UserDefaults, String) {
        let suite = "EmberTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    static func story(
        id: Int,
        title: String? = nil,
        type: String = "story",
        url: String? = nil,
        text: String? = nil
    ) -> HNItem {
        HNItem(
            id: id,
            type: type,
            by: "tester",
            time: 1_700_000_000,
            text: text,
            url: url,
            score: 10,
            title: title ?? "Story \(id)",
            descendants: 2
        )
    }
}

struct StubHNService: HNServicing {
    var storyIDsResult: Result<[Int], Error> = .success([])
    var itemsResult: Result<[HNItem], Error> = .success([])
    var userResult: Result<HNUser, Error> = .success(
        HNUser(id: "tester", created: 1_000, karma: 1, about: nil, submitted: [])
    )
    var treeResult: Result<AlgoliaItem, Error> = .success(
        AlgoliaItem(id: 1, children: [])
    )
    var searchResult: Result<[SearchHit], Error> = .success([])

    func storyIDs(for feed: Feed) async throws -> [Int] { try storyIDsResult.get() }
    func item(_ id: Int) async throws -> HNItem {
        try itemsResult.get().first { $0.id == id } ?? TestSupport.story(id: id)
    }
    func items(_ ids: [Int]) async throws -> [HNItem] {
        let items = try itemsResult.get()
        return ids.compactMap { id in items.first { $0.id == id } }
    }
    func user(_ id: String) async throws -> HNUser { try userResult.get() }
    func commentTree(for id: Int) async throws -> AlgoliaItem { try treeResult.get() }
    func search(_ query: String, mode: SearchMode, page: Int) async throws -> [SearchHit] {
        try searchResult.get()
    }
}
