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
            // A newer keystroke supersedes this request: typing cancels the
            // in-flight search (URLSession throws), and a stale query should
            // never flash an error for text the user has already moved past.
            guard !error.isCancellation,
                  trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
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

private extension Error {
    /// True when a request was cancelled (e.g. superseded by a newer search),
    /// including the `URLError.cancelled` wrapped inside `HNError.transport`.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        if let hnError = self as? HNError, case .transport(let underlying) = hnError,
           (underlying as? URLError)?.code == .cancelled {
            return true
        }
        return false
    }
}
