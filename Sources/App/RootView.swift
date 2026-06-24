import SwiftUI
import UIKit

/// Adaptive root: a sidebar-driven split view on Mac and regular-width iPad,
/// and a tab bar on iPhone. Shared app chrome (accent, color scheme, link
/// handling, in-app browser, onboarding) is applied once here for both.
struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadStore.self) private var readStore
    @Environment(LinkOpener.self) private var linkOpener
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var systemOpenURL
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var linkOpener = linkOpener

        Group {
            if sizeClass == .compact {
                MobileRootView()
            } else {
                DesktopRootView()
            }
        }
        .tint(settings.accent.color)
        .onChange(of: settings.appearance, initial: true) { _, appearance in
            applyInterfaceStyle(appearance.uiStyle)
        }
        // Route explicit article opens through the in-app browser (or system).
        .environment(\.openArticle) { url in
            if settings.openLinksInApp {
                linkOpener.present(url, reader: settings.readerMode)
            } else {
                systemOpenURL(url)
            }
        }
        // Route inline comment/text links the same way, honoring reader mode.
        .environment(\.openURL, OpenURLAction { url in
            if settings.openLinksInApp {
                linkOpener.present(url, reader: settings.readerMode)
                return .handled
            }
            return .systemAction
        })
        .sheet(item: $linkOpener.presented) { presented in
            SafariView(url: presented.url, entersReaderIfAvailable: presented.reader)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            // Re-inject the Observation stores: presented views (full-screen
            // cover / sheet) don't reliably inherit `@Observable` environment
            // objects across the presentation boundary, which crashed the
            // Mac Catalyst build on first launch (issue #1).
            OnboardingView()
                .modifier(AppStoresEnvironment(settings: settings, bookmarks: bookmarks,
                                               readStore: readStore, linkOpener: linkOpener,
                                               account: account))
        }
    }

    /// Apply the chosen interface style to every window so System truly
    /// follows the device and a forced Light/Dark reliably reverts.
    private func applyInterfaceStyle(_ style: UIUserInterfaceStyle) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { showing in
                if !showing { settings.hasCompletedOnboarding = true }
            }
        )
    }
}

/// iPhone layout: a tab bar with an independent navigation stack per tab.
struct MobileRootView: View {
    @State private var selectedTab: Tab = .stories
    @Environment(SettingsStore.self) private var settings
    @Environment(AccountStore.self) private var account

    enum Tab: Hashable { case stories, search, me, saved, settings }

    private var showMe: Bool { settings.accountFeaturesEnabled && account.isSignedIn }

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Stories", systemImage: "flame.fill") }
                .tag(Tab.stories)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
            if showMe, let username = account.username {
                NavigationStack {
                    UserView(username: username)
                        .navigationDestination(for: HNItem.self) { StoryDetailView(item: $0) }
                        .navigationDestination(for: UserRoute.self) { UserView(username: $0.username) }
                }
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
                .tag(Tab.me)
            }
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(Tab.saved)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .onAppear {
            #if DEBUG
            switch LaunchArgs.initialTab {
            case "search": selectedTab = .search
            case "saved": selectedTab = .saved
            case "settings": selectedTab = .settings
            default: break
            }
            #endif
        }
    }
}
