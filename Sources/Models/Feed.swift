import Foundation

/// The selectable Hacker News story feeds.
enum Feed: String, CaseIterable, Identifiable, Codable {
    case top, new, best, ask, show, job

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: "Top"
        case .new: "New"
        case .best: "Best"
        case .ask: "Ask HN"
        case .show: "Show HN"
        case .job: "Jobs"
        }
    }

    /// Short label used in compact contexts (segmented control, menus).
    var shortTitle: String {
        switch self {
        case .ask: "Ask"
        case .show: "Show"
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .top: "flame.fill"
        case .new: "sparkles"
        case .best: "trophy.fill"
        case .ask: "questionmark.bubble.fill"
        case .show: "eye.fill"
        case .job: "briefcase.fill"
        }
    }

    /// Firebase endpoint path component, e.g. "topstories".
    var endpoint: String {
        switch self {
        case .top: "topstories"
        case .new: "newstories"
        case .best: "beststories"
        case .ask: "askstories"
        case .show: "showstories"
        case .job: "jobstories"
        }
    }
}
