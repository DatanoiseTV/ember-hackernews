import SwiftUI

/// Horizontal, pinned feed selector. Each chip pairs an icon with a label so
/// selection never relies on color alone, and exposes the `.isSelected` trait
/// to VoiceOver.
struct FeedChipBar: View {
    let selection: Feed
    let onSelect: (Feed) -> Void

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(Feed.allCases) { feed in
                        chip(feed)
                            .id(feed)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
            }
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeInOut) { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider().background(Theme.hairline)
        }
    }

    private func chip(_ feed: Feed) -> some View {
        let isSelected = feed == selection
        return Button {
            onSelect(feed)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: feed.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(feed.shortTitle)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? settings.accent.color : Theme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
