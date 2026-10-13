import Foundation

/// Keyboard shortcuts are unique across the app: a combination assigned to one
/// action cannot be assigned to another one as well.
enum ShortcutConflicts {
    struct Assignment {
        let title: String
        let shortcut: String
    }

    /// Returns the title of the action already using `shortcut`, or `nil` when
    /// the shortcut is free. `assignments` must not contain the action the
    /// shortcut is being assigned to, so that keeping its own shortcut never
    /// reads as a conflict.
    static func conflictingActionTitle(for shortcut: String, in assignments: [Assignment]) -> String? {
        guard !shortcut.isEmpty else {
            return nil
        }

        return assignments.first { isSameShortcut($0.shortcut, shortcut) }?.title
    }

    static func isSameShortcut(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return false
        }

        // Compare the parsed key and modifiers so that different spellings of
        // the same combination, e.g. "cmd+shift+c" and "shift+cmd+c", match.
        if let parsedLhs = KeyboardShortcutParser.parse(lhs),
           let parsedRhs = KeyboardShortcutParser.parse(rhs) {
            return parsedLhs == parsedRhs
        }

        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}
