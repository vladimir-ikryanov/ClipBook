import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

enum HistorySortOption: String, CaseIterable, Equatable {
    case lastCopyTime = "Last Copy Time"
    case firstCopyTime = "First Copy Time"
    case numberOfCopies = "Number of Copies"
    case size = "Size"

    var title: String {
        switch self {
        case .lastCopyTime: L10n.string("Last Copy Time")
        case .firstCopyTime: L10n.string("First Copy Time")
        case .numberOfCopies: L10n.string("Number of Copies")
        case .size: L10n.string("Size")
        }
    }

    init(preferenceValue: String) {
        self = Self(rawValue: preferenceValue) ?? .lastCopyTime
    }
}

enum HistoryFilterContentType: String, CaseIterable, Equatable, Identifiable {
    case all
    case favorites
    case text
    case images
    case files
    case links
    case emails
    case colors
    case trash

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all: L10n.string("All Types")
        case .favorites: L10n.string("Favorites")
        case .text: L10n.string("Text")
        case .images: L10n.string("Images")
        case .files: L10n.string("Files")
        case .links: L10n.string("Links")
        case .emails: L10n.string("Emails")
        case .colors: L10n.string("Colors")
        case .trash: L10n.string("Trash")
        }
    }

    /// `true` for the entries that narrow the history to a kind of item. `all`
    /// only clears the group, `favorites` is applied on top of the kinds, and
    /// `trash` lists the deleted items instead of the history.
    var isKindFilter: Bool {
        self != .all && self != .favorites && self != .trash
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .favorites:
            return item.isFavorite
        case .text:
            return item.kind == .text || item.kind == .richText
        case .images:
            return item.kind == .image || item.isImageFileItem
        case .files:
            return item.kind == .file
        case .links:
            return item.kind == .link
        case .emails:
            return item.kind == .email
        case .colors:
            return item.kind == .color
        case .trash:
            return item.deletedAt != nil
        }
    }
}

struct HistorySourceApplication: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?

    init(name: String, bundleIdentifier: String?) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? name
        self.bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        id = Self.id(forName: self.name)
    }

    static func id(forName name: String) -> String {
        "name:\(normalizedName(for: name))"
    }

    private static func normalizedName(for name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var resolvedApplicationURL: URL? {
        if let bundleIdentifier,
           let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return applicationURL
        }

        return NSWorkspace.shared.applicationURL(named: name)
    }

    var hasResolvableApplication: Bool {
        resolvedApplicationURL != nil
    }
}

/// The selection of the history at one moment, kept to bring it back later.
struct HistorySelection {
    let itemID: ClipboardItem.ID?
    let itemIDs: Set<ClipboardItem.ID>
    let itemIDsInSelectionOrder: [ClipboardItem.ID]
}

@MainActor
final class AppModel: ObservableObject {
    // Everything `filteredItems` depends on drops the list it keeps, so the
    // next read builds it again.
    @Published var items: [ClipboardItem] = [] {
        didSet {
            invalidateFilteredItems()
            cachedHistorySourceApplications = nil
        }
    }
    /// The items in the Trash. They are read from the store while the Trash
    /// is shown and let go once it is not, so the Trash costs no memory while
    /// the history is used as usual.
    @Published var trashedItems: [ClipboardItem] = [] {
        didSet {
            invalidateFilteredItems()
            cachedHistorySourceApplications = nil
        }
    }
    @Published var tags: [Tag] = []
    @Published var selectedItemID: ClipboardItem.ID?
    @Published var selectedItemIDs: Set<ClipboardItem.ID> = []
    @Published var selectedItemIDsInSelectionOrder: [ClipboardItem.ID] = []
    @Published var searchQuery = "" {
        didSet { invalidateFilteredItems() }
    }
    @Published var preferences = AppPreferences() {
        didSet {
            if oldValue.pinFavoritesToTop != preferences.pinFavoritesToTop
                || oldValue.copySequenceModeEnabled != preferences.copySequenceModeEnabled {
                invalidateFilteredItems()
            }
        }
    }
    @Published var historySortOption: HistorySortOption = .lastCopyTime {
        didSet { invalidateFilteredItems() }
    }
    @Published var isHistorySortReversed = false {
        didSet { invalidateFilteredItems() }
    }
    /// Filters combine as an intersection across the groups and a union inside
    /// each group: an item is shown when it matches at least one selected
    /// content type, one selected tag and one selected source app. An empty
    /// group is not applied. `favorites` narrows the kinds further instead of
    /// widening them, because a user picking "Favorites" and "Images" expects
    /// favorite images rather than everything favorite plus every image.
    @Published var selectedHistoryFilterContentTypes: Set<HistoryFilterContentType> = [] {
        didSet {
            invalidateFilteredItems()
            if oldValue.contains(.trash) != selectedHistoryFilterContentTypes.contains(.trash) {
                cachedHistorySourceApplications = nil
            }
        }
    }
    @Published var selectedHistoryFilterTagIDs: Set<Tag.ID> = [] {
        didSet { invalidateFilteredItems() }
    }
    @Published var selectedHistoryFilterSourceApplicationIDs: Set<HistorySourceApplication.ID> = [] {
        didSet { invalidateFilteredItems() }
    }
    @Published var isPaused = false
    @Published var lastError: String?
    // The search and the list of source applications compare text the way the
    // app language does.
    @Published var localizationRevision = UUID() {
        didSet {
            invalidateFilteredItems()
            cachedHistorySourceApplications = nil
        }
    }

    // The history as the list shows it. Showing the history, moving the
    // selection and updating the toolbar each read it several times, and
    // filtering and sorting thousands of items every time kept the main
    // thread busy for hundreds of milliseconds whenever the history appeared.
    private var cachedFilteredItems: [ClipboardItem]?

    private func invalidateFilteredItems() {
        cachedFilteredItems = nil
    }

    var filteredItems: [ClipboardItem] {
        if let cachedFilteredItems {
            return cachedFilteredItems
        }

        let result = makeFilteredItems()
        cachedFilteredItems = result
        return result
    }

    /// Whether the list shows the Trash instead of the history.
    var isShowingTrash: Bool {
        selectedHistoryFilterContentTypes.contains(.trash)
    }

    /// The items the list is made of: the Trash while it is shown, otherwise
    /// the history.
    private var listedItems: [ClipboardItem] {
        isShowingTrash ? trashedItems : items
    }

    /// The history as the list would show it with the same filters, the
    /// Trash aside. Pasting the next item takes from it, so it never pastes
    /// a deleted item while the Trash happens to be shown.
    var filteredHistoryItems: [ClipboardItem] {
        guard isShowingTrash else {
            return filteredItems
        }

        var contentTypes = selectedHistoryFilterContentTypes
        contentTypes.remove(.trash)
        return makeFilteredItems(from: items, contentTypes: contentTypes, order: historyOrder)
    }

    private func makeFilteredItems() -> [ClipboardItem] {
        if isShowingTrash {
            return makeFilteredItems(from: trashedItems, contentTypes: selectedHistoryFilterContentTypes, order: nil)
        }

        return makeFilteredItems(from: items, contentTypes: selectedHistoryFilterContentTypes, order: historyOrder)
    }

    /// Without an order the items are sorted the way the Trash lists them,
    /// the most recently deleted first.
    private func makeFilteredItems(
        from items: [ClipboardItem],
        contentTypes: Set<HistoryFilterContentType>,
        order: HistoryOrder?
    ) -> [ClipboardItem] {
        var result = items

        if !contentTypes.isEmpty {
            result = result.filter { Self.contentTypes(contentTypes, match: $0) }
        }

        let tagIDs = selectedHistoryFilterTagIDs
        if !tagIDs.isEmpty {
            result = result.filter { item in item.tags.contains { tagIDs.contains($0) } }
        }

        let sourceApplicationIDs = selectedHistoryFilterSourceApplicationIDs
        if !sourceApplicationIDs.isEmpty {
            result = result.filter { item in
                guard let sourceApplicationID = Self.sourceApplicationID(for: item) else {
                    return false
                }

                return sourceApplicationIDs.contains(sourceApplicationID)
            }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { $0.searchText.localizedCaseInsensitiveContains(query) }
        }

        if let order {
            result.sort(by: order.ordersBefore(_:_:))
        } else {
            result.sort(by: Self.trashOrdersBefore(_:_:))
        }

        return result
    }

    private static func trashOrdersBefore(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        let lhsDeletedAt = lhs.deletedAt ?? .distantPast
        let rhsDeletedAt = rhs.deletedAt ?? .distantPast
        if lhsDeletedAt != rhsDeletedAt {
            return lhsDeletedAt > rhsDeletedAt
        }
        if lhs.copiedAt != rhs.copiedAt {
            return lhs.copiedAt > rhs.copiedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Every favorite in the order the pinned favorites section lists them,
    /// with no filter or search applied.
    var favoritesInDisplayOrder: [ClipboardItem] {
        let order = historyOrder
        return items.filter(\.isFavorite).sorted(by: order.ordersBefore(_:_:))
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else {
            return filteredItems.first
        }
        return listedItems.first { $0.id == selectedItemID }
    }

    var selectedItems: [ClipboardItem] {
        let ids = selectedItemIDs

        guard !ids.isEmpty else {
            return selectedItem.map { [$0] } ?? []
        }

        // Only the selected items are looked up. The toolbar asks for them on
        // every change, and indexing the whole history each time copied every
        // item in it.
        let orderedIDs = selectedItemIDsInSelectionOrder.filter { ids.contains($0) }
        if !orderedIDs.isEmpty {
            let wantedIDs = Set(orderedIDs)
            var itemsByID: [ClipboardItem.ID: ClipboardItem] = [:]
            for item in listedItems where wantedIDs.contains(item.id) && itemsByID[item.id] == nil {
                itemsByID[item.id] = item
            }
            let selectedItemsInOrder = orderedIDs.compactMap { itemsByID[$0] }
            if !selectedItemsInOrder.isEmpty {
                return selectedItemsInOrder
            }
        }

        return filteredItems.filter { ids.contains($0.id) }
    }

    var isHistoryFilterActive: Bool {
        !selectedHistoryFilterContentTypes.isEmpty
            || !selectedHistoryFilterTagIDs.isEmpty
            || !selectedHistoryFilterSourceApplicationIDs.isEmpty
    }

    var isHistorySearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `true` when the list shows a subset of the history, either because a
    /// filter group is selected or because the search query narrows it. Both
    /// live in the same search field, so actions that act on "everything"
    /// act on the visible items instead.
    var isHistoryNarrowed: Bool {
        isHistoryFilterActive || isHistorySearchActive
    }

    func clearHistoryFilters() {
        selectedHistoryFilterContentTypes = []
        selectedHistoryFilterTagIDs = []
        selectedHistoryFilterSourceApplicationIDs = []
    }

    static func contentTypes(_ contentTypes: Set<HistoryFilterContentType>, match item: ClipboardItem) -> Bool {
        if contentTypes.contains(.favorites), !item.isFavorite {
            return false
        }

        let kinds = contentTypes.filter(\.isKindFilter)
        return kinds.isEmpty || kinds.contains { $0.matches(item) }
    }

    var availableTags: [Tag] {
        tags
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // The applications the items came from, kept until the items change. The
    // history reads them on every reload to fill its filters, and finding them
    // goes through every item.
    private var cachedHistorySourceApplications: [HistorySourceApplication]?

    var availableHistorySourceApplications: [HistorySourceApplication] {
        if let cachedHistorySourceApplications {
            return cachedHistorySourceApplications
        }

        let applications = makeAvailableHistorySourceApplications()
        cachedHistorySourceApplications = applications
        return applications
    }

    private func makeAvailableHistorySourceApplications() -> [HistorySourceApplication] {
        // A history holds thousands of items copied from a handful of
        // applications, and telling which of two candidates is installed asks
        // Launch Services and the file system. Every application is therefore
        // considered once, however many items came from it.
        var seenSources = Set<SourceApplicationKey>()
        let applications = listedItems.compactMap { item -> HistorySourceApplication? in
            guard let sourceAppName = item.sourceAppName,
                  seenSources.insert(SourceApplicationKey(name: sourceAppName, bundleIdentifier: item.sourceBundleIdentifier)).inserted,
                  let name = sourceAppName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
                return nil
            }

            return HistorySourceApplication(name: name, bundleIdentifier: item.sourceBundleIdentifier)
        }
        let applicationsByID = applications.reduce(into: [HistorySourceApplication.ID: HistorySourceApplication]()) { result, application in
            guard let existingApplication = result[application.id] else {
                result[application.id] = application
                return
            }

            result[application.id] = Self.preferredSourceApplication(existingApplication, application)
        }
        return applicationsByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func tagNames(for tagIDs: [Int]) -> [String] {
        let tagsByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        return tagIDs.compactMap { tagsByID[$0] }
    }

    func insert(_ item: ClipboardItem) {
        // The list is published once, so the history reloads once per item.
        // Its items never hold their formatting; the store reads it when needed.
        let item = item.unloadingFormatting()
        var updatedItems = items
        updatedItems.removeAll { $0.id == item.id || $0.hasSameContent(as: item) }
        updatedItems.insert(item, at: 0)
        items = updatedItems
        clearUnavailableHistorySourceApplicationFilter()
        selectedItemID = item.id
        selectedItemIDs = [item.id]
        selectedItemIDsInSelectionOrder = [item.id]
    }

    func remove(_ id: ClipboardItem.ID) {
        remove(Set([id]))
    }

    func remove(_ ids: Set<ClipboardItem.ID>) {
        guard !ids.isEmpty else {
            return
        }

        let visibleItems = filteredItems
        let selectedVisibleIndex = selectedItemID.flatMap { selectedItemID in
            visibleItems.firstIndex { $0.id == selectedItemID }
        }
        items.removeAll { ids.contains($0.id) }
        if trashedItems.contains(where: { ids.contains($0.id) }) {
            trashedItems.removeAll { ids.contains($0.id) }
        }
        clearUnavailableHistorySourceApplicationFilter()
        selectedItemIDs.subtract(ids)
        selectedItemIDsInSelectionOrder.removeAll { ids.contains($0) }
        if selectedItemID.map(ids.contains) == true {
            let nextSelectedItem = selectedVisibleIndex.flatMap { visibleIndex in
                visibleItems[(visibleIndex + 1)...].first { !ids.contains($0.id) }
                    ?? visibleItems[..<visibleIndex].last { !ids.contains($0.id) }
            }

            if selectedVisibleIndex != nil {
                selectedItemID = nextSelectedItem?.id
            } else {
                selectedItemID = filteredItems.first?.id
            }
            selectedItemIDs = selectedItemID.map { [$0] } ?? []
            selectedItemIDsInSelectionOrder = selectedItemID.map { [$0] } ?? []
        }
    }

    /// Adds items moved to the Trash to the list of the Trash, if it is shown.
    func insertIntoTrash(_ trashedItems: [ClipboardItem]) {
        guard isShowingTrash, !trashedItems.isEmpty else {
            return
        }

        let ids = Set(trashedItems.map(\.id))
        self.trashedItems = trashedItems.map { $0.unloadingFormatting() }
            + self.trashedItems.filter { !ids.contains($0.id) }
    }

    var selection: HistorySelection {
        HistorySelection(
            itemID: selectedItemID,
            itemIDs: selectedItemIDs,
            itemIDsInSelectionOrder: selectedItemIDsInSelectionOrder
        )
    }

    /// Puts items taken out of the Trash back in the history. Unless the Trash
    /// is shown, where they are gone from, the selection goes back to what it
    /// was when they were deleted, or else moves to them.
    func restore(_ restoredItems: [ClipboardItem], selection: HistorySelection? = nil) {
        guard !restoredItems.isEmpty else {
            return
        }

        let ids = Set(restoredItems.map(\.id))
        let restoredItems = restoredItems.map { item -> ClipboardItem in
            var item = item.unloadingFormatting()
            item.deletedAt = nil
            return item
        }
        items = restoredItems + items.filter { !ids.contains($0.id) }
        clearUnavailableHistorySourceApplicationFilter()
        guard !isShowingTrash else {
            return
        }

        let visibleItemIDs = Set(filteredItems.map(\.id))
        if let selection,
           let itemID = selection.itemID ?? selection.itemIDsInSelectionOrder.first,
           visibleItemIDs.contains(itemID) {
            selectedItemID = itemID
            selectedItemIDs = selection.itemIDs.intersection(visibleItemIDs)
            selectedItemIDsInSelectionOrder = selection.itemIDsInSelectionOrder.filter { visibleItemIDs.contains($0) }
            return
        }

        let visibleRestoredItems = filteredItems.filter { ids.contains($0.id) }
        guard let firstItem = visibleRestoredItems.first else {
            return
        }

        selectedItemID = firstItem.id
        selectedItemIDs = Set(visibleRestoredItems.map(\.id))
        selectedItemIDsInSelectionOrder = visibleRestoredItems.map(\.id)
    }

    func replace(_ item: ClipboardItem) {
        let item = item.unloadingFormatting()
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            insert(item)
            return
        }
        items[index] = item
        items = items.enumerated().compactMap { offset, currentItem in
            currentItem.id == item.id && offset != index ? nil : currentItem
        }
        clearUnavailableHistorySourceApplicationFilter()
    }

    func replace(_ updatedItems: [ClipboardItem]) {
        guard !updatedItems.isEmpty else {
            return
        }

        var replacementsByID = Dictionary(
            updatedItems.map { ($0.id, $0.unloadingFormatting()) },
            uniquingKeysWith: { _, latest in latest }
        )
        var replacedIDs = Set<ClipboardItem.ID>()
        let replacedItems = items.compactMap { currentItem -> ClipboardItem? in
            guard let replacement = replacementsByID[currentItem.id] else {
                return currentItem
            }

            guard !replacedIDs.contains(replacement.id) else {
                return nil
            }

            replacedIDs.insert(replacement.id)
            replacementsByID[replacement.id] = nil
            return replacement
        }

        let insertedItems = updatedItems.filter { !replacedIDs.contains($0.id) }.map { $0.unloadingFormatting() }
        items = Array(insertedItems.reversed()) + replacedItems
        clearUnavailableHistorySourceApplicationFilter()
    }

    func incrementCopyCount(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].copyCount += 1
    }

    private func clearUnavailableHistorySourceApplicationFilter() {
        guard !selectedHistoryFilterSourceApplicationIDs.isEmpty else {
            return
        }

        let availableIDs = Set(availableHistorySourceApplications.map(\.id))
        let selectedIDs = selectedHistoryFilterSourceApplicationIDs.intersection(availableIDs)
        guard selectedIDs != selectedHistoryFilterSourceApplicationIDs else {
            return
        }

        selectedHistoryFilterSourceApplicationIDs = selectedIDs
    }

    private var historyOrder: HistoryOrder {
        HistoryOrder(
            pinsFavoritesToTop: preferences.pinFavoritesToTop,
            isCopySequenceModeEnabled: preferences.copySequenceModeEnabled,
            sortOption: historySortOption,
            isSortReversed: isHistorySortReversed
        )
    }

    private static func sourceApplicationID(for item: ClipboardItem) -> HistorySourceApplication.ID? {
        guard let name = item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }

        return HistorySourceApplication.id(forName: name)
    }

    private static func preferredSourceApplication(
        _ lhs: HistorySourceApplication,
        _ rhs: HistorySourceApplication
    ) -> HistorySourceApplication {
        if rhs.hasResolvableApplication && !lhs.hasResolvableApplication {
            return rhs
        }

        return lhs
    }
}

/// The settings the history is sorted by, taken once for a whole sort. Reading
/// them from the model copies all of the preferences, and sorting a history of
/// a few thousand items compares them tens of thousands of times.
private struct HistoryOrder {
    let pinsFavoritesToTop: Bool
    let isCopySequenceModeEnabled: Bool
    let sortOption: HistorySortOption
    let isSortReversed: Bool

    func ordersBefore(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if pinsFavoritesToTop {
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }

            if lhs.isFavorite, let isOrderedBefore = Self.favoriteOrderOrdersBefore(lhs, rhs) {
                return isOrderedBefore
            }
        }

        // Copy sequence mode defines its own order, so the reverse flag does not apply to it.
        let isReversed = isCopySequenceModeEnabled ? false : isSortReversed
        switch sortComparison(lhs, rhs) {
        case .orderedAscending:
            return isReversed
        case .orderedDescending:
            return !isReversed
        case .orderedSame:
            return Self.tieBreakerOrdersBefore(lhs, rhs)
        }
    }

    /// Arranged favorites keep the order the user gave them, and the sort
    /// option and its reverse flag leave that order alone. A favorite that
    /// was never arranged stays above the arranged ones and follows the
    /// history's own sort, so a freshly added favorite shows up at the top
    /// the way it always has. Nil means the history's own sort decides.
    private static func favoriteOrderOrdersBefore(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool? {
        switch (lhs.favoriteOrder, rhs.favoriteOrder) {
        case (nil, nil):
            return nil
        case (nil, _):
            return true
        case (_, nil):
            return false
        case (let lhsOrder?, let rhsOrder?):
            return lhsOrder == rhsOrder ? nil : lhsOrder < rhsOrder
        }
    }

    private func sortComparison(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> ComparisonResult {
        guard !isCopySequenceModeEnabled else {
            return Self.copySequenceComparison(lhs, rhs)
        }

        switch sortOption {
        case .lastCopyTime:
            return lhs.copiedAt.compare(rhs.copiedAt)
        case .firstCopyTime:
            return lhs.firstCopiedAt.compare(rhs.firstCopiedAt)
        case .numberOfCopies:
            return Self.compare(lhs.copyCount, rhs.copyCount)
        case .size:
            return Self.compare(lhs.byteSize, rhs.byteSize)
        }
    }

    private static func copySequenceComparison(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> ComparisonResult {
        let lhsGroupDate = lhs.copySequenceID ?? lhs.copiedAt
        let rhsGroupDate = rhs.copySequenceID ?? rhs.copiedAt

        let groupComparison = lhsGroupDate.compare(rhsGroupDate)
        guard groupComparison == .orderedSame else {
            return groupComparison
        }

        if lhs.copySequenceID != nil,
           lhs.copySequenceID == rhs.copySequenceID {
            return compare(rhs.copySequenceOrder ?? 0, lhs.copySequenceOrder ?? 0)
        }

        return lhs.copiedAt.compare(rhs.copiedAt)
    }

    private static func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }

        if lhs > rhs {
            return .orderedDescending
        }

        return .orderedSame
    }

    private static func tieBreakerOrdersBefore(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if lhs.copiedAt != rhs.copiedAt {
            return lhs.copiedAt > rhs.copiedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

/// A source application exactly as the items name it.
private struct SourceApplicationKey: Hashable {
    let name: String
    let bundleIdentifier: String?
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
