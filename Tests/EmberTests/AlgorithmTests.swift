import Foundation
import Testing
@testable import Ember

@Suite("Algorithms and utilities")
struct AlgorithmTests {
    @Test("Comment trees flatten depth-first with descendant counts")
    func flattenComments() {
        let tree = AlgoliaItem(
            id: 1,
            children: [
                AlgoliaItem(
                    id: 2, createdAtI: 100, author: "a", text: "root",
                    children: [
                        AlgoliaItem(id: 3, author: "b", text: "child", children: [])
                    ]
                ),
                AlgoliaItem(id: 4, author: "c", text: "sibling", children: [])
            ]
        )
        let comments = tree.flattenComments()
        #expect(comments.map(\.id) == [2, 3, 4])
        #expect(comments.map(\.depth) == [0, 1, 0])
        #expect(comments.map(\.descendantCount) == [1, 0, 0])
        #expect(comments[0].date == Date(timeIntervalSince1970: 100))
    }

    @Test("Deleted leaves are removed but deleted parents with replies remain")
    func deletedComments() {
        let tree = AlgoliaItem(
            id: 1,
            children: [
                AlgoliaItem(id: 2, author: nil, text: nil, children: []),
                AlgoliaItem(
                    id: 3, author: nil, text: nil,
                    children: [AlgoliaItem(id: 4, author: "survivor", text: "reply", children: [])]
                )
            ]
        )
        let comments = tree.flattenComments(startDepth: 2)
        #expect(comments.map(\.id) == [3, 4])
        #expect(comments.map(\.depth) == [2, 3])
        #expect(comments[0].author == "[deleted]")
        #expect(comments[0].isDeleted)
    }

    @Test("HTML renderer handles paragraphs and inline styles")
    func htmlInlineRendering() {
        let blocks = HTMLRenderer.render(
            "<p>Hello <i>there</i> <strong>friend</strong> <a href=\"https://example.com\">link</a></p>"
        )
        #expect(blocks.count == 1)
        guard case .text(let text) = blocks[0] else {
            Issue.record("Expected a text block")
            return
        }
        #expect(String(text.characters) == "Hello there friend link")
        #expect(text.runs.contains { $0.link?.absoluteString == "https://example.com" })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test("HTML renderer handles line breaks, quotes, code, and malformed input")
    func htmlBlocks() {
        let blocks = HTMLRenderer.render(
            "<p>line one<br>line two</p><p>&gt; quoted</p><pre><code>let x = 1 &amp;&amp; true</code></pre><p>tail"
        )
        #expect(blocks.count == 4)
        guard case .text(let first) = blocks[0],
              case .quote(let quote) = blocks[1],
              case .code(let code) = blocks[2],
              case .text(let tail) = blocks[3] else {
            Issue.record("Unexpected block sequence")
            return
        }
        #expect(String(first.characters) == "line one\nline two")
        #expect(String(quote.characters) == "quoted")
        #expect(code == "let x = 1 && true")
        #expect(String(tail.characters) == "tail")
        #expect(HTMLRenderer.render("").isEmpty)
    }

    @Test("Entity decoding handles named, decimal, hexadecimal, and unknown entities")
    func entities() {
        #expect(HTMLRenderer.decodeEntities("&amp; &mdash; &#65; &#x42;") == "& — A B")
        #expect(HTMLRenderer.decodeEntities("keep &unknown;") == "keep &unknown;")
    }

    @Test(arguments: [
        (44.0, "just now"),
        (45.0, "0m"),
        (3_599.0, "59m"),
        (3_600.0, "1h"),
        (86_400.0, "1d"),
        (604_800.0, "1w"),
        (2_629_800.0, "1mo"),
        (31_557_600.0, "1y"),
    ])
    func relativeTimeBoundaries(interval: TimeInterval, expected: String) {
        let reference = Date(timeIntervalSince1970: 40_000_000)
        let date = reference.addingTimeInterval(-interval)
        #expect(RelativeTime.compact(date, reference: reference) == expected)
    }

    @Test("Relative time handles nil and future dates")
    func relativeTimeEdgeCases() {
        let reference = Date(timeIntervalSince1970: 10_000)
        #expect(RelativeTime.compact(nil, reference: reference).isEmpty)
        #expect(RelativeTime.compact(reference.addingTimeInterval(60), reference: reference) == "just now")
    }
}
