@testable import ClipBook
import AppKit
import Foundation
import Testing

@Suite
enum AppModelAndLocalizationTests {
    @Suite
    struct AppModelSearchAndSelectionTests {
        @Test
        @MainActor
        func caseInsensitiveSearch() {
            let model = AppModel()
            let cafeResume = ClipboardItem.fixture(
                kind: .text,
                text: "Café Latté & Résumé Notes",
                sourceAppName: "Notes",
                copiedAt: Date(timeIntervalSince1970: 300)
            )
            let cafeOnly = ClipboardItem.fixture(
                kind: .text,
                text: "Cafe Mocha Recipe",
                sourceAppName: "Notes",
                copiedAt: Date(timeIntervalSince1970: 200)
            )
            let unrelated = ClipboardItem.fixture(
                kind: .text,
                text: "Plain clipboard entry",
                sourceAppName: "Terminal",
                copiedAt: Date(timeIntervalSince1970: 100)
            )
            model.items = [cafeResume, cafeOnly, unrelated]

            model.searchQuery = "  RÉSUMÉ  "
            #expect(model.isHistorySearchActive)
            #expect(model.isHistoryNarrowed)
            #expect(model.filteredItems.map(\.id) == [cafeResume.id])

            model.searchQuery = "latté & résumé"
            #expect(model.filteredItems.map(\.id) == [cafeResume.id])

            model.searchQuery = "notes"
            #expect(model.filteredItems.map(\.id) == [cafeResume.id, cafeOnly.id])

            model.searchQuery = "   "
            #expect(!model.isHistorySearchActive)
            #expect(!model.isHistoryNarrowed)
            #expect(model.filteredItems.count == 3)
        }

        @Test
        @MainActor
        func foldedSearchCacheInvalidationOnEdit() {
            let model = AppModel()
            let sharedID = UUID()
            let original = ClipboardItem.fixture(
                id: sharedID,
                kind: .text,
                text: "Initial Alpha Keyword",
                copiedAt: Date(timeIntervalSince1970: 200)
            )
            let secondary = ClipboardItem.fixture(
                kind: .text,
                text: "Secondary Entry",
                copiedAt: Date(timeIntervalSince1970: 100)
            )
            model.items = [original, secondary]

            model.searchQuery = "alpha"
            #expect(model.filteredItems.map(\.id) == [sharedID])

            let updatedInPlace = ClipboardItem.fixture(
                id: sharedID,
                kind: .text,
                text: "Updated Omega Keyword",
                copiedAt: Date(timeIntervalSince1970: 200)
            )
            model.replace(updatedInPlace)

            #expect(model.filteredItems.isEmpty)
            model.searchQuery = "omega"
            #expect(model.filteredItems.map(\.id) == [sharedID])
        }

        @Test
        @MainActor
        func filterGroupIntersectionAndFavoritesNarrowing() {
            let model = AppModel()
            let workTag = Tag(id: 1, name: "Work", color: "#FF0000")
            let personalTag = Tag(id: 2, name: "Personal", color: "#00FF00")
            let urgentTag = Tag(id: 3, name: "Urgent", color: "#0000FF")
            model.tags = [personalTag, urgentTag, workTag]

            func item(
                _ kind: ClipboardKind,
                _ text: String?,
                app: (name: String, bundleID: String),
                at seconds: TimeInterval,
                tag: ClipBook.Tag
            ) -> ClipboardItem {
                .fixture(
                    kind: kind,
                    text: text,
                    sourceAppName: app.name,
                    sourceBundleIdentifier: app.bundleID,
                    copiedAt: Date(timeIntervalSince1970: seconds),
                    isFavorite: true,
                    tags: [tag.id]
                )
            }
            let safari = (name: "Safari", bundleID: "com.apple.Safari")
            let favLinkSafariWork = item(.link, "https://example.com/work", app: safari, at: 500, tag: workTag)
            var nonFavLinkSafariWork = item(.link, "https://example.com/nonfav", app: safari, at: 400, tag: workTag)
            nonFavLinkSafariWork.isFavorite = false
            let favTextSafariWork = item(.text, "Favorite Safari note", app: safari, at: 300, tag: workTag)
            let favImageChromeUrgent = item(
                .image, nil, app: (name: "Chrome", bundleID: "com.google.Chrome"), at: 200, tag: urgentTag
            )
            let favTextNotesPersonal = item(
                .text, "Personal note", app: (name: "Notes", bundleID: "com.apple.Notes"), at: 100, tag: personalTag
            )

            model.items = [
                favLinkSafariWork,
                nonFavLinkSafariWork,
                favTextSafariWork,
                favImageChromeUrgent,
                favTextNotesPersonal,
            ]

            model.selectedHistoryFilterContentTypes = [.favorites, .links, .images]
            #expect(model.filteredItems.map(\.id) == [favLinkSafariWork.id, favImageChromeUrgent.id])

            model.selectedHistoryFilterTagIDs = [workTag.id, personalTag.id]
            #expect(model.filteredItems.map(\.id) == [favLinkSafariWork.id])

            let chromeSourceID = HistorySourceApplication.id(forName: "Chrome")
            let safariSourceID = HistorySourceApplication.id(forName: "Safari")
            model.selectedHistoryFilterSourceApplicationIDs = [chromeSourceID]
            #expect(model.filteredItems.isEmpty)

            model.selectedHistoryFilterSourceApplicationIDs = [chromeSourceID, safariSourceID]
            #expect(model.filteredItems.map(\.id) == [favLinkSafariWork.id])

            model.clearHistoryFilters()
            #expect(!model.isHistoryFilterActive)
            #expect(model.filteredItems.count == 5)
        }
    }

    @Suite
    struct HistoryOrderingTests {
        /// Whether `lhs` sorts ahead of `rhs`, read from a two-item history whose
        /// input order puts `rhs` first, so a stable sort cannot hide the answer.
        @MainActor
        private static func ordersBefore(
            _ lhs: ClipboardItem,
            _ rhs: ClipboardItem,
            in model: AppModel
        ) -> Bool {
            model.items = [rhs, lhs]
            return model.filteredItems.first?.id == lhs.id
        }

        /// The three items sort differently by every option, so each row below pins one ordering down.
        @Test(arguments: [
            (option: HistorySortOption.lastCopyTime, reversed: false, order: ["A", "B", "C"]),
            (option: HistorySortOption.lastCopyTime, reversed: true, order: ["C", "B", "A"]),
            (option: HistorySortOption.firstCopyTime, reversed: false, order: ["B", "C", "A"]),
            (option: HistorySortOption.firstCopyTime, reversed: true, order: ["A", "C", "B"]),
            (option: HistorySortOption.numberOfCopies, reversed: false, order: ["B", "C", "A"]),
            (option: HistorySortOption.numberOfCopies, reversed: true, order: ["A", "C", "B"]),
            (option: HistorySortOption.size, reversed: false, order: ["B", "C", "A"]),
            (option: HistorySortOption.size, reversed: true, order: ["A", "C", "B"])
        ])
        @MainActor
        func sortOptionsAndReverseOrdering(option: HistorySortOption, reversed: Bool, order: [String]) {
            let model = AppModel()
            model.preferences.pinFavoritesToTop = false
            model.preferences.copySequenceModeEnabled = false

            let itemA = ClipboardItem.fixture(
                text: "A",
                copiedAt: Date(timeIntervalSince1970: 300),
                firstCopiedAt: Date(timeIntervalSince1970: 100),
                byteSize: 50,
                copyCount: 2
            )
            let itemB = ClipboardItem.fixture(
                text: "B",
                copiedAt: Date(timeIntervalSince1970: 200),
                firstCopiedAt: Date(timeIntervalSince1970: 300),
                byteSize: 500,
                copyCount: 10
            )
            let itemC = ClipboardItem.fixture(
                text: "C",
                copiedAt: Date(timeIntervalSince1970: 100),
                firstCopiedAt: Date(timeIntervalSince1970: 200),
                byteSize: 150,
                copyCount: 5
            )
            model.items = [itemC, itemA, itemB]

            model.historySortOption = option
            model.isHistorySortReversed = reversed
            #expect(model.filteredItems.compactMap(\.text) == order)
        }

        @Test
        @MainActor
        func pinFavoritesToTopAndFavoriteOrder() {
            let model = AppModel()
            var prefs = AppPreferences()
            prefs.pinFavoritesToTop = true
            prefs.copySequenceModeEnabled = false
            model.preferences = prefs
            model.historySortOption = .lastCopyTime

            let unarrangedFavNew = ClipboardItem.fixture(
                text: "Unarranged Fav New",
                copiedAt: Date(timeIntervalSince1970: 200),
                isFavorite: true,
                favoriteOrder: nil
            )
            let arrangedFavFirst = ClipboardItem.fixture(
                text: "Arranged Fav 0",
                copiedAt: Date(timeIntervalSince1970: 100),
                isFavorite: true,
                favoriteOrder: 0
            )
            let arrangedFavSecond = ClipboardItem.fixture(
                text: "Arranged Fav 1",
                copiedAt: Date(timeIntervalSince1970: 400),
                isFavorite: true,
                favoriteOrder: 1
            )
            let regularNew = ClipboardItem.fixture(
                text: "Regular New",
                copiedAt: Date(timeIntervalSince1970: 500),
                isFavorite: false
            )
            let regularOld = ClipboardItem.fixture(
                text: "Regular Old",
                copiedAt: Date(timeIntervalSince1970: 300),
                isFavorite: false
            )

            model.items = [regularOld, arrangedFavSecond, regularNew, arrangedFavFirst, unarrangedFavNew]
            model.isHistorySortReversed = false
            #expect(
                model.filteredItems.map(\.id) == [
                    unarrangedFavNew.id,
                    arrangedFavFirst.id,
                    arrangedFavSecond.id,
                    regularNew.id,
                    regularOld.id,
                ]
            )

            model.isHistorySortReversed = true
            #expect(
                model.filteredItems.map(\.id) == [
                    unarrangedFavNew.id,
                    arrangedFavFirst.id,
                    arrangedFavSecond.id,
                    regularOld.id,
                    regularNew.id,
                ]
            )
        }
    }
}

extension SharedProcessStateTests {
    @Suite
    struct LocalizationAndExtensionTests {
        @Test
        func l10nSetLanguageAndFallback() {
            defer {
                L10n.setLanguage("en")
            }

            L10n.setLanguage("de")
            #expect(L10n.languageIdentifier == "de")
            #expect(L10n.currentLocale.identifier.hasPrefix("de"))

            let untrimmedKey = "NonExistent_Localization_Key_For_Test"
            #expect(L10n.string(forKey: untrimmedKey) == untrimmedKey)
            #expect(!L10n.string("All Types").isEmpty)
            #expect(L10n.string(forKey: "Items: %d", 42).contains("42"))

            L10n.setLanguage("fr-CA")
            #expect(L10n.languageIdentifier == "en")
            #expect(L10n.currentLocale.identifier == "en")
        }

        @Test
        func workspaceApplicationLookupByName() {
            let workspace = NSWorkspace.shared

            #expect(workspace.applicationURL(named: "DefinitelyNonExistentClipBookApp_12345") == nil)

            let finderURL = workspace.applicationURL(named: "Finder")
            #expect(finderURL != nil)
            #expect(finderURL?.lastPathComponent == "Finder.app")

            let finderWithExtensionURL = workspace.applicationURL(named: "Finder.app")
            #expect(finderWithExtensionURL == finderURL)
        }
    }
}
