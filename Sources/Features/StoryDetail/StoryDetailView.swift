import SwiftUI

/// Full story view: a rich header (title, article link, self-text, meta, author)
/// over a threaded, collapsible comment list.
struct StoryDetailView: View {
    let item: HNItem
    @State private var vm: StoryDetailViewModel

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadStore.self) private var readStore
    @Environment(\.openArticle) private var openArticle
    @Environment(\.openURL) private var openURL

    init(item: HNItem) {
        self.item = item
        _vm = State(initialValue: StoryDetailViewModel(item: item))
    }

    private var story: HNItem { vm.resolvedItem }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                commentsSection
            }
        }
        .background(Theme.background)
        .navigationTitle(story.host ?? "Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task {
            if settings.markReadOnOpen { readStore.markRead(item.id) }
            await vm.load()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let (label, color) = categoryTag {
                TagBadge(text: label, color: color)
            }

            Text(story.displayTitle)
                .font(.system(.title2, design: .default).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let url = story.articleURL {
                articleCard(url: url)
            }

            if story.isTextPost, let text = story.text, !text.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(Array(HTMLRenderer.render(text).enumerated()), id: \.offset) { _, block in
                        CommentBlockView(block: block)
                    }
                }
                .padding(.top, Spacing.xxs)
            }

            metaBar
            authorRow
        }
        .padding(Spacing.l)
        .background(Theme.surface)
    }

    private func articleCard(url: URL) -> some View {
        Button {
            Haptics.tap()
            openArticle(url)
        } label: {
            HStack(spacing: Spacing.m) {
                FaviconView(host: story.host, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.host ?? url.absoluteString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Read article")
                        .font(AppFont.meta)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 18))
                    .foregroundStyle(settings.accent.color)
            }
            .padding(Spacing.m)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.card)
        .accessibilityLabel("Read article from \(story.host ?? "link")")
        .accessibilityHint("Opens the linked page")
    }

    private var metaBar: some View {
        HStack(spacing: Spacing.l) {
            if story.kind != .job {
                StatLabel(systemImage: "arrow.up", value: "\(story.points)", tint: Theme.upvote)
                StatLabel(systemImage: "bubble.left.and.bubble.right", value: "\(vm.commentCount)")
            }
            StatLabel(systemImage: "clock", value: RelativeTime.compact(story.date))
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metaAccessibilityLabel)
    }

    private var authorRow: some View {
        NavigationLink(value: UserRoute(username: story.author)) {
            HStack(spacing: Spacing.s) {
                MonogramAvatar(name: story.author, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Posted by")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                    Text(story.author)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Spacing.m)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(.card)
        .accessibilityLabel("Posted by \(story.author). View profile.")
    }

    // MARK: Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if vm.commentCount > 0 {
                    Text("\(vm.commentCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if case .loaded = vm.phase, vm.commentCount > 0 {
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { vm.toggleCollapseAll() }
                    } label: {
                        Label(vm.allTopLevelCollapsed ? "Expand All" : "Collapse All",
                              systemImage: vm.allTopLevelCollapsed
                                ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .foregroundStyle(settings.accent.color)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)

            Divider().background(Theme.hairline)

            commentsContent
        }
        .padding(.top, Spacing.s)
    }

    @ViewBuilder private var commentsContent: some View {
        switch vm.phase {
        case .loading:
            VStack(spacing: Spacing.l) {
                ForEach(0..<5, id: \.self) { _ in SkeletonStoryRow().padding(.horizontal, Spacing.l) }
            }
            .padding(.top, Spacing.l)
        case .failed(let message):
            ErrorStateView(message: message) { Task { await vm.load() } }
        case .loaded:
            if vm.visibleComments.isEmpty {
                EmptyStateView(systemImage: "bubble.left.and.bubble.right",
                               title: "No comments yet",
                               message: "Be the first to join the discussion on Hacker News.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(vm.visibleComments) { comment in
                        CommentRow(
                            comment: comment,
                            opAuthor: story.author,
                            isCollapsed: vm.isCollapsed(comment.id)
                        ) {
                            withAnimation(.snappy(duration: 0.22)) {
                                vm.toggleCollapse(comment.id)
                            }
                        }
                        Divider()
                            .background(Theme.hairline)
                            .padding(.leading, Spacing.l)
                    }
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                let saved = bookmarks.toggle(story)
                Haptics.soft()
                _ = saved
            } label: {
                Image(systemName: bookmarks.isBookmarked(story) ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(bookmarks.isBookmarked(story) ? "Remove from saved" : "Save story")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let url = story.articleURL {
                    Button { openArticle(url) } label: { Label("Open Link", systemImage: "safari") }
                }
                Button { openURL(story.hnURL) } label: {
                    Label("Open in Hacker News", systemImage: "globe")
                }
                ShareLink(item: story.articleURL ?? story.hnURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.url = story.articleURL ?? story.hnURL
                    Haptics.tap()
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
                Divider()
                if readStore.isRead(item.id) {
                    Button { readStore.markUnread(item.id) } label: {
                        Label("Mark as Unread", systemImage: "circle")
                    }
                } else {
                    Button { readStore.markRead(item.id) } label: {
                        Label("Mark as Read", systemImage: "checkmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More actions")
        }
    }

    // MARK: Helpers

    private var categoryTag: (String, Color)? {
        switch story.kind {
        case .job: return ("Job", Theme.upvote)
        default:
            let t = story.displayTitle.lowercased()
            if t.hasPrefix("ask hn") { return ("Ask HN", Theme.link) }
            if t.hasPrefix("show hn") { return ("Show HN", Theme.positive) }
            return nil
        }
    }

    private var metaAccessibilityLabel: String {
        var parts: [String] = []
        if story.kind != .job {
            parts.append("\(story.points) points")
            parts.append("\(vm.commentCount) comments")
        }
        parts.append("posted \(RelativeTime.verbose(story.date))")
        return parts.joined(separator: ", ")
    }
}
