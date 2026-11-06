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
}
