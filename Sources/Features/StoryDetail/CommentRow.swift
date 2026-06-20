import SwiftUI

/// A single comment with depth-based thread indicators, collapse support, an
/// author profile link, and native rendering of its HTML body.
struct CommentRow: View {
    let comment: FlatComment
    let opAuthor: String?
    let isCollapsed: Bool
    let onToggle: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var isOP: Bool { opAuthor != nil && comment.author == opAuthor }
    private var blocks: [CommentBlock] { HTMLRenderer.render(comment.html) }

    private var indentPerLevel: CGFloat { typeSize.isAccessibilitySize ? 7 : 10 }
    private var cappedDepth: Int { min(comment.depth, 7) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ThreadIndicator(depth: cappedDepth)
                .padding(.trailing, comment.depth > 0 ? Spacing.s : 0)

            VStack(alignment: .leading, spacing: 7) {
                header

                if isCollapsed {
                    if comment.descendantCount > 0 {
                        Text("\(comment.descendantCount) hidden")
                            .font(AppFont.meta)
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityHidden(true)
                    }
                } else {
                    bodyContent
                }
            }
        }
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.l)
        .contentShape(Rectangle())
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            NavigationLink(value: UserRoute(username: comment.author)) {
                HStack(spacing: 6) {
                    MonogramAvatar(name: comment.author, size: 22)
                    Text(comment.author)
                        .font(AppFont.metaStrong)
                        .foregroundStyle(isOP ? Theme.upvote : Theme.textPrimary)
                    if isOP {
                        TagBadge(text: "OP", color: Theme.upvote)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOP ? "\(comment.author), original poster" : comment.author)
            .accessibilityHint("View profile")

            Spacer(minLength: Spacing.s)

            Button(action: {
                Haptics.tap()
                onToggle()
            }) {
                HStack(spacing: 5) {
                    if isCollapsed, comment.descendantCount > 0 {
                        Text("+\(comment.descendantCount)")
                            .font(AppFont.metaStrong)
                            .monospacedDigit()
                    }
                    Text(RelativeTime.compact(comment.date))
                        .font(AppFont.meta)
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.vertical, 4)
                .padding(.leading, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed
                ? "Expand thread, \(comment.descendantCount) replies hidden"
                : "Collapse thread")
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                CommentBlockView(block: block)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Vertical rainbow thread bars conveying nesting depth (also positional via
/// indentation, so it remains legible without color).
private struct ThreadIndicator: View {
    let depth: Int

    private static let palette: [Color] = [
        Color(hue: 0.07, saturation: 0.75, brightness: 0.95),
        Color(hue: 0.13, saturation: 0.70, brightness: 0.90),
        Color(hue: 0.33, saturation: 0.55, brightness: 0.75),
        Color(hue: 0.50, saturation: 0.60, brightness: 0.80),
        Color(hue: 0.60, saturation: 0.65, brightness: 0.85),
        Color(hue: 0.72, saturation: 0.55, brightness: 0.80),
        Color(hue: 0.85, saturation: 0.55, brightness: 0.80),
    ]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<depth, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Self.palette[level % Self.palette.count].opacity(0.7))
                    .frame(width: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
