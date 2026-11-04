import Foundation

/// How long confidential or sensitive content stays in the history, in
/// seconds. Zero keeps it out of the history and a negative value keeps it
/// like any other item.
enum ContentLifetime {
    static let dontSave = 0
    static let keep = -1
    /// The limited periods the settings offer, shortest first.
    static let periods = [60, 10 * 60, 60 * 60, 24 * 60 * 60, 7 * 24 * 60 * 60]
    static let options = [dontSave] + periods + [keep]

    /// A stored value the settings do not offer is read as the closest
    /// shorter option, so content is never kept longer than asked.
    static func validated(_ lifetime: Int) -> Int {
        guard lifetime > 0 else {
            return lifetime < 0 ? keep : dontSave
        }

        return options.filter { $0 > 0 && $0 <= lifetime }.max() ?? options.first { $0 > 0 }!
    }

    /// When content copied at `date` is deleted, or nil when it is kept.
    static func expiryDate(for lifetime: Int, from date: Date) -> Date? {
        lifetime > 0 ? date.addingTimeInterval(TimeInterval(lifetime)) : nil
    }

    /// Mostly the names the "Keep history" periods in the Storage settings
    /// use. Forever finishes the "Keep … content" titles better than
    /// Unlimited would.
    static func title(for lifetime: Int) -> String {
        switch lifetime {
        case dontSave:
            return L10n.string("Never")
        case 60:
            return L10n.string("1 minute")
        case 10 * 60:
            return L10n.string("10 minutes")
        case 60 * 60:
            return L10n.string("1 hour")
        case 24 * 60 * 60:
            return L10n.string("1 day")
        case 7 * 24 * 60 * 60:
            return L10n.string("1 week")
        case let lifetime where lifetime < 0:
            return L10n.string("Forever")
        default:
            return duration(lifetime)
        }
    }

    /// "10 minutes", "1 day" and the like, in the app's language.
    static func duration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = L10n.currentLocale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.weekOfMonth, .day, .hour, .minute, .second]
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }
}
