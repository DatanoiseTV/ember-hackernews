import SwiftUI

struct SavedView: View {
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(AccountStore.self) private var account
    @Environment(SettingsStore.self) private var settings
    @Environment(FavoritesStore.self) private var favorites
    @State private var path = NavigationPath()

    @State private var favItems: [HNItem] = []
    @State private var favPhase: Phase = .loading
    @State private var migrating = false
    @State private var migrateProgress = 0
    @State private var confirmClear = false

    enum Phase { case loading, loaded, failed }

    /// When signed in, the Saved tab becomes the user's HN Favorites.
    private var signedIn: Bool { settings.accountFeaturesEnabled && account.isSignedIn }
    private var writer: HNWebWriter { HNWebWriter(dataStore: account.dataStore) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if signedIn {
                    favoritesContent
                } else {
                    bookmarksContent
                }
            }
            .navigationTitle(signedIn ? "Favorites" : "Saved")
            .navigationDestination(for: HNItem.self) { StoryDetailView(item: $0) }
            .navigationDestination(for: UserRoute.self) { UserView(username: $0.username) }
        }
        .task(id: signedIn) {
            if signedIn { await loadFavorites() }
        }
    }

    // MARK: Favorites (signed in)

    @ViewBuilder private var favoritesContent: some View {
        switch favPhase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                .background(Theme.background)
        case .failed:
            ErrorStateView(message: "Couldn't load your favorites.") {
                Task { await loadFavorites() }
            }
            .background(Theme.background)
        case .loaded:
            if favItems.isEmpty && bookmarks.items.isEmpty {
                EmptyStateView(systemImage: "star",
                               title: "No favorites yet",
                               message: "Tap the star on a story to add it to your Hacker News favorites.")
                .background(Theme.background)
            } else {
                List {
                    if !bookmarks.items.isEmpty { migrationSection }
                    ForEach(favItems) { story in
                        row(story) {
                            Button(role: .destructive) {
                                Task { await favorites.toggle(story.id, writer: writer); await loadFavorites() }
                            } label: { Label("Remove", systemImage: "star.slash.fill") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .refreshable { await loadFavorites() }
            }
        }
    }

    private var migrationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label("\(bookmarks.items.count) saved on this device",
                      systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Add them to your Hacker News favorites so they sync with your account.")
                    .font(AppFont.meta)
                    .foregroundStyle(Theme.textSecondary)
                if migrating {
                    ProgressView(value: Double(migrateProgress), total: Double(bookmarks.items.count)) {
                        Text("Migrating \(migrateProgress) of \(bookmarks.items.count)…")
                            .font(AppFont.meta)
                    }
                } else {
                    Button {
                        Task { await migrate() }
                    } label: {
                        Label("Add to Favorites", systemImage: "star")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.accent.color)
                }
            }
            .padding(.vertical, Spacing.xs)
            .listRowBackground(Theme.surface)
        }
        .confirmationDialog("Added to Favorites. Remove the local copies?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Remove Local Saved", role: .destructive) {
                withAnimation { bookmarks.removeAll() }
                Haptics.warning()
            }
            Button("Keep Both", role: .cancel) {}
        }
    }

    private func loadFavorites() async {
        guard let username = account.username else { return }
        await favorites.refresh(username: username)
        if favorites.ids.isEmpty {
            favItems = []
            favPhase = .loaded
            return
        }
        do {
            favItems = try await LiveHNService.shared.items(favorites.ids)
            favPhase = .loaded
        } catch {
            if favItems.isEmpty { favPhase = .failed }
        }
    }

    private func migrate() async {
        migrating = true
        migrateProgress = 0
        for item in bookmarks.items {
            if !favorites.isFavorite(item.id) {
                try? await writer.setFavorite(itemID: item.id, on: true)
                favorites.markFavorite(item.id)
            }
            migrateProgress += 1
        }
        migrating = false
        Haptics.success()
        await loadFavorites()
        confirmClear = true
    }

    // MARK: Local bookmarks (signed out)

    @ViewBuilder private var bookmarksContent: some View {
        if bookmarks.items.isEmpty {
            EmptyStateView(
                systemImage: "bookmark",
                title: "Nothing saved yet",
                message: "Swipe a story or tap the bookmark icon to keep it here for later."
            )
            .background(Theme.background)
        } else {
            List {
                ForEach(bookmarks.items) { story in
                    row(story) {
                        Button(role: .destructive) {
                            withAnimation { bookmarks.remove(story.id) }
                            Haptics.soft()
                        } label: { Label("Remove", systemImage: "bookmark.slash.fill") }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    // MARK: Shared row

    @ViewBuilder private func row(_ story: HNItem, @ViewBuilder swipe: () -> some View) -> some View {
        ZStack {
            NavigationLink(value: story) { EmptyView() }.opacity(0)
            StoryRow(item: story)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l))
        .listRowSeparatorTint(Theme.separator)
        .listRowBackground(Theme.background)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: swipe)
    }
}
