import Foundation

/// Compact and verbose relative-time formatting, tuned to match HN's style.
enum RelativeTime {
    /// Compact form for dense metadata rows: "just now", "5m", "3h", "2d", "4w", "6mo", "2y".
    static func compact(_ date: Date?, reference: Date = Date()) -> String {
        guard let date else { return "" }
        let s = max(0, reference.timeIntervalSince(date))
        switch s {
        case ..<45: return "just now"
        case ..<3600: return "\(Int(s / 60))m"
        case ..<86_400: return "\(Int(s / 3600))h"
        case ..<604_800: return "\(Int(s / 86_400))d"
        case ..<2_629_800: return "\(Int(s / 604_800))w"
        case ..<31_557_600: return "\(Int(s / 2_629_800))mo"
        default: return "\(Int(s / 31_557_600))y"
        }
    }

    /// Verbose form: "5 minutes ago", "3 hours ago", "2 days ago".
    static func verbose(_ date: Date?, reference: Date = Date()) -> String {
        guard let date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: reference)
    }

    /// Absolute medium date for profiles: "Oct 9, 2006".
    static func absolute(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
