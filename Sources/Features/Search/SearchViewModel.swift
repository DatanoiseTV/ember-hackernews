import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var mode: SearchMode = .relevance
    private(set) var results: [HNItem] = []
    private(set) var phase: SearchPhase = .idle

    private let service: HNServicing

    enum SearchPhase: Equatable {
        case idle, searching, results, empty, failed(String)
    }

    init(service: HNServicing = LiveHNService.shared) {
        self.service = service
    }

    func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            phase = .idle
            return
        }
        phase = .searching
        do {
            let hits = try await service.search(trimmed, mode: mode, page: 0)
            // Debounced callers may have moved on; honor only the latest query.
            guard trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let items = hits.compactMap(HNItem.init(searchHit:))
            results = items
            phase = items.isEmpty ? .empty : .results
        } catch {
            results = []
            phase = .failed((error as? HNError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func setMode(_ newMode: SearchMode) async {
        guard newMode != mode else { return }
        mode = newMode
        await runSearch()
    }
}
