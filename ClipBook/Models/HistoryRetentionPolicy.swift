import Foundation

/// Which history items have outlived their "Keep history" period. Every kind
/// gets its own cutoff date; kinds that are kept forever have none, and a
/// kind kept for zero days expires outright.
struct HistoryRetentionPolicy {
    let cutoffsByKind: [ClipboardKind: Date]
    let keepsFavoritesAndTaggedItems: Bool

    init(
        preferences: AppPreferences,
        kinds: Set<ClipboardKind> = Set(ClipboardKind.allCases),
        now: Date = Date()
    ) {
        var cutoffsByKind: [ClipboardKind: Date] = [:]
        for kind in kinds {
            let days = preferences.retentionDays(for: kind)
            guard days >= 0,
                  let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else {
                continue
            }
            cutoffsByKind[kind] = cutoff
        }
        self.cutoffsByKind = cutoffsByKind
        keepsFavoritesAndTaggedItems = preferences.keepFavoritesOnClearHistory
    }

    /// True when no item can expire under this policy.
    var isEmpty: Bool {
        cutoffsByKind.isEmpty
    }

    func isExpired(_ item: ClipboardItem) -> Bool {
        guard let cutoff = cutoffsByKind[item.kind], item.copiedAt < cutoff else {
            return false
        }
        if keepsFavoritesAndTaggedItems, item.isFavorite || !item.tags.isEmpty {
            return false
        }
        return true
    }
}

extension AppPreferences {
    /// A period of zero days: the kind is never captured.
    static let neverKeepRetentionDays = 0
    /// A negative period: the kind never expires.
    static let unlimitedRetentionDays = -1

    func retentionDays(for kind: ClipboardKind) -> Int {
        self[keyPath: RetentionClipType(kind: kind).preferenceKeyPath]
    }

    func capturesHistory(for kind: ClipboardKind) -> Bool {
        retentionDays(for: kind) != Self.neverKeepRetentionDays
    }
}
