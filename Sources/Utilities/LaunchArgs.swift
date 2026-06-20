import Foundation

#if DEBUG
/// DEBUG-only launch arguments used to deep-link into specific screens for
/// screenshot automation and UI testing. Has no effect in release builds.
enum LaunchArgs {
    private static let args = ProcessInfo.processInfo.arguments

    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static func flag(_ key: String) -> Bool { args.contains(key) }

    static var initialTab: String? { value("-uiTab") }
    static var query: String? { value("-uiQuery") }
    static var autoOpenFirst: Bool { flag("-uiAutoOpenFirst") }
    static var onboardingStep: Int? { value("-uiOnboardingStep").flatMap(Int.init) }
}
#endif
