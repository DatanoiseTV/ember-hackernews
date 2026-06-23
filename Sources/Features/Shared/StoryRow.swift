import SwiftUI

/// The canonical story row used across feeds, search, and saved lists.
/// Designed to be color-blind safe (icons + text, never color alone) and fully
/// described to VoiceOver as a single element with custom actions.
struct StoryRow: View {
    let item: HNItem
    var rank: Int?
    /// When provided, the username becomes a tappable shortcut to the author's
    /// profile. Passed by containers that own a navigation path; when nil the
    /// username is plain text so the row's own tap (the story) stays intact.
    var onSelectUser: ((String) -> Void)?

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadStore.self) private var readStore
    @Environment(AccountStore.self) private var account
    @Environment(FavoritesStore.self) private var favorites
    @Environment(VoteStore.self) private var voteStore
    @Environment(\.openArticle) private var openArticle
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDiffNoColor
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Web fallback shown when a native upvote is rejected (expired session, etc.).
    @State private var webTask: HNWebTask?

    private var isRead: Bool { readStore.isRead(item.id) }
    /// When signed in, the save action manages HN favorites; otherwise local bookmarks.
    private var usesFavorites: Bool { settings.accountFeaturesEnabled && account.isSignedIn }
    private var isSaved: Bool {
        usesFavorites ? favorites.isFavorite(item.id) : bookmarks.isBookmarked(item.id)
    }
    private var diffNoColor: Bool { systemDiffNoColor || settings.distinguishWithoutColor }

    private func toggleSaved() {
        if usesFavorites {
            Task { await favorites.toggle(item.id, writer: HNWebWriter(dataStore: account.dataStore)) }
        } else {
            bookmarks.toggle(item)
        }
    }

    /// Whether the signed-in user can upvote this item directly from the row.
    /// HN shows no vote arrow on your own posts, so hide the affordance there
    /// rather than letting the tap fail into the web fallback.
    private var canVote: Bool {
        settings.accountFeaturesEnabled && account.isSignedIn
            && item.kind != .job && item.author != account.username
    }
    private var hasVoted: Bool { voteStore.hasVoted(item.id) }
    /// Points bumped by our own optimistic upvote (HN's API count lags).
    private var displayedPoints: Int { item.points + (hasVoted ? 1 : 0) }

    /// Optimistic native upvote; on any failure, revert and offer the web fallback.
    private func upvote() {
        guard canVote, !hasVoted else { return }
        voteStore.markVoted(item.id)
        Haptics.soft()
        Task {
            do {
                try await HNWebWriter(dataStore: account.dataStore).vote(itemID: item.id, up: true)
            } catch {
                voteStore.unmarkVoted(item.id)
                Haptics.warning()
                webTask = .item(itemID: item.id)
            }
        }
    }

    private var categoryTag: (String, Color)? {
        switch item.kind {
        case .job: return ("Job", Theme.upvote)
        default:
            let t = item.displayTitle.lowercased()
            if t.hasPrefix("ask hn") { return ("Ask", Theme.link) }
            if t.hasPrefix("show hn") { return ("Show", Theme.positive) }
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            if settings.showRankNumbers, let rank {
                Text("\(rank)")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, alignment: .trailing)
                    .padding(.top, 2)
            }

            if settings.showThumbnails {
                thumbnail
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(AppFont.storyTitle)
                    .foregroundStyle(isRead ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let host = item.host {
                    hostLabel(host)
                }

                metaRow
            }

            Spacer(minLength: 0)

            if isSaved {
                Image(systemName: usesFavorites ? "star.fill" : "bookmark.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.upvote)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.m)
        .contentShape(Rectangle())
        .opacity(isRead ? 0.82 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the discussion")
        .accessibilityAddTraits(.isButton)
        .accessibilityActions { rowActions }
        .contextMenu { contextMenu } preview: { StoryPreview(item: item) }
        .sheet(item: $webTask) { task in
            HNWebSheet(task: task)
        }
    }

    // MARK: Pieces

    @ViewBuilder private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            if let tag = categoryTag, item.host == nil {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tag.1.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: item.kind == .job ? "briefcase.fill" : "text.bubble.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tag.1)
                    )
            } else {
                FaviconView(host: item.host, size: 38)
            }

            // Color-independent "read" cue.
            if isRead && diffNoColor {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white, Theme.positive)
                    .background(Circle().fill(Theme.background))
                    .offset(x: 4, y: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, 1)
    }

    /// Host as a tappable shortcut to the article when one exists.
    @ViewBuilder private func hostLabel(_ host: String) -> some View {
        let label = Text(host)
            .font(AppFont.meta)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
        if let url = item.articleURL {
            Button {
                Haptics.tap()
                openArticle(url)
            } label: { label }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        } else {
            label
        }
    }

    private var metaRow: some View {
        HStack(spacing: Spacing.m) {
            if item.kind != .job {
                upvoteStat
                StatLabel(systemImage: "bubble.left", value: "\(item.commentCount)")
            }
            if let tag = categoryTag, item.host != nil {
                TagBadge(text: tag.0, color: tag.1)
            }
            // Author and time-since are spaced like the other meta items (no
            // separator bullet) so the whole row reads consistently.
            // A plain Button (not a NavigationLink) keeps the username tappable
            // without the List promoting it to the row's tap action — the rest of
            // the row still opens the story.
            if let onSelectUser {
                Button { onSelectUser(item.author) } label: {
                    Text(item.author).lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(item.author).lineLimit(1)
            }
            Text(RelativeTime.compact(item.date))
        }
        .font(AppFont.meta)
        .foregroundStyle(Theme.textSecondary)
    }

    /// Points stat that doubles as a one-tap upvote when signed in.
    @ViewBuilder private var upvoteStat: some View {
        if canVote {
            Button { upvote() } label: {
                StatLabel(systemImage: hasVoted ? "arrow.up.circle.fill" : "arrow.up",
                          value: "\(displayedPoints)", tint: Theme.upvote)
            }
            .buttonStyle(.plain)
            .disabled(hasVoted)
            .accessibilityHidden(true)
        } else {
            StatLabel(systemImage: "arrow.up", value: "\(displayedPoints)", tint: Theme.upvote)
        }
    }

    // MARK: Actions

    @ViewBuilder private var rowActions: some View {
        if let url = item.articleURL {
            Button("Open Link") { openArticle(url) }
        }
        if canVote, !hasVoted {
            Button("Upvote") { upvote() }
        }
        Button(saveActionTitle) {
            toggleSaved()
            Haptics.soft()
        }
        if let url = item.articleURL ?? Optional(item.hnURL) {
            ShareLink(item: url) { Text("Share") }
        }
    }

    private var saveActionTitle: String {
        if usesFavorites { return isSaved ? "Remove from Favorites" : "Add to Favorites" }
        return isSaved ? "Remove from Saved" : "Save"
    }

    @ViewBuilder private var contextMenu: some View {
        if let url = item.articleURL {
            Button {
                openArticle(url)
            } label: {
                Label("Open Link", systemImage: "safari")
            }
        }
        Button {
            toggleSaved()
            Haptics.soft()
        } label: {
            Label(saveActionTitle,
                  systemImage: usesFavorites
                    ? (isSaved ? "star.slash" : "star")
                    : (isSaved ? "bookmark.slash" : "bookmark"))
        }
        ShareLink(item: item.articleURL ?? item.hnURL) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button {
            UIPasteboard.general.url = item.articleURL ?? item.hnURL
            Haptics.tap()
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }
        Divider()
        if isRead {
            Button {
                readStore.markUnread(item.id)
            } label: {
                Label("Mark as Unread", systemImage: "circle")
            }
        } else {
            Button {
                readStore.markRead(item.id)
            } label: {
                Label("Mark as Read", systemImage: "checkmark.circle")
            }
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if settings.showRankNumbers, let rank { parts.append("Number \(rank).") }
        parts.append(item.displayTitle + ".")
        if let host = item.host { parts.append("From \(host).") }
        if item.kind != .job {
            parts.append("\(item.points) points.")
            parts.append("\(item.commentCount) comments.")
        }
        parts.append("Posted by \(item.author) \(RelativeTime.verbose(item.date)).")
        if isSaved { parts.append("Saved.") }
        if isRead { parts.append("Already read.") }
        return parts.joined(separator: " ")
    }
}

/// Lightweight preview shown in the context-menu peek.
private struct StoryPreview: View {
    let item: HNItem
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(item.displayTitle)
                .font(.headline)
            if let host = item.host {
                Label(host, systemImage: "link")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if item.isTextPost, !(item.text ?? "").isEmpty {
                Text(HTMLRenderer.decodeEntities(item.text ?? "").prefix(280))
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(6)
            }
        }
        .padding()
        .frame(maxWidth: 320, alignment: .leading)
    }
}
