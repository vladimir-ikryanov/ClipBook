import Foundation

/// The terms a search query looks for in each history item.
nonisolated struct HistorySearchTerms: Equatable, Sendable {
    let values: [String]

    init(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        values = trimmed.isEmpty ? [] : [trimmed]
    }

    var isEmpty: Bool {
        values.isEmpty
    }
}

/// Checks whether an item's search text contains every term of a search query.
nonisolated enum HistorySearchMatcher {
    static func warmUp() {}

    static func matches(_ text: String, _ terms: HistorySearchTerms, locale: Locale) -> Bool {
        for term in terms.values {
            if text.range(of: term, options: .caseInsensitive, range: nil, locale: locale) == nil {
                return false
            }
        }
        return true
    }
}
