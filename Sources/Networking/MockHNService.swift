import Foundation

/// In-memory service for SwiftUI previews and tests. No network.
struct MockHNService: HNServicing {
    static let sampleStories: [HNItem] = [
        HNItem(id: 1, type: "story", by: "pg", time: nowOffset(-3600),
               kids: [101, 102], url: "https://paulgraham.com/greatwork.html",
               score: 842, title: "How to Do Great Work", descendants: 312),
        HNItem(id: 2, type: "story", by: "antirez", time: nowOffset(-7200),
               kids: [], url: "https://github.com/redis/redis",
               score: 511, title: "Redis 8.0 released with vector sets and faster persistence",
               descendants: 188),
        HNItem(id: 3, type: "story", by: "swift_dev", time: nowOffset(-10800),
               text: "I built a native Hacker News reader in SwiftUI over a weekend. AMA about the design decisions, the Algolia API, and rendering comment HTML natively.",
               score: 274, title: "Ask HN: What makes a great native reading experience?",
               descendants: 96),
        HNItem(id: 4, type: "story", by: "ai_researcher", time: nowOffset(-16200),
               url: "https://arxiv.org/abs/2501.00001",
               score: 198, title: "A practical guide to on-device inference with small language models",
               descendants: 54),
        HNItem(id: 5, type: "job", by: "yc_startup", time: nowOffset(-21600),
               url: "https://example.com/careers",
               score: 0, title: "Founding iOS Engineer at a seed-stage startup (Remote)",
               descendants: 0),
    ]

    static let sampleUser = HNUser(
        id: "pg", created: 1160418092, karma: 157_000,
        about: "Co-founder of Y Combinator. Lisp hacker, essayist.",
        submitted: Array(1...340)
    )

    static func nowOffset(_ seconds: Int) -> Int {
        // Fixed reference time so previews are deterministic.
        1_718_000_000 + seconds
    }

    func storyIDs(for feed: Feed) async throws -> [Int] {
        Self.sampleStories.map(\.id)
    }
    func item(_ id: Int) async throws -> HNItem {
        Self.sampleStories.first { $0.id == id } ?? Self.sampleStories[0]
    }
    func items(_ ids: [Int]) async throws -> [HNItem] {
        ids.compactMap { id in Self.sampleStories.first { $0.id == id } }
    }
    func user(_ id: String) async throws -> HNUser { Self.sampleUser }

    func commentTree(for id: Int) async throws -> AlgoliaItem {
        AlgoliaItem(
            id: id, createdAtI: Self.nowOffset(-3600), type: "story",
            author: "pg", title: "How to Do Great Work",
            url: "https://paulgraham.com/greatwork.html", text: nil, points: 842,
            parentId: nil,
            children: [
                AlgoliaItem(id: 101, createdAtI: Self.nowOffset(-3000), type: "comment",
                            author: "curious_dev",
                            text: "<p>This resonates. The hardest part is choosing <i>what</i> to work on — the rest is momentum.</p>",
                            points: nil, parentId: id,
                            children: [
                                AlgoliaItem(id: 1011, createdAtI: Self.nowOffset(-2800),
                                            type: "comment", author: "builder",
                                            text: "<p>Agreed. &quot;Stay upwind&quot; is the line that stuck with me.</p>",
                                            parentId: 101, children: [])
                            ]),
                AlgoliaItem(id: 102, createdAtI: Self.nowOffset(-2400), type: "comment",
                            author: "skeptic",
                            text: "<p>Survivorship bias, though? We only hear from the people it worked out for.</p>",
                            parentId: id, children: []),
            ]
        )
    }

    func search(_ query: String, mode: SearchMode, page: Int) async throws -> [SearchHit] {
        Self.sampleStories.map {
            SearchHit(objectID: String($0.id), title: $0.title, url: $0.url,
                      author: $0.by, points: $0.score, numComments: $0.descendants,
                      createdAtI: $0.time, storyText: $0.text)
        }
    }
}
