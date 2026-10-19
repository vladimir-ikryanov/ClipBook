import AppKit

@MainActor
protocol HistoryDelegate: AnyObject {
  func listPane(_ pane: History, didSelectItems items: [ClipboardItem], focusedItem: ClipboardItem?)
  func listPane(_ pane: History, didClickItem item: ClipboardItem)
  func listPane(_ pane: History, didDoubleClickItem item: ClipboardItem)
  func listPane(_ pane: History, didReceiveSearchKeyDown event: NSEvent)
  func listPane(_ pane: History, actionsMenuFor selectedItems: [ClipboardItem], focusedItem: ClipboardItem?) -> NSMenu
  func listPane(_ pane: History, shouldLoadLinkPreviewFor item: ClipboardItem)
  func listPane(_ pane: History, didChangeMultipleSelectionWith change: HistoryMultipleSelectionChange)
  /// The user dropped pinned favorites, listed in their current order, right
  /// before the favorite `targetItemID` names, or at the end when it is nil.
  func listPane(_ pane: History, moveFavorites itemIDs: [UUID], before targetItemID: UUID?)
  /// The user clicked the eye of an item whose content is hidden or shown for now.
  func listPane(_ pane: History, didRequestTogglingSensitiveContentVisibilityOf item: ClipboardItem)
}

enum HistoryMultipleSelectionChange {
  case added
  case removed
}

private enum HistoryTableRowIdentity: Equatable {
  case sectionHeader(String)
  case item(UUID)
}

enum HistoryKeyboardMultipleSelectionCommand {
  case addCurrent
  case removeCurrent
}

@MainActor
final class History: NSView {
  weak var delegate: HistoryDelegate?
  var filePreviewCache: FilePreviewCache?
  /// Reads the formatting of a rich text item, which the history's items come
  /// without, for dragging it out with its formatting.
  var loadFormatting: ((ClipboardItem) -> ClipboardItem)?

  var items: [ClipboardItem] = []
  var availableTags: [Tag] = [] {
    didSet {
      availableTagsByID = Dictionary(uniqueKeysWithValues: availableTags.map { ($0.id, $0) })
    }
  }
  private(set) var availableTagsByID: [Int: Tag] = [:]
  var searchQuery = ""
  private(set) var tableRows: [HistoryTableRow] = []
  private var groupsPinnedFavorites = false
  var showCommandNumberShortcut = true
  var showPreviewForLinks = true
  var detectsSensitiveContent = true
  // The items whose hidden content the user asked to see. It is never stored, and is
  // forgotten when the history window goes away.
  private var sensitiveContentRevealedItemIDs: Set<UUID> = []
  var showsDividers = false
  var preferDraggingAsPlainText = true
  /// A read-only history (after the trial) can't be dragged out of, which
  /// would copy its items. Favorites can still be rearranged.
  var isReadOnly = false
  var isSyncingSelection = false
  private var selectionAnchorRow: Int?
  var selectionLeadRow: Int?
  private var selectionOrderIDs: [UUID] = []
  var isKeyboardMultipleSelectionMode = false
  /// Selects the item under the pointer as the pointer moves over the list.
  var selectsItemOnHover = false {
    didSet {
      guard selectsItemOnHover != oldValue else {
        return
      }

      tableView.onMouseMovedOverRow = selectsItemOnHover
        ? { [weak self] row in self?.selectItemOnHover(atRow: row) }
        : nil
      pauseHoverSelectionUntilPointerMoves()
    }
  }
  // Where the pointer was when the selection last changed in some other way:
  // the history opened, a key or a click moved it, or the list reloaded.
  // Hover selection waits until the pointer moves away from there, so a
  // pointer that happens to rest over the list, or a nudge of the mouse,
  // doesn't take the selection away from the item the user just got to.
  private var hoverSelectionPausedAtPointerLocation: NSPoint?
  private var isSelectingItemOnHover = false
  private static let hoverSelectionResumeDistance: CGFloat = 4
  let tableView = HistoryTableView()
  private let scrollView = OverlayScrollView()
  private static let scrollBottomPadding: CGFloat = 4
  private static let firstRowPaddingBelowNotice: CGFloat = 8
  /// The trial notice sits right on top of the list. A section header (such as
  /// Today) keeps the first row away from it; without one, as in a list sorted
  /// by size, the list gets the room itself.
  var showsNoticeAbove = false {
    didSet {
      guard showsNoticeAbove != oldValue else {
        return
      }

      updateScrollContentInsets()
    }
  }

  /// Extra room below the last row, for a fade laid over the bottom of the
  /// list: scrolled all the way down, the last row ends above it.
  var additionalBottomContentInset: CGFloat = 0 {
    didSet {
      guard additionalBottomContentInset != oldValue else {
        return
      }

      needsLayout = true
    }
  }

  // Before macOS 26 the history window's titlebar is transparent, so rows
  // scrolled under the toolbar would show through it. The list starts below
  // the toolbar there instead of scrolling beneath it.
  private static var scrollsUnderToolbar: Bool {
    if #available(macOS 26.0, *) {
      return true
    }

    return false
  }
  private let emptyListView = EmptyHistory(
    title: L10n.string("No clipboard items"),
    message: L10n.string("Copy text, images, files, links, emails, or colors to build your history."),
    symbolName: "clipboard"
  )
  private let emptySearchResultsView = EmptyHistory(
    title: L10n.string("No results"),
    symbolName: "magnifyingglass"
  )
  private let emptyTrashView = EmptyHistory(
    title: L10n.string("Trash is empty"),
    message: L10n.string("Deleted items stay here for a while, so you can put them back."),
    symbolName: "trash"
  )
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func focusTableView() {
    window?.makeFirstResponder(tableView)
  }

  /// Scrolls the item's row to the middle of the list, so the items copied
  /// just before and after it are visible on both sides. It runs after the
  /// scroll that a selection change schedules, which would otherwise only
  /// bring the row to an edge of the list.
  func scrollItemToCenter(_ itemID: UUID) {
    DispatchQueue.main.async { [weak self] in
      DispatchQueue.main.async { [weak self] in
        DispatchQueue.main.async { [weak self] in
          guard let self, let row = self.tableRowIndex(forItemID: itemID) else {
            return
          }

          self.scrollRowToCenter(row)
        }
      }
    }
  }

  /// Scrolls once the list has caught up with the selection and the window
  /// has been laid out.
  func scrollSelectionIntoView() {
    DispatchQueue.main.async { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          return
        }

        self.scrollToRevealSelectedRow(self.currentSelectionFocusRow())
      }
    }
  }

  func scrollInitialSelectionIntoViewIfNeeded() {
    let row = currentSelectionFocusRow()
    guard row >= 0, row == firstSelectableRow() else {
      return
    }

    scrollToRevealSelectedRow(row)
  }

  func reload(
    items: [ClipboardItem],
    availableTags: [Tag],
    selectedItemID: UUID?,
    selectedItemIDs: Set<UUID>,
    searchQuery: String,
    showCommandNumberShortcut: Bool,
    showPreviewForLinks: Bool,
    detectSensitiveContent: Bool,
    showDividers: Bool,
    preferPastingAsPlainText: Bool,
    groupPinnedFavorites: Bool,
    sectionDate: ((ClipboardItem) -> Date?)?,
    isShowingTrash: Bool = false,
    onSelectFirstItem: @escaping (ClipboardItem) -> Void
  ) {
    let previousRows = tableRows
    let newRows = HistoryTableRowBuilder.build(from: items, groupPinnedFavorites: groupPinnedFavorites, sectionDate: sectionDate)
    let removedRowIndexes = removedRowIndexes(from: previousRows, to: newRows)

    self.items = items
    self.availableTags = availableTags
    self.searchQuery = searchQuery
    self.showCommandNumberShortcut = showCommandNumberShortcut
    self.showPreviewForLinks = showPreviewForLinks
    detectsSensitiveContent = detectSensitiveContent
    showsDividers = showDividers
    preferDraggingAsPlainText = preferPastingAsPlainText
    groupsPinnedFavorites = groupPinnedFavorites
    tableRows = newRows
    applyTableReload(removedRowIndexes: removedRowIndexes)
    updateScrollContentInsets()
    // Keep the scroll view visible even when the list is empty. Hiding it makes
    // the window's automatic titlebar separator lose the scroll view it tracks,
    // and a permanent separator line appears above the empty view.
    let isSearchActive = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    emptyListView.isHidden = !items.isEmpty || isSearchActive || isShowingTrash
    emptyTrashView.isHidden = !items.isEmpty || isSearchActive || !isShowingTrash
    emptySearchResultsView.isHidden = !items.isEmpty || !isSearchActive
    syncSelection(
      selectedItemID: selectedItemID,
      selectedItemIDs: selectedItemIDs,
      onSelectFirstItem: onSelectFirstItem
    )
  }

  func revealsSensitiveContent(of item: ClipboardItem) -> Bool {
    sensitiveContentRevealedItemIDs.contains(item.id)
  }

  func setRevealsSensitiveContent(_ reveals: Bool, of item: ClipboardItem) {
    guard reveals != revealsSensitiveContent(of: item) else {
      return
    }

    if reveals {
      sensitiveContentRevealedItemIDs.insert(item.id)
    } else {
      sensitiveContentRevealedItemIDs.remove(item.id)
    }
    if let row = tableRowIndex(forItemID: item.id) {
      tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }
  }

  func hideRevealedSensitiveContent() {
    guard !sensitiveContentRevealedItemIDs.isEmpty else {
      return
    }

    let rows = tableRowIndexes(forItemIDs: sensitiveContentRevealedItemIDs)
    sensitiveContentRevealedItemIDs = []
    tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
  }

  func refreshVisibleFilePreviewRows() {
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    guard visibleRows.location != NSNotFound else {
      return
    }

    let fileRows = IndexSet(
      (visibleRows.location..<(visibleRows.location + visibleRows.length)).filter { row in
        guard tableRows.indices.contains(row),
              case .item(let item, _) = tableRows[row] else {
          return false
        }

        return item.kind == .file
      }
    )
    guard !fileRows.isEmpty else {
      return
    }

    tableView.reloadData(forRowIndexes: fileRows, columnIndexes: IndexSet(integer: 0))
  }

  private func applyTableReload(removedRowIndexes: IndexSet?) {
    isSyncingSelection = true
    defer { isSyncingSelection = false }

    guard let removedRowIndexes else {
      tableView.reloadData()
      return
    }

    tableView.beginUpdates()
    tableView.removeRows(at: removedRowIndexes, withAnimation: [])
    tableView.endUpdates()

    let changedAccessoryRows = rowsToReloadForQuickPasteIndexes(firstItemRows(limit: 9))
    if !changedAccessoryRows.isEmpty {
      tableView.reloadData(forRowIndexes: changedAccessoryRows, columnIndexes: IndexSet(integer: 0))
    }
  }

  func syncSelection(selectedItemID: UUID?, selectedItemIDs: Set<UUID>, onSelectFirstItem: (ClipboardItem) -> Void) {
    guard !isSyncingSelection else {
      return
    }

    let selectedIDs = selectedItemIDs.isEmpty
      ? Set(selectedItemID.map { [$0] } ?? [])
      : selectedItemIDs
    let selectedRows = tableRowIndexes(forItemIDs: selectedIDs)

    if !selectedRows.isEmpty {
      let focusedRow = selectedItemID.flatMap(tableRowIndex(forItemID:)) ?? selectedRows.first
      if tableView.selectedRowIndexes != selectedRows {
        // The model sets a selection of its own once the selected items are
        // gone, deleted or put back for instance, which ends the multiple
        // selection they were picked with. Rows that only moved, under an item
        // copied meanwhile, keep it.
        if Set(selectionOrderIDs) != selectedIDs {
          isKeyboardMultipleSelectionMode = false
          tableView.isKeyboardMultipleSelectionMode = false
        }
        isSyncingSelection = true
        defer { isSyncingSelection = false }
        tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        selectionAnchorRow = focusedRow
        selectionLeadRow = focusedRow
        selectionOrderIDs = selectionOrderIDs(for: selectedRows, focusedRow: focusedRow)
        if let focusedRow {
          scheduleScrollToRevealSelectedRow(focusedRow)
        }
      } else if focusedRow == firstSelectableRow(), let focusedRow {
        selectionAnchorRow = focusedRow
        selectionLeadRow = focusedRow
        scheduleScrollToRevealSelectedRow(focusedRow)
      } else if focusedRow != selectionLeadRow {
        selectionAnchorRow = focusedRow
        selectionLeadRow = focusedRow
      }
    } else if let firstItem = items.first {
      onSelectFirstItem(firstItem)
    } else {
      isKeyboardMultipleSelectionMode = false
      tableView.isKeyboardMultipleSelectionMode = false
      isSyncingSelection = true
      defer { isSyncingSelection = false }
      selectionAnchorRow = nil
      selectionLeadRow = nil
      selectionOrderIDs = []
      tableView.deselectAll(nil)
    }

    updateVisibleRowDividers()
    updateVisibleRowSelectionOrderBadges()
  }

  /// Returns `false` when the selection stayed put because the list ran out of
  /// rows in that direction, which is what lets the caller move the focus
  /// somewhere else instead.
  @discardableResult
  func moveSelection(_ direction: HistorySelectionDirection) -> Bool {
    guard !items.isEmpty else {
      return false
    }

    let selectedRow = selectionLeadRow ?? tableView.selectedRow
    let nextRow: Int

    switch direction {
    case .up:
      if selectedRow < 0 {
        nextRow = lastSelectableRow() ?? 0
      } else {
        guard let previousRow = previousSelectableRow(before: selectedRow) else {
          return false
        }
        nextRow = previousRow
      }
    case .down:
      if selectedRow < 0 {
        nextRow = firstSelectableRow() ?? 0
      } else {
        guard let followingRow = nextSelectableRow(after: selectedRow) else {
          return false
        }
        nextRow = followingRow
      }
    }

    guard isSelectableRow(nextRow) else {
      return false
    }

    focusTableView()
    selectSingleRow(nextRow)
    return true
  }

  func extendSelection(_ direction: HistorySelectionDirection) {
    guard !items.isEmpty else {
      return
    }

    focusTableView()
    isKeyboardMultipleSelectionMode = false
    tableView.isKeyboardMultipleSelectionMode = false

    let currentLeadRow = selectionLeadRow ?? tableView.selectedRow
    let leadRow: Int
    if currentLeadRow < 0 {
      leadRow = firstSelectableRow() ?? 0
    } else {
      leadRow = currentLeadRow
    }

    let anchorRow = selectionAnchorRow ?? leadRow
    let nextRow: Int?
    switch direction {
    case .up:
      nextRow = previousSelectableRow(before: leadRow)
    case .down:
      nextRow = nextSelectableRow(after: leadRow)
    }

    guard let nextRow, isSelectableRow(nextRow) else {
      return
    }

    let lowerBound = min(anchorRow, nextRow)
    let upperBound = max(anchorRow, nextRow)
    let selectedRows = IndexSet((lowerBound...upperBound).filter(isSelectableRow(_:)))

    isSyncingSelection = true
    tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
    isSyncingSelection = false

    selectionAnchorRow = anchorRow
    selectionLeadRow = nextRow
    notifySelectionChanged(focusedRow: nextRow)
    scrollToRevealSelectedRow(nextRow)
  }

  func updateKeyboardMultipleSelection(_ command: HistoryKeyboardMultipleSelectionCommand) {
    guard !items.isEmpty else {
      return
    }

    focusTableView()

    let currentRow = currentKeyboardSelectionFocusRow()
    guard isSelectableRow(currentRow) else {
      return
    }

    let wasKeyboardMultipleSelectionMode = isKeyboardMultipleSelectionMode
    isKeyboardMultipleSelectionMode = true
    tableView.isKeyboardMultipleSelectionMode = true
    var selectedRows = tableView.selectedRowIndexes
    var selectionChange: HistoryMultipleSelectionChange?

    switch command {
    case .addCurrent:
      if !selectedRows.contains(currentRow) {
        selectedRows.insert(currentRow)
        selectionChange = .added
      } else if !wasKeyboardMultipleSelectionMode {
        // The focused row is already selected when the multiple selection
        // starts, so the first command promotes it into the selection.
        selectionChange = .added
      }
    case .removeCurrent:
      if selectedRows.contains(currentRow) {
        // The focused row is selected even outside of the multiple selection,
        // so removing it is only a selection change when the selection exists.
        let hadMultipleSelection = wasKeyboardMultipleSelectionMode || selectedRows.count > 1
        selectedRows.remove(currentRow)
        if hadMultipleSelection {
          selectionChange = .removed
        }
      }
    }

    guard !selectedRows.isEmpty else {
      selectSingleRow(currentRow)
      notifyMultipleSelectionChanged(selectionChange)
      return
    }

    selectionAnchorRow = currentRow
    selectionLeadRow = currentRow
    applyKeyboardMultipleSelection(selectedRows, focusedRow: currentRow)
    notifyMultipleSelectionChanged(selectionChange)
  }

  func exitKeyboardMultipleSelectionMode() {
    guard isKeyboardMultipleSelectionMode else {
      return
    }

    isKeyboardMultipleSelectionMode = false
    tableView.isKeyboardMultipleSelectionMode = false
    updateVisibleRowDividers()
    updateVisibleRowSelectionOrderBadges()
  }

  func moveKeyboardMultipleSelectionFocus(_ direction: HistorySelectionDirection) {
    guard isKeyboardMultipleSelectionMode, !items.isEmpty else {
      return
    }

    focusTableView()

    let currentRow = currentKeyboardSelectionFocusRow()
    let nextRow: Int?
    switch direction {
    case .up:
      nextRow = previousSelectableRow(before: currentRow)
    case .down:
      nextRow = nextSelectableRow(after: currentRow)
    }

    guard let nextRow else {
      return
    }

    selectionAnchorRow = nextRow
    selectionLeadRow = nextRow
    notifySelectionChanged(focusedRow: nextRow)
    scrollToRevealSelectedRow(nextRow)
  }

  private func applyKeyboardMultipleSelection(_ selectedRows: IndexSet, focusedRow: Int) {
    isSyncingSelection = true
    tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
    isSyncingSelection = false

    notifySelectionChanged(focusedRow: focusedRow)
    scrollToRevealSelectedRow(focusedRow)
  }

  override func layout() {
    super.layout()
    updateScrollContentInsets()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    updateScrollContentInsets()
  }

  private func updateScrollContentInsets() {
    var firstRowPadding: CGFloat = 0
    if showsNoticeAbove, let firstRow = tableRows.first {
      if case .sectionHeader = firstRow {} else {
        firstRowPadding = Self.firstRowPaddingBelowNotice
      }
    }
    let insets = NSEdgeInsets(
      top: (Self.scrollsUnderToolbar ? safeAreaInsets.top : 0) + firstRowPadding,
      left: 0,
      bottom: max(safeAreaInsets.bottom, Self.scrollBottomPadding) + additionalBottomContentInset,
      right: 0
    )
    let previousInsets = scrollView.contentInsets
    scrollView.automaticallyAdjustsContentInsets = false
    guard insets.top != previousInsets.top || insets.bottom != previousInsets.bottom else {
      return
    }

    // A list scrolled to its top stays there, rather than keeping its offset
    // and hiding the first row under the new inset or leaving a gap.
    let clipView = scrollView.contentView
    let wasAtTop = clipView.bounds.origin.y <= -previousInsets.top + 0.5
    scrollView.contentInsets = insets
    if wasAtTop {
      clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: -insets.top))
      scrollView.reflectScrolledClipView(clipView)
    }
  }

  private func tableRowIndex(forItemID id: UUID) -> Int? {
    tableRows.firstIndex { row in
      guard case .item(let item, _) = row else {
        return false
      }
      return item.id == id
    }
  }

  private func tableRowIndexes(forItemIDs ids: Set<UUID>) -> IndexSet {
    guard !ids.isEmpty else {
      return []
    }

    return IndexSet(tableRows.indices.filter { row in
      guard case .item(let item, _) = tableRows[row] else {
        return false
      }
      return ids.contains(item.id)
    })
  }

  private func removedRowIndexes(from previousRows: [HistoryTableRow], to newRows: [HistoryTableRow]) -> IndexSet? {
    guard previousRows.count > newRows.count else {
      return nil
    }

    var newRowIndex = newRows.startIndex
    var removedIndexes = IndexSet()

    for previousRowIndex in previousRows.indices {
      if newRowIndex < newRows.endIndex,
         rowIdentity(previousRows[previousRowIndex]) == rowIdentity(newRows[newRowIndex]) {
        newRowIndex += 1
      } else {
        removedIndexes.insert(previousRowIndex)
      }
    }

    guard newRowIndex == newRows.endIndex,
          previousRows.count - removedIndexes.count == newRows.count,
          !removedIndexes.isEmpty else {
      return nil
    }

    return removedIndexes
  }

  private func rowIdentity(_ row: HistoryTableRow) -> HistoryTableRowIdentity {
    switch row {
    case .sectionHeader(let title):
      return .sectionHeader(title)
    case .item(let item, _):
      return .item(item.id)
    }
  }

  private func firstItemRows(limit: Int) -> IndexSet {
    guard limit > 0 else {
      return []
    }

    var indexes = IndexSet()
    for row in tableRows.indices {
      guard case .item = tableRows[row] else {
        continue
      }

      indexes.insert(row)
      if indexes.count == limit {
        break
      }
    }

    return indexes
  }

  private func selectSingleRow(_ row: Int, scrollsToReveal: Bool = true) {
    isKeyboardMultipleSelectionMode = false
    tableView.isKeyboardMultipleSelectionMode = false
    isSyncingSelection = true
    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    isSyncingSelection = false

    selectionAnchorRow = row
    selectionLeadRow = row
    selectionOrderIDs = selectionOrderIDs(for: IndexSet(integer: row), focusedRow: row)
    notifySelectionChanged(focusedRow: row)
    if scrollsToReveal {
      scrollToRevealSelectedRow(row)
    }
  }

  func handleTableSelectionDidChange(clickedRow: Int?) {
    guard !isSyncingSelection else {
      return
    }

    isKeyboardMultipleSelectionMode = false
    tableView.isKeyboardMultipleSelectionMode = false

    let focusedRow: Int?
    if let clickedRow, tableView.selectedRowIndexes.contains(clickedRow) {
      focusedRow = clickedRow
    } else {
      focusedRow = tableView.selectedRowIndexes.first
    }

    selectionAnchorRow = focusedRow
    selectionLeadRow = focusedRow
    notifySelectionChanged(focusedRow: focusedRow)
  }

  private func notifySelectionChanged(focusedRow: Int?) {
    updateVisibleRowDividers()

    let selectedItemsByID = Dictionary(uniqueKeysWithValues: selectedItemsInRowOrder().map { ($0.id, $0) })
    updateSelectionOrder(focusedRow: focusedRow)
    updateVisibleRowSelectionOrderBadges()
    let selectedItems = selectionOrderIDs.compactMap { selectedItemsByID[$0] }

    let focusedItem: ClipboardItem?
    if let focusedRow,
       tableRows.indices.contains(focusedRow),
       case .item(let item, _) = tableRows[focusedRow] {
      focusedItem = item
    } else {
      focusedItem = selectedItems.first
    }

    delegate?.listPane(self, didSelectItems: selectedItems, focusedItem: focusedItem)
  }

  private func notifyMultipleSelectionChanged(_ change: HistoryMultipleSelectionChange?) {
    guard let change else {
      return
    }

    delegate?.listPane(self, didChangeMultipleSelectionWith: change)
  }

  private func currentKeyboardSelectionFocusRow() -> Int {
    if let selectionLeadRow, isSelectableRow(selectionLeadRow) {
      return selectionLeadRow
    }

    if tableView.selectedRow >= 0, isSelectableRow(tableView.selectedRow) {
      return tableView.selectedRow
    }

    return firstSelectableRow() ?? 0
  }

  private func currentSelectionFocusRow() -> Int {
    if isKeyboardMultipleSelectionMode {
      return currentKeyboardSelectionFocusRow()
    }

    return tableView.selectedRow
  }

  private func selectedItemsInRowOrder() -> [ClipboardItem] {
    tableView.selectedRowIndexes.compactMap { row -> ClipboardItem? in
      guard tableRows.indices.contains(row),
            case .item(let item, _) = tableRows[row] else {
        return nil
      }
      return item
    }
  }

  private func updateSelectionOrder(focusedRow: Int?) {
    selectionOrderIDs = selectionOrderIDs(for: tableView.selectedRowIndexes, focusedRow: focusedRow)
  }

  var isMultipleSelectionOrderBadgeMode: Bool {
    isKeyboardMultipleSelectionMode || tableView.selectedRowIndexes.count > 1
  }

  func selectionOrderBadgeNumber(forItemID id: UUID) -> Int? {
    guard isMultipleSelectionOrderBadgeMode,
          let index = selectionOrderIDs.firstIndex(of: id) else {
      return nil
    }

    return index + 1
  }

  func updateVisibleRowSelectionOrderBadges() {
    let showsPlaceholder = isMultipleSelectionOrderBadgeMode
    tableView.enumerateAvailableRowViews { _, row in
      guard tableRows.indices.contains(row),
            case .item(let item, _) = tableRows[row],
            let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? HistoryItemRowView else {
        return
      }

      cell.setSelectionOrderBadge(
        number: selectionOrderBadgeNumber(forItemID: item.id),
        showsPlaceholder: showsPlaceholder,
        animated: true
      )
    }
  }

  private func selectionOrderIDs(for selectedRows: IndexSet, focusedRow: Int?) -> [UUID] {
    let selectedItemsByRow = selectedRows.compactMap { row -> (row: Int, item: ClipboardItem)? in
      guard tableRows.indices.contains(row),
            case .item(let item, _) = tableRows[row] else {
        return nil
      }
      return (row, item)
    }
    let selectedIDs = Set(selectedItemsByRow.map { $0.item.id })

    var orderedIDs = selectionOrderIDs.filter { selectedIDs.contains($0) }
    if let focusedRow,
       let focusedItem = selectedItemsByRow.first(where: { $0.row == focusedRow })?.item,
       !orderedIDs.contains(focusedItem.id) {
      orderedIDs.append(focusedItem.id)
    }

    for item in selectedItemsByRow.map({ $0.item }) where !orderedIDs.contains(item.id) {
      orderedIDs.append(item.id)
    }

    return orderedIDs
  }

  private func isSelectableRow(_ row: Int) -> Bool {
    guard tableRows.indices.contains(row) else {
      return false
    }

    if case .item = tableRows[row] {
      return true
    }

    return false
  }

  private func firstSelectableRow() -> Int? {
    tableRows.indices.first(where: isSelectableRow(_:))
  }

  private func lastSelectableRow() -> Int? {
    tableRows.indices.last(where: isSelectableRow(_:))
  }

  private func nextSelectableRow(after row: Int) -> Int? {
    guard row + 1 < tableRows.count else {
      return nil
    }

    return (row + 1..<tableRows.count).first(where: isSelectableRow(_:))
  }

  private func previousSelectableRow(before row: Int) -> Int? {
    guard row > 0 else {
      return nil
    }

    return stride(from: row - 1, through: 0, by: -1).first(where: isSelectableRow(_:))
  }

  private func firstSectionHeaderRow() -> Int? {
    tableRows.firstIndex { row in
      if case .sectionHeader = row {
        return true
      }
      return false
    }
  }

  private func scrollToRevealSelectedRow(_ row: Int) {
    guard row >= 0 else {
      return
    }

    if row == firstSelectableRow(), let headerRow = firstSectionHeaderRow() {
      scrollRowFullyIntoView(headerRow, alignToTop: true)
      return
    }

    if row == lastSelectableRow() {
      scrollRowFullyIntoView(row, alignToTop: false)
      return
    }

    tableView.scrollRowToVisible(row)
  }

  private func scheduleScrollToRevealSelectedRow(_ row: Int) {
    DispatchQueue.main.async { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, self.tableRows.indices.contains(row) else {
          return
        }

        self.scrollToRevealSelectedRow(row)
      }
    }
  }

  private func scrollRowToCenter(_ row: Int) {
    tableView.layoutSubtreeIfNeeded()
    let rowRect = tableView.rect(ofRow: row)
    guard !rowRect.isEmpty else {
      tableView.scrollRowToVisible(row)
      return
    }

    let clipView = scrollView.contentView
    let insets = scrollView.contentInsets
    let visibleHeight = max(0, clipView.bounds.height - insets.top - insets.bottom)
    let minScrollY = -insets.top
    let maxScrollY = max(minScrollY, tableView.frame.height - clipView.bounds.height + insets.bottom)

    var origin = clipView.bounds.origin
    origin.y = min(max(rowRect.midY - visibleHeight / 2 - insets.top, minScrollY), maxScrollY)
    clipView.scroll(to: origin)
    scrollView.reflectScrolledClipView(clipView)
  }

  private func scrollRowFullyIntoView(_ row: Int, alignToTop: Bool) {
    tableView.layoutSubtreeIfNeeded()
    let rowRect = tableView.rect(ofRow: row)
    guard !rowRect.isEmpty else {
      tableView.scrollRowToVisible(row)
      return
    }

    let clipView = scrollView.contentView
    let insets = scrollView.contentInsets
    let visibleHeight = max(0, clipView.bounds.height - insets.top - insets.bottom)
    let visibleRect = NSRect(
      x: clipView.documentVisibleRect.minX,
      y: clipView.bounds.origin.y + insets.top,
      width: clipView.documentVisibleRect.width,
      height: visibleHeight
    )
    let minScrollY = -insets.top
    let maxScrollY = max(minScrollY, tableView.frame.height - clipView.bounds.height + insets.bottom)

    if alignToTop {
      guard rowRect.minY < visibleRect.minY || rowRect.maxY > visibleRect.maxY else {
        return
      }

      var origin = clipView.bounds.origin
      origin.y = min(max(rowRect.minY - insets.top, minScrollY), maxScrollY)
      clipView.scroll(to: origin)
      return
    }

    guard rowRect.maxY > visibleRect.maxY else {
      if rowRect.minY < visibleRect.minY {
        var origin = clipView.bounds.origin
        origin.y = min(max(rowRect.minY - insets.top, minScrollY), maxScrollY)
        clipView.scroll(to: origin)
      }
      return
    }

    var origin = clipView.bounds.origin
    origin.y = min(max(rowRect.maxY - visibleHeight - insets.top, minScrollY), maxScrollY)
    clipView.scroll(to: origin)
  }

  private func configure() {
    translatesAutoresizingMaskIntoConstraints = false

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = true
    scrollView.backgroundColor = HistoryAppearance.backgroundColor
    scrollView.documentView = tableView

    tableView.headerView = nil
    tableView.style = .fullWidth
    tableView.backgroundColor = HistoryAppearance.backgroundColor
    tableView.autoresizingMask = [.width]
    tableView.rowHeight = HistoryRow.height
    tableView.allowsMultipleSelection = true
    tableView.selectionHighlightStyle = .regular
    tableView.dataSource = self
    tableView.delegate = self
    tableView.onMouseDownSelection = { [weak self] row, event in
      self?.handleMouseDownSelection(row: row, event: event) ?? false
    }
    tableView.onMouseUpSelection = { [weak self] row, event in
      self?.handleMouseUpSelection(row: row, event: event)
    }
    tableView.onItemClick = { [weak self] row, event in
      self?.handleItemClick(row: row, event: event)
    }
    tableView.dragPayloadForRow = { [weak self] row, modifierFlags in
      self?.dragPayload(forRow: row, modifierFlags: modifierFlags)
    }
    tableView.reorderItemIDForRow = { [weak self] row in
      self?.reorderableItemID(forRow: row)
    }
    tableView.registerForDraggedTypes([.historyItemID])
    tableView.onExtendSelectionKeyDown = { [weak self] direction in
      self?.extendSelection(direction)
    }
    tableView.onKeyboardMultipleSelectionKeyDown = { [weak self] command in
      self?.updateKeyboardMultipleSelection(command)
    }
    tableView.onKeyboardMultipleSelectionMoveKeyDown = { [weak self] direction in
      self?.moveKeyboardMultipleSelectionFocus(direction)
    }
    tableView.onWidthChange = { [weak self] in
      self?.reloadVisibleMultipleFilePreviewRowsForWidthChange()
    }
    tableView.onSearchKeyDown = { [weak self] event in
      guard let self else {
        return
      }
      self.delegate?.listPane(self, didReceiveSearchKeyDown: event)
    }

    let column = NSTableColumn(identifier: .historyItemColumn)
    column.resizingMask = .autoresizingMask
    tableView.addTableColumn(column)

    let menu = NSMenu()
    menu.delegate = self
    tableView.menu = menu

    emptyListView.translatesAutoresizingMaskIntoConstraints = false
    emptySearchResultsView.translatesAutoresizingMaskIntoConstraints = false
    emptySearchResultsView.isHidden = true
    emptyTrashView.translatesAutoresizingMaskIntoConstraints = false
    emptyTrashView.isHidden = true

    addSubview(scrollView)
    addSubview(emptyListView)
    addSubview(emptySearchResultsView)
    addSubview(emptyTrashView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
      scrollView.topAnchor.constraint(
        equalTo: Self.scrollsUnderToolbar ? topAnchor : safeAreaLayoutGuide.topAnchor
      ),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.scrollBottomPadding),
      emptyListView.leadingAnchor.constraint(equalTo: leadingAnchor),
      emptyListView.trailingAnchor.constraint(equalTo: trailingAnchor),
      emptyListView.topAnchor.constraint(equalTo: topAnchor),
      emptyListView.bottomAnchor.constraint(equalTo: bottomAnchor),
      emptySearchResultsView.leadingAnchor.constraint(equalTo: leadingAnchor),
      emptySearchResultsView.trailingAnchor.constraint(equalTo: trailingAnchor),
      emptySearchResultsView.topAnchor.constraint(equalTo: topAnchor),
      emptySearchResultsView.bottomAnchor.constraint(equalTo: bottomAnchor),
      emptyTrashView.leadingAnchor.constraint(equalTo: leadingAnchor),
      emptyTrashView.trailingAnchor.constraint(equalTo: trailingAnchor),
      emptyTrashView.topAnchor.constraint(equalTo: topAnchor),
      emptyTrashView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  // The number of file previews a multiple files row shows depends on the row width.
  private func reloadVisibleMultipleFilePreviewRowsForWidthChange() {
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    guard visibleRows.location != NSNotFound else {
      return
    }

    var multipleFileRowIndexes = IndexSet()
    for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
      guard tableRows.indices.contains(row),
            case .item(let item, _) = tableRows[row],
            item.kind == .file,
            item.filePaths.count > 1 else {
        continue
      }

      multipleFileRowIndexes.insert(row)
    }

    guard !multipleFileRowIndexes.isEmpty else {
      return
    }

    tableView.reloadData(forRowIndexes: multipleFileRowIndexes, columnIndexes: IndexSet(integer: 0))
  }

  func pauseHoverSelectionUntilPointerMoves() {
    guard !isSelectingItemOnHover else {
      return
    }

    hoverSelectionPausedAtPointerLocation = NSEvent.mouseLocation
  }

  private func selectItemOnHover(atRow row: Int) {
    if let pausedAtLocation = hoverSelectionPausedAtPointerLocation {
      let location = NSEvent.mouseLocation
      guard hypot(location.x - pausedAtLocation.x, location.y - pausedAtLocation.y)
              >= Self.hoverSelectionResumeDistance else {
        return
      }
      hoverSelectionPausedAtPointerLocation = nil
    }

    // A multiple selection was made on purpose, so the pointer leaves it be.
    guard !isKeyboardMultipleSelectionMode,
          tableView.selectedRowIndexes.count <= 1,
          row != tableView.selectedRow,
          isSelectableRow(row) else {
      return
    }

    // The row is already under the pointer. Scrolling it into view would move
    // another row under the pointer, which the next move would select.
    isSelectingItemOnHover = true
    selectSingleRow(row, scrollsToReveal: false)
    isSelectingItemOnHover = false
  }

  private func handleMouseDownSelection(row: Int, event: NSEvent) -> Bool {
    isKeyboardMultipleSelectionMode = false
    tableView.isKeyboardMultipleSelectionMode = false

    guard isSelectableRow(row) else {
      return false
    }

    // Option is the drag modifier (it flips the plain-text payload), so it is
    // ignored for selection: an Option press selects like a plain one.
    let modifiers = event.modifierFlags.intersection([.command, .shift, .control])
    let previousSelectedRows = tableView.selectedRowIndexes
    let selectedRows: IndexSet
    var shiftSelectionRowOrder: [Int]?

    if modifiers.isEmpty {
      // A press on a row that is already selected keeps the selection for now:
      // it may turn into a drag of all selected rows, and only a release
      // narrows the selection down to this row.
      guard !previousSelectedRows.contains(row) else {
        return true
      }
      selectedRows = IndexSet(integer: row)
    } else if modifiers == .shift {
      let anchorRow = selectionAnchorRow ?? previousSelectedRows.first ?? row
      let lowerBound = min(anchorRow, row)
      let upperBound = max(anchorRow, row)
      let rangeRows = (lowerBound...upperBound).filter(isSelectableRow(_:))
      selectedRows = IndexSet(rangeRows)
      // Number the range from the anchor toward the clicked row so badges
      // follow the visual selection direction instead of click order.
      shiftSelectionRowOrder = anchorRow <= row ? rangeRows : rangeRows.reversed()
    } else if modifiers == .command {
      var toggledRows = previousSelectedRows
      if toggledRows.contains(row) {
        toggledRows.remove(row)
      } else {
        toggledRows.insert(row)
      }
      selectedRows = toggledRows
    } else {
      return false
    }

    guard selectedRows != previousSelectedRows else {
      return true
    }

    if let shiftSelectionRowOrder {
      selectionOrderIDs = shiftSelectionOrderIDs(forOrderedRows: shiftSelectionRowOrder)
    }
    tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
    return true
  }

  private func shiftSelectionOrderIDs(forOrderedRows rows: [Int]) -> [UUID] {
    let orderedRangeIDs = rows.compactMap { row -> UUID? in
      guard tableRows.indices.contains(row),
            case .item(let item, _) = tableRows[row] else {
        return nil
      }
      return item.id
    }

    // Items that already had a badge keep their numbers; newly selected items
    // are appended in anchor-to-clicked-row order.
    let rangeIDs = Set(orderedRangeIDs)
    var orderedIDs = selectionOrderIDs.filter { rangeIDs.contains($0) }
    for id in orderedRangeIDs where !orderedIDs.contains(id) {
      orderedIDs.append(id)
    }

    return orderedIDs
  }

  /// The release half of a plain press on an already selected row: a
  /// multiple selection collapses to the released row, as it would in any
  /// list, now that the press did not become a drag.
  private func handleMouseUpSelection(row: Int, event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .shift, .control]).isEmpty,
          isSelectableRow(row) else {
      return
    }

    let selectedRows = tableView.selectedRowIndexes
    guard selectedRows.count > 1, selectedRows.contains(row) else {
      return
    }

    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
  }

  /// Text-like items follow the "prefer pasting as plain text" setting, and
  /// Option held while dragging flips it, like the secondary paste shortcut
  /// does.
  /// The rows of the favorites pinned at the top of the list, which sit right
  /// under the "Favorites" header at row 0. Nil when favorites are not pinned
  /// there or none is listed.
  var pinnedFavoriteRows: Range<Int>? {
    guard groupsPinnedFavorites, case .sectionHeader = tableRows.first else {
      return nil
    }

    var end = 1
    while end < tableRows.count, case .item(let item, _) = tableRows[end], item.isFavorite {
      end += 1
    }
    return end > 1 ? 1..<end : nil
  }

  private func reorderableItemID(forRow row: Int) -> UUID? {
    guard let pinnedFavoriteRows, pinnedFavoriteRows.contains(row),
          case .item(let item, _) = tableRows[row] else {
      return nil
    }

    return item.id
  }

  private func dragPayload(forRow row: Int, modifierFlags: NSEvent.ModifierFlags) -> HistoryRowDragPayload? {
    guard !isReadOnly,
          tableRows.indices.contains(row),
          case .item(let item, _) = tableRows[row] else {
      return nil
    }

    let asPlainText = preferDraggingAsPlainText != modifierFlags.contains(.option)
    let draggedItem = !asPlainText && item.kind == .richText ? loadFormatting?(item) ?? item : item
    return HistoryItemDragging.payload(for: draggedItem, asPlainText: asPlainText)
  }

  private func handleItemClick(row: Int, event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty,
          tableRows.indices.contains(row),
          case .item(let item, _) = tableRows[row] else {
      return
    }

    switch event.clickCount {
    case 1:
      delegate?.listPane(self, didClickItem: item)
    case 2:
      delegate?.listPane(self, didDoubleClickItem: item)
    default:
      return
    }
  }
}
