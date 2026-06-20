import Foundation
import Testing
@testable import Ember

@Suite("Models")
struct ModelTests {
    @Test("Feed metadata covers every case")
    func feedMetadata() {
        #expect(Feed.allCases.map(\.rawValue) == ["top", "new", "best", "ask", "show", "job"])
        #expect(Feed.top.title == "Top")
        #expect(Feed.ask.shortTitle == "Ask")
        #expect(Feed.show.shortTitle == "Show")
        #expect(Feed.job.endpoint == "jobstories")
        #expect(Feed.best.systemImage == "trophy.fill")
    }

    @Test("HN item derives display properties")
    func itemProperties() {
        let item = HNItem(
            id: 42, type: "story", by: nil, time: 1_000,
            text: nil, url: "https://www.example.com/path",
            score: nil, title: nil, descendants: nil
        )
        #expect(item.kind == .story)
        #expect(item.author == "unknown")
        #expect(item.points == 0)
        #expect(item.commentCount == 0)
        #expect(item.displayTitle == "(untitled)")
        #expect(item.date == Date(timeIntervalSince1970: 1_000))
        #expect(item.articleURL?.absoluteString == "https://www.example.com/path")
        #expect(item.host == "example.com")
        #expect(item.hnURL.absoluteString == "https://news.ycombinator.com/item?id=42")
        #expect(!item.isTextPost)
    }

    @Test("HN item recognizes kinds, flags, and text posts")
    func itemKindsAndFlags() {
        let item = HNItem(
            id: 1, deleted: true, type: "mystery", by: "a", time: nil,
            text: "Body", dead: true, url: nil, title: "Ask HN"
        )
        #expect(item.kind == .unknown)
        #expect(item.isDeleted)
        #expect(item.isDead)
        #expect(item.isTextPost)
    }

    @Test("HN user derives stable profile values")
    func userProperties() {
        let user = HNUser(id: "pg", created: 1_000, karma: nil, about: nil, submitted: [1, 2])
        #expect(user.createdDate == Date(timeIntervalSince1970: 1_000))
        #expect(user.karmaValue == 0)
        #expect(user.submissionCount == 2)
        #expect(user.profileURL.absoluteString == "https://news.ycombinator.com/user?id=pg")
    }

    @Test("Search hits convert to stories")
    func searchHitConversion() throws {
        let hit = SearchHit(
            objectID: "123", title: "Result", url: "https://www.swift.org",
            author: "swift", points: 8, numComments: 3,
            createdAtI: 1_500, storyText: "Text"
        )
        let item = try #require(HNItem(searchHit: hit))
        #expect(item.id == 123)
        #expect(item.kind == .story)
        #expect(item.host == "swift.org")
        #expect(item.text == "Text")
        #expect(item.commentCount == 3)
        #expect(HNItem(searchHit: SearchHit(objectID: "not-an-int")) == nil)
    }
}
