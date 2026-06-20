import Foundation
import Observation

enum LoadPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

/// Drives a single story feed: fetches the id list once, then pages items in
/// batches. Tolerates per-item failures (deleted/missing) without failing the
/// whole feed.
@MainActor
@Observable
final class FeedViewModel {
    private(set) var feed: Feed
    private(set) var stories: [HNItem] = []
    private(set) var phase: LoadPhase = .loading
    private(set) var isLoadingMore = false
    private(set) var canLoadMore = true

    private var allIDs: [Int] = []
    private var nextIndex = 0
    private let pageSize = 20
    private let service: HNServicing

    init(feed: Feed = .top, service: HNServicing = LiveHNService.shared) {
        self.feed = feed
        self.service = service
    }

    /// Initial load; no-op once populated (so tab switches don't refetch) and
    /// after a failure (the error view offers an explicit retry instead).
    func startIfNeeded() async {
        guard stories.isEmpty else { return }
        if case .failed = phase { return }
        await reload()
    }

    func reload() async {
        do {
            let ids = try await service.storyIDs(for: feed)
            allIDs = ids
            nextIndex = 0
            canLoadMore = true
            let firstPage = try await fetchPage()
            stories = firstPage
            phase = .loaded
        } catch {
            if stories.isEmpty { phase = .failed(message(for: error)) }
        }
    }

    func loadNextPage() async {
        guard phase == .loaded, canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let more = try? await fetchPage() {
            stories.append(contentsOf: more)
        }
    }

    func switchTo(_ newFeed: Feed) async {
        guard newFeed != feed else { return }
        feed = newFeed
        stories = []
        allIDs = []
        nextIndex = 0
        canLoadMore = true
        phase = .loading
        await reload()
    }

    func shouldLoadMore(at item: HNItem) -> Bool {
        guard let index = stories.firstIndex(of: item) else { return false }
        return index >= stories.count - 4
    }

    private func fetchPage() async throws -> [HNItem] {
        guard nextIndex < allIDs.count else {
            canLoadMore = false
            return []
        }
        let end = min(nextIndex + pageSize, allIDs.count)
        let slice = Array(allIDs[nextIndex..<end])
        let items = try await service.items(slice)
        nextIndex = end
        canLoadMore = nextIndex < allIDs.count
        return items
    }

    private func message(for error: Error) -> String {
        (error as? HNError)?.errorDescription ?? error.localizedDescription
    }
}
