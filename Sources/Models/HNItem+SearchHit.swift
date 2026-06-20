import Foundation

extension HNItem {
    /// Builds a display-ready story item from an Algolia search hit so search
    /// results can reuse the same row and detail views as the feeds.
    init?(searchHit hit: SearchHit) {
        guard let id = hit.itemID else { return nil }
        self.init(
            id: id,
            type: "story",
            by: hit.author,
            time: hit.createdAtI,
            text: hit.storyText,
            url: hit.url,
            score: hit.points,
            title: hit.title,
            descendants: hit.numComments
        )
    }
}
