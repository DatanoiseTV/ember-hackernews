import SwiftUI

/// The canonical story row used across feeds, search, and saved lists.
/// Designed to be color-blind safe (icons + text, never color alone) and fully
/// described to VoiceOver as a single element with custom actions.
struct StoryRow: View {
    let item: HNItem
    var rank: Int?

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadStore.self) private var readStore
    @Environment(\.openArticle) private var openArticle
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDiffNoColor
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isRead: Bool { readStore.isRead(item.id) }
    private var isSaved: Bool { bookmarks.isBookmarked(item.id) }
    private var diffNoColor: Bool { systemDiffNoColor || settings.distinguishWithoutColor }

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

            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(AppFont.storyTitle)
                    .foregroundStyle(isRead ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let host = item.host {
                    Text(host)
                        .font(AppFont.meta)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                metaRow
            }

            Spacer(minLength: 0)

            if isSaved {
                Image(systemName: "bookmark.fill")
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

    private var metaRow: some View {
        HStack(spacing: Spacing.m) {
            if item.kind != .job {
                StatLabel(systemImage: "arrow.up", value: "\(item.points)", tint: Theme.upvote)
                StatLabel(systemImage: "bubble.left", value: "\(item.commentCount)")
            }
            if let tag = categoryTag, item.host != nil {
                TagBadge(text: tag.0, color: tag.1)
            }
            HStack(spacing: 4) {
                Text(item.author).lineLimit(1)
                Text("·")
                Text(RelativeTime.compact(item.date))
            }
            .font(AppFont.meta)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Actions

    @ViewBuilder private var rowActions: some View {
        if let url = item.articleURL {
            Button("Open Link") { openArticle(url) }
        }
        Button(isSaved ? "Remove from Saved" : "Save") {
            bookmarks.toggle(item)
            Haptics.soft()
        }
        if let url = item.articleURL ?? Optional(item.hnURL) {
            ShareLink(item: url) { Text("Share") }
        }
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
            let nowSaved = bookmarks.toggle(item)
            Haptics.soft()
            _ = nowSaved
        } label: {
            Label(isSaved ? "Remove from Saved" : "Save",
                  systemImage: isSaved ? "bookmark.slash" : "bookmark")
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
