@testable import ClipBook
import AppKit
import Foundation
import Testing

@Suite
enum AppCoordinatorTests {
    @Suite
    struct HistoryMutationTests {
        private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        /// A text item copied `offset` seconds after `baseDate`.
        private static func textItem(_ text: String, at offset: TimeInterval, sensitivity: ItemSensitivity? = nil) -> ClipboardItem {
            .fixture(kind: .text, text: text, copiedAt: baseDate.addingTimeInterval(offset), sensitivity: sensitivity)
        }

        @Test
        @MainActor
        func mergingTextThatIsALinkJoinsTheExistingLinkItem() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let url = "https://example.com/docs"
            let existingLink = ClipboardItem.fixture(
                kind: .link,
                text: url,
                copiedAt: Self.baseDate.addingTimeInterval(10),
                firstCopiedAt: Self.baseDate
            )
            let part1 = Self.textItem(url, at: 30)
            let part2 = Self.textItem("   ", at: 20)
            try harness.seedHistory([Self.textItem("Unrelated clip", at: 40), part1, part2, existingLink])

            harness.coordinator.merge([part1, part2])

            let merged = try #require(harness.model.items.first)
            #expect(merged.kind == .link)
            #expect(harness.model.items.filter { $0.kind == .link && $0.contentKey == merged.contentKey }.count == 1)
        }

        @Test
        @MainActor
        func mergingAHexColorWithBlankTextYieldsAColorItem() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let part1 = Self.textItem("#ff0000", at: 50)
            let part2 = Self.textItem("   ", at: 45)
            try harness.seedHistory([part1, part2])

            harness.coordinator.merge([part1, part2])

            #expect(harness.model.items.first?.kind == .color)
        }

        @Test
        @MainActor
        func splitClassifiesLinesAndPlacesAtTop() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let multiLineItem = Self.textItem("alpha\nbeta\nhttps://example.com", at: 200)
            try harness.seedHistory([multiLineItem])

            harness.coordinator.split(multiLineItem)

            let items = harness.model.items
            #expect(items.count == 4)
            #expect(items[0].text == "alpha")
            #expect(items[1].text == "beta")
            #expect(items[2].kind == .link)
            #expect(items[2].text == "https://example.com")
        }

        @Test
        @MainActor
        func transformingFormattedTextAppliesEachTransformAndDropsTheFormatting() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let formatted = ClipboardItem.fixture(
                kind: .richText,
                text: "  Hello World  ",
                rtfData: Data("{\\rtf1\\ansi bold}".utf8),
                html: "<b>Hello World</b>",
                copiedAt: Self.baseDate.addingTimeInterval(200)
            )
            try harness.seedHistory([formatted])
            #expect(try #require(harness.currentItem(formatted.id)).hasFormatting)

            harness.coordinator.transform(try #require(harness.currentItem(formatted.id)), using: .trimSurroundingWhitespaces)
            harness.coordinator.transform(try #require(harness.currentItem(formatted.id)), using: .upperCase)

            let transformed = try #require(harness.currentItem(formatted.id))
            #expect(transformed.text == "HELLO WORLD")
            #expect(transformed.kind == .text)
            #expect(!transformed.hasFormatting)
        }

        @Test
        @MainActor
        func editingContentReclassifiesTheItem() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let item = Self.textItem("HELLO WORLD", at: 200)
            try harness.seedHistory([item])

            harness.coordinator.editContent(item, text: "user@example.com")

            #expect(harness.currentItem(item.id)?.kind == .email)
        }

        @Test
        @MainActor
        func sensitiveItemsAreDeletedPermanentlyInsteadOfTrashed() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let secretToken = ["sk", "-proj-", String(repeating: "aB3dE5fG", count: 4)].joined()
            let autoDetectedSecret = Self.textItem("API Key: \(secretToken)", at: 200)
            let markedSensitive = Self.textItem("Marked sensitive manually", at: 300, sensitivity: .sensitive)
            let normal = Self.textItem("Normal note", at: 100)
            try harness.seedHistory([normal, autoDetectedSecret, markedSensitive])

            harness.coordinator.delete([autoDetectedSecret, markedSensitive])

            #expect(harness.model.items.map(\.id) == [normal.id])
            #expect(try harness.trashedIDs().isEmpty)
        }

        @Test
        @MainActor
        func deletingMovesAnItemToTheTrashAndUndoAndRedoMoveItBack() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let item = Self.textItem("Normal note to trash", at: 100)
            try harness.seedHistory([item])

            harness.coordinator.delete(item)
            #expect(harness.currentItem(item.id) == nil)
            #expect(try harness.trashedIDs() == [item.id])

            harness.coordinator.undoHistoryChange()
            #expect(harness.currentItem(item.id) != nil)
            #expect(try harness.trashedIDs().isEmpty)

            harness.coordinator.redoHistoryChange()
            #expect(harness.currentItem(item.id) == nil)
            #expect(try harness.trashedIDs() == [item.id])
        }
    }

    @Suite
    struct RebootTests {
        private static let bootTime: TimeInterval = 1_800_000_000

        @Test
        func firstLaunchIsNotAReboot() {
            #expect(!AppCoordinator.isReboot(previousBootTime: nil, currentBootTime: Self.bootTime))
        }

        /// `previousOffset` is the stored boot time relative to the current one.
        /// A stored time ahead of the current one, such as `Date() - systemUptime`
        /// (which runs ahead of the real boot time by the time spent asleep) or a
        /// clock adjustment, never looks like a reboot.
        @Test(arguments: [
            (previousOffset: 86_400.0, isReboot: false),
            (previousOffset: 3_600.0, isReboot: false),
            (previousOffset: 1.0, isReboot: false),
            (previousOffset: 0.0, isReboot: false),
            (previousOffset: -59.0, isReboot: false),
            (previousOffset: -60.0, isReboot: false),
            (previousOffset: -61.0, isReboot: true),
            (previousOffset: -3_600.0, isReboot: true)
        ])
        func onlyALaterBootTimeIsAReboot(previousOffset: Double, isReboot: Bool) {
            #expect(
                AppCoordinator.isReboot(previousBootTime: Self.bootTime + previousOffset, currentBootTime: Self.bootTime)
                    == isReboot
            )
        }

        @Test
        @MainActor
        func systemBootTimeIsBeforeNowAndNotAfterTheUptimeEstimate() {
            let boot = AppCoordinator.systemBootTime()
            let now = Date()
            #expect(boot.timeIntervalSince1970 > 0)
            #expect(boot < now)
            // Uptime pauses during sleep, so `now - uptime` is never earlier than the real boot time.
            #expect(boot.timeIntervalSince1970 <= now.timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime + 1)
        }
    }

    @Suite
    struct PasteNextTests {
        @Test
        @MainActor
        func skipsPinnedFavoritesUnlessFavoritesFilterIsActive() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let favorite = ClipboardItem.fixture(text: "Favorite", isFavorite: true)
            let first = ClipboardItem.fixture(text: "First")
            let second = ClipboardItem.fixture(text: "Second")
            let items = [favorite, first, second]

            harness.model.preferences.pinFavoritesToTop = true
            #expect(harness.coordinator.historyItemsForPasteNext(in: items).map(\.id) == [first.id, second.id])

            harness.model.selectedHistoryFilterContentTypes = [.favorites]
            #expect(harness.coordinator.historyItemsForPasteNext(in: items).map(\.id) == items.map(\.id))

            harness.model.selectedHistoryFilterContentTypes = []
            harness.model.preferences.pinFavoritesToTop = false
            #expect(harness.coordinator.historyItemsForPasteNext(in: items).map(\.id) == items.map(\.id))
        }

        @Test
        @MainActor
        func fallsBackToAllItemsWhenOnlyFavoritesExist() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let favorites = [
                ClipboardItem.fixture(text: "Favorite A", isFavorite: true),
                ClipboardItem.fixture(text: "Favorite B", isFavorite: true)
            ]
            harness.model.preferences.pinFavoritesToTop = true

            #expect(harness.coordinator.historyItemsForPasteNext(in: favorites).map(\.id) == favorites.map(\.id))
            #expect(harness.coordinator.historyItemsForPasteNext(in: []).isEmpty)
        }
    }

    @Suite
    struct AppDelegateTests {
        @Test
        @MainActor
        func aTestRunUsesStorageOfItsOwnAndRemovesItWhenTheProcessTerminates() throws {
            let delegate = AppDelegate()
            let directory = try #require(delegate.scratchStorageForTests.directory)
            let suiteName = try #require(delegate.scratchStorageForTests.suiteName)
            #expect(suiteName.hasPrefix("com.ikryanov.clipbook.apptests."))
            #expect(directory.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path))
            #expect(directory.standardizedFileURL != AppDirectories.applicationSupport(fileManager: .default).standardizedFileURL)

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.set("kept until termination", forKey: "probe")
            #expect(defaults.string(forKey: "probe") == "kept until termination")

            // Removing the storage and stopping the coordinator are alternatives in `applicationWillTerminate`,
            // so the removal below also shows that the coordinator was not stopped.
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

            #expect(!FileManager.default.fileExists(atPath: directory.path))
            #expect(UserDefaults(suiteName: suiteName)?.string(forKey: "probe") == nil)
        }
    }
}

// Saving applies appearance and language, which are process-wide.
extension SharedProcessStateTests {
    @Suite
    struct PreferencesSavingTests {
        struct ShortcutRow: Sendable, CustomTestStringConvertible {
            let identifier: GlobalShortcutIdentifier
            let edit: @MainActor @Sendable (inout AppPreferences) -> Void

            var testDescription: String { "\(identifier)" }
        }

        private static let shortcutRows = [
            ShortcutRow(identifier: .showHistory) { $0.showHistoryShortcut = "ctrl+shift+cmd+a" },
            ShortcutRow(identifier: .pauseCapture) { $0.pauseShortcut = "ctrl+shift+cmd+b" },
            ShortcutRow(identifier: .pasteNext) { $0.pasteNextShortcut = "ctrl+shift+cmd+c" },
            ShortcutRow(identifier: .pasteNextRich) { $0.pasteNextRichShortcut = "ctrl+shift+cmd+d" },
            ShortcutRow(identifier: .pasteNextAndDelete) { $0.pasteNextAndDeleteShortcut = "ctrl+shift+cmd+e" },
            ShortcutRow(identifier: .pasteNextRichAndDelete) { $0.pasteNextRichAndDeleteShortcut = "ctrl+shift+cmd+f" }
        ]

        @Test
        func everyGlobalShortcutHasARowAndAListedPreference() {
            #expect(Set(Self.shortcutRows.map(\.identifier)) == Set(GlobalShortcutIdentifier.allCases))
            #expect(AppPreferences().globalShortcuts.count == GlobalShortcutIdentifier.allCases.count)
        }

        /// Every global shortcut is registered by `configureShortcuts()`, and `savePreferences()`
        /// registers them again when `AppPreferences.globalShortcuts` changes.
        @Test(arguments: shortcutRows)
        @MainActor
        func changingAGlobalShortcutRegistersTheHotKeysAgain(row: ShortcutRow) throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            harness.coordinator.savePreferences()
            #expect(harness.globalShortcuts.hasHandler(for: row.identifier))
            let passes = harness.globalShortcuts.unregisterAllCallCount

            row.edit(&harness.model.preferences)
            harness.coordinator.savePreferences()

            #expect(harness.globalShortcuts.unregisterAllCallCount == passes + 1)
            #expect(harness.globalShortcuts.hasHandler(for: row.identifier))
        }

        struct ChangeRow: Sendable, CustomTestStringConvertible {
            let label: String
            let edit: @MainActor @Sendable (inout AppPreferences) -> Void
            let expected: AppCoordinator.PreferenceChanges

            var testDescription: String { label }
        }

        private static let none = AppCoordinator.PreferenceChanges(
            appearance: false, language: false, launchAtLogin: false, automaticUpdateChecks: false, globalShortcuts: false
        )

        private static let changeRows: [ChangeRow] = {
            func only(_ keyPath: WritableKeyPath<AppCoordinator.PreferenceChanges, Bool>) -> AppCoordinator.PreferenceChanges {
                var changes = none
                changes[keyPath: keyPath] = true
                return changes
            }
            return [
                ChangeRow(label: "nothing", edit: { _ in }, expected: none),
                ChangeRow(label: "an unrelated setting", edit: { $0.warnOnClearHistory.toggle() }, expected: none),
                ChangeRow(label: "appearance", edit: { $0.appearance = $0.appearance == .dark ? .light : .dark }, expected: only(\.appearance)),
                ChangeRow(label: "language", edit: { $0.language = $0.language == "de" ? "en" : "de" }, expected: only(\.language)),
                ChangeRow(label: "launch at login", edit: { $0.launchAtLogin.toggle() }, expected: only(\.launchAtLogin)),
                ChangeRow(label: "update checks", edit: { $0.checkForUpdatesAutomatically.toggle() }, expected: only(\.automaticUpdateChecks)),
                ChangeRow(label: "a global shortcut", edit: { $0.pauseShortcut = "ctrl+shift+cmd+b" }, expected: only(\.globalShortcuts)),
            ]
        }()

        @Test(arguments: changeRows)
        @MainActor
        func preferenceChangesListOnlyWhatChanged(row: ChangeRow) {
            let previous = AppPreferences()
            var current = previous
            row.edit(&current)
            #expect(AppCoordinator.preferenceChanges(from: previous, to: current) == row.expected)
        }

        @Test
        @MainActor
        func everythingCountsAsChangedBeforeTheFirstSave() {
            #expect(
                AppCoordinator.preferenceChanges(from: nil, to: AppPreferences())
                    == AppCoordinator.PreferenceChanges(
                        appearance: true, language: true, launchAtLogin: true, automaticUpdateChecks: true, globalShortcuts: true
                    )
            )
        }

        @Test
        @MainActor
        func savePreferencesReappliesOnlyChangedSettings() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let coordinator = harness.coordinator

            let checksForUpdates = harness.model.preferences.checkForUpdatesAutomatically

            // The first save applies everything.
            coordinator.savePreferences()
            #expect(harness.updateService.automaticChecksEnabledValues == [checksForUpdates])
            let shortcutPasses = harness.globalShortcuts.unregisterAllCallCount

            // An unrelated setting leaves the update check and the hotkeys alone.
            harness.model.preferences.warnOnClearHistory.toggle()
            coordinator.savePreferences()
            coordinator.savePreferences()
            #expect(harness.updateService.automaticChecksEnabledValues == [checksForUpdates])
            #expect(harness.globalShortcuts.unregisterAllCallCount == shortcutPasses)

            // Changing the update check applies it once.
            harness.model.preferences.checkForUpdatesAutomatically = !checksForUpdates
            coordinator.savePreferences()
            coordinator.savePreferences()
            #expect(harness.updateService.automaticChecksEnabledValues == [checksForUpdates, !checksForUpdates])
            #expect(harness.globalShortcuts.unregisterAllCallCount == shortcutPasses)

            // Changing a global shortcut registers the hotkeys again, once.
            harness.model.preferences.pauseShortcut = "shift+cmd+o"
            coordinator.savePreferences()
            coordinator.savePreferences()
            #expect(harness.globalShortcuts.unregisterAllCallCount == shortcutPasses + 1)
        }
    }
}
