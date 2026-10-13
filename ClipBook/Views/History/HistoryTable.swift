import AppKit
import ImageIO

enum HistoryTableRow: Equatable {
  case sectionHeader(String)
  case item(ClipboardItem, itemIndex: Int)
}

enum HistoryAppearance {
  static var backgroundColor: NSColor {
    .textBackgroundColor
  }

  static func backgroundCGColor(for view: NSView) -> CGColor {
    var color = backgroundColor.cgColor
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
      color = backgroundColor.cgColor
    }
    return color
  }
}

enum HistoryTableRowBuilder {
  static func build(
    from items: [ClipboardItem],
    groupPinnedFavorites: Bool = false,
    sectionDate: ((ClipboardItem) -> Date?)? = { $0.copiedAt },
    calendar: Calendar = .current
  ) -> [HistoryTableRow] {
    var rows: [HistoryTableRow] = []
    var currentDay: Date?
    var isInFavoritesSection = false

    for (itemIndex, item) in items.enumerated() {
      if groupPinnedFavorites, item.isFavorite {
        if !isInFavoritesSection {
          isInFavoritesSection = true
          rows.append(.sectionHeader("Favorites"))
        }
        rows.append(.item(item, itemIndex: itemIndex))
        continue
      }

      guard let date = sectionDate?(item) else {
        rows.append(.item(item, itemIndex: itemIndex))
        continue
      }

      let day = calendar.startOfDay(for: date)
      if currentDay != day {
        currentDay = day
        rows.append(.sectionHeader(sectionTitle(for: date, calendar: calendar)))
      }
      rows.append(.item(item, itemIndex: itemIndex))
    }

    return rows
  }

  static func sectionTitle(for date: Date, calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) {
      return "Today"
    }

    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }

    return date.formatted(.dateTime.month(.abbreviated).day())
  }
}

enum HistoryRow {
  /// Every item row has the same height, so the list scans as an even grid whatever
  /// the rows hold.
  static let height: CGFloat = 50
  static let sectionHeaderHeight: CGFloat = 36
  static let sectionHeaderFirstHeight: CGFloat = 28
  static let sectionHeaderHorizontalInset: CGFloat = 9
  static let sectionHeaderTopInset: CGFloat = 14
  static let sectionHeaderFirstTopInset: CGFloat = 6
  static let rowSpacing: CGFloat = 0
  static let selectionCornerRadius: CGFloat = 16
  static let selectionHorizontalInset: CGFloat = 9
  static let selectionAccentColor = NSColor.gray.withAlphaComponent(0.2)

  // The row content sits inside the selection shape with the same inset on both sides.
  static let contentHorizontalInset: CGFloat = selectionHorizontalInset + 8
  static let contentVerticalInset: CGFloat = 4
  static let typeIconBoxSize: CGFloat = 34
  static let typeIconBoxCornerRadius: CGFloat = 9
  static let typeIconBoxColor = NSColor.gray.withAlphaComponent(0.15)
  static let typeIconSize: CGFloat = 18
  static let typeIconContentSpacing: CGFloat = 10
  static let mainSpacing: CGFloat = 8
  // The gap between the content (text and any preview next to it) and the accessory controls.
  static let contentAccessorySpacing: CGFloat = 16
  static let accessorySpacing: CGFloat = 6
  static let lineSpacing: CGFloat = 2
  static let tagIconSize: CGFloat = 12
  static let tagIconSpacing: CGFloat = 4
  static let sourceAppIconSize: CGFloat = 20
  static let linkPreviewImageWidth: CGFloat = 74
  static let linkPreviewImageHeight: CGFloat = 38
  static let linkPreviewImageCornerRadius: CGFloat = 6
  static let multipleFilesPreviewImageSize: CGFloat = 32
  static let multipleFilesPreviewImageSpacing: CGFloat = 8
  static let multipleFilesPreviewMaximumCount = 6
  // The item count and file summary keep at least this much room next to the previews.
  static let multipleFilesPreviewMinimumTextWidth: CGFloat = 120
  static let textPreviewMaximumNumberOfLines = 2
  // In multiple selection every row shows a selection order circle in a column on the left
  // of its content, which slides in and out.
  static let selectionOrderBadgeSize: CGFloat = 22
  static let selectionOrderColumnWidth: CGFloat = selectionOrderBadgeSize + typeIconContentSpacing
  static let selectionOrderColumnAnimationDuration: TimeInterval = 0.2
  static let dividerLeftInset: CGFloat = contentHorizontalInset + typeIconBoxSize + typeIconContentSpacing
  static let dividerRightInset: CGFloat = selectionHorizontalInset

  static func dividerColor(for view: NSView) -> NSColor {
    view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(white: 0x2F / 255.0, alpha: 1.0)
      : NSColor(srgbRed: 229.0 / 255.0, green: 229.0 / 255.0, blue: 229.0 / 255.0, alpha: 1.0)
  }

  static func makePrimaryFont() -> NSFont {
    .systemFont(ofSize: NSFont.systemFontSize + 0.5, weight: .regular)
  }

  static func makeSecondaryFont() -> NSFont {
    .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
  }

  // The details under a title: a link's page title, a file's size, image size and path.
  static func makeDetailsFont() -> NSFont {
    .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
  }

  static func makeItemTitleFont() -> NSFont {
    .systemFont(ofSize: NSFont.systemFontSize + 0.5, weight: .semibold)
  }

  static func textPreviewHeight(font: NSFont, lineCount: Int) -> CGFloat {
    ceil(font.historyLineHeight * CGFloat(lineCount))
  }
}

extension History: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in tableView: NSTableView) -> Int {
    tableRows.count
  }

  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    guard tableRows.indices.contains(row) else {
      return HistoryRow.height
    }

    switch tableRows[row] {
    case .sectionHeader:
      return row == 0 ? HistoryRow.sectionHeaderFirstHeight : HistoryRow.sectionHeaderHeight
    case .item:
      return HistoryRow.height
    }
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard tableRows.indices.contains(row) else {
      return nil
    }

    switch tableRows[row] {
    case .sectionHeader(let title):
      return makeSectionHeaderView(title: title, isFirst: row == 0, in: tableView)
    case .item(let item, let itemIndex):
      let cell = makeRowView(for: item, in: tableView)
      cell.filePreviewCache = filePreviewCache
      let rowWidth = tableColumn?.width ?? rowLayoutWidth(in: tableView)
      let quickPasteIndex = quickPasteIndex(forItemIndex: itemIndex)
      let tags = itemTags(for: item)
      cell.configure(
        item: item,
        quickPasteIndex: quickPasteIndex,
        tableWidth: rowWidth,
        searchQuery: searchQuery,
        itemTags: tags,
        linkPreview: showPreviewForLinks ? item.linkPreview : nil,
        showsLinkPreview: showPreviewForLinks,
        detectsSensitiveContent: detectsSensitiveContent,
        revealsSensitiveContent: revealsSensitiveContent(of: item),
        onToggleSensitiveContentVisibility: { [weak self] in
          guard let self else {
            return
          }
          self.delegate?.listPane(self, didRequestTogglingSensitiveContentVisibilityOf: item)
        }
      )
      cell.setSelectionOrderBadge(
        number: selectionOrderBadgeNumber(forItemID: item.id),
        showsPlaceholder: isMultipleSelectionOrderBadgeMode
      )
      if showPreviewForLinks, item.kind == .link, item.linkPreviewDetails == nil {
        delegate?.listPane(self, shouldLoadLinkPreviewFor: item)
      }
      return cell
    }
  }

  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    guard tableRows.indices.contains(row) else {
      return makeItemRowView(in: tableView)
    }

    if case .sectionHeader = tableRows[row] {
      return makeSectionHeaderRowView(in: tableView)
    }

    let rowView = makeItemRowView(in: tableView)
    rowView.showsDivider = shouldShowDivider(aboveRow: row)
    let selectedRows = self.tableView.selectedRowIndexes
    rowView.joinsSelectedRowAbove = rowCanJoinSelectedNeighbors(row, selectedRows: selectedRows)
      && isSelectedItemRow(row - 1)
      && selectedRows.contains(row - 1)
    rowView.joinsSelectedRowBelow = rowCanJoinSelectedNeighbors(row, selectedRows: selectedRows)
      && isSelectedItemRow(row + 1)
      && selectedRows.contains(row + 1)
    rowView.isPartOfMultipleSelection = selectedRows.count > 1
    rowView.isKeyboardMultipleSelectionMode = isKeyboardMultipleSelectionMode
    rowView.isKeyboardSelectionFocusedRow = selectionLeadRow == row
    return rowView
  }

  func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
    if case .item = tableRows[safe: row] {
      return true
    }

    return false
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let clickedRow = tableView.lastMouseDownRow
    tableView.lastMouseDownRow = nil
    pauseHoverSelectionUntilPointerMoves()
    handleTableSelectionDidChange(clickedRow: clickedRow)
  }

  // MARK: - Reordering pinned favorites

  func tableView(
    _ tableView: NSTableView,
    validateDrop info: NSDraggingInfo,
    proposedRow row: Int,
    proposedDropOperation dropOperation: NSTableView.DropOperation
  ) -> NSDragOperation {
    guard let dropRow = favoritesDropRow(for: info, proposedRow: row, proposedDropOperation: dropOperation) else {
      return []
    }

    tableView.setDropRow(dropRow, dropOperation: .above)
    return .move
  }

  func tableView(
    _ tableView: NSTableView,
    acceptDrop info: NSDraggingInfo,
    row: Int,
    dropOperation: NSTableView.DropOperation
  ) -> Bool {
    let draggedItemIDs = self.tableView.reorderDraggedItemIDs
    guard self.tableView.isOwnDrag(info), !draggedItemIDs.isEmpty,
          let pinnedFavoriteRows else {
      return false
    }

    // The favorite the dragged ones land in front of is the first one at or
    // below the drop line that is not itself on the move. None means the end
    // of the favorites.
    let draggedIDs = Set(draggedItemIDs)
    var targetItemID: UUID?
    for candidateRow in max(row, pinnedFavoriteRows.lowerBound)..<pinnedFavoriteRows.upperBound {
      guard case .item(let item, _) = tableRows[candidateRow], !draggedIDs.contains(item.id) else {
        continue
      }
      targetItemID = item.id
      break
    }

    delegate?.listPane(self, moveFavorites: draggedItemIDs, before: targetItemID)
    return true
  }

  /// The row the insertion line goes above for a drop of the table's own
  /// favorites, or nil when the drag cannot land here: it is not a reorder of
  /// pinned favorites, or the pointer is below the favorites section.
  private func favoritesDropRow(
    for info: NSDraggingInfo,
    proposedRow row: Int,
    proposedDropOperation dropOperation: NSTableView.DropOperation
  ) -> Int? {
    guard tableView.isOwnDrag(info), !tableView.reorderDraggedItemIDs.isEmpty,
          let pinnedFavoriteRows, row >= 0 else {
      return nil
    }

    var dropRow = row
    if dropOperation == .on {
      // Landing on a row means before or after it, whichever half of the row
      // holds the pointer.
      let location = tableView.convert(info.draggingLocation, from: nil)
      dropRow = location.y < tableView.rect(ofRow: row).midY ? row : row + 1
    }

    // Above the "Favorites" header still means the first place in the section,
    // and above the row that follows the section means the last.
    dropRow = max(dropRow, pinnedFavoriteRows.lowerBound)
    guard dropRow <= pinnedFavoriteRows.upperBound else {
      return nil
    }

    return dropRow
  }

  private func quickPasteIndex(forItemIndex itemIndex: Int) -> Int? {
    guard showCommandNumberShortcut, itemIndex < 9 else {
      return nil
    }

    return itemIndex + 1
  }

  private func itemTags(for item: ClipboardItem) -> [Tag] {
    guard !item.tags.isEmpty else {
      return []
    }

    return item.tags.compactMap { availableTagsByID[$0] }
  }

  private func rowLayoutWidth(in tableView: NSTableView) -> CGFloat {
    tableView.tableColumns.first?.width ?? tableView.bounds.width
  }

  private func makeSectionHeaderView(title: String, isFirst: Bool, in tableView: NSTableView) -> NSView {
    let identifier = NSUserInterfaceItemIdentifier.historySectionHeader
    let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HistorySectionHeaderCellView
      ?? HistorySectionHeaderCellView()
    cell.identifier = identifier
    cell.configure(title: title, isFirst: isFirst)
    return cell
  }

  private func makeRowView(for item: ClipboardItem, in tableView: NSTableView) -> HistoryItemRowView {
    let identifier = item.historyRowIdentifier
    let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryItemRowView
      ?? item.makeHistoryItemRowView()
    rowView.identifier = identifier
    return rowView
  }

  // Row views need a reuse identifier as well as cells. NSTableView parks a
  // row view without one in its row view "purgatory" when the row scrolls out,
  // and that set kept growing: scrolling the whole history five times left
  // about 30,000 dead row views (each with its own layout engine and backing
  // store) alive and about 900 MB in use.
  private func makeItemRowView(in tableView: NSTableView) -> RoundedSelectionRowView {
    let identifier = NSUserInterfaceItemIdentifier.historyItemRowView
    let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? RoundedSelectionRowView
      ?? RoundedSelectionRowView()
    rowView.identifier = identifier
    return rowView
  }

  private func makeSectionHeaderRowView(in tableView: NSTableView) -> HistorySectionHeaderRowView {
    let identifier = NSUserInterfaceItemIdentifier.historySectionHeaderRowView
    let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? HistorySectionHeaderRowView
      ?? HistorySectionHeaderRowView()
    rowView.identifier = identifier
    return rowView
  }

  func updateVisibleRowDividers() {
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    guard visibleRows.location != NSNotFound else {
      return
    }

    for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
      guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? RoundedSelectionRowView else {
        continue
      }

      let selectedRows = tableView.selectedRowIndexes
      rowView.showsDivider = shouldShowDivider(aboveRow: row)
      rowView.joinsSelectedRowAbove = rowCanJoinSelectedNeighbors(row, selectedRows: selectedRows)
        && isSelectedItemRow(row - 1)
        && selectedRows.contains(row - 1)
      rowView.joinsSelectedRowBelow = rowCanJoinSelectedNeighbors(row, selectedRows: selectedRows)
        && isSelectedItemRow(row + 1)
        && selectedRows.contains(row + 1)
      rowView.isPartOfMultipleSelection = selectedRows.count > 1
      rowView.isKeyboardMultipleSelectionMode = isKeyboardMultipleSelectionMode
      rowView.isKeyboardSelectionFocusedRow = selectionLeadRow == row
    }
  }

  private func shouldShowDivider(aboveRow row: Int) -> Bool {
    guard showsDividers,
          case .item = tableRows[safe: row],
          case .item = tableRows[safe: row - 1] else {
      return false
    }

    if isKeyboardMultipleSelectionMode,
       (selectionLeadRow == row || selectionLeadRow == row - 1) {
      return false
    }

    let selectedRows = tableView.selectedRowIndexes
    return !selectedRows.contains(row) && !selectedRows.contains(row - 1)
  }

  private func rowCanJoinSelectedNeighbors(_ row: Int, selectedRows: IndexSet) -> Bool {
    !(isKeyboardMultipleSelectionMode && selectionLeadRow == row && !selectedRows.contains(row))
  }

  private func isSelectedItemRow(_ row: Int) -> Bool {
    guard case .item = tableRows[safe: row] else {
      return false
    }

    return true
  }
}

extension History: NSMenuDelegate {
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()

    let clickedRow = tableView.contextualMenuRow ?? tableView.clickedRow
    let row = clickedRow >= 0 ? clickedRow : tableView.selectedRow
    guard case .item(let focusedItem, _) = tableRows[safe: row] else {
      return
    }

    if !tableView.selectedRowIndexes.contains(row) {
      tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    guard let delegate else {
      return
    }

    let selectedItems = selectedItemsForMenu()
    let menuFocusedItem = selectedItems.contains(where: { $0.id == focusedItem.id })
      ? focusedItem
      : selectedItems.first
    for menuItem in delegate.listPane(self, actionsMenuFor: selectedItems, focusedItem: menuFocusedItem).items {
      menu.addItem(menuItem)
    }
  }

  func menuDidClose(_ menu: NSMenu) {
    tableView.contextualMenuRow = nil
  }

  private func selectedItemsForMenu() -> [ClipboardItem] {
    tableView.selectedRowIndexes.compactMap { row in
      guard case .item(let item, _) = tableRows[safe: row] else {
        return nil
      }
      return item
    }
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

private enum HistorySectionHeaderAppearance {
  static func titleColor(for view: NSView) -> NSColor {
    view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(srgbRed: 110.0 / 255.0, green: 110.0 / 255.0, blue: 110.0 / 255.0, alpha: 1.0)
      : NSColor(srgbRed: 174.0 / 255.0, green: 174.0 / 255.0, blue: 178.0 / 255.0, alpha: 1.0)
  }
}

private final class HistorySectionHeaderCellView: NSTableCellView {
  private let titleField = NSTextField(labelWithString: "")
  private var titleTopConstraint: NSLayoutConstraint?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateTitleColor()
  }

  func configure(title: String, isFirst: Bool) {
    titleField.stringValue = title
    titleTopConstraint?.constant = isFirst
      ? HistoryRow.sectionHeaderFirstTopInset
      : HistoryRow.sectionHeaderTopInset
    updateTitleColor()
  }

  private func configure() {
    titleField.translatesAutoresizingMaskIntoConstraints = false
    titleField.font = .systemFont(ofSize: 12, weight: .regular)
    titleField.lineBreakMode = .byTruncatingTail
    textField = titleField
    addSubview(titleField)
    updateTitleColor()

    let topConstraint = titleField.topAnchor.constraint(equalTo: topAnchor)
    titleTopConstraint = topConstraint

    NSLayoutConstraint.activate([
      titleField.leadingAnchor.constraint(
        equalTo: leadingAnchor,
        constant: HistoryRow.sectionHeaderHorizontalInset
      ),
      titleField.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor,
        constant: -HistoryRow.sectionHeaderHorizontalInset
      ),
      topConstraint
    ])
  }

  private func updateTitleColor() {
    titleField.textColor = HistorySectionHeaderAppearance.titleColor(for: self)
  }
}

private final class HistorySectionHeaderRowView: NSTableRowView {
  override func drawBackground(in dirtyRect: NSRect) {}
  override func drawSelection(in dirtyRect: NSRect) {}
}

private final class RoundedSelectionRowView: NSTableRowView {
  var showsDivider = false {
    didSet {
      if oldValue != showsDivider {
        needsDisplay = true
      }
    }
  }
  var joinsSelectedRowAbove = false {
    didSet {
      if oldValue != joinsSelectedRowAbove {
        needsDisplay = true
      }
    }
  }
  var joinsSelectedRowBelow = false {
    didSet {
      if oldValue != joinsSelectedRowBelow {
        needsDisplay = true
      }
    }
  }
  var isPartOfMultipleSelection = false {
    didSet {
      if oldValue != isPartOfMultipleSelection {
        needsDisplay = true
      }
    }
  }
  var isKeyboardMultipleSelectionMode = false {
    didSet {
      if oldValue != isKeyboardMultipleSelectionMode {
        needsDisplay = true
      }
    }
  }
  var isKeyboardSelectionFocusedRow = false {
    didSet {
      if oldValue != isKeyboardSelectionFocusedRow {
        needsDisplay = true
      }
    }
  }

  override var isEmphasized: Bool {
    get { true }
    set {}
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    drawDivider(in: dirtyRect)
  }

  override func drawBackground(in dirtyRect: NSRect) {
    if isKeyboardMultipleSelectionMode && isKeyboardSelectionFocusedRow && !isSelected {
      let path = rowBackgroundPath
      activeSelectionColor.setFill()
      path.fill()
      return
    }

    guard !isSelected else {
      return
    }

    let path = rowBackgroundPath
    rowBackgroundColor.setFill()
    path.fill()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func drawSelection(in dirtyRect: NSRect) {
    guard selectionHighlightStyle != .none else {
      return
    }

    let path = rowBackgroundPath
    selectionColorForCurrentState.setFill()
    path.fill()
  }

  private var rowBackgroundPath: NSBezierPath {
    let rect = NSRect(
      x: HistoryRow.selectionHorizontalInset,
      y: HistoryRow.rowSpacing / 2,
      width: bounds.size.width - HistoryRow.selectionHorizontalInset * 2,
      height: bounds.size.height - HistoryRow.rowSpacing
    )
    return selectionPath(in: rect)
  }

  private func selectionPath(in rect: NSRect) -> NSBezierPath {
    let roundsTop = !joinsSelectedRowAbove
    let roundsBottom = !joinsSelectedRowBelow
    let roundsMinY = isFlipped ? roundsTop : roundsBottom
    let roundsMaxY = isFlipped ? roundsBottom : roundsTop

    var corners: ContinuousCorners = []
    if roundsMinY {
      corners.formUnion([.minXMinY, .maxXMinY])
    }
    if roundsMaxY {
      corners.formUnion([.minXMaxY, .maxXMaxY])
    }
    return NSBezierPath.continuousRoundedRect(rect, cornerRadius: HistoryRow.selectionCornerRadius, corners: corners)
  }

  private var selectionColorForCurrentState: NSColor {
    guard isKeyboardMultipleSelectionMode else {
      return isPartOfMultipleSelection ? secondarySelectionColor : activeSelectionColor
    }

    return isKeyboardSelectionFocusedRow ? activeSelectionColor : secondarySelectionColor
  }

  private var activeSelectionColor: NSColor {
    HistoryRow.selectionAccentColor
  }

  private var secondarySelectionColor: NSColor {
    return isDarkAppearance
      ? NSColor.gray.withAlphaComponent(0.16)
      : NSColor.gray.withAlphaComponent(0.12)
  }

  private var rowBackgroundColor: NSColor {
    isDarkAppearance
      ? NSColor(srgbRed: 39.0 / 255.0, green: 39.0 / 255.0, blue: 39.0 / 255.0, alpha: 0.0)
      : NSColor(srgbRed: 249.0 / 255.0, green: 249.0 / 255.0, blue: 249.0 / 255.0, alpha: 0.0)
  }

  private func drawDivider(in dirtyRect: NSRect) {
    guard showsDivider else {
      return
    }

    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    let dividerHeight = 1 / scale
    let dividerY = isFlipped
      ? HistoryRow.rowSpacing / 2
      : bounds.height - HistoryRow.rowSpacing / 2 - dividerHeight
    let dividerRect = NSRect(
      x: HistoryRow.dividerLeftInset,
      y: dividerY,
      width: max(0, bounds.width - HistoryRow.dividerLeftInset - HistoryRow.dividerRightInset),
      height: dividerHeight
    )
    guard dirtyRect.intersects(dividerRect) else {
      return
    }

    HistoryRow.dividerColor(for: self).setFill()
    dividerRect.fill()
  }

  private var isDarkAppearance: Bool {
    effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }
}

final class HistoryTableView: NSTableView {
  var contextualMenuRow: Int?
  var lastMouseDownRow: Int?
  var isKeyboardMultipleSelectionMode = false
  var onMouseDownSelection: ((Int, NSEvent) -> Bool)?
  var onMouseUpSelection: ((Int, NSEvent) -> Void)?
  var onItemClick: ((Int, NSEvent) -> Void)?
  var dragPayloadForRow: ((Int, NSEvent.ModifierFlags) -> HistoryRowDragPayload?)?
  /// The ID of the item in a row that may be dragged to a new place in the
  /// list, nil for a row that stays where it is.
  var reorderItemIDForRow: ((Int) -> UUID?)?
  var onDragSessionEnded: ((NSDragOperation) -> Void)?
  private(set) var isDragSessionActive = false
  /// The items of the drag under way, in row order, when every dragged row
  /// may be reordered. Empty for any other drag.
  private(set) var reorderDraggedItemIDs: [UUID] = []
  private let dragSource = HistoryDragSource()
  private static let dragThreshold: CGFloat = 4
  private static let fallbackDragImageSize = NSSize(width: 40, height: 40)
  var onSearchKeyDown: ((NSEvent) -> Void)?
  var onExtendSelectionKeyDown: ((HistorySelectionDirection) -> Void)?
  var onKeyboardMultipleSelectionKeyDown: ((HistoryKeyboardMultipleSelectionCommand) -> Void)?
  var onKeyboardMultipleSelectionMoveKeyDown: ((HistorySelectionDirection) -> Void)?
  var onWidthChange: (() -> Void)?
  /// Called with the row under the pointer each time the pointer moves over
  /// the list. The list only tracks the pointer while this is set.
  var onMouseMovedOverRow: ((Int) -> Void)? {
    didSet {
      if (oldValue == nil) != (onMouseMovedOverRow == nil) {
        updateTrackingAreas()
      }
    }
  }
  private var mouseMovedTrackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let mouseMovedTrackingArea {
      removeTrackingArea(mouseMovedTrackingArea)
      self.mouseMovedTrackingArea = nil
    }

    guard onMouseMovedOverRow != nil else {
      return
    }

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    mouseMovedTrackingArea = trackingArea
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)

    guard let onMouseMovedOverRow, !isDragSessionActive, isPointerOverList(event) else {
      return
    }

    onMouseMovedOverRow(row(at: convert(event.locationInWindow, from: nil)))
  }

  /// The tracking area covers the whole visible part of the list, also where
  /// the toolbar, the trial notice or another view covers it. Only a pointer
  /// that would land on the list itself counts as being over it.
  private func isPointerOverList(_ event: NSEvent) -> Bool {
    // The frame view has no superview, so it is hit-tested in window coordinates.
    guard let frameView = window?.contentView?.superview,
          let hitView = frameView.hitTest(event.locationInWindow) else {
      return false
    }

    return hitView.isDescendant(of: self)
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let location = convert(event.locationInWindow, from: nil)
    contextualMenuRow = row(at: location)
    return menu
  }

  override func mouseDown(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    let clickedRow = row(at: location)
    lastMouseDownRow = clickedRow

    guard onMouseDownSelection?(clickedRow, event) == true else {
      super.mouseDown(with: event)
      onItemClick?(clickedRow, event)
      return
    }

    window?.makeFirstResponder(self)

    // The selection is already applied, so the rest of the press decides
    // between a click and a drag of the selected rows.
    if trackMouseUntilDragOrRelease(after: event, row: clickedRow) {
      return
    }

    onMouseUpSelection?(clickedRow, event)
    onItemClick?(clickedRow, event)
  }

  // MARK: - Dragging out of the history

  /// Consumes the rest of the mouse press. Returns true when a drag session
  /// was started, false when the mouse was released in place.
  private func trackMouseUntilDragOrRelease(after mouseDown: NSEvent, row: Int) -> Bool {
    guard let window else {
      return false
    }

    let startLocation = mouseDown.locationInWindow
    while let event = window.nextEvent(
      matching: [.leftMouseDragged, .leftMouseUp],
      until: .distantFuture,
      inMode: .eventTracking,
      dequeue: true
    ) {
      guard event.type == .leftMouseDragged else {
        return false
      }

      let distance = hypot(
        event.locationInWindow.x - startLocation.x,
        event.locationInWindow.y - startLocation.y
      )
      guard distance >= Self.dragThreshold else {
        continue
      }

      // A row that was just taken out of the selection with Cmd+click is not
      // dragged; the press then ends as a plain release.
      guard selectedRowIndexes.contains(row) else {
        continue
      }

      if beginDragSession(with: mouseDown, rows: selectedRowIndexes) {
        return true
      }
    }

    return false
  }

  /// True when the drag `info` describes started in this table.
  func isOwnDrag(_ info: NSDraggingInfo) -> Bool {
    (info.draggingSource as AnyObject?) === dragSource
  }

  private func beginDragSession(with event: NSEvent, rows: IndexSet) -> Bool {
    var draggingItems: [NSDraggingItem] = []
    var containsFileURLs = false
    var reorderItemIDs: [UUID] = []
    var everyRowIsReorderable = true
    // The modifiers held as the drag begins pick the payload.
    let modifierFlags = NSEvent.modifierFlags.intersection([.command, .shift, .option, .control])

    for row in rows {
      let reorderItemID = reorderItemIDForRow?(row)
      if let reorderItemID {
        reorderItemIDs.append(reorderItemID)
      } else {
        everyRowIsReorderable = false
      }

      var payload = dragPayloadForRow?(row, modifierFlags)
      if payload == nil, reorderItemID != nil {
        payload = HistoryItemDragging.reorderOnlyPayload()
      }
      guard let payload, !payload.entries.isEmpty else {
        continue
      }

      containsFileURLs = containsFileURLs || payload.containsFileURLs
      draggingItems.append(contentsOf: makeDraggingItems(for: payload, row: row, itemID: reorderItemID))
    }

    guard !draggingItems.isEmpty else {
      return false
    }

    // A drag that mixes favorites with other rows has nowhere to land in the
    // list, so it is only ever a drag out of the app.
    reorderDraggedItemIDs = everyRowIsReorderable ? reorderItemIDs : []
    dragSource.containsFileURLs = containsFileURLs
    dragSource.allowsMoveWithinApplication = !reorderDraggedItemIDs.isEmpty
    dragSource.onEnded = { [weak self] operation in
      guard let self else {
        return
      }
      self.isDragSessionActive = false
      self.reorderDraggedItemIDs = []
      self.onDragSessionEnded?(operation)
    }

    isDragSessionActive = true
    let session = beginDraggingSession(with: draggingItems, event: event, source: dragSource)
    session.animatesToStartingPositionsOnCancelOrFail = true
    session.draggingFormation = draggingItems.count > 1 ? .stack : .default
    return true
  }

  private func makeDraggingItems(for payload: HistoryRowDragPayload, row: Int, itemID: UUID?) -> [NSDraggingItem] {
    let rowRect = rect(ofRow: row)
    let writer = { (entry: HistoryRowDragEntry) -> NSPasteboardWriting in
      guard let itemID else {
        return entry.writer
      }
      return HistoryItemDragging.writer(entry.writer, carrying: itemID)
    }

    if payload.entries.count == 1, let entry = payload.entries.first {
      let draggingItem = NSDraggingItem(pasteboardWriter: writer(entry))
      if let snapshot = snapshotImage(forRow: row) {
        draggingItem.setDraggingFrame(rowRect, contents: snapshot)
      } else {
        draggingItem.setDraggingFrame(fallbackDragFrame(in: rowRect), contents: entry.icon)
      }
      return [draggingItem]
    }

    // Several entries stand for several files: each gets its own icon, laid
    // out across the row so they lift off from where the row is.
    let iconSize = payload.entries.first?.icon?.size ?? Self.fallbackDragImageSize
    let spacing: CGFloat = 8
    return payload.entries.enumerated().map { index, entry in
      let draggingItem = NSDraggingItem(pasteboardWriter: writer(entry))
      let originX = rowRect.minX + HistoryRow.contentHorizontalInset + CGFloat(index) * (iconSize.width + spacing)
      let frame = NSRect(
        x: min(originX, rowRect.maxX - iconSize.width),
        y: rowRect.midY - iconSize.height / 2,
        width: iconSize.width,
        height: iconSize.height
      )
      draggingItem.setDraggingFrame(frame, contents: entry.icon)
      return draggingItem
    }
  }

  private func fallbackDragFrame(in rowRect: NSRect) -> NSRect {
    NSRect(
      x: rowRect.minX + HistoryRow.contentHorizontalInset,
      y: rowRect.midY - Self.fallbackDragImageSize.height / 2,
      width: Self.fallbackDragImageSize.width,
      height: Self.fallbackDragImageSize.height
    )
  }

  /// A picture of the row as it is drawn, selection highlight included, so the
  /// dragged content stays readable over whatever it is dragged across. Rows
  /// scrolled out of view have no view to draw and get no snapshot.
  private func snapshotImage(forRow row: Int) -> NSImage? {
    guard let rowView = rowView(atRow: row, makeIfNecessary: false) else {
      return nil
    }

    let bounds = rowView.bounds
    guard bounds.width > 0, bounds.height > 0,
          let representation = rowView.bitmapImageRepForCachingDisplay(in: bounds) else {
      return nil
    }

    rowView.cacheDisplay(in: bounds, to: representation)
    let image = NSImage(size: bounds.size)
    image.addRepresentation(representation)
    return image
  }

  override func setFrameSize(_ newSize: NSSize) {
    let previousWidth = frame.width
    super.setFrameSize(newSize)

    guard abs(previousWidth - newSize.width) > 0.5, numberOfRows > 0 else {
      return
    }

    // Every row has a fixed height, so a new width only changes what the rows
    // lay out inside. Telling the table their heights changed made it ask for
    // the height of every row, and resizing itself in the middle of that
    // brought it back here, which AppKit reports as a reentrant operation.
    onWidthChange?()
  }

  override func keyDown(with event: NSEvent) {
    if handleExtendSelectionKeyDown(event) {
      return
    }

    if handleKeyboardMultipleSelectionKeyDown(event) {
      return
    }

    if handleKeyboardMultipleSelectionMoveKeyDown(event) {
      return
    }

    if isSearchKeyDown(event) {
      onSearchKeyDown?(event)
      return
    }

    super.keyDown(with: event)
  }

  private func handleExtendSelectionKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers == .shift else {
      return false
    }

    switch event.keyCode {
    case 126:
      onExtendSelectionKeyDown?(.up)
      return true
    case 125:
      onExtendSelectionKeyDown?(.down)
      return true
    default:
      return false
    }
  }

  private func handleKeyboardMultipleSelectionKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers.isEmpty else {
      return false
    }

    switch event.keyCode {
    case 124:
      onKeyboardMultipleSelectionKeyDown?(.addCurrent)
      return true
    case 123:
      onKeyboardMultipleSelectionKeyDown?(.removeCurrent)
      return true
    default:
      return false
    }
  }

  private func handleKeyboardMultipleSelectionMoveKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers.isEmpty, isKeyboardMultipleSelectionMode else {
      return false
    }

    switch event.keyCode {
    case 126:
      onKeyboardMultipleSelectionMoveKeyDown?(.up)
      return true
    case 125:
      onKeyboardMultipleSelectionMoveKeyDown?(.down)
      return true
    default:
      return false
    }
  }

  private func isSearchKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .control])
    guard modifiers.isEmpty,
          let characters = event.characters,
          !characters.isEmpty else {
      return false
    }

    return characters.unicodeScalars.allSatisfy { scalar in
      !CharacterSet.controlCharacters.contains(scalar) && scalar.value < 0xF700
    }
  }
}

extension NSUserInterfaceItemIdentifier {
  static let historyItemColumn = NSUserInterfaceItemIdentifier("HistoryItemColumn")
  static let historySectionHeader = NSUserInterfaceItemIdentifier("HistorySectionHeader")
  static let historyItemRowView = NSUserInterfaceItemIdentifier("HistoryItemRowView")
  static let historySectionHeaderRowView = NSUserInterfaceItemIdentifier("HistorySectionHeaderRowView")
}

private extension ClipboardKind {
  var historyRowIdentifier: NSUserInterfaceItemIdentifier {
    switch self {
    case .text:
      return NSUserInterfaceItemIdentifier("TextHistoryItemRow")
    case .richText:
      return NSUserInterfaceItemIdentifier("RichTextHistoryItemRow")
    case .link:
      return NSUserInterfaceItemIdentifier("LinkHistoryItemRow")
    case .email:
      return NSUserInterfaceItemIdentifier("EmailHistoryItemRow")
    case .color:
      return NSUserInterfaceItemIdentifier("ColorHistoryItemRow")
    case .image:
      return NSUserInterfaceItemIdentifier("ImageHistoryItemRow")
    case .file:
      return NSUserInterfaceItemIdentifier("FileHistoryItemRow")
    }
  }

  func makeHistoryItemRowView() -> HistoryItemRowView {
    switch self {
    case .text:
      return HistoryItemRowTextView()
    case .richText:
      return HistoryItemRowRichTextView()
    case .link:
      return HistoryItemRowLinkView()
    case .email:
      return HistoryItemRowEmailView()
    case .color:
      return HistoryItemRowColorView()
    case .image:
      return HistoryItemRowImageView()
    case .file:
      return HistoryItemRowFileView()
    }
  }
}

private extension ClipboardItem {
  var historyRowIdentifier: NSUserInterfaceItemIdentifier {
    guard kind == .file, filePaths.count > 1 else {
      return kind.historyRowIdentifier
    }

    return NSUserInterfaceItemIdentifier("FilesHistoryItemRow")
  }

  func makeHistoryItemRowView() -> HistoryItemRowView {
    guard kind == .file, filePaths.count > 1 else {
      return kind.makeHistoryItemRowView()
    }

    return HistoryItemRowFilesView()
  }
}
