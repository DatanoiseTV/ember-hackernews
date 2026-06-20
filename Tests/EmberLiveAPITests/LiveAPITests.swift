import Testing
@testable import Ember

@Suite("Live Hacker News API smoke tests")
struct LiveAPITests {
    private let service = LiveHNService()

    @Test("Firebase feed and item decode")
    func feedAndItem() async throws {
        let ids = try await service.storyIDs(for: .top)
        let id = try #require(ids.first)
        let item = try await service.item(id)
        #expect(item.id == id)
        #expect(item.type != nil)
    }

    @Test("Firebase user decodes")
    func user() async throws {
        let user = try await service.user("pg")
        #expect(user.id == "pg")
        #expect(user.created != nil)
    }

    @Test("Algolia search decodes")
    func search() async throws {
        let hits = try await service.search("swift", mode: .relevance, page: 0)
        #expect(hits.allSatisfy { !$0.objectID.isEmpty })
    }

    @Test("Algolia discussion tree decodes")
    func discussion() async throws {
        let tree = try await service.commentTree(for: 8863)
        #expect(tree.id == 8863)
        #expect(tree.type != nil)
    }
}
