import Foundation
import Observation

@MainActor
@Observable
final class UserViewModel {
    let username: String
    private(set) var user: HNUser?
    private(set) var submissions: [HNItem] = []
    private(set) var phase: LoadPhase = .loading

    private let service: HNServicing

    init(username: String, service: HNServicing = LiveHNService.shared) {
        self.username = username
        self.service = service
    }

    func load() async {
        guard user == nil else { return }
        do {
            let fetched = try await service.user(username)
            user = fetched
            let ids = Array((fetched.submitted ?? []).prefix(20))
            if !ids.isEmpty {
                let items = try await service.items(ids)
                // Keep only top-level submissions (stories/jobs/polls), not comments.
                submissions = items.filter { $0.title != nil }
            }
            phase = .loaded
        } catch {
            phase = .failed((error as? HNError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
