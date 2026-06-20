import Foundation
import Testing
@testable import Ember

@MainActor
@Suite("View models")
struct ViewModelTests {
    @Test("Feed loads mock stories once and reaches the terminal page")
    func feedInitialLoad() async {
        let vm = FeedViewModel(service: MockHNService())
        await vm.startIfNeeded()
        #expect(vm.phase == .loaded)
        #expect(vm.stories.map(\.id) == MockHNService.sampleStories.map(\.id))
        #expect(!vm.canLoadMore)

        let snapshot = vm.stories
        await vm.startIfNeeded()
        #expect(vm.stories == snapshot)
        await vm.loadNextPage()
        #expect(vm.stories == snapshot)
    }

    @Test("Feed paginates, detects its threshold, and switches feeds")
    func feedPaginationAndSwitching() async {
        let stories = (1...25).map { TestSupport.story(id: $0) }
        let service = StubHNService(
            storyIDsResult: .success(Array(1...25)),
            itemsResult: .success(stories)
        )
        let vm = FeedViewModel(service: service)
        await vm.reload()
        #expect(vm.stories.count == 20)
        #expect(vm.canLoadMore)
        #expect(!vm.shouldLoadMore(at: vm.stories[10]))
        #expect(vm.shouldLoadMore(at: vm.stories[16]))

        await vm.loadNextPage()
        #expect(vm.stories.count == 25)
        #expect(!vm.canLoadMore)

        await vm.switchTo(.new)
        #expect(vm.feed == .new)
        #expect(vm.stories.count == 20)
    }

    @Test("Search enforces minimum input and converts mock results")
    func searchResults() async {
        let vm = SearchViewModel(service: MockHNService())
        vm.query = " "
        await vm.runSearch()
        #expect(vm.phase == .idle)
        #expect(vm.results.isEmpty)

        vm.query = "Swift"
        await vm.runSearch()
        #expect(vm.phase == .results)
        #expect(vm.results.map(\.id) == MockHNService.sampleStories.map(\.id))

        await vm.setMode(.recent)
        #expect(vm.mode == .recent)
        #expect(vm.phase == .results)
    }

    @Test("Story detail merges fields and manages collapsed comments")
    func storyDetail() async {
        let base = HNItem(id: 1, type: "story")
        let vm = StoryDetailViewModel(item: base, service: MockHNService())
        await vm.load()
        #expect(vm.phase == .loaded)
        #expect(vm.resolvedItem.title == "How to Do Great Work")
        #expect(vm.resolvedItem.author == "pg")
        #expect(vm.commentCount == 3)
        #expect(vm.visibleComments.count == 3)

        vm.toggleCollapse(101)
        #expect(vm.isCollapsed(101))
        #expect(vm.visibleComments.map(\.id) == [101, 102])
        vm.toggleCollapse(101)
        #expect(vm.visibleComments.count == 3)

        vm.toggleCollapseAll()
        #expect(vm.allTopLevelCollapsed)
        #expect(vm.visibleComments.map(\.id) == [101, 102])
        vm.toggleCollapseAll()
        #expect(vm.collapsed.isEmpty)
    }

    @Test("User load limits IDs, filters comments, and does not reload")
    func userLoad() async {
        let submitted = Array(1...30)
        let user = HNUser(id: "tester", created: 1_000, karma: 7, submitted: submitted)
        var items = (1...19).map { TestSupport.story(id: $0) }
        items.append(HNItem(id: 20, type: "comment", by: "tester", title: nil))
        let service = StubHNService(
            itemsResult: .success(items),
            userResult: .success(user)
        )
        let vm = UserViewModel(username: "tester", service: service)
        await vm.load()
        #expect(vm.phase == .loaded)
        #expect(vm.user?.id == "tester")
        #expect(vm.submissions.count == 19)
        #expect(vm.submissions.allSatisfy { $0.title != nil })

        await vm.load()
        #expect(vm.submissions.count == 19)
    }
}
