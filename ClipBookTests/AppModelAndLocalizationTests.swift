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

        @Test
        @MainActor
        func removeExhaustedSourceApplicationFilterSelectsFirstFilteredItem() {
            let model = AppModel()
            let safariOnlyItem = ClipboardItem.fixture(
                kind: .text,
                text: "Only Safari item",
                sourceAppName: "Safari",
                sourceBundleIdentifier: "com.apple.Safari",
                copiedAt: Date(timeIntervalSince1970: 300)
            )
            let notesFirst = ClipboardItem.fixture(
                kind: .text,
                text: "Notes item 1",
                sourceAppName: "Notes",
                sourceBundleIdentifier: "com.apple.Notes",
                copiedAt: Date(timeIntervalSince1970: 200)
            )
            let notesSecond = ClipboardItem.fixture(
                kind: .text,
                text: "Notes item 2",
                sourceAppName: "Notes",
                sourceBundleIdentifier: "com.apple.Notes",
                copiedAt: Date(timeIntervalSince1970: 100)
            )
            model.items = [safariOnlyItem, notesFirst, notesSecond]

            let safariSourceID = HistorySourceApplication.id(forName: "Safari")
            model.selectedHistoryFilterSourceApplicationIDs = [safariSourceID]
            model.selectedItemID = safariOnlyItem.id
            model.selectedItemIDs = [safariOnlyItem.id]
            model.selectedItemIDsInSelectionOrder = [safariOnlyItem.id]

            #expect(model.filteredItems.map(\.id) == [safariOnlyItem.id])

            model.remove(safariOnlyItem.id)

            #expect(model.selectedHistoryFilterSourceApplicationIDs.isEmpty)
            #expect(model.filteredItems.map(\.id) == [notesFirst.id, notesSecond.id])
            #expect(model.selectedItemID == notesFirst.id)
            #expect(model.selectedItemIDs == [notesFirst.id])
            #expect(model.selectedItemIDsInSelectionOrder == [notesFirst.id])
        }

        @Test
        @MainActor
        func removePrimarySelectedItemPreservesMultiSelection() {
            let model = AppModel()
            let first = ClipboardItem.fixture(text: "First", copiedAt: Date(timeIntervalSince1970: 300))
            let second = ClipboardItem.fixture(text: "Second", copiedAt: Date(timeIntervalSince1970: 200))
            let third = ClipboardItem.fixture(text: "Third", copiedAt: Date(timeIntervalSince1970: 100))
            model.items = [first, second, third]

            model.selectedItemID = first.id
            model.selectedItemIDs = [first.id, second.id, third.id]
            model.selectedItemIDsInSelectionOrder = [third.id, first.id, second.id]

            model.remove(first.id)

            #expect(model.selectedItemID == third.id)
            #expect(model.selectedItemIDs == [second.id, third.id])
            #expect(model.selectedItemIDsInSelectionOrder == [third.id, second.id])
            #expect(model.selectedItems.map(\.id) == [third.id, second.id])
        }

        @Test
        @MainActor
        func replaceUpdatesTrashedItemsWithoutResurrection() {
            let model = AppModel()
            let activeItem = ClipboardItem.fixture(
                kind: .text,
                text: "Active item",
                copiedAt: Date(timeIntervalSince1970: 300)
            )
            let trashedItem = ClipboardItem.fixture(
                kind: .image,
                text: nil,
                copiedAt: Date(timeIntervalSince1970: 200),
                deletedAt: Date(timeIntervalSince1970: 250)
            )
            let unloadedTrashedNotInMemory = ClipboardItem.fixture(
                kind: .link,
                text: "https://example.com",
                copiedAt: Date(timeIntervalSince1970: 100),
                deletedAt: Date(timeIntervalSince1970: 150)
            )

            model.items = [activeItem]
            model.trashedItems = [trashedItem]

            var ocrUpdatedTrashed = trashedItem
            ocrUpdatedTrashed.text = "Recognized OCR in trash"
            model.replace(ocrUpdatedTrashed)

            #expect(model.items.map(\.id) == [activeItem.id])
            #expect(model.trashedItems.count == 1)
            #expect(model.trashedItems.first?.text == "Recognized OCR in trash")

            model.replace(unloadedTrashedNotInMemory)
            #expect(model.items.map(\.id) == [activeItem.id])

            var batchUpdatedTrashed = ocrUpdatedTrashed
            batchUpdatedTrashed.title = "Trashed Image Title"
            let newFirst = ClipboardItem.fixture(text: "New First", copiedAt: Date(timeIntervalSince1970: 500))
            let newSecond = ClipboardItem.fixture(text: "New Second", copiedAt: Date(timeIntervalSince1970: 400))
            var updatedActive = activeItem
            updatedActive.title = "Updated Active"

            model.replace([batchUpdatedTrashed, unloadedTrashedNotInMemory, newFirst, newSecond, updatedActive])

            #expect(model.trashedItems.map(\.id) == [trashedItem.id])
            #expect(model.trashedItems.first?.title == "Trashed Image Title")
            #expect(model.items.map(\.id) == [newFirst.id, newSecond.id, activeItem.id])
            #expect(model.items.last?.title == "Updated Active")
        }

        @Test
        @MainActor
        func replaceInsertsANewItemOnceEvenWhenTheBatchRepeatsIt() {
            let model = AppModel()
            let existing = ClipboardItem.fixture(text: "Existing", copiedAt: Date(timeIntervalSince1970: 100))
            model.items = [existing]

            let newItem = ClipboardItem.fixture(text: "New, first version", copiedAt: Date(timeIntervalSince1970: 300))
            var newItemLater = newItem
            newItemLater.text = "New, latest version"
            let other = ClipboardItem.fixture(text: "Other", copiedAt: Date(timeIntervalSince1970: 200))

            model.replace([newItem, other, newItemLater])

            #expect(model.items.map(\.id) == [newItem.id, other.id, existing.id])
            #expect(model.items.first?.text == "New, latest version")
        }

        @Test
        @MainActor
        func replaceUpdatesAnExistingItemOnceEvenWhenTheBatchRepeatsIt() {
            let model = AppModel()
            let item = ClipboardItem.fixture(text: "Original", copiedAt: Date(timeIntervalSince1970: 200))
            let other = ClipboardItem.fixture(text: "Other", copiedAt: Date(timeIntervalSince1970: 100))
            model.items = [item, other, item]

            var firstUpdate = item
            firstUpdate.title = "First update"
            var secondUpdate = item
            secondUpdate.title = "Second update"
            model.replace([firstUpdate, secondUpdate])

            #expect(model.items.map(\.id) == [item.id, other.id])
            #expect(model.items.first?.title == "Second update")
        }

        @Test
        @MainActor
        func restoreRemovesFromTrashedItemsAndRestoresSelection() {
            let model = AppModel()
            let existingActive = ClipboardItem.fixture(
                text: "Existing Active",
                copiedAt: Date(timeIntervalSince1970: 100)
            )
            let trashedOne = ClipboardItem.fixture(
                text: "Trashed One",
                copiedAt: Date(timeIntervalSince1970: 300),
                deletedAt: Date(timeIntervalSince1970: 350)
            )
            let trashedTwo = ClipboardItem.fixture(
                text: "Trashed Two",
                copiedAt: Date(timeIntervalSince1970: 200),
                deletedAt: Date(timeIntervalSince1970: 250)
            )

            model.items = [existingActive]
            model.trashedItems = [trashedOne, trashedTwo]

            let savedSelection = HistorySelection(
                itemID: trashedOne.id,
                itemIDs: [trashedOne.id],
                itemIDsInSelectionOrder: [trashedOne.id]
            )

            model.restore([trashedOne], selection: savedSelection)

            #expect(model.trashedItems.map(\.id) == [trashedTwo.id])
            #expect(model.items.contains { $0.id == trashedOne.id && $0.deletedAt == nil })
            #expect(model.selectedItemID == trashedOne.id)
            #expect(model.selectedItemIDs == [trashedOne.id])
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

        @Test
        @MainActor
        func copySequenceOrderingPermutations() {
            let model = AppModel()
            var prefs = AppPreferences()
            prefs.pinFavoritesToTop = false
            prefs.copySequenceModeEnabled = true
            model.preferences = prefs

            let sharedGroupDate = Date(timeIntervalSince1970: 1_000)

            // The non-sequence item has the smallest id and the same copiedAt as the
            // first sequence item. Without a rule that puts sequence items ahead of
            // non-sequence items in the same group, the pairs would run in a cycle
            // (C before A by id, A before B by sequence order, B before C by time).
            let itemC = ClipboardItem.fixture(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                text: "Non-Sequence Same GroupDate",
                copiedAt: sharedGroupDate,
                copySequenceID: nil,
                copySequenceOrder: nil
            )
            let itemA = ClipboardItem.fixture(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                text: "Sequence First",
                copiedAt: sharedGroupDate,
                copySequenceID: sharedGroupDate,
                copySequenceOrder: 1
            )
            let itemB = ClipboardItem.fixture(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                text: "Sequence Second",
                copiedAt: Date(timeIntervalSince1970: 1_020),
                copySequenceID: sharedGroupDate,
                copySequenceOrder: 2
            )

            let elements = [itemA, itemB, itemC]

            #expect(Self.ordersBefore(itemA, itemB, in: model))
            #expect(Self.ordersBefore(itemB, itemC, in: model))
            #expect(Self.ordersBefore(itemA, itemC, in: model))

            for x in elements {
                for y in elements where x.id != y.id {
                    let xy = Self.ordersBefore(x, y, in: model)
                    let yx = Self.ordersBefore(y, x, in: model)
                    #expect(xy != yx)
                }
            }

            for x in elements {
                for y in elements where y.id != x.id {
                    for z in elements where z.id != y.id && z.id != x.id {
                        if Self.ordersBefore(x, y, in: model) && Self.ordersBefore(y, z, in: model) {
                            #expect(Self.ordersBefore(x, z, in: model))
                        }
                    }
                }
            }

            let permutations: [[ClipboardItem]] = [
                [itemA, itemB, itemC],
                [itemA, itemC, itemB],
                [itemB, itemA, itemC],
                [itemB, itemC, itemA],
                [itemC, itemA, itemB],
                [itemC, itemB, itemA],
            ]
            let expectedOrder = [itemA.id, itemB.id, itemC.id]
            for permutation in permutations {
                model.items = permutation
                #expect(model.filteredItems.map(\.id) == expectedOrder)
            }
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

        @Test
        func osTypeFourCharCodePaddingAndTruncation() {
            #expect(OSType("CLPB") == 0x434C_5042)
            #expect(OSType("AB") == 0x4142_2020)
            #expect(OSType("A") == 0x4120_2020)
            #expect(OSType("") == 0x2020_2020)
            #expect(OSType("CLIPBOOK") == OSType("CLIP"))
            #expect(OSType("CLIPBOOK") == 0x434C_4950)
        }
    }
}
