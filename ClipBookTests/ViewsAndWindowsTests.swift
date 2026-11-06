@testable import ClipBook
import AppKit
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
enum ViewsAndWindowsTests {
    @Suite
    struct RowBuilderAndFormattingTests {
        @Test
        func historyTableRowBuilderGroupingAndDST() throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))

            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayDate = try #require(calendar.date(byAdding: .day, value: -1, to: todayStart)).addingTimeInterval(3600)
            let olderDate = try #require(calendar.date(byAdding: .day, value: -10, to: todayStart)).addingTimeInterval(3600)

            // DST spring-forward in America/New_York on 2026-03-08.
            let dstComponents = DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30)
            let dstBeforeJump = try #require(calendar.date(from: dstComponents))
            let dstAfterJump = dstBeforeJump.addingTimeInterval(3 * 3600)

            let pinnedFav = ClipboardItem.fixture(
                kind: .text,
                text: "Pinned Favorite",
                copiedAt: olderDate,
                isFavorite: true,
                favoriteOrder: 0
            )
            let todayItem = ClipboardItem.fixture(
                kind: .text,
                text: "Today Item",
                copiedAt: todayStart.addingTimeInterval(600)
            )
            let yesterdayItem = ClipboardItem.fixture(
                kind: .text,
                text: "Yesterday Item",
                copiedAt: yesterdayDate
            )
            let dstItem1 = ClipboardItem.fixture(
                kind: .text,
                text: "DST Early",
                copiedAt: dstAfterJump
            )
            let dstItem2 = ClipboardItem.fixture(
                kind: .text,
                text: "DST Late",
                copiedAt: dstBeforeJump
            )

            // 00:30 the day after the jump is inside 24 hours of the start of the 23-hour day before it.
            let nextDayComponents = DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30)
            let dstNextDay = ClipboardItem.fixture(
                kind: .text,
                text: "DST Next Day",
                copiedAt: try #require(calendar.date(from: nextDayComponents))
            )

            let rows = HistoryTableRowBuilder.build(
                from: [pinnedFav, todayItem, yesterdayItem, dstNextDay, dstItem1, dstItem2],
                groupPinnedFavorites: true,
                calendar: calendar
            )

            #expect(rows.count == 11)
            #expect(rows[0] == .sectionHeader("Favorites"))
            #expect(rows[1] == .item(pinnedFav, itemIndex: 0))
            #expect(rows[2] == .sectionHeader("Today"))
            #expect(rows[3] == .item(todayItem, itemIndex: 1))
            #expect(rows[4] == .sectionHeader("Yesterday"))
            #expect(rows[5] == .item(yesterdayItem, itemIndex: 2))

            guard case .sectionHeader(let nextDayTitle) = rows[6], case .sectionHeader(let jumpDayTitle) = rows[8] else {
                Issue.record("Expected a section header for each of the two days around the DST jump")
                return
            }
            #expect(!nextDayTitle.isEmpty)
            #expect(!jumpDayTitle.isEmpty)
            #expect(nextDayTitle != jumpDayTitle)
            #expect(![nextDayTitle, jumpDayTitle].contains("Today"))
            #expect(![nextDayTitle, jumpDayTitle].contains("Yesterday"))
            #expect(rows[7] == .item(dstNextDay, itemIndex: 3))
            #expect(rows[9] == .item(dstItem1, itemIndex: 4))
            #expect(rows[10] == .item(dstItem2, itemIndex: 5))
        }

        @Test
        func searchMatchHighlighterDiacritics() {
            let text = "Café résumé naïve CAFÉ"
            let font = NSFont.systemFont(ofSize: 13)
            let baseColor = NSColor.labelColor
            let attributed = HistorySearchMatchHighlighter.attributedString(
                text: text,
                font: font,
                textColor: baseColor,
                searchQuery: "cafe"
            )

            let nsText = text as NSString
            let firstCafeRange = nsText.range(of: "Café")
            let secondCafeRange = nsText.range(of: "CAFÉ")
            let resumeRange = nsText.range(of: "résumé")

            let firstColor = attributed.attribute(.foregroundColor, at: firstCafeRange.location, effectiveRange: nil) as? NSColor
            let secondColor = attributed.attribute(.foregroundColor, at: secondCafeRange.location, effectiveRange: nil) as? NSColor
            let resumeColor = attributed.attribute(.foregroundColor, at: resumeRange.location, effectiveRange: nil) as? NSColor

            #expect(firstColor == .systemBlue)
            #expect(secondColor == .systemBlue)
            #expect(resumeColor == baseColor)
        }

        @Test
        func linkPreviewHTMLParserMetadataAndEntities() throws {
            let baseURL = try #require(URL(string: "https://example.com/articles/post"))
            let html = """
            <html>
            <head>
              <title>Fallback &amp; Title</title>
              <meta property="og:title" content="Tom &amp; Jerry&nbsp;&mdash;&nbsp;Official &rsquo;Site&rsquo; &copy; 2026 &amp; more">
              <meta name="twitter:description" content="A &quot;classic&quot; show &amp; tell with bare &amp; ampersand">
              <meta property="og:image" content="/assets/preview.png">
              <link rel="shortcut icon" href="/old.ico" type="image/x-icon">
              <link rel="icon" href="/favicon-custom.png">
              <link rel="apple-touch-icon" href="/apple-touch.png">
            </head>
            </html>
            """

            let metadata = LinkPreviewHTMLParser.parse(html: html, baseURL: baseURL)
            #expect(metadata.title == "Tom & Jerry \u{2014} Official \u{2019}Site\u{2019} \u{00A9} 2026 & more")
            #expect(metadata.description == "A \"classic\" show & tell with bare & ampersand")
            #expect(metadata.imageURL?.absoluteString == "https://example.com/assets/preview.png")

            let faviconStrings = metadata.faviconURLs.map(\.absoluteString)
            #expect(faviconStrings.count >= 4)
            #expect(faviconStrings[0] == "https://example.com/apple-touch.png")
            #expect(faviconStrings[1] == "https://example.com/favicon-custom.png")
            #expect(faviconStrings[2] == "https://example.com/old.ico")

            let fallbackHTML = """
            <html><head><title>Bare &amp; Simple &nbsp; Title</title></head></html>
            """
            let fallbackMeta = LinkPreviewHTMLParser.parse(html: fallbackHTML, baseURL: baseURL)
            #expect(fallbackMeta.title == "Bare & Simple Title")
        }
    }

    @Suite
    struct ViewsDialogsAndWindowsTests {
        private static let rowFrame = NSRect(x: 0, y: 0, width: 480, height: HistoryRow.height)

        @MainActor
        private static func labels(of row: NSView) -> [HistoryFixedTextColorLabel] {
            row.layoutSubtreeIfNeeded()
            return collectLabels(in: row)
        }

        /// A toolbar with its search item built, and a delegate that records what the toolbar reports.
        @MainActor
        private static func makeSearchToolbar() throws -> (toolbar: HistoryToolbar, delegate: ToolbarDelegateSpy, searchView: NSView) {
            let toolbar = HistoryToolbar()
            let delegate = ToolbarDelegateSpy()
            toolbar.delegate = delegate
            let searchItem = try #require(
                toolbar.toolbar(
                    toolbar.makeToolbar(),
                    itemForItemIdentifier: NSToolbarItem.Identifier("HistoryToolbarSearch"),
                    willBeInsertedIntoToolbar: true
                )
            )
            return (toolbar, delegate, try #require(searchItem.view))
        }

        @MainActor
        private static func allItems(in menu: NSMenu) -> [NSMenuItem] {
            menu.items.flatMap { [$0] + ($0.submenu.map(allItems(in:)) ?? []) }
        }

        /// The preview's "More actions" menu for a stored rich text item, with the full context
        /// menu it is built from and a count of how often the preview was dismissed.
        @MainActor
        private final class PreviewMenuFixture {
            let harness: TestCoordinatorHarness
            let item = ClipboardItem.fixture(kind: .richText, text: "Bold Text", html: "<b>Bold Text</b>")
            let viewController: HistoryContentViewController
            let contextMenuBuilder: HistoryItemContextMenu
            private(set) var dismissCount = 0
            private(set) var previewMenuBuilder: ItemPreviewActionsMenu!
            /// Built once: building the menu again forgets the actions of the one before.
            private(set) var previewMenuItems: [NSMenuItem] = []

            init() throws {
                TestSupport.ensureAppKitInitialized()
                harness = try TestSupport.makeTestCoordinator()
                try harness.seedHistory([item])
                viewController = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
                contextMenuBuilder = HistoryItemContextMenu(
                    target: viewController,
                    availableTags: [],
                    preferences: harness.model.preferences
                )
                previewMenuBuilder = ItemPreviewActionsMenu(
                    makeItemMenu: { [contextMenuBuilder] in contextMenuBuilder.makeMenu(for: $0) },
                    dismissPreview: { [unowned self] in dismissCount += 1 }
                )
                previewMenuItems = ViewsDialogsAndWindowsTests.allItems(in: previewMenuBuilder.makeMenu(for: item))
            }

            /// Every item of the full context menu.
            var fullMenuItems: [NSMenuItem] {
                ViewsDialogsAndWindowsTests.allItems(in: contextMenuBuilder.makeMenu(for: item))
            }

            /// The item of the preview menu that shows the same title as the item of the full menu with `action`.
            func previewItem(forFullMenuAction action: Selector) throws -> NSMenuItem {
                let title = try #require(fullMenuItems.first { $0.action == action }).title
                return try #require(previewMenuItems.first { $0.title == title })
            }
        }

        @Test
        @MainActor
        func previewActionsMenuDropsPasteAndCopyActionsAndKeepsTheRest() throws {
            let fixture = try PreviewMenuFixture()
            defer { fixture.harness.cleanup() }

            let droppedActions = [
                #selector(HistoryContentViewController.pasteMenuItem(_:)),
                #selector(HistoryContentViewController.pastePlainTextMenuItem(_:)),
                #selector(HistoryContentViewController.copyMenuItem(_:)),
                #selector(HistoryContentViewController.copyPlainTextMenuItem(_:))
            ]
            let droppedTitles = fixture.fullMenuItems.filter { $0.action.map(droppedActions.contains) == true }.map(\.title)
            #expect(!droppedTitles.isEmpty, "The full context menu should offer the actions the preview leaves out")

            let previewTitles = fixture.previewMenuItems.map(\.title)
            #expect(previewTitles.contains { !$0.isEmpty })
            for title in droppedTitles {
                #expect(!previewTitles.contains(title), "\(title) should not be in the preview menu")
            }
        }

        @Test
        @MainActor
        func previewActionsThatOpenASheetDismissThePreviewAndInPlaceActionsDoNot() throws {
            let fixture = try PreviewMenuFixture()
            defer { fixture.harness.cleanup() }

            let sheetAction = try fixture.previewItem(forFullMenuAction: #selector(HistoryContentViewController.deleteMenuItem(_:)))
            let inPlaceAction = try fixture.previewItem(forFullMenuAction: #selector(HistoryContentViewController.sensitiveMenuItem(_:)))

            NSApp.sendAction(try #require(inPlaceAction.action), to: inPlaceAction.target, from: inPlaceAction)
            #expect(fixture.dismissCount == 0)

            NSApp.sendAction(try #require(sheetAction.action), to: sheetAction.target, from: sheetAction)
            #expect(fixture.dismissCount == 1)
        }

        /// The preview masks only an item found to hold a secret, so a secret far into a long item has
        /// to make the item count as holding one.
        @Test(arguments: [3_000, 50_000])
        @MainActor
        func previewMasksASecretWhereverItIs(offset: Int) {
            TestSupport.ensureAppKitInitialized()
            let token = ["ghp", "_", "1234567890abcdefghijklmnopqrstuvwxyzAB"].joined()
            let controller = ItemPreviewDialogController(
                item: ClipboardItem.fixture(kind: .text, text: String(repeating: "a", count: offset) + " " + token + " end"),
                maximumContentSize: NSSize(width: 800, height: 600),
                detectsSensitiveContent: true,
                revealsSensitiveContent: false,
                loadFormatting: { $0 }
            )
            _ = controller.view

            func textViews(in view: NSView) -> [NSTextView] {
                ((view as? NSTextView).map { [$0] } ?? []) + view.subviews.flatMap(textViews(in:))
            }
            let shown = textViews(in: controller.view).map(\.string).joined()
            #expect(!shown.isEmpty)
            #expect(!shown.contains(token))
        }

        @Test
        @MainActor
        func windowFrameIsSavedOnceTheWindowHasBeenShown() throws {
            TestSupport.ensureAppKitInitialized()

            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let historyWindow = HistoryWindow(model: harness.model, coordinator: harness.coordinator)
            defer { historyWindow.window.orderOut(nil) }

            historyWindow.show()
            historyWindow.saveWindowFrame()

            let frame = historyWindow.window.frame
            let preferences = harness.model.preferences
            #expect(preferences.historyWindowX == Double(frame.origin.x))
            #expect(preferences.historyWindowY == Double(frame.origin.y))
            #expect(preferences.historyWindowWidth == Double(frame.width))
            #expect(preferences.historyWindowHeight == Double(frame.height))
            #expect(harness.preferencesStore.load().historyWindowWidth == Double(frame.width))
        }

        @Test
        @MainActor
        func windowFrameIsNotSavedBeforeTheWindowHasBeenShown() throws {
            TestSupport.ensureAppKitInitialized()

            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            var initialPrefs = harness.model.preferences
            initialPrefs.openWindowStrategy = HistoryWindowOpenStrategy.lastLocation.rawValue
            initialPrefs.historyWindowX = 222
            initialPrefs.historyWindowY = 333
            initialPrefs.historyWindowWidth = 520
            initialPrefs.historyWindowHeight = 460
            harness.model.preferences = initialPrefs
            harness.preferencesStore.save(initialPrefs)

            let historyWindow = HistoryWindow(model: harness.model, coordinator: harness.coordinator)
            historyWindow.saveWindowFrame()
            #expect(harness.model.preferences.historyWindowX == 222)
            #expect(harness.model.preferences.historyWindowY == 333)
        }

        @MainActor
        private static func findEditableTextView(in root: NSView) -> NSTextView? {
            if let textView = root as? NSTextView, textView.isEditable {
                return textView
            }
            for subview in root.subviews {
                if let found = findEditableTextView(in: subview) {
                    return found
                }
            }
            return nil
        }

        @MainActor
        private static func collectLabels(in root: NSView) -> [HistoryFixedTextColorLabel] {
            var results: [HistoryFixedTextColorLabel] = []
            if let label = root as? HistoryFixedTextColorLabel, !label.isHidden, label.superview != nil {
                results.append(label)
            }
            for subview in root.subviews where !subview.isHidden {
                results.append(contentsOf: collectLabels(in: subview))
            }
            return results
        }
    }
}

// Saving applies appearance and language, which are process-wide.
extension SharedProcessStateTests {
    @Suite
    struct SettingsViewWiringTests {
    }
}

@MainActor
private final class ToolbarDelegateSpy: HistoryToolbarDelegate {
    var selectedTags: [(ClipBook.Tag.ID, Bool)] = []

    func historyToolbar(_ toolbar: HistoryToolbar, didChangeSearchQuery query: String) {}
    func historyToolbar(_ toolbar: HistoryToolbar, didRequestMoveSelection direction: HistorySelectionDirection) {}
    func historyToolbar(_ toolbar: HistoryToolbar, didSelectSortOption sortOption: HistorySortOption) {}
    func historyToolbar(_ toolbar: HistoryToolbar, didSetFilterContentType contentType: HistoryFilterContentType, isSelected: Bool) {}

    func historyToolbar(_ toolbar: HistoryToolbar, didSetFilterTagID tagID: ClipBook.Tag.ID, isSelected: Bool) {
        selectedTags.append((tagID, isSelected))
    }

    func historyToolbar(
        _ toolbar: HistoryToolbar,
        didSetFilterSourceApplicationID sourceApplicationID: HistorySourceApplication.ID,
        isSelected: Bool
    ) {}

    func historyToolbar(_ toolbar: HistoryToolbar, didRequestClearFilterGroup group: SearchTokenGroup) {}
    func historyToolbarDidRequestClearFilters(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestToggleSortOrder(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestPaste(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestCopy(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestCopyTextFromImage(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestCopyTextFromQRCode(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestOpenInBrowser(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestMergeSelection(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestTogglePin(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestToggleCopySequenceMode(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestTogglePreviewPane(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestToggleDetails(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestToggleImageTiles(_ toolbar: HistoryToolbar) {}
    func historyToolbarDidRequestCommandDialog(_ toolbar: HistoryToolbar) {}
}
