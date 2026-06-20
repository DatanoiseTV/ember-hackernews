import SwiftUI

/// Adaptive root: a sidebar-driven split view on Mac and regular-width iPad,
/// and a tab bar on iPhone. Shared app chrome (accent, color scheme, link
/// handling, in-app browser, onboarding) is applied once here for both.
struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LinkOpener.self) private var linkOpener
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
        .preferredColorScheme(settings.appearance.colorScheme)
        // Route explicit article opens through the in-app browser (or system).
        .environment(\.openArticle) { url in
            if settings.openLinksInApp {
                linkOpener.present(url, reader: settings.readerMode)
            } else {
                systemOpenURL(url)
            }
        }
        // Route inline comment/text links the same way.
        .environment(\.openURL, OpenURLAction { url in
            if settings.openLinksInApp {
                linkOpener.present(url, reader: false)
                return .handled
            }
            return .systemAction
        })
        .sheet(item: $linkOpener.presented) { presented in
            SafariView(url: presented.url, entersReaderIfAvailable: presented.reader)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView()
                // Presentation containers do not reliably inherit Observation
                // environment values on Mac Catalyst (notably on macOS 27).
                .environment(settings)
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

    enum Tab: Hashable { case stories, search, saved, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Stories", systemImage: "flame.fill") }
                .tag(Tab.stories)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
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
