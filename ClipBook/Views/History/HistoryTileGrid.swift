import AppKit

enum HistoryTile {
  /// Tiles share the width of the list evenly, as many in a line as fit at
  /// this width or more.
  static let minimumWidth: CGFloat = 150
  // The cards line up with the titles of the section headers.
  static let horizontalInset: CGFloat = HistoryRow.sectionHeaderHorizontalInset - cardInset
  // Every item is a card, its picture on top and its caption below. Half the
  // gap between two cards is on each side of a card.
  static let cardInset: CGFloat = 5
  static let cardCornerRadius: CGFloat = 12
  static let cardBackgroundColor = NSColor.gray.withAlphaComponent(0.12)
  // A selected card has a border of the accent color, the color of the
  // selection order badges.
  static let selectionBorderWidth: CGFloat = 2
  static let pictureAspectRatio: CGFloat = 3.0 / 4.0
  // The picture keeps this much room to the edges of the card, and the
  // caption lines up with it.
  static let picturePadding: CGFloat = 8
  static let pictureCornerRadius: CGFloat = 6
  static let captionHorizontalPadding: CGFloat = picturePadding
  static let captionVerticalPadding: CGFloat = 6
  static let accessorySpacing: CGFloat = 4
  static let favoriteSymbolSize: CGFloat = 10
  static let sourceAppIconSize: CGFloat = 16
  // The selection order badge sits in the top left corner of the card.
  static let selectionOrderBadgeInset: CGFloat = 8

  static func makeCaptionFont() -> NSFont {
    HistoryRow.makeDetailsFont()
  }

  // The caption is a line of text, or as tall as the icon of the app the
  // item was copied from when that is taller.
  static func captionHeight() -> CGFloat {
    max(ceil(makeCaptionFont().historyLineHeight), sourceAppIconSize)
  }

  static func height(forWidth width: CGFloat) -> CGFloat {
    cardInset + picturePadding + pictureHeight(forWidth: width)
      + captionVerticalPadding * 2 + captionHeight() + cardInset
  }

  static func pictureHeight(forWidth width: CGFloat) -> CGFloat {
    floor((width - cardInset * 2 - picturePadding * 2) * pictureAspectRatio)
  }
}

/// How a tile shows the selection, the same way a row of the list does.
struct HistoryTileSelectionState: Equatable {
  var isSelected = false
  var isPartOfMultipleSelection = false
  var isKeyboardMultipleSelectionMode = false
  var isKeyboardSelectionFocused = false
  var selectionOrderNumber: Int?
}

/// The history as a grid of tiles, for a history filtered to images, whose
/// pictures are too small to tell apart in the rows of the list. It shows the
/// same rows as the list, the section headers across the whole width and the
/// items as tiles in lines between them, and is driven by the same selection
/// logic in `History`, through the row indexes the list uses.
///
/// Only the tiles in sight have a view, and those views are used again for
/// the tiles that scroll in, so a history of thousands of images scrolls as
/// smoothly as a short one.
@MainActor
final class HistoryTileGridView: NSView {
  var rows: [HistoryTableRow] = []
  var configureTile: ((HistoryTileView, ClipboardItem, Int) -> Void)?
  var selectionState: ((Int) -> HistoryTileSelectionState)?
  var contextualMenuRow: Int?
  var lastMouseDownRow: Int?
  var isKeyboardMultipleSelectionMode = false
  var onSelectionDidChange: (() -> Void)?
  var onMouseDownSelection: ((Int, NSEvent) -> Bool)?
  var onMouseUpSelection: ((Int, NSEvent) -> Void)?
  var onItemClick: ((Int, NSEvent) -> Void)?
  var onSearchKeyDown: ((NSEvent) -> Void)?
  var onMoveSelectionKeyDown: ((HistorySelectionStep) -> Void)?
  var onExtendSelectionKeyDown: ((HistorySelectionStep) -> Void)?
  var dragPayloadForRow: ((Int, NSEvent.ModifierFlags) -> HistoryRowDragPayload?)?
  /// Called with the row under the pointer each time the pointer moves over
  /// the tiles. The grid only tracks the pointer while this is set.
  var onMouseMovedOverRow: ((Int) -> Void)? {
    didSet {
      if (oldValue == nil) != (onMouseMovedOverRow == nil) {
        updateTrackingAreas()
      }
    }
  }

  private(set) var selectedRowIndexes = IndexSet()
  private var rowFrames: [NSRect] = []
  /// The rows of the tiles in each line, top to bottom.
  private var lines: [[Int]] = []
  /// The line and the place in it of each tile, nil for a section header.
  private var tilePositions: [Int: (line: Int, column: Int)] = [:]
  private var laidOutWidth: CGFloat?
  private var contentHeight: CGFloat = 0
  private var tileViews: [Int: HistoryTileView] = [:]
  private var headerViews: [Int: HistorySectionHeaderCellView] = [:]
  private var reusableTileViews: [HistoryTileView] = []
  private var reusableHeaderViews: [HistorySectionHeaderCellView] = []
  private var clipViewBoundsObserver: NSObjectProtocol?
  private var mouseMovedTrackingArea: NSTrackingArea?
  private let dragSource = HistoryDragSource()
  private(set) var isDragSessionActive = false
  private static let dragThreshold: CGFloat = 4
  private static let fallbackDragImageSize = NSSize(width: 40, height: 40)

  override var isFlipped: Bool {
    true
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    autoresizingMask = [.width]
    setAccessibilityRole(.list)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Data

  /// Shows `rows` from scratch: the selection is cleared and every tile in
  /// sight is set up again.
  func reload(rows: [HistoryTableRow]) {
    self.rows = rows
    selectedRowIndexes = []
    contextualMenuRow = nil
    recycleAllViews()
    invalidateLayout()
  }

  /// Sets the tiles of `rows` up again, the ones in sight; the others are set
  /// up once they scroll in.
  func reloadRows(_ rowIndexes: IndexSet) {
    for row in rowIndexes {
      guard let tileView = tileViews[row], case .item(let item, let itemIndex) = rows[safe: row] else {
        continue
      }

      configureTile?(tileView, item, itemIndex)
      tileView.selectionState = selectionState?(row) ?? HistoryTileSelectionState()
    }
  }

  func reloadVisibleRows() {
    reloadRows(IndexSet(tileViews.keys))
  }

  /// Shows the selection, the keyboard focus and the selection order of the
  /// tiles in sight as they are now.
  func updateVisibleTileSelectionStates() {
    for (row, tileView) in tileViews {
      tileView.selectionState = selectionState?(row) ?? HistoryTileSelectionState()
    }
  }

  // MARK: - Selection

  var selectedRow: Int {
    selectedRowIndexes.first ?? -1
  }

  func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
    let selectableIndexes = IndexSet(indexes.filter(isItemRow(_:)))
    let newSelection = extend ? selectedRowIndexes.union(selectableIndexes) : selectableIndexes
    guard newSelection != selectedRowIndexes else {
      return
    }

    selectedRowIndexes = newSelection
    updateVisibleTileSelectionStates()
    onSelectionDidChange?()
  }

  override func selectAll(_ sender: Any?) {
    selectRowIndexes(IndexSet(rows.indices), byExtendingSelection: false)
  }

  func deselectAll(_ sender: Any?) {
    selectRowIndexes([], byExtendingSelection: false)
  }

  // MARK: - Geometry

  func rect(ofRow row: Int) -> NSRect {
    layOutRowsIfNeeded()
    return rowFrames[safe: row] ?? .zero
  }

  func row(at point: NSPoint) -> Int {
    layOutRowsIfNeeded()
    guard let row = firstRow(endingBelow: point.y) else {
      return -1
    }

    for candidate in row..<rowFrames.count {
      let frame = rowFrames[candidate]
      if frame.minY > point.y {
        break
      }
      if frame.contains(point), isItemRow(candidate) {
        return candidate
      }
    }
    return -1
  }

  /// The line of tiles a row is in, counted from the top, nil for a section header.
  func line(ofRow row: Int) -> Int? {
    layOutRowsIfNeeded()
    return tilePositions[row]?.line
  }

  /// The tile right above the one of `row`, or the last one of the line
  /// above when that line is shorter. Nil on the first line.
  func row(above row: Int) -> Int? {
    adjacentLineRow(to: row, lineOffset: -1)
  }

  /// The tile right below the one of `row`, or the last one of the line
  /// below when that line is shorter. Nil on the last line.
  func row(below row: Int) -> Int? {
    adjacentLineRow(to: row, lineOffset: 1)
  }

  private func adjacentLineRow(to row: Int, lineOffset: Int) -> Int? {
    layOutRowsIfNeeded()
    guard let position = tilePositions[row],
          let line = lines[safe: position.line + lineOffset],
          !line.isEmpty else {
      return nil
    }

    return line[min(position.column, line.count - 1)]
  }

  func scrollRowToVisible(_ row: Int) {
    let rowRect = rect(ofRow: row)
    guard !rowRect.isEmpty else {
      return
    }

    scrollToVisible(rowRect)
  }

  private func isItemRow(_ row: Int) -> Bool {
    if case .item = rows[safe: row] {
      return true
    }

    return false
  }

  // MARK: - Layout

  override func setFrameSize(_ newSize: NSSize) {
    if laidOutWidth.map({ abs($0 - newSize.width) > 0.5 }) ?? true {
      layOutRows(width: newSize.width)
    }

    // The grid is as tall as its tiles, whatever height it is given.
    super.setFrameSize(NSSize(width: newSize.width, height: contentHeight))
    needsLayout = true
  }

  override func layout() {
    super.layout()
    updateVisibleViews()
  }

  override func viewWillMove(toSuperview newSuperview: NSView?) {
    super.viewWillMove(toSuperview: newSuperview)
    if let clipViewBoundsObserver {
      NotificationCenter.default.removeObserver(clipViewBoundsObserver)
      self.clipViewBoundsObserver = nil
    }
  }

  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    guard let clipView = superview as? NSClipView else {
      return
    }

    // The tiles that scroll into sight get their views as the list scrolls.
    clipView.postsBoundsChangedNotifications = true
    clipViewBoundsObserver = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: clipView,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updateVisibleViews()
      }
    }
    if let width = laidOutWidth, abs(width - clipView.bounds.width) <= 0.5 {
      return
    }
    setFrameSize(NSSize(width: clipView.bounds.width, height: frame.height))
  }

  private func invalidateLayout() {
    laidOutWidth = nil
    layOutRowsIfNeeded()
    super.setFrameSize(NSSize(width: frame.width, height: contentHeight))
    updateVisibleViews()
  }

  private func layOutRowsIfNeeded() {
    guard laidOutWidth == nil else {
      return
    }

    layOutRows(width: frame.width)
  }

  private func layOutRows(width: CGFloat) {
    laidOutWidth = width

    let availableWidth = max(0, width - HistoryTile.horizontalInset * 2)
    let columnCount = max(1, Int(availableWidth / HistoryTile.minimumWidth))
    let tileWidth = floor(availableWidth / CGFloat(columnCount))
    let tileHeight = HistoryTile.height(forWidth: tileWidth)

    var frames: [NSRect] = []
    frames.reserveCapacity(rows.count)
    var lines: [[Int]] = []
    var positions: [Int: (line: Int, column: Int)] = [:]
    var y: CGFloat = 0
    var column = 0

    for (row, tableRow) in rows.enumerated() {
      switch tableRow {
      case .sectionHeader:
        if column > 0 {
          y += tileHeight
          column = 0
        }
        let height = row == 0 ? HistoryRow.sectionHeaderFirstHeight : HistoryRow.sectionHeaderHeight
        frames.append(NSRect(x: 0, y: y, width: width, height: height))
        y += height
      case .item:
        if column == 0 {
          lines.append([])
        }
        frames.append(NSRect(
          x: HistoryTile.horizontalInset + CGFloat(column) * tileWidth,
          y: y,
          width: tileWidth,
          height: tileHeight
        ))
        lines[lines.count - 1].append(row)
        positions[row] = (lines.count - 1, column)
        column += 1
        if column == columnCount {
          y += tileHeight
          column = 0
        }
      }
    }
    if column > 0 {
      y += tileHeight
    }

    rowFrames = frames
    self.lines = lines
    tilePositions = positions
    contentHeight = y
    // Tiles of another size need pictures of another size.
    if let anyTileView = tileViews.values.first, anyTileView.frame.size != NSSize(width: tileWidth, height: tileHeight) {
      recycleAllViews()
    }
  }

  /// The first row whose frame reaches below `y`. The frames go down the
  /// grid in row order, so it is found by halving.
  private func firstRow(endingBelow y: CGFloat) -> Int? {
    var low = 0
    var high = rowFrames.count
    while low < high {
      let middle = (low + high) / 2
      if rowFrames[middle].maxY <= y {
        low = middle + 1
      } else {
        high = middle
      }
    }
    return low < rowFrames.count ? low : nil
  }

  private func visibleRows() -> [Int] {
    layOutRowsIfNeeded()
    // A line above and below the visible part is set up ahead, so tiles
    // already show their pictures as they scroll in.
    let overscan = rowFrames.first(where: { $0.width < bounds.width })?.height ?? 0
    let area = visibleRect.insetBy(dx: 0, dy: -overscan)
    guard !area.isEmpty, let firstRow = firstRow(endingBelow: area.minY) else {
      return []
    }

    var rows: [Int] = []
    for row in firstRow..<rowFrames.count {
      if rowFrames[row].minY >= area.maxY {
        break
      }
      rows.append(row)
    }
    return rows
  }

  private func updateVisibleViews() {
    let visibleRows = visibleRows()
    let visibleRowSet = Set(visibleRows)

    for (row, tileView) in tileViews where !visibleRowSet.contains(row) {
      tileViews[row] = nil
      recycle(tileView)
    }
    for (row, headerView) in headerViews where !visibleRowSet.contains(row) {
      headerViews[row] = nil
      recycle(headerView)
    }

    for row in visibleRows {
      switch rows[row] {
      case .sectionHeader(let title):
        let headerView = headerViews[row] ?? dequeueHeaderView()
        if headerViews[row] == nil {
          headerViews[row] = headerView
          headerView.configure(title: title, isFirst: row == 0)
        }
        headerView.frame = rowFrames[row]
      case .item(let item, let itemIndex):
        if let tileView = tileViews[row] {
          tileView.frame = rowFrames[row]
          continue
        }

        let tileView = dequeueTileView()
        tileViews[row] = tileView
        tileView.frame = rowFrames[row]
        configureTile?(tileView, item, itemIndex)
        tileView.selectionState = selectionState?(row) ?? HistoryTileSelectionState()
      }
    }
  }

  private func dequeueTileView() -> HistoryTileView {
    let tileView = reusableTileViews.popLast() ?? HistoryTileView()
    if tileView.superview !== self {
      addSubview(tileView)
    }
    tileView.isHidden = false
    return tileView
  }

  private func dequeueHeaderView() -> HistorySectionHeaderCellView {
    let headerView = reusableHeaderViews.popLast() ?? HistorySectionHeaderCellView()
    if headerView.superview !== self {
      addSubview(headerView)
    }
    headerView.isHidden = false
    return headerView
  }

  // Views out of sight stay in the grid, hidden, until a row scrolls in.
  private func recycle(_ tileView: HistoryTileView) {
    tileView.isHidden = true
    tileView.clearForReuse()
    reusableTileViews.append(tileView)
  }

  private func recycle(_ headerView: HistorySectionHeaderCellView) {
    headerView.isHidden = true
    reusableHeaderViews.append(headerView)
  }

  private func recycleAllViews() {
    tileViews.values.forEach(recycle(_:))
    headerViews.values.forEach(recycle(_:))
    tileViews = [:]
    headerViews = [:]
  }

  // MARK: - Mouse

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

    guard let onMouseMovedOverRow, !isDragSessionActive, isPointerOverGrid(event) else {
      return
    }

    onMouseMovedOverRow(row(at: convert(event.locationInWindow, from: nil)))
  }

  /// The tracking area covers the whole visible part of the grid, also where
  /// the toolbar or another view covers it. Only a pointer that would land on
  /// the grid itself counts as being over it.
  private func isPointerOverGrid(_ event: NSEvent) -> Bool {
    guard let frameView = window?.contentView?.superview,
          let hitView = frameView.hitTest(event.locationInWindow) else {
      return false
    }

    return hitView.isDescendant(of: self)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // The tiles are pictures of the items, not controls: every click goes to the grid.
    let hitView = super.hitTest(point)
    return hitView == nil ? nil : self
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let row = row(at: convert(event.locationInWindow, from: nil))
    guard row >= 0 else {
      return nil
    }

    contextualMenuRow = row
    return menu
  }

  override func mouseDown(with event: NSEvent) {
    let clickedRow = row(at: convert(event.locationInWindow, from: nil))
    lastMouseDownRow = clickedRow
    window?.makeFirstResponder(self)

    guard onMouseDownSelection?(clickedRow, event) == true else {
      lastMouseDownRow = nil
      super.mouseDown(with: event)
      return
    }

    // The selection is already applied, so the rest of the press decides
    // between a click and a drag of the selected tiles.
    if trackMouseUntilDragOrRelease(after: event, row: clickedRow) {
      return
    }

    onMouseUpSelection?(clickedRow, event)
    onItemClick?(clickedRow, event)
  }

  // MARK: - Dragging out of the history

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
      guard distance >= Self.dragThreshold, selectedRowIndexes.contains(row) else {
        continue
      }

      if beginDragSession(with: mouseDown) {
        return true
      }
    }

    return false
  }

  private func beginDragSession(with event: NSEvent) -> Bool {
    var draggingItems: [NSDraggingItem] = []
    var containsFileURLs = false
    // The modifiers held as the drag begins pick the payload.
    let modifierFlags = NSEvent.modifierFlags.intersection([.command, .shift, .option, .control])

    for row in selectedRowIndexes {
      guard let payload = dragPayloadForRow?(row, modifierFlags), !payload.entries.isEmpty else {
        continue
      }

      containsFileURLs = containsFileURLs || payload.containsFileURLs
      draggingItems.append(contentsOf: makeDraggingItems(for: payload, row: row))
    }

    guard !draggingItems.isEmpty else {
      return false
    }

    dragSource.containsFileURLs = containsFileURLs
    dragSource.allowsMoveWithinApplication = false
    dragSource.onEnded = { [weak self] _ in
      self?.isDragSessionActive = false
    }

    isDragSessionActive = true
    let session = beginDraggingSession(with: draggingItems, event: event, source: dragSource)
    session.animatesToStartingPositionsOnCancelOrFail = true
    session.draggingFormation = draggingItems.count > 1 ? .stack : .default
    return true
  }

  private func makeDraggingItems(for payload: HistoryRowDragPayload, row: Int) -> [NSDraggingItem] {
    let tileRect = rect(ofRow: row)

    if payload.entries.count == 1, let entry = payload.entries.first {
      let draggingItem = NSDraggingItem(pasteboardWriter: entry.writer)
      if let snapshot = snapshotImage(forRow: row) {
        draggingItem.setDraggingFrame(tileRect, contents: snapshot)
      } else {
        draggingItem.setDraggingFrame(fallbackDragFrame(in: tileRect), contents: entry.icon)
      }
      return [draggingItem]
    }

    // Several entries stand for several files: each gets its own icon, laid
    // out across the tile so they lift off from where the tile is.
    let iconSize = payload.entries.first?.icon?.size ?? Self.fallbackDragImageSize
    let spacing: CGFloat = 8
    return payload.entries.enumerated().map { index, entry in
      let draggingItem = NSDraggingItem(pasteboardWriter: entry.writer)
      let originX = tileRect.minX + HistoryTile.cardInset + CGFloat(index) * (iconSize.width + spacing)
      let frame = NSRect(
        x: min(originX, tileRect.maxX - iconSize.width),
        y: tileRect.midY - iconSize.height / 2,
        width: iconSize.width,
        height: iconSize.height
      )
      draggingItem.setDraggingFrame(frame, contents: entry.icon)
      return draggingItem
    }
  }

  private func fallbackDragFrame(in tileRect: NSRect) -> NSRect {
    NSRect(
      x: tileRect.midX - Self.fallbackDragImageSize.width / 2,
      y: tileRect.midY - Self.fallbackDragImageSize.height / 2,
      width: Self.fallbackDragImageSize.width,
      height: Self.fallbackDragImageSize.height
    )
  }

  /// A picture of the tile as it is drawn, selection included. Tiles scrolled
  /// out of view have no view to draw and get no snapshot.
  private func snapshotImage(forRow row: Int) -> NSImage? {
    guard let tileView = tileViews[row] else {
      return nil
    }

    let bounds = tileView.bounds
    guard bounds.width > 0, bounds.height > 0,
          let representation = tileView.bitmapImageRepForCachingDisplay(in: bounds) else {
      return nil
    }

    tileView.cacheDisplay(in: bounds, to: representation)
    let image = NSImage(size: bounds.size)
    image.addRepresentation(representation)
    return image
  }

  // MARK: - Keyboard

  override func keyDown(with event: NSEvent) {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if let step = Self.selectionStep(forKeyCode: event.keyCode) {
      if modifiers.isEmpty {
        onMoveSelectionKeyDown?(step)
        return
      }
      if modifiers == .shift {
        onExtendSelectionKeyDown?(step)
        return
      }
    }

    if isSearchKeyDown(event) {
      onSearchKeyDown?(event)
      return
    }

    super.keyDown(with: event)
  }

  static func selectionStep(forKeyCode keyCode: UInt16) -> HistorySelectionStep? {
    switch keyCode {
    case 123:
      return .previous
    case 124:
      return .next
    case 125:
      return .down
    case 126:
      return .up
    default:
      return nil
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

/// One item of the grid: its picture, big enough to tell what is on it, and
/// a caption with its name.
@MainActor
final class HistoryTileView: NSView {
  private let cardView = HistoryTileCardView()
  private let imageView = NSImageView()
  private let titleField = NSTextField(labelWithString: "")
  private let favoriteView = FavoriteView.make(isFavorite: false)
  private let quickPasteField = NSTextField(labelWithString: "")
  private let sourceAppIconView = NSImageView()
  private let selectionOrderBadgeView = HistorySelectionOrderBadgeView()
  private var configuredItemID: UUID?

  var selectionState = HistoryTileSelectionState() {
    didSet {
      guard selectionState != oldValue else {
        return
      }

      selectionOrderBadgeView.number = selectionState.selectionOrderNumber
      selectionOrderBadgeView.isHidden = selectionState.selectionOrderNumber == nil
      cardView.selectionBorderStyle = selectionBorderStyle
    }
  }

  override var isFlipped: Bool {
    true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Shows the item. The picture is decoded in the background unless it was
  /// decoded at this size before.
  func configure(item: ClipboardItem, quickPasteIndex: Int?) {
    let isSameItem = configuredItemID == item.id
    configuredItemID = item.id

    let title = Self.title(for: item)
    titleField.stringValue = title
    toolTip = title
    setAccessibilityLabel(title)
    favoriteView.isHidden = !item.isFavorite
    quickPasteField.stringValue = quickPasteIndex.map { "⌘\($0)" } ?? ""
    quickPasteField.isHidden = quickPasteIndex == nil
    let sourceAppIcon = HistorySourceAppIcon.image(
      bundleIdentifier: item.sourceBundleIdentifier,
      appName: item.sourceAppName,
      size: HistoryTile.sourceAppIconSize
    )
    sourceAppIconView.image = sourceAppIcon
    sourceAppIconView.toolTip = item.sourceAppName
    sourceAppIconView.isHidden = sourceAppIcon == nil
    needsLayout = true

    if !isSameItem {
      imageView.image = nil
    }
    loadPicture(for: item)
  }

  func clearForReuse() {
    configuredItemID = nil
    imageView.image = nil
    selectionState = HistoryTileSelectionState()
  }

  private static func title(for item: ClipboardItem) -> String {
    if let title = item.itemTitle {
      return title
    }

    if item.isMultipleFileItem {
      return "\(item.filePaths.count) items"
    }

    return item.contentTitle
  }

  private func loadPicture(for item: ClipboardItem) {
    let url: URL
    if item.kind == .image, let assetURL = item.assetURL {
      url = assetURL
    } else if let filePath = item.filePaths.first {
      url = URL(fileURLWithPath: filePath)
    } else {
      return
    }

    let pictureSize = pictureFrame().size
    guard pictureSize.width > 0, pictureSize.height > 0 else {
      return
    }

    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    let maximumPixelSize = ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: pictureSize, scale: scale)
    let itemID = item.id
    let isFile = item.kind == .file
    let cachedImage = ImageAssetThumbnailLoader.shared.thumbnail(
      for: url,
      maximumPixelSize: maximumPixelSize
    ) { [weak self] image in
      guard let self, self.configuredItemID == itemID else {
        return
      }

      self.showPicture(image, fileURL: isFile ? url : nil)
    }
    if let cachedImage {
      showPicture(cachedImage, fileURL: nil)
    }
  }

  /// A file that can't be read, gone or in a format the thumbnails can't be
  /// made of, shows its icon instead.
  private func showPicture(_ image: NSImage?, fileURL: URL?) {
    if let image {
      imageView.image = image
    } else if let fileURL {
      imageView.image = NSWorkspace.shared.icon(forFile: fileURL.path)
    }
    needsLayout = true
  }

  override func layout() {
    super.layout()

    cardView.frame = bounds.insetBy(dx: HistoryTile.cardInset, dy: HistoryTile.cardInset)
    let pictureFrame = pictureFrame()
    imageView.frame = imageFrame(in: pictureFrame)
    selectionOrderBadgeView.frame = NSRect(
      x: HistoryTile.selectionOrderBadgeInset,
      y: HistoryTile.selectionOrderBadgeInset,
      width: HistoryRow.selectionOrderBadgeSize,
      height: HistoryRow.selectionOrderBadgeSize
    )

    let captionHeight = HistoryTile.captionHeight()
    let captionY = pictureFrame.maxY + HistoryTile.captionVerticalPadding
    let captionMinX = HistoryTile.captionHorizontalPadding
    // The app icon sits in the corner of the card, as far from its right
    // edge as from its bottom edge.
    var trailingX = cardView.bounds.width
      - (sourceAppIconView.isHidden ? HistoryTile.captionHorizontalPadding : HistoryTile.captionVerticalPadding)
    // The same order as in a row of the list: favorite, shortcut, app.
    for accessoryView in [sourceAppIconView, quickPasteField, favoriteView] as [NSView] where !accessoryView.isHidden {
      let size = accessoryView === sourceAppIconView
        ? NSSize(width: HistoryTile.sourceAppIconSize, height: HistoryTile.sourceAppIconSize)
        : accessoryView.fittingSize
      trailingX -= size.width
      accessoryView.frame = NSRect(
        x: trailingX,
        y: captionY + (captionHeight - size.height) / 2,
        width: size.width,
        height: size.height
      )
      trailingX -= HistoryTile.accessorySpacing
    }
    let titleHeight = ceil(HistoryTile.makeCaptionFont().historyLineHeight)
    titleField.frame = NSRect(
      x: captionMinX,
      y: captionY + (captionHeight - titleHeight) / 2,
      width: max(0, trailingX - captionMinX),
      height: titleHeight
    )
  }

  /// Where the picture is in the card: across its width and at its top, with
  /// room around it.
  private func pictureFrame() -> NSRect {
    NSRect(
      x: HistoryTile.picturePadding,
      y: HistoryTile.picturePadding,
      width: max(0, bounds.width - HistoryTile.cardInset * 2 - HistoryTile.picturePadding * 2),
      height: max(0, HistoryTile.pictureHeight(forWidth: bounds.width))
    )
  }

  /// The picture fit into its place and centered there, never made bigger
  /// than it is, so its own corners are the ones rounded.
  private func imageFrame(in pictureFrame: NSRect) -> NSRect {
    guard let imageSize = imageView.image?.size, imageSize.width > 0, imageSize.height > 0 else {
      return pictureFrame
    }

    let scale = min(1, pictureFrame.width / imageSize.width, pictureFrame.height / imageSize.height)
    let size = NSSize(width: round(imageSize.width * scale), height: round(imageSize.height * scale))
    return NSRect(
      x: round(pictureFrame.midX - size.width / 2),
      y: round(pictureFrame.midY - size.height / 2),
      width: size.width,
      height: size.height
    )
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    needsLayout = true
  }

  private var selectionBorderStyle: HistoryTileCardView.SelectionBorderStyle {
    let state = selectionState
    guard state.isSelected else {
      // The item the keyboard is on in a multiple selection, not picked yet.
      return state.isKeyboardMultipleSelectionMode && state.isKeyboardSelectionFocused ? .focused : .none
    }

    return .selected
  }

  private func configure() {
    wantsLayer = true
    setAccessibilityElement(true)
    setAccessibilityRole(.image)

    imageView.imageScaling = .scaleProportionallyDown
    imageView.imageAlignment = .alignCenter
    imageView.animates = false
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = HistoryTile.pictureCornerRadius
    imageView.layer?.cornerCurve = .continuous
    imageView.layer?.masksToBounds = true

    let captionFont = HistoryTile.makeCaptionFont()
    titleField.font = captionFont
    titleField.textColor = .labelColor
    titleField.lineBreakMode = .byTruncatingMiddle
    titleField.maximumNumberOfLines = 1

    quickPasteField.font = .monospacedDigitSystemFont(ofSize: captionFont.pointSize, weight: .regular)
    quickPasteField.textColor = .tertiaryLabelColor

    favoriteView.symbolConfiguration = NSImage.SymbolConfiguration(
      pointSize: HistoryTile.favoriteSymbolSize,
      weight: .regular
    )

    sourceAppIconView.imageScaling = .scaleProportionallyDown

    selectionOrderBadgeView.isHidden = true

    cardView.translatesAutoresizingMaskIntoConstraints = true
    addSubview(cardView)
    for subview in [imageView, selectionOrderBadgeView, titleField, favoriteView, quickPasteField, sourceAppIconView] as [NSView] {
      subview.translatesAutoresizingMaskIntoConstraints = true
      cardView.addSubview(subview)
    }
  }
}

/// The rounded card of a tile. It clips the picture to its corners and draws
/// the selection border over it.
@MainActor
final class HistoryTileCardView: NSView {
  enum SelectionBorderStyle {
    case none
    case selected
    case focused
  }

  var selectionBorderStyle = SelectionBorderStyle.none {
    didSet {
      if oldValue != selectionBorderStyle {
        needsDisplay = true
      }
    }
  }

  override var isFlipped: Bool {
    true
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.cornerRadius = HistoryTile.cardCornerRadius
    layer?.cornerCurve = .continuous
    layer?.masksToBounds = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // Called within the view's appearance, so the colors resolve for it, and
  // again when the accent color changes.
  override func updateLayer() {
    layer?.backgroundColor = HistoryTile.cardBackgroundColor.cgColor
    switch selectionBorderStyle {
    case .none:
      layer?.borderWidth = 0
    case .selected:
      layer?.borderWidth = HistoryTile.selectionBorderWidth
      layer?.borderColor = NSColor.controlAccentColor.cgColor
    case .focused:
      layer?.borderWidth = HistoryTile.selectionBorderWidth
      layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
    }
  }
}

/// A step of the selection through the history. In the list going up is
/// going to the previous item; in the tiles it is going to the tile above.
enum HistorySelectionStep {
  case previous
  case next
  case up
  case down
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
