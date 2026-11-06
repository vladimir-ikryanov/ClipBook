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
        @MainActor
        func maskStyleRespectsHidesSensitiveContentFlag() throws {
            TestSupport.ensureAppKitInitialized()
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
            let baseFont = NSFont.systemFont(ofSize: 14, weight: .regular)
            let literalBullets = "Prefix ●●●●●●●● Suffix"
            let nsLiteral = literalBullets as NSString
            let bulletRange = nsLiteral.range(of: "●●●●●●●●")

            let unmaskedAttr = NSMutableAttributedString(
                string: literalBullets,
                attributes: [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor]
            )
            HistoryPreviewSymbolAppearance.applyMaskStyle(
                to: unmaskedAttr,
                text: literalBullets,
                font: baseFont,
                in: view,
                hidesSensitiveContent: false
            )
            let unmaskedFont = try #require(unmaskedAttr.attribute(.font, at: bulletRange.location, effectiveRange: nil) as? NSFont)
            #expect(abs(unmaskedFont.pointSize - baseFont.pointSize) < 0.01)

            let maskedAttr = NSMutableAttributedString(
                string: literalBullets,
                attributes: [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor]
            )
            HistoryPreviewSymbolAppearance.applyMaskStyle(
                to: maskedAttr,
                text: literalBullets,
                font: baseFont,
                in: view,
                hidesSensitiveContent: true
            )
            let maskedFont = try #require(maskedAttr.attribute(.font, at: bulletRange.location, effectiveRange: nil) as? NSFont)
            let expectedMaskSize = baseFont.pointSize * 0.42
            #expect(abs(maskedFont.pointSize - expectedMaskSize) < 0.01)
            let kern = maskedAttr.attribute(.kern, at: bulletRange.location, effectiveRange: nil) as? CGFloat
            #expect(kern != nil && (kern ?? 0) > 0)
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

    /// A link row decodes the pictures of a stored preview in the background. Each test uses
    /// files of its own, so the shared thumbnail loader has nothing cached for them.
    @Suite
    struct LinkRowImageLoadingTests {
        private static let pageURL = URL(string: "https://site.example/page")!

        private enum Picture: CaseIterable, Sendable {
            case favicon
            case preview
        }

        private enum Change: CaseIterable, Sendable {
            case maskedWhileLoading
            case reusedForAnotherItemWhileLoading
            case previewsTurnedOffWhileLoading
        }

        private static var screenScale: CGFloat { NSScreen.main?.backingScaleFactor ?? 2 }

        private static var faviconPixelSize: Int {
            let side = HistoryRow.typeIconSize
            return ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: CGSize(width: side, height: side), scale: screenScale)
        }

        private static var previewPixelSize: Int {
            let size = CGSize(width: HistoryRow.linkPreviewImageWidth * 2, height: HistoryRow.linkPreviewImageHeight * 2)
            return ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: size, scale: screenScale)
        }

        private static func writePNG(named name: String, width: Int, height: Int, in directory: URL) throws -> URL {
            let rep = try TestSupport.makeBitmap(pixelsWide: width, pixelsHigh: height)
            let url = directory.appendingPathComponent(name)
            try #require(rep.representation(using: .png, properties: [:])).write(to: url)
            return url
        }

        /// Returns once the row's request for `url` has delivered its result. The loader calls
        /// the requests for one picture in the order they were made, so a request made after the
        /// row's is answered after it.
        @MainActor
        private static func waitForDecode(of url: URL, maximumPixelSize: Int) async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let cached = ImageAssetThumbnailLoader.shared.thumbnail(for: url, maximumPixelSize: maximumPixelSize) { _ in
                    continuation.resume()
                }
                if cached != nil {
                    // Decoded already: the row's callback is queued on the main queue ahead of this one.
                    DispatchQueue.main.async { continuation.resume() }
                }
            }
        }

        @MainActor
        private static func toolTips(in view: NSView) -> [String] {
            ([view.toolTip].compactMap { $0 }) + view.subviews.flatMap { toolTips(in: $0) }
        }

        @MainActor
        private static func previewImageViews(in view: NSView) -> [NSImageView] {
            let own = (view as? NSImageView).map { String(describing: type(of: $0)).contains("AspectFill") ? [$0] : [] } ?? []
            return own + view.subviews.flatMap { previewImageViews(in: $0) }
        }

        @MainActor
        private static func makeRow() -> HistoryItemRowLinkView {
            HistoryItemRowLinkView(frame: NSRect(x: 0, y: 0, width: 480, height: HistoryRow.height))
        }

        @Test(.timeLimit(.minutes(1)))
        @MainActor
        func faviconIsShownOnceDecoded() async throws {
            TestSupport.ensureAppKitInitialized()
            try await TestSupport.withTemporaryDirectory { directory in
                let faviconURL = try Self.writePNG(named: "favicon.png", width: 32, height: 32, in: directory)
                let preview = LinkPreview(url: Self.pageURL, title: "Site", description: nil, image: nil, favicon: nil, faviconURL: faviconURL)
                let row = Self.makeRow()

                row.configureForTest(item: .fixture(kind: .link, text: Self.pageURL.absoluteString), linkPreview: preview, showsLinkPreview: true)
                #expect(!Self.toolTips(in: row).contains("site.example"))

                await Self.waitForDecode(of: faviconURL, maximumPixelSize: Self.faviconPixelSize)
                #expect(Self.toolTips(in: row).contains("site.example"))
            }
        }

        @Test(.timeLimit(.minutes(1)))
        @MainActor
        func previewImageIsShownOnceDecoded() async throws {
            TestSupport.ensureAppKitInitialized()
            try await TestSupport.withTemporaryDirectory { directory in
                let imageURL = try Self.writePNG(named: "preview.png", width: 96, height: 48, in: directory)
                let preview = LinkPreview(url: Self.pageURL, title: "Site", description: nil, image: nil, favicon: nil, imageURL: imageURL)
                let row = Self.makeRow()

                row.configureForTest(item: .fixture(kind: .link, text: Self.pageURL.absoluteString), linkPreview: preview, showsLinkPreview: true)
                let imageView = try #require(Self.previewImageViews(in: row).first)
                #expect(imageView.image == nil)

                await Self.waitForDecode(of: imageURL, maximumPixelSize: Self.previewPixelSize)
                #expect(imageView.image != nil)
            }
        }

        @Test(.timeLimit(.minutes(1)), arguments: Picture.allCases, Change.allCases)
        @MainActor
        private func aPictureThatArrivesAfterTheRowChangedIsNotShown(picture: Picture, change: Change) async throws {
            TestSupport.ensureAppKitInitialized()
            try await TestSupport.withTemporaryDirectory { directory in
                let pictureURL = try Self.writePNG(named: "picture.png", width: 32, height: 32, in: directory)
                let preview: LinkPreview
                let pixelSize: Int
                switch picture {
                case .favicon:
                    preview = LinkPreview(url: Self.pageURL, title: "Site", description: nil, image: nil, favicon: nil, faviconURL: pictureURL)
                    pixelSize = Self.faviconPixelSize
                case .preview:
                    preview = LinkPreview(url: Self.pageURL, title: "Site", description: nil, image: nil, favicon: nil, imageURL: pictureURL)
                    pixelSize = Self.previewPixelSize
                }
                let itemID = UUID()
                let row = Self.makeRow()

                row.configureForTest(
                    item: .fixture(id: itemID, kind: .link, text: Self.pageURL.absoluteString),
                    linkPreview: preview,
                    showsLinkPreview: true
                )
                // The picture view stays with the row when it is no longer shown.
                let previewImageView = Self.previewImageViews(in: row).first

                // A row that stays as it is. The loader answers the requests for one picture in
                // the order they were made, so once the wait below is over, this row has been
                // answered too, which shows that the wait used the same request as the rows.
                let controlRow = Self.makeRow()
                controlRow.configureForTest(
                    item: .fixture(kind: .link, text: Self.pageURL.absoluteString),
                    linkPreview: preview,
                    showsLinkPreview: true
                )
                let controlImageView = Self.previewImageViews(in: controlRow).first

                switch change {
                case .maskedWhileLoading:
                    row.configureForTest(
                        item: .fixture(id: itemID, kind: .link, text: Self.pageURL.absoluteString, sensitivity: .sensitive),
                        linkPreview: preview,
                        showsLinkPreview: true
                    )
                case .reusedForAnotherItemWhileLoading:
                    row.prepareForReuse()
                    row.configureForTest(
                        item: .fixture(kind: .link, text: "https://other.example/page"),
                        showsLinkPreview: true
                    )
                case .previewsTurnedOffWhileLoading:
                    row.configureForTest(
                        item: .fixture(id: itemID, kind: .link, text: Self.pageURL.absoluteString),
                        linkPreview: preview,
                        showsLinkPreview: false
                    )
                }

                await Self.waitForDecode(of: pictureURL, maximumPixelSize: pixelSize)
                switch picture {
                case .favicon:
                    #expect(Self.toolTips(in: controlRow).contains("site.example"), "The loader had not answered the control row")
                    #expect(!Self.toolTips(in: row).contains("site.example"))
                case .preview:
                    #expect(try #require(controlImageView).image != nil, "The loader had not answered the control row")
                    #expect(try #require(previewImageView).image == nil)
                }
            }
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

        @Test
        @MainActor
        func linkRowMasksASensitiveURLOnLineTwo() throws {
            TestSupport.ensureAppKitInitialized()
            let secretToken = ["sk", "-", String(repeating: "aB3dE5fG", count: 4)].joined()
            let secretURLString = "https://api.example.com/v1/auth?token=\(secretToken)"
            let item = ClipboardItem.fixture(
                kind: .link,
                title: "Production Webhook",
                text: secretURLString,
                sensitivity: .sensitive
            )
            let preview = LinkPreview(
                url: try #require(URL(string: secretURLString)),
                title: "Webhook Dashboard",
                description: "Internal portal",
                image: NSImage(size: NSSize(width: 80, height: 40)),
                favicon: NSImage(size: NSSize(width: 16, height: 16))
            )

            let row = HistoryItemRowLinkView(frame: Self.rowFrame)
            row.configureForTest(item: item, linkPreview: preview, showsLinkPreview: true)

            let labels = Self.labels(of: row)
            #expect(labels.contains { $0.text == "Production Webhook" })
            #expect(!labels.contains { $0.text.contains(secretToken) })
            #expect(labels.contains { $0.text.contains(SensitiveContent.inlineMask) })
        }

        @Test
        @MainActor
        func reusedLinkRowShowsLiteralBulletsAsTheyAre() throws {
            TestSupport.ensureAppKitInitialized()
            let sensitiveItem = ClipboardItem.fixture(
                kind: .link,
                title: "Production Webhook",
                text: "https://api.example.com/v1/auth?token=sk-secret-token-value",
                sensitivity: .sensitive
            )
            let bulletItem = ClipboardItem.fixture(
                kind: .link,
                title: "Bullet Doc",
                text: "https://example.com/●●●●●●●●",
                sensitivity: .notSensitive
            )

            let row = HistoryItemRowLinkView(frame: Self.rowFrame)
            row.configureForTest(item: sensitiveItem, showsLinkPreview: true)
            row.prepareForReuse()
            row.configureForTest(item: bulletItem, quickPasteIndex: 2, showsLinkPreview: true)

            let secondLineLabel = try #require(Self.labels(of: row).first { $0.text.contains("●●●●●●●●") })
            #expect(!secondLineLabel.hidesSensitiveContent)
        }

        @Test
        @MainActor
        func emailRowMasksASensitiveAddress() {
            TestSupport.ensureAppKitInitialized()
            let item = ClipboardItem.fixture(
                kind: .email,
                title: "Root Contact",
                text: "security-admin@example.com",
                sensitivity: .sensitive
            )

            let row = HistoryItemRowEmailView(frame: Self.rowFrame)
            row.configureForTest(item: item)

            let labels = Self.labels(of: row)
            #expect(labels.contains { $0.text == "Root Contact" })
            #expect(!labels.contains { $0.text.contains("security-admin@example.com") })
            #expect(labels.contains { $0.text.contains(SensitiveContent.inlineMask) })
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

        @Test
        @MainActor
        func historyToolbarSuggestionSelectionAndRanking() throws {
            TestSupport.ensureAppKitInitialized()
            let tagPrefix = ClipBook.Tag(id: 1, name: "SwiftUI", color: "#3B84ED")
            let tagInfix = ClipBook.Tag(id: 2, name: "RxSwift", color: "#E03E3E")
            let sourceApp = HistorySourceApplication(name: "Swift Playgrounds", bundleIdentifier: "com.apple.Playgrounds")

            let suggestions = SearchSuggestionProvider.suggestions(
                for: "swift",
                tags: [tagInfix, tagPrefix],
                sourceApplications: [sourceApp],
                activeKinds: []
            )
            #expect(suggestions.count == 3)
            #expect(suggestions[0].token.kind == .sourceApplication(sourceApp.id))
            #expect(suggestions[1].token.kind == .tag(tagPrefix.id))
            #expect(suggestions[2].token.kind == .tag(tagInfix.id))

            let (toolbar, delegate, _) = try Self.makeSearchToolbar()
            let onSelect = try #require(toolbar.suggestionsPopup.onSelect)
            onSelect(suggestions[1])
            #expect(delegate.selectedTags.map(\.0) == [tagPrefix.id])
            #expect(delegate.selectedTags.map(\.1) == [true])
            #expect(toolbar.searchField.tokens.contains { $0.kind == .tag(tagPrefix.id) })
        }

        @Test
        @MainActor
        func searchTokenFieldChipNavigation() throws {
            TestSupport.ensureAppKitInitialized()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            defer { window.orderOut(nil) }

            let (toolbar, _, searchView) = try Self.makeSearchToolbar()
            searchView.frame = NSRect(x: 0, y: 0, width: 360, height: 52)
            window.contentView?.addSubview(searchView)

            let field = toolbar.searchField
            field.setTokens([
                SearchToken(kind: .contentType(.links), title: "Link", image: nil),
                SearchToken(kind: .contentType(.images), title: "Image", image: nil)
            ])
            field.text = ""
            field.layoutSubtreeIfNeeded()

            #expect(field.control(NSControl(), textView: NSTextView(), doCommandBy: #selector(NSResponder.moveLeft(_:))))
            #expect(field.selectedChipIndex == 1)

            // Left arrow (keyCode 123) selects chip 0.
            field.keyDown(with: try TestSupport.keyDownEvent(keyCode: 123, windowNumber: window.windowNumber))
            #expect(field.selectedChipIndex == 0)

            // Right arrow (keyCode 124) moves from chip 0 to chip 1, then back to the text field.
            let rightArrow = try TestSupport.keyDownEvent(keyCode: 124, windowNumber: window.windowNumber)
            field.keyDown(with: rightArrow)
            #expect(field.selectedChipIndex == 1)

            field.keyDown(with: rightArrow)
            #expect(field.selectedChipIndex == nil)
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
        func itemPreviewDialogSavesEditedText() throws {
            TestSupport.ensureAppKitInitialized()

            let item = ClipboardItem.fixture(kind: .richText, text: "Bold Text", html: "<b>Bold Text</b>")
            var saved: [(ClipboardItem, String)] = []
            let controller = ItemPreviewDialogController(
                item: item,
                maximumContentSize: NSSize(width: 800, height: 600),
                detectsSensitiveContent: true,
                revealsSensitiveContent: false,
                loadFormatting: { $0 }
            )
            controller.onSave = { saved.append(($0, $1)) }
            _ = controller.view

            // Saving without a change saves nothing and keeps the formatting.
            controller.beginEditing()
            #expect(controller.isEditing)
            controller.saveEditing()
            #expect(!controller.isEditing)
            #expect(saved.isEmpty)
            #expect(controller.item.html == "<b>Bold Text</b>")

            // Restoring the original text leaves nothing to save either.
            controller.beginEditing()
            let textView = try #require(Self.findEditableTextView(in: controller.view))
            #expect(textView.string == "Bold Text")
            textView.string = "Changed"
            controller.restoreEditingText()
            #expect(textView.string == "Bold Text")
            controller.saveEditing()
            #expect(saved.isEmpty)

            // A real edit is saved exactly once, with the new text.
            controller.beginEditing()
            let editor = try #require(Self.findEditableTextView(in: controller.view))
            editor.string = "Edited text"
            controller.saveEditing()
            #expect(!controller.isEditing)
            #expect(saved.count == 1)
            #expect(saved.first?.0.id == item.id)
            #expect(saved.first?.1 == "Edited text")
        }

        @Test
        @MainActor
        func commandPaletteRunsCommandShortcuts() async throws {
            TestSupport.ensureAppKitInitialized()

            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            let item = ClipboardItem.fixture(kind: .text, text: "Editable clip")
            try harness.seedHistory([item])

            let historyWindow = HistoryWindow(model: harness.model, coordinator: harness.coordinator)
            historyWindow.window.alphaValue = 0
            historyWindow.show()
            defer {
                if let sheet = historyWindow.window.attachedSheet {
                    historyWindow.window.endSheet(sheet)
                }
                historyWindow.window.orderOut(nil)
            }

            // ⌘K opens the command palette sheet.
            historyWindow.window.sendEvent(try TestSupport.keyDownEvent(keyCode: 40, modifiers: [.command]))
            let paletteSheet = try #require(historyWindow.window.attachedSheet as? CommandPaletteSheetWindow)

            // Space is a plain key for typing in the search field, not a command shortcut.
            #expect(!paletteSheet.performKeyEquivalent(with: try TestSupport.keyDownEvent(keyCode: 49)))
            #expect(historyWindow.window.attachedSheet === paletteSheet)

            // ⌘S runs Add to Favorites and closes the command palette.
            #expect(paletteSheet.performKeyEquivalent(with: try TestSupport.keyDownEvent(keyCode: 1, modifiers: [.command])))
            #expect(harness.currentItem(item.id)?.isFavorite == true)
            #expect(historyWindow.window.attachedSheet == nil)

            // ⌘K then ⌘E closes the command palette and opens the preview editor sheet.
            historyWindow.window.sendEvent(try TestSupport.keyDownEvent(keyCode: 40, modifiers: [.command]))
            let editPaletteSheet = try #require(historyWindow.window.attachedSheet as? CommandPaletteSheetWindow)
            #expect(editPaletteSheet.performKeyEquivalent(with: try TestSupport.keyDownEvent(keyCode: 14, modifiers: [.command])))
            let editorOpened = await TestSupport.waitUntil(timeout: .seconds(5)) {
                guard let sheet = historyWindow.window.attachedSheet,
                      !(sheet is CommandPaletteSheetWindow),
                      let contentView = sheet.contentView else {
                    return false
                }
                return Self.findEditableTextView(in: contentView) != nil
            }
            #expect(editorOpened)
            if let editSheet = historyWindow.window.attachedSheet {
                historyWindow.window.endSheet(editSheet)
            }

            // ⌘K then ⌘R closes the command palette and opens the Rename sheet.
            historyWindow.window.sendEvent(try TestSupport.keyDownEvent(keyCode: 40, modifiers: [.command]))
            let renamePaletteSheet = try #require(historyWindow.window.attachedSheet as? CommandPaletteSheetWindow)
            #expect(renamePaletteSheet.performKeyEquivalent(with: try TestSupport.keyDownEvent(keyCode: 15, modifiers: [.command])))
            let renameOpened = await TestSupport.waitUntil(timeout: .seconds(5)) {
                guard let sheet = historyWindow.window.attachedSheet,
                      !(sheet is CommandPaletteSheetWindow) else {
                    return false
                }
                return true
            }
            #expect(renameOpened)
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
