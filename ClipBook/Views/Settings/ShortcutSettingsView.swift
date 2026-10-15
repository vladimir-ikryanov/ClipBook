import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var recordingShortcuts = RecordingShortcuts()

    /// The shortcuts whose recorder is waiting for a combination. Clicking
    /// another recorder starts it before the previous one stops, so there can
    /// briefly be two. Nothing is drawn from it, so it stays out of the view
    /// state: redrawing the rows would hand the keyboard back to the previous
    /// recorder.
    private final class RecordingShortcuts {
        var keyPaths: Set<WritableKeyPath<AppPreferences, String>> = []
    }

    /// One configurable shortcut. Keeping every shortcut in a single list lets a
    /// row tell whether the combination the user just pressed is already taken
    /// by another action, and by which one.
    private struct ShortcutEntry: Identifiable {
        let title: String
        let keyPath: WritableKeyPath<AppPreferences, String>
        let defaultValue: String

        var id: WritableKeyPath<AppPreferences, String> { keyPath }
    }

    private var globalShortcuts: [ShortcutEntry] {
        [
            ShortcutEntry(title: L10n.string("Show clipboard history"), keyPath: \.showHistoryShortcut, defaultValue: AppPreferences.defaultShowHistoryShortcut),
            ShortcutEntry(title: L10n.string("Pause or resume capture"), keyPath: \.pauseShortcut, defaultValue: AppPreferences.defaultPauseShortcut),
            ShortcutEntry(title: L10n.string("Paste next item"), keyPath: \.pasteNextShortcut, defaultValue: AppPreferences.defaultPasteNextShortcut),
            ShortcutEntry(title: L10n.string("Paste next rich item"), keyPath: \.pasteNextRichShortcut, defaultValue: AppPreferences.defaultPasteNextRichShortcut),
            ShortcutEntry(title: L10n.string("Paste next item and delete"), keyPath: \.pasteNextAndDeleteShortcut, defaultValue: AppPreferences.defaultPasteNextAndDeleteShortcut),
            ShortcutEntry(title: L10n.string("Paste next rich item and delete"), keyPath: \.pasteNextRichAndDeleteShortcut, defaultValue: AppPreferences.defaultPasteNextRichAndDeleteShortcut)
        ]
    }

    private var navigationShortcuts: [ShortcutEntry] {
        [
            ShortcutEntry(title: L10n.string("Close history window"), keyPath: \.closeHistoryShortcut, defaultValue: AppPreferences.defaultCloseHistoryShortcut),
            ShortcutEntry(title: L10n.string("Close history window 1"), keyPath: \.closeHistorySecondaryShortcut, defaultValue: AppPreferences.defaultCloseHistorySecondaryShortcut),
            ShortcutEntry(title: L10n.string("Close history window 2"), keyPath: \.closeHistoryTertiaryShortcut, defaultValue: AppPreferences.defaultCloseHistoryTertiaryShortcut),
            ShortcutEntry(title: L10n.string("Select next item"), keyPath: \.selectNextItemShortcut, defaultValue: AppPreferences.defaultSelectNextItemShortcut),
            ShortcutEntry(title: L10n.string("Select previous item"), keyPath: \.selectPreviousItemShortcut, defaultValue: AppPreferences.defaultSelectPreviousItemShortcut),
            ShortcutEntry(title: L10n.string("Show Command Palette"), keyPath: \.showCommandPaletteShortcut, defaultValue: AppPreferences.defaultShowCommandPaletteShortcut),
            ShortcutEntry(title: L10n.string("Focus search field"), keyPath: \.focusSearchFieldShortcut, defaultValue: AppPreferences.defaultFocusSearchFieldShortcut),
            ShortcutEntry(title: L10n.string("Show or hide preview"), keyPath: \.togglePreviewPaneShortcut, defaultValue: AppPreferences.defaultTogglePreviewPaneShortcut),
            ShortcutEntry(title: L10n.string("Show or hide details"), keyPath: \.toggleDetailsShortcut, defaultValue: AppPreferences.defaultToggleDetailsShortcut),
            ShortcutEntry(title: L10n.string("Open settings"), keyPath: \.openSettingsShortcut, defaultValue: AppPreferences.defaultOpenSettingsShortcut)
        ]
    }

    private var itemActionShortcuts: [ShortcutEntry] {
        [
            ShortcutEntry(title: L10n.string("Paste selected item"), keyPath: \.pasteSelectedShortcut, defaultValue: AppPreferences.defaultPasteSelectedShortcut),
            ShortcutEntry(title: L10n.string("Paste selected item with secondary action"), keyPath: \.pasteSelectedSecondaryShortcut, defaultValue: AppPreferences.defaultPasteSelectedSecondaryShortcut),
            ShortcutEntry(title: L10n.string("Paste and delete selected item"), keyPath: \.pasteAndDeleteSelectedShortcut, defaultValue: AppPreferences.defaultPasteAndDeleteSelectedShortcut),
            ShortcutEntry(title: L10n.string("Paste and delete selected item with secondary action"), keyPath: \.pasteAndDeleteSelectedSecondaryShortcut, defaultValue: AppPreferences.defaultPasteAndDeleteSelectedSecondaryShortcut),
            ShortcutEntry(title: L10n.string("Copy selected item"), keyPath: \.copySelectedShortcut, defaultValue: AppPreferences.defaultCopySelectedShortcut),
            ShortcutEntry(title: L10n.string("Copy selected item with secondary action"), keyPath: \.copySelectedSecondaryShortcut, defaultValue: AppPreferences.defaultCopySelectedSecondaryShortcut),
            ShortcutEntry(title: L10n.string("Delete item"), keyPath: \.deleteItemShortcut, defaultValue: AppPreferences.defaultDeleteItemShortcut),
            ShortcutEntry(title: L10n.string("Toggle favorite"), keyPath: \.toggleFavoriteShortcut, defaultValue: AppPreferences.defaultToggleFavoriteShortcut),
            ShortcutEntry(title: L10n.string("Show in Finder"), keyPath: \.showInFinderShortcut, defaultValue: AppPreferences.defaultShowInFinderShortcut),
            ShortcutEntry(title: L10n.string("Show in History"), keyPath: \.showInHistoryShortcut, defaultValue: AppPreferences.defaultShowInHistoryShortcut),
            ShortcutEntry(title: L10n.string("Open in Browser"), keyPath: \.openInBrowserShortcut, defaultValue: AppPreferences.defaultOpenInBrowserShortcut),
            ShortcutEntry(title: L10n.string("Edit item"), keyPath: \.editItemShortcut, defaultValue: AppPreferences.defaultEditItemShortcut),
            ShortcutEntry(title: L10n.string("Rename item"), keyPath: \.renameItemShortcut, defaultValue: AppPreferences.defaultRenameItemShortcut),
            ShortcutEntry(title: L10n.string("Transform item"), keyPath: \.transformItemShortcut, defaultValue: AppPreferences.defaultTransformItemShortcut),
            ShortcutEntry(title: L10n.string("Show or hide sensitive content"), keyPath: \.toggleSensitiveContentShortcut, defaultValue: AppPreferences.defaultToggleSensitiveContentShortcut)
        ]
    }

    private var allShortcuts: [ShortcutEntry] {
        globalShortcuts + navigationShortcuts + itemActionShortcuts
    }

    private static let closeHistoryKeyPaths: Set<WritableKeyPath<AppPreferences, String>> = [
        \.closeHistoryShortcut,
        \.closeHistorySecondaryShortcut,
        \.closeHistoryTertiaryShortcut
    ]

    /// Showing and closing the history window may share a combination, which
    /// then toggles the window.
    private func canShareShortcut(
        _ lhs: WritableKeyPath<AppPreferences, String>,
        _ rhs: WritableKeyPath<AppPreferences, String>
    ) -> Bool {
        (lhs == \.showHistoryShortcut && Self.closeHistoryKeyPaths.contains(rhs))
            || (rhs == \.showHistoryShortcut && Self.closeHistoryKeyPaths.contains(lhs))
    }

    var body: some View {
        Group {
            SettingsSectionGroup(L10n.string("Global shortcuts")) {
                shortcutRows(for: globalShortcuts, requiresModifiers: true)
            }

            SettingsSectionGroup(L10n.string("Navigation")) {
                shortcutRows(for: navigationShortcuts)
            }

            SettingsSectionGroup(L10n.string("Item actions")) {
                shortcutRows(for: itemActionShortcuts)
            }
        }
        .onChange(of: model.preferences) { _ in
            coordinator.savePreferences()
        }
        .onDisappear {
            recordingShortcuts.keyPaths.removeAll()
            coordinator.setGlobalShortcutsSuspended(false)
        }
    }

    private func shortcutRows(for entries: [ShortcutEntry], requiresModifiers: Bool = false) -> some View {
        ForEach(entries) { entry in
            ShortcutRow(
                title: entry.title,
                text: binding(for: entry.keyPath),
                defaultText: entry.defaultValue,
                requiresModifiers: requiresModifiers,
                conflictingActionTitle: { shortcut in
                    conflictingActionTitle(for: shortcut, assignedTo: entry.keyPath)
                },
                onRecordingChanged: { isRecording in
                    if isRecording {
                        recordingShortcuts.keyPaths.insert(entry.keyPath)
                    } else {
                        recordingShortcuts.keyPaths.remove(entry.keyPath)
                    }
                    coordinator.setGlobalShortcutsSuspended(!recordingShortcuts.keyPaths.isEmpty)
                }
            )
        }
    }

    private func binding(for keyPath: WritableKeyPath<AppPreferences, String>) -> Binding<String> {
        Binding(
            get: { model.preferences[keyPath: keyPath] },
            set: { model.preferences[keyPath: keyPath] = $0 }
        )
    }

    /// Returns the title of the action already using `shortcut`, or `nil` when
    /// the shortcut is free. The action being edited is left out so that
    /// keeping its current shortcut never reads as a conflict.
    private func conflictingActionTitle(
        for shortcut: String,
        assignedTo keyPath: WritableKeyPath<AppPreferences, String>
    ) -> String? {
        let assignments = allShortcuts
            .filter { $0.keyPath != keyPath && !canShareShortcut($0.keyPath, keyPath) }
            .map { ShortcutConflicts.Assignment(title: $0.title, shortcut: model.preferences[keyPath: $0.keyPath]) }

        return ShortcutConflicts.conflictingActionTitle(for: shortcut, in: assignments)
    }
}
