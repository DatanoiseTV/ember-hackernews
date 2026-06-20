import SwiftUI

/// The primary feeds screen: a pinned feed selector over a paginated story list.
struct FeedView: View {
    @State private var vm = FeedViewModel()
    @State private var path = NavigationPath()

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Ember")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(settings.accent.color)
                            Text("Ember")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Ember")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    FeedChipBar(selection: vm.feed) { feed in
                        Haptics.selection()
                        Task { await vm.switchTo(feed) }
                    }
                }
                .navigationDestination(for: HNItem.self) { StoryDetailView(item: $0) }
                .navigationDestination(for: UserRoute.self) { UserView(username: $0.username) }
        }
        .task {
            await vm.startIfNeeded()
            #if DEBUG
            if LaunchArgs.autoOpenFirst, path.isEmpty, let first = vm.stories.first {
                path.append(first)
            }
            #endif
        }
    }

    @ViewBuilder private var content: some View {
        switch vm.phase {
        case .loading where vm.stories.isEmpty:
            ScrollView { SkeletonList() }
                .background(Theme.background)
        case .failed(let message) where vm.stories.isEmpty:
            ScrollView {
                ErrorStateView(message: message) { Task { await vm.reload() } }
            }
            .background(Theme.background)
            .refreshable { await vm.reload() }
        default:
            storyList
        }
    }

    private var storyList: some View {
        List {
            ForEach(Array(vm.stories.enumerated()), id: \.element.id) { index, story in
                ZStack {
                    // Hide the default disclosure chevron for a cleaner row.
                    NavigationLink(value: story) { EmptyView() }.opacity(0)
                    StoryRow(item: story, rank: index + 1)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l))
                .listRowSeparatorTint(Theme.separator)
                .listRowBackground(Theme.background)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        bookmarks.toggle(story)
                        Haptics.soft()
                    } label: {
                        Label(bookmarks.isBookmarked(story) ? "Unsave" : "Save",
                              systemImage: bookmarks.isBookmarked(story) ? "bookmark.slash.fill" : "bookmark.fill")
                    }
                    .tint(Theme.upvote)
                }
                .task {
                    if vm.shouldLoadMore(at: story) { await vm.loadNextPage() }
                }
            }

            if vm.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Theme.background)
                .padding(.vertical, Spacing.s)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable { await vm.reload() }
    }
}

#Preview {
    FeedView()
        .environment(SettingsStore())
        .environment(BookmarkStore())
        .environment(ReadStore())
}
