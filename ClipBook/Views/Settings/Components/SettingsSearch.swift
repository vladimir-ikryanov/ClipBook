import SwiftUI

/// One setting that the settings search can find. Strings are catalog keys,
/// localized when shown or matched.
struct SettingsSearchEntry {
    let section: SettingsSection
    let title: String
    let group: String?
    let detail: String?

    init(_ section: SettingsSection, _ title: String, group: String?, detail: String?) {
        self.section = section
        self.title = title
        self.group = group
        self.detail = detail
    }

    /// Whether the title or the description contains the query, in the
    /// current language or in English, ignoring case and diacritics.
    func matches(_ query: String) -> Bool {
        var candidates = [title, L10n.string(forKey: title)]
        if let detail {
            candidates += [detail, L10n.string(forKey: detail)]
        }
        return candidates.contains { $0.localizedStandardContains(query) }
    }
}

/// A row in the sidebar while searching: a pane found by its name, or a
/// setting with the path to it, like the results of System Settings.
struct SettingsSearchResult: Identifiable, Hashable {
    let section: SettingsSection
    let title: String
    let subtitle: String?
    /// The title of the row to scroll to and highlight, if the result is a
    /// setting rather than a whole pane.
    let anchor: String?

    var id: String {
        anchor.map { "\(section.rawValue)/\($0)" } ?? section.rawValue
    }
}

enum SettingsSearch {
    /// Panes whose name matches come first, then the settings in the order
    /// they appear in the sidebar and in their panes.
    static func results(for query: String) -> [SettingsSearchResult] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        let sections = Array(SettingsSection.sidebarGroups.joined()) + [.about]
        let panes = sections
            .filter { $0.nameMatches(query) }
            .map { SettingsSearchResult(section: $0, title: $0.title, subtitle: nil, anchor: nil) }

        let settings = sections.flatMap { section in
            entries
                .filter { $0.section == section && $0.matches(query) }
                .map { entry in
                    let title = L10n.string(forKey: entry.title)
                    let path = [section.title] + (entry.group.map { [L10n.string(forKey: $0)] } ?? [])
                    return SettingsSearchResult(
                        section: section,
                        title: title,
                        subtitle: path.joined(separator: " → "),
                        anchor: title
                    )
                }
        }

        return panes + settings
    }

    /// Every setting the search can find. Group headers are entries too, so a
    /// search for a group finds the group. Keep it in sync with the panes:
    /// each title is the catalog key of a row title or group header there.
    static let entries: [SettingsSearchEntry] = [
        .init(.general, "Launch at login", group: nil, detail: "Start ClipBook automatically when you sign in."),
        .init(.general, "Show history window at startup", group: nil, detail: "Open the clipboard history window when ClipBook starts."),
        .init(.general, "Check for updates automatically", group: nil, detail: "Periodically check for a newer direct-download release."),
        .init(.general, "Appearance", group: nil, detail: nil),
        .init(.general, "Theme", group: "Appearance", detail: nil),
        .init(.general, "List mode", group: "Appearance", detail: nil),
        .init(.general, "Language", group: "Appearance", detail: "Change the language of the user interface."),
        .init(.general, "Show icon in menu bar", group: "Appearance", detail: "Display the ClipBook app icon in the menu bar. You can always open Settings by pressing ⌘ + , inside the clipboard history window."),
        .init(.general, "Open with a click on the menu bar icon", group: "Appearance", detail: "Open the clipboard history window when you click the ClipBook icon in the menu bar. Right-click the icon to show its menu."),
        .init(.general, "Window", group: nil, detail: nil),
        .init(.general, "Open window position", group: "Window", detail: "Choose where the clipboard history window appears."),
        .init(.history, "Update history after action", group: nil, detail: "Move an item to the top of the history after a copy or paste action."),
        .init(.history, "Remember selection", group: nil, detail: "Open the history with the last selected item instead of the first one."),
        .init(.history, "Pin favorites to top", group: nil, detail: "Keep favorite items above regular clipboard history."),
        .init(.history, "Show quick paste shortcuts", group: nil, detail: nil),
        .init(.history, "Show dividers between items", group: nil, detail: nil),
        .init(.history, "Show preview for links", group: nil, detail: "Fetch and display link preview details when available."),
        .init(.history, "Highlight code syntax", group: nil, detail: "Color code copied as plain text in the preview by its programming language."),
        .init(.history, "Treat digit numbers as colors", group: nil, detail: "Detect hex color values copied without a leading number sign."),
        .init(.history, "Prefer pasting as plain text", group: nil, detail: "Use the default paste shortcut for plain-text paste actions."),
        .init(.history, "Actions", group: nil, detail: nil),
        .init(.history, "Single-click action", group: "Actions", detail: "Choose what clicking a history item does. Paste and Copy also select the item under the mouse pointer."),
        .init(.history, "Double-click action", group: "Actions", detail: "Choose what double-clicking a history item does."),
        .init(.history, "Number key action", group: "Actions", detail: "Choose what quick number shortcuts do."),
        .init(.history, "Key between pasted items", group: "Actions", detail: "Choose the key pressed between items when you paste several items at once."),
        .init(.history, "Copy and merge", group: nil, detail: nil),
        .init(.history, "Enable copy and merge", group: "Copy and merge", detail: "Press CMD+C+C to append the currently selected text to the previously copied text in the clipboard history."),
        .init(.history, "Separator", group: "Copy and merge", detail: "Choose how merged text fragments are separated."),
        .init(.history, "Copy merged item to clipboard", group: "Copy and merge", detail: "Put the merged value back on the system clipboard."),
        .init(.storage, "Always keep favorites and tagged items", group: nil, detail: "Preserve favorite and tagged items when clearing history and when older items are removed automatically."),
        .init(.storage, "Keep history", group: nil, detail: nil),
        .init(.storage, "Texts", group: "Keep history", detail: nil),
        .init(.storage, "Rich Texts", group: "Keep history", detail: nil),
        .init(.storage, "Images", group: "Keep history", detail: nil),
        .init(.storage, "Files & Folders", group: "Keep history", detail: nil),
        .init(.storage, "Links", group: "Keep history", detail: nil),
        .init(.storage, "Emails", group: "Keep history", detail: nil),
        .init(.storage, "Colors", group: "Keep history", detail: nil),
        .init(.storage, "Keep deleted items in Trash", group: nil, detail: "Deleted items can be put back until this period ends. Type Trash in the search field to see them."),
        .init(.storage, "Empty Trash", group: nil, detail: "Permanently delete the items in the Trash."),
        .init(.storage, "Warn before manually clearing history", group: nil, detail: "Display a confirmation dialog when clearing history manually using the 'Delete All' command."),
        .init(.storage, "Clear history on quit", group: nil, detail: "Delete unprotected items when ClipBook quits."),
        .init(.storage, "Clear history after Mac reboot", group: nil, detail: "Delete unprotected items after a system restart."),
        .init(.privacy, "Show during screen sharing and recordings", group: nil, detail: "When off, the history window stays visible to you but is hidden from screen sharing, screen recordings and screenshots."),
        .init(.privacy, "Mask sensitive content", group: nil, detail: "Mask passwords, API keys, access tokens and card numbers in copied text. Pasting and copying still use the original text."),
        .init(.privacy, "Keep confidential content", group: nil, detail: "Passwords and other data that password managers mark as confidential."),
        .init(.privacy, "Keep sensitive content", group: nil, detail: "Passwords, API keys, access tokens and card numbers found in copied text."),
        .init(.privacy, "Ignore transient content", group: nil, detail: "Skip temporary pasteboard values that apps do not intend to store."),
        .init(.privacy, "Ignored applications", group: nil, detail: nil),
        .init(.importExport, "Export", group: nil, detail: nil),
        .init(.importExport, "Export history and tags", group: "Export", detail: "Create a ClipBook archive containing history items, tags, and copied image assets."),
        .init(.importExport, "Import history and tags", group: "Import", detail: "Import a ClipBook archive. Existing matching items are updated, and existing tags are reused by name."),
        .init(.sounds, "Copy item", group: nil, detail: nil),
        .init(.sounds, "Paste item to active app", group: nil, detail: nil),
        .init(.sounds, "Delete item", group: nil, detail: nil),
        .init(.sounds, "Add item to selection", group: nil, detail: nil),
        .init(.sounds, "Remove item from selection", group: nil, detail: nil),
        .init(.tags, "New Tag...", group: nil, detail: nil),
        .init(.shortcuts, "Global shortcuts", group: nil, detail: nil),
        .init(.shortcuts, "Show clipboard history", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Pause or resume capture", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Paste next item", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Paste next rich item", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Paste next item and delete", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Paste next rich item and delete", group: "Global shortcuts", detail: nil),
        .init(.shortcuts, "Navigation", group: nil, detail: nil),
        .init(.shortcuts, "Close history window", group: "Navigation", detail: nil),
        .init(.shortcuts, "Close history window 1", group: "Navigation", detail: nil),
        .init(.shortcuts, "Close history window 2", group: "Navigation", detail: nil),
        .init(.shortcuts, "Select next item", group: "Navigation", detail: nil),
        .init(.shortcuts, "Select previous item", group: "Navigation", detail: nil),
        .init(.shortcuts, "Show Command Palette", group: "Navigation", detail: nil),
        .init(.shortcuts, "Focus search field", group: "Navigation", detail: nil),
        .init(.shortcuts, "Show or hide preview", group: "Navigation", detail: nil),
        .init(.shortcuts, "Show or hide details", group: "Navigation", detail: nil),
        .init(.shortcuts, "Open settings", group: "Navigation", detail: nil),
        .init(.shortcuts, "Item actions", group: nil, detail: nil),
        .init(.shortcuts, "Paste selected item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Paste selected item with secondary action", group: "Item actions", detail: nil),
        .init(.shortcuts, "Paste and delete selected item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Paste and delete selected item with secondary action", group: "Item actions", detail: nil),
        .init(.shortcuts, "Copy selected item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Copy selected item with secondary action", group: "Item actions", detail: nil),
        .init(.shortcuts, "Delete item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Toggle favorite", group: "Item actions", detail: nil),
        .init(.shortcuts, "Show in Finder", group: "Item actions", detail: nil),
        .init(.shortcuts, "Show in History", group: "Item actions", detail: nil),
        .init(.shortcuts, "Open in Browser", group: "Item actions", detail: nil),
        .init(.shortcuts, "Edit item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Rename item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Transform item", group: "Item actions", detail: nil),
        .init(.shortcuts, "Show or hide sensitive content", group: "Item actions", detail: nil)
    ]
}

/// Asks the detail column to scroll to a setting and highlight it. Each
/// request is new, so choosing the same result again repeats the highlight.
struct SettingsSearchHighlight: Equatable {
    let anchor: String
    let token = UUID()
}

/// The scroll target of a settings row, made from the row's title.
struct SettingsSearchAnchorID: Hashable {
    let title: String
}

private struct SettingsSearchHighlightKey: EnvironmentKey {
    nonisolated static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The title of the settings row to highlight after a search.
    nonisolated var settingsSearchHighlight: String? {
        get { self[SettingsSearchHighlightKey.self] }
        set { self[SettingsSearchHighlightKey.self] = newValue }
    }
}

/// Makes a settings row a scroll target for the search and draws the
/// highlight around it when the search leads to it, like System Settings.
private struct SettingsSearchAnchorModifier: ViewModifier {
    let title: String
    @Environment(\.settingsSearchHighlight) private var highlight

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        content
            .background(
                shape
                    .fill(Color.accentColor.opacity(0.14))
                    .overlay(shape.strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 1.5))
                    .padding(.horizontal, -6)
                    .padding(.vertical, -1)
                    .opacity(highlight == title ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: highlight)
                    .allowsHitTesting(false)
            )
            .id(SettingsSearchAnchorID(title: title))
    }
}

extension View {
    func settingsSearchAnchor(_ title: String) -> some View {
        modifier(SettingsSearchAnchorModifier(title: title))
    }
}
