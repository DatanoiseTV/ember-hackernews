import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    /// UIKit interface style applied directly to the window. `.unspecified`
    /// (System) lets the window follow the device — unlike SwiftUI's
    /// `.preferredColorScheme(nil)`, which fails to revert once forced.
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// User preferences, persisted to `UserDefaults` and observed app-wide.
@Observable
final class SettingsStore {
    var appearance: AppAppearance {
        didSet { store(appearance.rawValue, .appearance) }
    }
    var accent: AccentTheme {
        didSet { store(accent.rawValue, .accent) }
    }
    var defaultFeed: Feed {
        didSet { store(defaultFeed.rawValue, .defaultFeed) }
    }
    var openLinksInApp: Bool {
        didSet { store(openLinksInApp, .openLinksInApp) }
    }
    var readerMode: Bool {
        didSet { store(readerMode, .readerMode) }
    }
    var markReadOnOpen: Bool {
        didSet { store(markReadOnOpen, .markReadOnOpen) }
    }
    /// Show the favicon/image thumbnail on each story row.
    var showThumbnails: Bool {
        didSet { store(showThumbnails, .showThumbnails) }
    }
    /// Opt-in: enable signing in to a Hacker News account for voting, commenting
    /// and submitting. Default off; the app stays read-only and API-only when off.
    var accountFeaturesEnabled: Bool {
        didSet { store(accountFeaturesEnabled, .accountFeaturesEnabled) }
    }
    var hapticsEnabled: Bool {
        didSet {
            store(hapticsEnabled, .haptics)
            Haptics.isEnabled = hapticsEnabled
        }
    }

    // MARK: Accessibility

    /// Underline links inside comments/text for users who can't rely on color.
    var underlineLinks: Bool {
        didSet { store(underlineLinks, .underlineLinks) }
    }
    /// Force color-independent status cues (read badges, status shapes) on,
    /// regardless of the system "Differentiate Without Color" setting.
    var distinguishWithoutColor: Bool {
        didSet { store(distinguishWithoutColor, .distinguishWithoutColor) }
    }
    /// Show the numeric rank badge on story rows (extra non-color ordering cue).
    var showRankNumbers: Bool {
        didSet { store(showRankNumbers, .showRankNumbers) }
    }

    /// Multiplier applied to reading text (comments, article body, titles) on
    /// top of Dynamic Type. Adjustable in Settings and by pinch-to-zoom.
    var readingTextScale: Double {
        didSet { store(readingTextScale, .readingTextScale) }
    }

    /// Whether the first-run personalization flow has been completed.
    var hasCompletedOnboarding: Bool {
        didSet { store(hasCompletedOnboarding, .onboarded) }
    }

    static let minTextScale = 0.8
    static let maxTextScale = 1.7

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance.rawValue) ?? "") ?? .system
        accent = AccentTheme(rawValue: defaults.string(forKey: Key.accent.rawValue) ?? "") ?? .ember
        defaultFeed = Feed(rawValue: defaults.string(forKey: Key.defaultFeed.rawValue) ?? "") ?? .top
        openLinksInApp = defaults.object(forKey: Key.openLinksInApp.rawValue) as? Bool ?? true
        readerMode = defaults.object(forKey: Key.readerMode.rawValue) as? Bool ?? false
        markReadOnOpen = defaults.object(forKey: Key.markReadOnOpen.rawValue) as? Bool ?? true
        showThumbnails = defaults.object(forKey: Key.showThumbnails.rawValue) as? Bool ?? true
        accountFeaturesEnabled = defaults.object(forKey: Key.accountFeaturesEnabled.rawValue) as? Bool ?? false
        hapticsEnabled = defaults.object(forKey: Key.haptics.rawValue) as? Bool ?? true
        underlineLinks = defaults.object(forKey: Key.underlineLinks.rawValue) as? Bool ?? true
        distinguishWithoutColor = defaults.object(forKey: Key.distinguishWithoutColor.rawValue) as? Bool ?? false
        showRankNumbers = defaults.object(forKey: Key.showRankNumbers.rawValue) as? Bool ?? true
        hasCompletedOnboarding = defaults.object(forKey: Key.onboarded.rawValue) as? Bool ?? false
        let storedScale = defaults.object(forKey: Key.readingTextScale.rawValue) as? Double ?? 1.0
        readingTextScale = min(Self.maxTextScale, max(Self.minTextScale, storedScale))
        Haptics.isEnabled = hapticsEnabled
    }

    /// Restore every preference to its first-launch default. Used before
    /// re-running onboarding so personalization starts from a clean slate.
    func resetToDefaults() {
        appearance = .system
        accent = .ember
        defaultFeed = .top
        openLinksInApp = true
        readerMode = false
        markReadOnOpen = true
        hapticsEnabled = true
        underlineLinks = true
        distinguishWithoutColor = false
        showRankNumbers = true
        showThumbnails = true
        readingTextScale = 1.0
        hasCompletedOnboarding = false
    }

    private enum Key: String {
        case appearance = "settings.appearance"
        case accent = "settings.accent"
        case defaultFeed = "settings.defaultFeed"
        case openLinksInApp = "settings.openLinksInApp"
        case readerMode = "settings.readerMode"
        case markReadOnOpen = "settings.markReadOnOpen"
        case showThumbnails = "settings.showThumbnails"
        case accountFeaturesEnabled = "settings.accountFeaturesEnabled"
        case haptics = "settings.haptics"
        case underlineLinks = "settings.underlineLinks"
        case distinguishWithoutColor = "settings.distinguishWithoutColor"
        case showRankNumbers = "settings.showRankNumbers"
        case onboarded = "settings.hasCompletedOnboarding"
        case readingTextScale = "settings.readingTextScale"
    }

    private func store(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
