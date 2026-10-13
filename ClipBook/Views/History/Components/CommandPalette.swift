import AppKit

struct CommandPaletteCommand {
  let title: String
  let description: String?
  let shortcut: String?
  let image: NSImage?
  let systemImageName: String
  let showsIcon: Bool
  let sectionTitle: String?
  let section: Int
  let isDestructive: Bool
  let isChecked: Bool
  /// A command that only clutters the list when nothing is typed, but is worth
  /// finding by name, is shown for a search query only.
  var showsOnlyWhenSearching = false
  /// Whether the command still works once the trial is over and the history
  /// is read-only: it looks at or organizes items rather than using them.
  var isAvailableInReadOnlyHistory = false
  let action: () -> Void
  /// Runs instead of `action` when the command is executed with Cmd+Return.
  var alternateAction: (() -> Void)? = nil
}

final class CommandPalette: NSViewController {
  var onDismiss: (() -> Void)?
  private let commands: [CommandPaletteCommand]
  private let maximumContentSize: NSSize
  private let searchPlaceholderText: String
  private let dismissalShortcut: String
  private let footerText: String?
  private var paletteView: CommandPaletteView? {
    view as? CommandPaletteView
  }

  /// The palette is as tall as its commands need, up to the height of
  /// `maximumContentSize`, and scrolls past that.
  init(
    commands: [CommandPaletteCommand],
    maximumContentSize: NSSize,
    searchPlaceholderText: String,
    dismissalShortcut: String,
    footerText: String? = nil
  ) {
    self.commands = commands
    self.maximumContentSize = maximumContentSize
    self.searchPlaceholderText = searchPlaceholderText
    self.dismissalShortcut = dismissalShortcut
    self.footerText = footerText
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let contentView = CommandPaletteView(
      commands: commands,
      searchPlaceholderText: searchPlaceholderText,
      dismissalShortcut: dismissalShortcut,
      footerText: footerText,
      maximumHeight: maximumContentSize.height,
      frame: NSRect(origin: .zero, size: maximumContentSize)
    )
    contentView.setFrameSize(NSSize(width: maximumContentSize.width, height: contentView.preferredHeight))
    contentView.onPreferredHeightChange = { [weak self] height in
      self?.updateHeight(height)
    }
    contentView.onCancel = { [weak self] in
      self?.dismiss(nil)
    }
    contentView.onExecute = { [weak self] command, usesAlternateAction in
      if usesAlternateAction, let alternateAction = command.alternateAction {
        alternateAction()
      } else {
        command.action()
      }
      self?.dismiss(nil)
    }
    view = contentView
    preferredContentSize = contentView.frame.size
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    paletteView?.focusSearchField()
  }

  override func viewDidDisappear() {
    super.viewDidDisappear()
    onDismiss?()
  }

override func cancelOperation(_ sender: Any?) {
  dismiss(nil)
}

  /// Fits the sheet to the commands a search leaves. The top edge stays where
  /// it is, so the search field does not move under the user while typing.
  private func updateHeight(_ height: CGFloat) {
    preferredContentSize = NSSize(width: maximumContentSize.width, height: height)
    guard let window = view.window else {
      view.setFrameSize(preferredContentSize)
      return
    }

    var frame = window.frame
    let heightDelta = height - window.contentRect(forFrameRect: frame).height
    guard heightDelta != 0 else {
      return
    }

    frame.origin.y -= heightDelta
    frame.size.height += heightDelta
    if let window = window as? CommandPaletteSheetWindow {
      window.setFrameKeepingTopEdge(frame)
    } else {
      window.setFrame(frame, display: true)
    }
  }
}

/// Shows the palette as a sheet of the presenting view controller's window, in
/// a window that can change its height without moving its top edge.
final class CommandPaletteSheetAnimator: NSObject, NSViewControllerPresentationAnimator {
  func animatePresentation(of viewController: NSViewController, from fromViewController: NSViewController) {
    guard let parentWindow = fromViewController.view.window else {
      return
    }

    let sheetWindow = CommandPaletteSheetWindow(contentViewController: viewController)
    // The sheet style is set up front, like presentAsSheet does, so the
    // content keeps the size it asked for.
    sheetWindow.styleMask.insert(.docModalWindow)
    sheetWindow.isReleasedWhenClosed = false
    parentWindow.beginSheet(sheetWindow)
  }

  func animateDismissal(of viewController: NSViewController, from fromViewController: NSViewController) {
    guard let sheetWindow = viewController.view.window else {
      return
    }

    sheetWindow.sheetParent?.endSheet(sheetWindow)
  }
}

/// The window of a command palette sheet.
///
/// Since macOS 26 AppKit centers a sheet in its parent window again whenever
/// the sheet changes size, so the search field would jump on every keystroke
/// that changes the number of results. While the palette resizes itself, it
/// reports a private `sheetBehavior` other than "centered", which makes AppKit
/// attach the sheet's top edge to the rect from the parent window delegate's
/// `window(_:willPositionSheet:using:)`, and that rect is placed at the current
/// top edge. The sheet still appears in the usual place.
final class CommandPaletteSheetWindow: NSWindow {
  private static let sheetBehaviorSelector = NSSelectorFromString("sheetBehavior")
  /// How far above the positioning rect AppKit puts an attached sheet's top
  /// edge. It is learned from the first resize that misses its target.
  private static var attachedTopEdgeOffset: CGFloat = 0
  private var pinnedTopEdge: CGFloat?

  func setFrameKeepingTopEdge(_ frame: NSRect) {
    guard let parentFrame = sheetParent?.frame,
          NSWindow.instancesRespond(to: Self.sheetBehaviorSelector) else {
      setFrame(frame, display: true)
      return
    }

    // A palette that grows during a search moves up rather than past the
    // bottom of the parent window.
    var frame = frame
    frame.origin.y = max(frame.minY, parentFrame.minY)
    pinnedTopEdge = frame.maxY
    defer {
      pinnedTopEdge = nil
    }

    setFrame(frame, display: false)
    let missedBy = self.frame.maxY - frame.maxY
    if missedBy != 0 {
      Self.attachedTopEdgeOffset += missedBy
      setFrame(frame, display: false)
    }
    display()
  }

  /// The rect for `window(_:willPositionSheet:using:)` that keeps the top edge
  /// in place, or nil when the sheet is positioned the usual way.
  func positioningRect(in parentWindow: NSWindow, proposedRect rect: NSRect) -> NSRect? {
    guard let pinnedTopEdge else {
      return nil
    }

    let y = pinnedTopEdge - parentWindow.frame.minY - Self.attachedTopEdgeOffset
    return NSRect(x: rect.minX, y: y, width: rect.width, height: 0)
  }

  @objc var sheetBehavior: UInt {
    guard pinnedTopEdge == nil,
          let method = class_getInstanceMethod(NSWindow.self, Self.sheetBehaviorSelector) else {
      return 0
    }

    typealias Getter = @convention(c) (NSWindow, Selector) -> UInt
    return unsafeBitCast(method_getImplementation(method), to: Getter.self)(self, Self.sheetBehaviorSelector)
  }
}

private enum CommandPaletteRow {
  case sectionHeader(String, hasTopSpacing: Bool)
  case divider
  case command(CommandPaletteCommand)

  var isCommand: Bool {
    if case .command = self {
      return true
    }

    return false
  }
}

private final class CommandPaletteView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
  var onCancel: (() -> Void)?
  var onExecute: ((CommandPaletteCommand, _ usesAlternateAction: Bool) -> Void)?

  private let commands: [CommandPaletteCommand]
  private let searchPlaceholderText: String
  private let dismissalShortcut: String
  private let footerText: String?
  private var rows: [CommandPaletteRow] = []
  private let searchContainer = NSView()
  private let searchIconView = NSImageView()
  private let searchField = CommandPaletteSearchField()
  private let searchDivider = CommandPaletteDividerView()
  private let tableView = CommandPaletteTableView()
  private let scrollView = NSScrollView()
  private let noResultsLabel = NSTextField(labelWithString: L10n.string("No Results"))
  private let footerContainer = NSView()
  private let footerDivider = CommandPaletteDividerView()
  private let footerLabel = NSTextField(labelWithString: "")
  private let maximumHeight: CGFloat
  private(set) var preferredHeight: CGFloat = 0
  var onPreferredHeightChange: ((CGFloat) -> Void)?
  private static let searchContainerHeight: CGFloat = 52
  private static let listVerticalInset: CGFloat = 8
  private static let noResultsHeight: CGFloat = 80
  private static let footerHeight: CGFloat = 30

  init(
    commands: [CommandPaletteCommand],
    searchPlaceholderText: String,
    dismissalShortcut: String,
    footerText: String?,
    maximumHeight: CGFloat,
    frame frameRect: NSRect
  ) {
    self.commands = commands
    self.searchPlaceholderText = searchPlaceholderText
    self.dismissalShortcut = dismissalShortcut
    self.footerText = footerText
    self.maximumHeight = maximumHeight
    super.init(frame: frameRect)
    configure()
    reloadRows()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateBackgroundColor()
  }

  func focusSearchField() {
    window?.makeFirstResponder(searchField)
  }

  override func keyDown(with event: NSEvent) {
    if handleKeyDown(event) {
      return
    }

    super.keyDown(with: event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if KeyboardShortcutParser.event(event, matches: dismissalShortcut) {
      onCancel?()
      return true
    }

    // Cmd+Return is a key equivalent, so it never reaches the search field as
    // a plain Return and has to be picked up here.
    if Self.isAlternateExecutionEvent(event), selectedCommand?.alternateAction != nil {
      executeSelectedCommand(usesAlternateAction: true)
      return true
    }

    return super.performKeyEquivalent(with: event)
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    rows.count
  }

  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    switch rows[row] {
    case .sectionHeader(_, let hasTopSpacing):
      return hasTopSpacing ? 34 : 24
    case .divider:
      return 12
    case .command(let command):
      return command.description?.isEmpty == false ? 50 : 34
    }
  }

  func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
    if case .command = rows[row] {
      return true
    }

    return false
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    switch rows[row] {
    case .sectionHeader(let title, let hasTopSpacing):
      let identifier = NSUserInterfaceItemIdentifier("CommandPaletteSectionHeaderCell")
      let view = tableView.makeView(withIdentifier: identifier, owner: self) as? CommandPaletteSectionHeaderCellView
        ?? CommandPaletteSectionHeaderCellView()
      view.identifier = identifier
      view.configure(title: title, hasTopSpacing: hasTopSpacing)
      return view
    case .divider:
      let identifier = NSUserInterfaceItemIdentifier("CommandPaletteDividerCell")
      let view = tableView.makeView(withIdentifier: identifier, owner: self) as? CommandPaletteDividerCellView
        ?? CommandPaletteDividerCellView()
      view.identifier = identifier
      return view
    case .command(let command):
      let identifier = NSUserInterfaceItemIdentifier("CommandPaletteCommandCell")
      let view = tableView.makeView(withIdentifier: identifier, owner: self) as? CommandPaletteCommandCellView
        ?? CommandPaletteCommandCellView()
      view.identifier = identifier
      view.configure(command)
      return view
    }
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    scrollSelectedRowToVisible()
  }

  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    if case .command = rows[row] {
      return CommandPaletteRowView()
    }

    return NSTableRowView()
  }

  func controlTextDidChange(_ obj: Notification) {
    reloadRows()
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.moveUp(_:)):
      moveSelection(.up)
      return true
    case #selector(NSResponder.moveDown(_:)):
      moveSelection(.down)
      return true
    case #selector(NSResponder.insertNewline(_:)):
      executeSelectedCommand()
      return true
    case #selector(NSResponder.cancelOperation(_:)):
      if clearSearchQuery() {
        return true
      }

      onCancel?()
      return true
    default:
      return false
    }
  }

  private func configure() {
    wantsLayer = true
    updateBackgroundColor()

    configureSearchField()
    configureTableView()
    configureNoResultsLabel()
    configureFooter()

    addSubview(searchContainer)
    addSubview(scrollView)
    addSubview(noResultsLabel)
    addSubview(footerContainer)

    NSLayoutConstraint.activate([
      searchContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      searchContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
      searchContainer.topAnchor.constraint(equalTo: topAnchor),
      searchContainer.heightAnchor.constraint(equalToConstant: Self.searchContainerHeight),

      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor),
      scrollView.bottomAnchor.constraint(equalTo: footerContainer.topAnchor),

      footerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      footerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
      footerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      footerContainer.heightAnchor.constraint(equalToConstant: footerText == nil ? 0 : Self.footerHeight),

      noResultsLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
      noResultsLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
    ])
  }

  private func updateBackgroundColor() {
    var backgroundColor = NSColor.windowBackgroundColor.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    layer?.backgroundColor = backgroundColor
  }

  private func configureSearchField() {
    let font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 1, weight: .regular)
    searchContainer.translatesAutoresizingMaskIntoConstraints = false

    searchIconView.translatesAutoresizingMaskIntoConstraints = false
    searchIconView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: L10n.string("Search"))?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
    searchIconView.contentTintColor = .placeholderTextColor

    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.font = font
    searchField.textColor = .labelColor
    searchField.placeholderAttributedString = NSAttributedString(
      string: searchPlaceholderText,
      attributes: [
        .font: font,
        .foregroundColor: NSColor.placeholderTextColor
      ]
    )
    searchField.delegate = self
    searchField.focusRingType = .none
    searchField.isBordered = false
    searchField.drawsBackground = false
    searchField.onKeyDown = { [weak self] event in
      self?.handleKeyDown(event) ?? false
    }

    searchDivider.translatesAutoresizingMaskIntoConstraints = false

    searchContainer.addSubview(searchIconView)
    searchContainer.addSubview(searchField)
    searchContainer.addSubview(searchDivider)

    NSLayoutConstraint.activate([
      searchIconView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
      searchIconView.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
      searchIconView.widthAnchor.constraint(equalToConstant: 22),
      searchIconView.heightAnchor.constraint(equalToConstant: 22),

      searchField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 8),
      searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16),
      searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

      searchDivider.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
      searchDivider.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
      searchDivider.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor)
    ])
  }

  private func configureTableView() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = false
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInsets = NSEdgeInsets(
      top: Self.listVerticalInset,
      left: 0,
      bottom: Self.listVerticalInset,
      right: 0
    )
    scrollView.documentView = tableView

    tableView.headerView = nil
    tableView.style = .fullWidth
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .regular
    tableView.allowsMultipleSelection = false
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.dataSource = self
    tableView.delegate = self
    tableView.onMouseMovedOverRow = { [weak self] row in
      self?.selectCommandRow(at: row)
    }
    tableView.onMouseClickedRow = { [weak self] row in
      self?.executeCommand(at: row)
    }

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandPaletteCommandColumn"))
    column.resizingMask = .autoresizingMask
    tableView.addTableColumn(column)
  }

  private func configureNoResultsLabel() {
    noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
    noResultsLabel.font = .systemFont(ofSize: 14, weight: .regular)
    noResultsLabel.textColor = .secondaryLabelColor
    noResultsLabel.isHidden = true
  }

  private func configureFooter() {
    footerContainer.translatesAutoresizingMaskIntoConstraints = false
    footerContainer.isHidden = footerText == nil
    guard let footerText else {
      return
    }

    footerDivider.translatesAutoresizingMaskIntoConstraints = false
    footerLabel.translatesAutoresizingMaskIntoConstraints = false
    footerLabel.stringValue = footerText
    footerLabel.font = .systemFont(ofSize: 11, weight: .regular)
    footerLabel.textColor = .secondaryLabelColor
    footerLabel.lineBreakMode = .byTruncatingTail
    footerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    footerContainer.addSubview(footerDivider)
    footerContainer.addSubview(footerLabel)

    NSLayoutConstraint.activate([
      footerDivider.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor),
      footerDivider.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor),
      footerDivider.topAnchor.constraint(equalTo: footerContainer.topAnchor),

      footerLabel.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
      footerLabel.trailingAnchor.constraint(lessThanOrEqualTo: footerContainer.trailingAnchor, constant: -16),
      footerLabel.centerYAnchor.constraint(equalTo: footerContainer.centerYAnchor)
    ])
  }

  private func reloadRows() {
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let filteredCommands = commands.filter { command in
      guard !query.isEmpty else {
        return !command.showsOnlyWhenSearching
      }

      return command.title.localizedCaseInsensitiveContains(query)
        || (command.description?.localizedCaseInsensitiveContains(query) ?? false)
        || (command.shortcut?.localizedCaseInsensitiveContains(query) ?? false)
        || Self.shortcutDisplayTokens(for: command.shortcut).joined().localizedCaseInsensitiveContains(query)
    }

    rows = Self.rows(from: filteredCommands)
    let hasNoSearchResults = !query.isEmpty && filteredCommands.isEmpty
    scrollView.isHidden = hasNoSearchResults
    noResultsLabel.isHidden = !hasNoSearchResults
    tableView.reloadData()
    updatePreferredHeight(hasNoSearchResults: hasNoSearchResults)
    selectFirstCommand()
  }

  private func updatePreferredHeight(hasNoSearchResults: Bool) {
    let listHeight = hasNoSearchResults
      ? Self.noResultsHeight
      : rows.indices.reduce(Self.listVerticalInset * 2) { height, row in
        height + tableView(tableView, heightOfRow: row)
      }
    let footerHeight = footerText == nil ? 0 : Self.footerHeight
    let height = min(Self.searchContainerHeight + listHeight + footerHeight, maximumHeight).rounded()
    guard height != preferredHeight else {
      return
    }

    preferredHeight = height
    onPreferredHeightChange?(height)
  }

  private func clearSearchQuery() -> Bool {
    guard !searchField.stringValue.isEmpty else {
      return false
    }

    searchField.stringValue = ""
    reloadRows()
    return true
  }

  private static func rows(from commands: [CommandPaletteCommand]) -> [CommandPaletteRow] {
    var rows: [CommandPaletteRow] = []
    var lastSection: Int?

    for command in commands {
      if lastSection != command.section {
        if let lastSection, lastSection != command.section, rows.contains(where: \.isCommand), command.sectionTitle == nil {
          rows.append(.divider)
        }
        if let sectionTitle = command.sectionTitle, !sectionTitle.isEmpty {
          rows.append(.sectionHeader(sectionTitle, hasTopSpacing: rows.contains(where: \.isCommand)))
        }
      }

      rows.append(.command(command))
      lastSection = command.section
    }

    return rows
  }

  private func selectFirstCommand() {
    guard let firstIndex = rows.firstIndex(where: \.isCommand) else {
      tableView.deselectAll(nil)
      return
    }

    tableView.selectRowIndexes(IndexSet(integer: firstIndex), byExtendingSelection: false)
    scrollSelectedRowToVisible()
  }

  private func selectCommandRow(at row: Int) {
    guard isCommandRow(at: row), tableView.selectedRow != row else {
      return
    }

    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
  }

  private func moveSelection(_ direction: HistorySelectionDirection) {
    guard !rows.isEmpty else {
      return
    }

    let selectedRow = tableView.selectedRow
    let nextRow: Int?

    switch direction {
    case .up:
      if selectedRow < 0 {
        nextRow = lastCommandRow()
      } else {
        guard let previousRow = previousCommandRow(before: selectedRow) else {
          return
        }
        nextRow = previousRow
      }
    case .down:
      if selectedRow < 0 {
        nextRow = firstCommandRow()
      } else {
        guard let followingRow = nextCommandRow(after: selectedRow) else {
          return
        }
        nextRow = followingRow
      }
    }

    guard let nextRow else {
      return
    }

    tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
    scrollSelectedRowToVisible()
  }

  private func firstCommandRow() -> Int? {
    rows.indices.first(where: isCommandRow(at:))
  }

  private func lastCommandRow() -> Int? {
    rows.indices.last(where: isCommandRow(at:))
  }

  private func nextCommandRow(after row: Int) -> Int? {
    guard row + 1 < rows.count else {
      return nil
    }

    return (row + 1..<rows.count).first(where: isCommandRow(at:))
  }

  private func previousCommandRow(before row: Int) -> Int? {
    guard row > 0 else {
      return nil
    }

    return stride(from: row - 1, through: 0, by: -1).first(where: isCommandRow(at:))
  }

  private func isCommandRow(at index: Int) -> Bool {
    guard rows.indices.contains(index) else {
      return false
    }

    return rows[index].isCommand
  }

  private func scrollSelectedRowToVisible() {
    let row = tableView.selectedRow
    guard row >= 0 else {
      return
    }

    tableView.scrollRowToVisible(row)
  }

  private var selectedCommand: CommandPaletteCommand? {
    guard case .command(let command) = rows[safe: tableView.selectedRow] else {
      return nil
    }

    return command
  }

  private static func isAlternateExecutionEvent(_ event: NSEvent) -> Bool {
    event.type == .keyDown
      && event.keyCode == 36
      && event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]) == .command
  }

  private func executeSelectedCommand(usesAlternateAction: Bool = false) {
    executeCommand(at: tableView.selectedRow, usesAlternateAction: usesAlternateAction)
  }

  private func executeCommand(at row: Int, usesAlternateAction: Bool = false) {
    guard case .command(let command) = rows[safe: row] else {
      return
    }

    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    onExecute?(command, usesAlternateAction)
  }

  private func handleKeyDown(_ event: NSEvent) -> Bool {
    if KeyboardShortcutParser.event(event, matches: dismissalShortcut) {
      onCancel?()
      return true
    }

    if event.charactersIgnoringModifiers == "\u{1b}" {
      onCancel?()
      return true
    }

    if event.keyCode == 126 {
      moveSelection(.up)
      return true
    }

    if event.keyCode == 125 {
      moveSelection(.down)
      return true
    }

    if event.keyCode == 36 {
      executeSelectedCommand(usesAlternateAction: Self.isAlternateExecutionEvent(event))
      return true
    }

    return false
  }

  fileprivate static func shortcutDisplayTokens(for shortcut: String?) -> [String] {
    guard let shortcut, !shortcut.isEmpty else {
      return []
    }

    let parts = shortcut.split(separator: "+").map { String($0).lowercased() }
    let key = parts.last ?? shortcut
    let modifiers = parts.dropLast().map { part -> String in
      switch part {
      case "cmd", "command":
        return "⌘"
      case "shift":
        return "⇧"
      case "option", "alt":
        return "⌥"
      case "control", "ctrl":
        return "⌃"
      default:
        return part.capitalized
      }
    }

    return modifiers + [displayKey(for: key)]
  }

  private static func displayKey(for key: String) -> String {
    KeyboardShortcutParser.keyDisplayText(for: key)
  }
}

private final class CommandPaletteTableView: NSTableView {
  var onMouseMovedOverRow: ((Int) -> Void)?
  var onMouseClickedRow: ((Int) -> Void)?

  private var trackingArea: NSTrackingArea?
  private weak var mouseMovedEventsWindow: NSWindow?
  private var previousAcceptsMouseMovedEvents: Bool?

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    super.viewWillMove(toWindow: newWindow)

    if window !== newWindow {
      restoreMouseMovedEventsSettingIfNeeded()
    }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    guard let window else {
      return
    }

    mouseMovedEventsWindow = window
    previousAcceptsMouseMovedEvents = window.acceptsMouseMovedEvents
    window.acceptsMouseMovedEvents = true
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingArea {
      removeTrackingArea(trackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    onMouseMovedOverRow?(row(for: event))
  }

  override func mouseDown(with event: NSEvent) {
    let clickedRow = row(for: event)
    guard clickedRow >= 0 else {
      super.mouseDown(with: event)
      return
    }

    window?.makeFirstResponder(self)
    onMouseClickedRow?(clickedRow)
  }

  private func row(for event: NSEvent) -> Int {
    let location = convert(event.locationInWindow, from: nil)
    return row(at: location)
  }

  private func restoreMouseMovedEventsSettingIfNeeded() {
    guard let mouseMovedEventsWindow, let previousAcceptsMouseMovedEvents else {
      return
    }

    mouseMovedEventsWindow.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
    self.mouseMovedEventsWindow = nil
    self.previousAcceptsMouseMovedEvents = nil
  }
}

private final class CommandPaletteSearchField: NSTextField {
  var onKeyDown: ((NSEvent) -> Bool)?

  override func keyDown(with event: NSEvent) {
    guard onKeyDown?(event) != true else {
      return
    }

    super.keyDown(with: event)
  }
}

private final class CommandPaletteDividerView: NSView {
  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: 1)
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    updateColor()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColor()
  }

  private func configure() {
    wantsLayer = true
    updateColor()
  }

  private func updateColor() {
    layer?.backgroundColor = HistoryRow.dividerColor(for: self).cgColor
  }
}

private final class CommandPaletteDividerCellView: NSTableCellView {
  private let divider = CommandPaletteDividerView()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func configure() {
    divider.translatesAutoresizingMaskIntoConstraints = false
    addSubview(divider)

    NSLayoutConstraint.activate([
      divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      divider.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
}

private final class CommandPaletteSectionHeaderCellView: NSTableCellView {
  private let titleField = NSTextField(labelWithString: "")
  private var titleTopConstraint: NSLayoutConstraint?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(title: String, hasTopSpacing: Bool) {
    titleField.stringValue = title
    titleTopConstraint?.constant = hasTopSpacing ? 8 : 0
  }

  private func configure() {
    titleField.translatesAutoresizingMaskIntoConstraints = false
    titleField.font = .systemFont(ofSize: 13, weight: .semibold)
    titleField.textColor = .secondaryLabelColor
    addSubview(titleField)

    let titleTopConstraint = titleField.topAnchor.constraint(equalTo: topAnchor, constant: 0)
    self.titleTopConstraint = titleTopConstraint

    NSLayoutConstraint.activate([
      titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      titleField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
      titleTopConstraint,
      titleField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
    ])
  }
}

private final class CommandPaletteRowView: NSTableRowView {
  override var isSelected: Bool {
    didSet {
      updateCellSelectionColors()
    }
  }

  override func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)
    updateCellSelectionColors()
  }

  override func drawSelection(in dirtyRect: NSRect) {
    guard isSelected else {
      return
    }

    let selectionRect = bounds.insetBy(dx: 8, dy: 0)
    let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 12, yRadius: 12)
    HistoryRow.selectionAccentColor.setFill()
    selectionPath.fill()
  }

  private func updateCellSelectionColors() {
    for cellView in subviews.compactMap({ $0 as? CommandPaletteCommandCellView }) {
      cellView.setSelected(isSelected)
    }
  }
}

private final class CommandPaletteCommandCellView: NSTableCellView {
  private let iconView = NSImageView()
  private let textStack = NSStackView()
  private let titleField = NSTextField(labelWithString: "")
  private let descriptionField = NSTextField(labelWithString: "")
  private let shortcutStack = NSStackView()
  private let checkmarkView = NSImageView()
  private var textLeadingToIconConstraint: NSLayoutConstraint?
  private var textLeadingToContentConstraint: NSLayoutConstraint?
  private var isSelected = false
  private var isDestructive = false
  private var isChecked = false
  private var systemImageName = ""
  private var iconAccessibilityDescription: String?
  private var customIconImage: NSImage?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(_ command: CommandPaletteCommand) {
    iconView.isHidden = !command.showsIcon
    textLeadingToIconConstraint?.isActive = command.showsIcon
    textLeadingToContentConstraint?.isActive = !command.showsIcon
    titleField.stringValue = command.title
    descriptionField.stringValue = command.description ?? ""
    descriptionField.isHidden = command.description?.isEmpty != false
    isDestructive = command.isDestructive
    isChecked = command.isChecked
    checkmarkView.isHidden = !command.isChecked
    systemImageName = command.systemImageName
    iconAccessibilityDescription = command.title
    customIconImage = command.image
    iconView.image = command.showsIcon ? iconImage : nil
    configureShortcut(command.shortcut)
    updateSelectionColors()
  }

  func setSelected(_ isSelected: Bool) {
    guard self.isSelected != isSelected else {
      return
    }

    self.isSelected = isSelected
    updateSelectionColors()
  }

  private func configure() {
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

    textStack.orientation = .vertical
    textStack.alignment = .leading
    textStack.spacing = 1
    textStack.translatesAutoresizingMaskIntoConstraints = false
    textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    titleField.translatesAutoresizingMaskIntoConstraints = false
    titleField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    titleField.lineBreakMode = .byTruncatingTail
    titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    descriptionField.translatesAutoresizingMaskIntoConstraints = false
    descriptionField.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    descriptionField.lineBreakMode = .byTruncatingTail
    descriptionField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    shortcutStack.orientation = .horizontal
    shortcutStack.alignment = .centerY
    shortcutStack.spacing = 4
    shortcutStack.translatesAutoresizingMaskIntoConstraints = false

    checkmarkView.translatesAutoresizingMaskIntoConstraints = false
    checkmarkView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    checkmarkView.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: L10n.string("Selected"))
    checkmarkView.isHidden = true

    addSubview(iconView)
    textStack.addArrangedSubview(titleField)
    textStack.addArrangedSubview(descriptionField)
    addSubview(textStack)
    addSubview(shortcutStack)
    addSubview(checkmarkView)

    textLeadingToIconConstraint = textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8)
    textLeadingToContentConstraint = textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12)

    NSLayoutConstraint.activate([
      iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 22),
      iconView.heightAnchor.constraint(equalToConstant: 22),

      textStack.centerYAnchor.constraint(equalTo: centerYAnchor),

      shortcutStack.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 10),
      shortcutStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      shortcutStack.centerYAnchor.constraint(equalTo: centerYAnchor),

      checkmarkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
    textLeadingToIconConstraint?.isActive = true
  }

  private func configureShortcut(_ shortcut: String?) {
    shortcutStack.arrangedSubviews.forEach { view in
      shortcutStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    let tokens = CommandPaletteView.shortcutDisplayTokens(for: shortcut)
    guard !tokens.isEmpty else {
      return
    }

    for token in tokens {
      shortcutStack.addArrangedSubview(CommandPaletteShortcutBadge(token))
    }
  }

  private func updateSelectionColors() {
    let foregroundColor = isDestructive ? NSColor.systemRed : titleColor
    if !iconView.isHidden {
      iconView.image = iconImage
    }
    iconView.contentTintColor = iconColor
    titleField.textColor = foregroundColor
    descriptionField.textColor = descriptionColor
    checkmarkView.contentTintColor = foregroundColor

    for badge in shortcutStack.arrangedSubviews.compactMap({ $0 as? CommandPaletteShortcutBadge }) {
      badge.isSelected = isSelected
    }
  }

  private var iconImage: NSImage? {
    if let customIconImage {
      return customIconImage
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
      .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
    let image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: iconAccessibilityDescription)?
      .withSymbolConfiguration(configuration)
    image?.isTemplate = false
    return image
  }

  private var iconColor: NSColor {
    isDestructive ? .systemRed : .labelColor
  }

  private var titleColor: NSColor {
    guard isSelected else {
      return .labelColor
    }

    return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua ? .black : .white
  }

  private var descriptionColor: NSColor {
    guard isSelected else {
      return .secondaryLabelColor
    }

    return titleColor.withAlphaComponent(0.75)
  }
}

private final class CommandPaletteShortcutBadge: NSView {
  private let label = NSTextField(labelWithString: "")
  var isSelected = false {
    didSet {
      updateColors()
    }
  }

  init(_ text: String) {
    super.init(frame: .zero)
    label.stringValue = text
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColors()
  }

  private func configure() {
    translatesAutoresizingMaskIntoConstraints = false
    wantsLayer = true
    layer?.cornerRadius = 6

    label.translatesAutoresizingMaskIntoConstraints = false
    label.alignment = .center
    label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    label.lineBreakMode = .byClipping
    addSubview(label)

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
      widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
      heightAnchor.constraint(equalToConstant: 20)
    ])

    updateColors()
  }

  private func updateColors() {
    label.textColor = isSelected ? selectedTextColor : .secondaryLabelColor

    var backgroundColor = badgeBackgroundColor.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      backgroundColor = badgeBackgroundColor.cgColor
    }
    layer?.backgroundColor = backgroundColor
  }

  private var badgeBackgroundColor: NSColor {
    guard isSelected else {
      return NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
    }

    return isLightAppearance ? NSColor.black.withAlphaComponent(0.08) : NSColor.white.withAlphaComponent(0.18)
  }

  private var selectedTextColor: NSColor {
    isLightAppearance ? .black : .white
  }

  private var isLightAppearance: Bool {
    effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
