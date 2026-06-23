import SwiftUI
import UIKit

/// Scroll position plus the current top content inset, observed together so the
/// nav-bar height can be derived from the inset.
private struct ScrollInfo: Equatable {
    var scrolled: CGFloat
    var insetTop: CGFloat
}

/// The primary feeds screen: a pinned feed selector over a paginated story list.
/// The Ember wordmark fades + lifts and the selector eases up as you scroll; the
/// nav bar collapses to reclaim the wordmark's space once it's gone.
struct FeedView: View {
    @State private var vm = FeedViewModel()
    @State private var path = NavigationPath()
    @State private var logoHidden = false
    @State private var logoOpacity: CGFloat = 1
    @State private var logoOffset: CGFloat = 0
    @State private var pickerOffset: CGFloat = 0
    /// Real nav-bar height, derived as `inset − statusBar − pickerHeight`, computed
    /// before the first scroll so the list doesn't jump on first use.
    @State private var navBar: CGFloat = 44
    @State private var pickerHeight: CGFloat = 0
    @State private var shownInsetTop: CGFloat = 0

    /// Picker rises at half the wordmark's rate → over 2× the scroll.
    private static let pickerRate: CGFloat = 0.5

    /// Status-bar inset from the key window (the nav bar isn't part of this).
    private var statusBarTop: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top) ?? 0
    }

    private func updateNavBar() {
        guard shownInsetTop > 0, pickerHeight > 0 else { return }
        let measured = shownInsetTop - statusBarTop - pickerHeight
        if measured > 1 { navBar = measured }
    }

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Ember")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(logoHidden ? .hidden : .visible, for: .navigationBar)
                // One continuous bar: the picker's `.bar` extends up behind the
                // wordmark, so there's no second bar to fade or seam.
                .toolbarBackground(.hidden, for: .navigationBar)
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
                        .opacity(logoOpacity)
                        .offset(y: logoOffset)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Ember")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    FeedChipBar(selection: vm.feed) { feed in
                        Haptics.selection()
                        Task { await vm.switchTo(feed) }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pickerHeight = $0; updateNavBar() }
                    .offset(y: pickerOffset)
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
                    StoryRow(item: story, rank: index + 1,
                             onSelectUser: { path.append(UserRoute(username: $0)) })
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
        .onScrollGeometryChange(for: ScrollInfo.self) { geo in
            ScrollInfo(scrolled: geo.contentOffset.y + geo.contentInsets.top,
                       insetTop: geo.contentInsets.top)
        } action: { _, info in
            let scrolled = info.scrolled
            if !logoHidden {
                shownInsetTop = info.insetTop
                updateNavBar()
            }
            // Fade + lift the wordmark continuously; compensate for the inset jump
            // while hidden so it tracks the true visual position across the toggle.
            let visualScroll = scrolled + (logoHidden ? navBar : 0)
            let progress = max(0, min(1, visualScroll / navBar))
            logoOpacity = max(0.001, 1 - progress)
            logoOffset = -progress * navBar
            // Picker eases up at half rate; offset compensated once hidden so it
            // stays put across the (instant) collapse.
            let pickerRise = max(0, min(navBar, visualScroll * Self.pickerRate))
            pickerOffset = logoHidden ? (navBar - pickerRise) : -pickerRise
            // Collapse instantly. Un-collapse a bar-height from the top so the
            // offset never goes positive (no gap above the picker); the wide
            // hide/show gap prevents flapping.
            if !logoHidden, scrolled > navBar * 2.2 {
                logoHidden = true
            } else if logoHidden, scrolled < navBar {
                logoHidden = false
            }
        }
        .refreshable { await vm.reload() }
    }
}

#Preview {
    FeedView()
        .environment(SettingsStore())
        .environment(BookmarkStore())
        .environment(ReadStore())
}
