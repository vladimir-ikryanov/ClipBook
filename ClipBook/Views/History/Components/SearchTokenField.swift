import AppKit

/// Identifies what a search token filters by. Each kind maps onto one of the
/// history filters exposed by `AppModel`, so the tokens and the filter menus
/// always describe the same state.
enum SearchTokenKind: Hashable {
  case contentType(HistoryFilterContentType)
  case tag(Tag.ID)
  case sourceApplication(HistorySourceApplication.ID)

  /// Tokens are laid out group by group, in the order the groups are declared,
  /// so the chips read the same way the filter menus do.
  var group: SearchTokenGroup {
    switch self {
    case .contentType:
      return .contentType
    case .sourceApplication:
      return .sourceApplication
    case .tag:
      return .tag
    }
  }
}

enum SearchTokenGroup: Int, CaseIterable {
  case contentType
  case sourceApplication
  case tag
}

struct SearchToken {
  let kind: SearchTokenKind
  let title: String
  let image: NSImage?

  init(kind: SearchTokenKind, title: String, image: NSImage?) {
    self.kind = kind
    self.title = title
    self.image = image
  }
}

extension SearchToken: Equatable {
  static func == (lhs: SearchToken, rhs: SearchToken) -> Bool {
    lhs.kind == rhs.kind && lhs.title == rhs.title
  }
}

extension HistoryFilterContentType {
  /// A chip names the kind of a single item ("Link", "Image"), while the filter
  /// menus label a whole group ("Links", "Images"), so the search field takes
  /// its titles from `ClipboardKind` instead of `title`.
  var searchTokenTitle: String {
    switch self {
    case .all, .favorites, .trash:
      return title
    case .text:
      return ClipboardKind.text.title
    case .images:
      return ClipboardKind.image.title
    case .files:
      return ClipboardKind.file.title
    case .links:
      return ClipboardKind.link.title
    case .emails:
      return ClipboardKind.email.title
    case .colors:
      return ClipboardKind.color.title
    }
  }
}

enum SearchTokenFieldCommand {
  case cancel
  case commit
  case complete
}

@MainActor
protocol SearchTokenFieldDelegate: AnyObject {
  func searchTokenFieldDidChangeText(_ field: SearchTokenField)
  func searchTokenField(_ field: SearchTokenField, didRemoveToken token: SearchToken)
  func searchTokenField(_ field: SearchTokenField, didRequestMoveSelection direction: HistorySelectionDirection)
  /// Returns `true` when the delegate handled the command and the field should
  /// not fall back to its default behavior.
  func searchTokenField(_ field: SearchTokenField, didReceiveCommand command: SearchTokenFieldCommand) -> Bool
}

/// A search control that mixes free text with removable filter chips.
///
/// `NSTokenField` cannot render an icon inside a token and forces a
/// delimiter-based editing model, so the field is composed from a borderless
/// text field preceded by chip subviews that are laid out manually.
@MainActor
final class SearchTokenField: NSView, NSTextFieldDelegate {
  static let height: CGFloat = 32
  private static let chipSpacing: CGFloat = 4
  private static let chipTrailingSpacing: CGFloat = 7
  private static let minimumTextWidth: CGFloat = 30

  weak var delegate: SearchTokenFieldDelegate?

  /// Called when the width taken by the chips changes so the container can grow
  /// the search field instead of squeezing the text out of view.
  var onTokensWidthChange: (() -> Void)?

  /// Called after the chips and the text field have been laid out.
  var onLayout: (() -> Void)?

  private let textField = SearchTokenTextField()
  /// Before macOS 14 the placeholder the field editor draws while the field is
  /// focused starts at the visible part of the field, which is where the search
  /// field meets the toolbar item it overflows, so it jumps right on focus. A
  /// label behind the text field shows the placeholder there instead.
  private let placeholderLabel: NSTextField? = {
    if #available(macOS 14.0, *) {
      return nil
    }

    return SearchTokenPlaceholderLabel()
  }()
  private var chipViews: [SearchTokenChipView] = []
  private var selectedChipIndex: Int? {
    didSet {
      guard selectedChipIndex != oldValue else {
        return
      }

      updateChipSelection()
    }
  }

  private(set) var tokens: [SearchToken] = []

  var text: String {
    get { textField.stringValue }
    set {
      guard textField.stringValue != newValue else {
        return
      }

      textField.stringValue = newValue
      updatePlaceholderVisibility()
    }
  }

  /// Whether an input method (e.g. Japanese conversion) still holds
  /// unconfirmed text in the field.
  var isComposingText: Bool {
    (textField.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
  }

  var font: NSFont? {
    get { textField.font }
    set {
      textField.font = newValue
      // The cell centers the text by the control's font, so the label needs
      // the same font as the text field to draw the placeholder at its height.
      placeholderLabel?.font = newValue
    }
  }

  var placeholderAttributedString: NSAttributedString? {
    didSet {
      updatePlaceholder()
    }
  }

  /// Width the field needs to show the whole placeholder, including the
  /// padding the text field cell keeps around its text.
  var placeholderFittingWidth: CGFloat {
    guard let placeholderAttributedString,
          let cell = textField.cell?.copy() as? NSTextFieldCell else {
      return 0
    }

    cell.attributedStringValue = placeholderAttributedString
    return ceil(cell.cellSize.width)
  }

  var isEditing: Bool {
    guard let editor = textField.currentEditor() else {
      return false
    }

    return window?.firstResponder === editor
  }

  /// Screen rectangle of the editable text area, used to anchor the suggestion
  /// list right underneath the text the user is typing.
  var textAreaFrameInScreen: NSRect? {
    guard let window else {
      return nil
    }

    return window.convertToScreen(textAreaFrameInWindow)
  }

  var textAreaFrameInWindow: NSRect {
    convert(textField.frame, to: nil)
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  // While a chip is selected the field itself holds focus: with no editing
  // session there is no caret to blink next to the selection, and the keystroke
  // that acts on the chip cannot be mistaken for one that edits the text.
  // TextKit 2 draws the caret in a private view, so suppressing it from inside
  // an active editor is not possible.
  override func becomeFirstResponder() -> Bool {
    guard selectedChipIndex == nil else {
      return true
    }

    focusText()
    return true
  }

  override func resignFirstResponder() -> Bool {
    selectedChipIndex = nil
    return true
  }

  override func keyDown(with event: NSEvent) {
    guard let selectedChipIndex else {
      super.keyDown(with: event)
      return
    }

    switch Int(event.keyCode) {
    case 51, 117:
      removeToken(at: selectedChipIndex)
    case 123:
      selectChip(at: max(0, selectedChipIndex - 1))
    case 124, 53:
      resumeEditing(with: nil)
    case 126:
      delegate?.searchTokenField(self, didRequestMoveSelection: .up)
    case 125:
      delegate?.searchTokenField(self, didRequestMoveSelection: .down)
    default:
      resumeEditing(with: event)
    }
  }

  /// Hands focus back to the text so the keystroke that ended the selection is
  /// typed rather than swallowed.
  private func resumeEditing(with event: NSEvent?) {
    clearSelectedChip()

    guard let event, let editor = textField.currentEditor() as? NSTextView else {
      return
    }

    editor.keyDown(with: event)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let localPoint = convert(point, from: superview)
    guard bounds.contains(localPoint) else {
      return nil
    }

    if let chipView = chipViews.first(where: { $0.frame.contains(localPoint) }) {
      return chipView
    }

    return textField
  }

  override func layout() {
    super.layout()
    layoutContent()
  }

  /// Delivers a click that hit testing could not bring here because the field
  /// reaches outside the view that holds it, the way the window would have.
  func handleMouseDown(with event: NSEvent) {
    guard let window, let superview else {
      return
    }

    // The search logo ahead of the field focuses it, as the rest of the
    // search item does.
    guard let target = hitTest(superview.convert(event.locationInWindow, from: nil)) else {
      window.makeFirstResponder(self)
      return
    }

    if target === textField, textField.currentEditor() == nil {
      window.makeFirstResponder(textField)
    }

    target.mouseDown(with: event)
  }

  func focusText() {
    window?.makeFirstResponder(textField)
  }

  /// Puts the caret where the chips end. A text field selects its whole
  /// contents when it starts editing, which would make the next keystroke
  /// replace the query instead of extending it.
  private func focusTextAtStart() {
    focusText()
    textField.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
  }

  func moveCaretToEnd() {
    guard let editor = textField.currentEditor() else {
      return
    }

    editor.selectedRange = NSRange(location: editor.string.count, length: 0)
  }

  func handleKeyDown(with event: NSEvent) {
    focusText()

    if let editor = textField.currentEditor() as? NSTextView {
      moveCaretToEnd()
      editor.keyDown(with: event)
      return
    }

    guard let characters = event.characters else {
      return
    }

    textField.stringValue += characters
    updatePlaceholderVisibility()
    delegate?.searchTokenFieldDidChangeText(self)
  }

  func setTokens(_ tokens: [SearchToken]) {
    guard self.tokens != tokens else {
      return
    }

    self.tokens = tokens
    selectedChipIndex = nil
    rebuildChipViews()
    updatePlaceholder()
    onTokensWidthChange?()
    needsLayout = true
  }

  private func updatePlaceholder() {
    let placeholder = tokens.isEmpty ? placeholderAttributedString : nil
    guard let placeholderLabel else {
      textField.placeholderAttributedString = placeholder
      return
    }

    placeholderLabel.placeholderAttributedString = placeholder
    updatePlaceholderVisibility()
  }

  private func updatePlaceholderVisibility() {
    guard let placeholderLabel else {
      return
    }

    // The field editor holds the text being typed, including unconfirmed input
    // method text, before the text field's own value catches up.
    let text = textField.currentEditor()?.string ?? textField.stringValue
    placeholderLabel.isHidden = !text.isEmpty || !tokens.isEmpty
  }

  /// Width required by the chips, including the gap before the text area.
  var tokensWidth: CGFloat {
    guard !chipViews.isEmpty else {
      return 0
    }

    let chipsWidth = chipViews.reduce(0) { $0 + $1.intrinsicContentSize.width }
    let spacing = Self.chipSpacing * CGFloat(chipViews.count - 1)
    return chipsWidth + spacing + Self.chipTrailingSpacing
  }

  /// Chip widths for the current bounds. Chips keep their natural width while
  /// they fit; once the row would push the text area below its minimum, the
  /// remaining room is shared out shortest-first so a long title is truncated
  /// before a short one that still fits.
  private var chipWidths: [CGFloat] {
    let naturalWidths = chipViews.map { $0.intrinsicContentSize.width }
    guard !naturalWidths.isEmpty else {
      return []
    }

    let spacing = Self.chipSpacing * CGFloat(naturalWidths.count - 1) + Self.chipTrailingSpacing
    let available = bounds.width - Self.minimumTextWidth - spacing
    guard available > 0, naturalWidths.reduce(0, +) > available else {
      return naturalWidths
    }

    var widths = naturalWidths
    var remaining = available
    let order = naturalWidths.indices.sorted { naturalWidths[$0] < naturalWidths[$1] }

    for (position, index) in order.enumerated() {
      let share = remaining / CGFloat(order.count - position)
      let width = max(SearchTokenChipView.minimumWidth, min(naturalWidths[index], floor(share)))
      widths[index] = width
      remaining -= width
    }

    return widths
  }

  func clearSelectedChip() {
    guard selectedChipIndex != nil else {
      return
    }

    selectedChipIndex = nil
    focusTextAtStart()
  }

  // MARK: - Layout

  private func configure() {
    focusRingType = .none
    textField.delegate = self
    textField.onMouseDown = { [weak self] in
      self?.clearSelectedChip()
    }
    if let placeholderLabel {
      addSubview(placeholderLabel)
    }
    addSubview(textField)
  }

  private func layoutContent() {
    var x: CGFloat = 0
    let widths = chipWidths

    for (index, chipView) in chipViews.enumerated() {
      let size = chipView.intrinsicContentSize
      let width = widths[index]
      chipView.frame = NSRect(
        x: x,
        y: ((bounds.height - size.height) / 2).rounded(),
        width: width,
        height: size.height
      )
      x += width + Self.chipSpacing
    }

    if !chipViews.isEmpty {
      x += Self.chipTrailingSpacing - Self.chipSpacing
    }

    let textHeight = ceil(textField.intrinsicContentSize.height)
    textField.frame = NSRect(
      x: x,
      y: ((bounds.height - textHeight) / 2).rounded(),
      width: max(Self.minimumTextWidth, bounds.width - x),
      height: textHeight
    )
    placeholderLabel?.frame = textField.frame
    onLayout?()
  }

  private func rebuildChipViews() {
    chipViews.forEach { $0.removeFromSuperview() }
    chipViews = tokens.map { token in
      let chipView = SearchTokenChipView(token: token)
      chipView.onClick = { [weak self, weak chipView] in
        guard let self, let chipView, let index = self.chipViews.firstIndex(of: chipView) else {
          return
        }

        self.selectChip(at: index)
      }
      addSubview(chipView, positioned: .below, relativeTo: textField)
      return chipView
    }
  }

  private func selectChip(at index: Int) {
    guard chipViews.indices.contains(index) else {
      return
    }

    selectedChipIndex = index
    window?.makeFirstResponder(self)
  }

  private func updateChipSelection() {
    for (index, chipView) in chipViews.enumerated() {
      chipView.isSelected = index == selectedChipIndex
    }
  }

  private func removeToken(at index: Int) {
    guard tokens.indices.contains(index) else {
      return
    }

    let token = tokens[index]
    tokens.remove(at: index)
    selectedChipIndex = nil
    rebuildChipViews()
    updatePlaceholder()
    onTokensWidthChange?()
    needsLayout = true
    delegate?.searchTokenField(self, didRemoveToken: token)
    focusTextAtStart()
  }

  // MARK: - Editing

  private var isCaretAtStart: Bool {
    guard let editor = textField.currentEditor() else {
      return textField.stringValue.isEmpty
    }

    let range = editor.selectedRange
    return range.location == 0 && range.length == 0
  }

  func controlTextDidChange(_ obj: Notification) {
    updatePlaceholderVisibility()
    clearSelectedChip()
    delegate?.searchTokenFieldDidChangeText(self)
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.deleteBackward(_:)):
      return handleDeleteBackward()
    case #selector(NSResponder.moveLeft(_:)):
      return handleMoveLeft()
    case #selector(NSResponder.moveUp(_:)):
      delegate?.searchTokenField(self, didRequestMoveSelection: .up)
      return true
    case #selector(NSResponder.moveDown(_:)):
      delegate?.searchTokenField(self, didRequestMoveSelection: .down)
      return true
    case #selector(NSResponder.insertTab(_:)):
      return delegate?.searchTokenField(self, didReceiveCommand: .complete) ?? false
    case #selector(NSResponder.insertNewline(_:)),
         #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
      _ = delegate?.searchTokenField(self, didReceiveCommand: .commit)
      return true
    case #selector(NSResponder.cancelOperation(_:)):
      return delegate?.searchTokenField(self, didReceiveCommand: .cancel) ?? false
    default:
      return false
    }
  }

  private func handleDeleteBackward() -> Bool {
    guard isCaretAtStart, !chipViews.isEmpty else {
      return false
    }

    selectChip(at: chipViews.count - 1)
    return true
  }

  private func handleMoveLeft() -> Bool {
    guard isCaretAtStart, !chipViews.isEmpty else {
      return false
    }

    selectChip(at: chipViews.count - 1)
    return true
  }
}

/// Borderless single line text field used for the free text part of the search.
private final class SearchTokenTextField: NSTextField {
  var onMouseDown: (() -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func mouseDown(with event: NSEvent) {
    onMouseDown?()
    super.mouseDown(with: event)
  }

  private func configure() {
    let searchCell = VerticallyCenteredTextFieldCell(textCell: "")
    searchCell.usesSingleLineMode = true
    searchCell.wraps = false
    searchCell.isScrollable = true
    searchCell.lineBreakMode = .byTruncatingTail
    cell = searchCell
    isBordered = false
    isBezeled = false
    drawsBackground = false
    focusRingType = .none
    isEditable = true
    isSelectable = true
    refusesFirstResponder = false
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }
}

/// Placeholder drawn behind the text field. It is set up like the text field
/// and draws the placeholder the same way, it only never takes focus.
private final class SearchTokenPlaceholderLabel: NSTextField {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let placeholderCell = VerticallyCenteredTextFieldCell(textCell: "")
    placeholderCell.usesSingleLineMode = true
    placeholderCell.wraps = false
    placeholderCell.isScrollable = true
    placeholderCell.lineBreakMode = .byTruncatingTail
    cell = placeholderCell
    isBordered = false
    isBezeled = false
    drawsBackground = false
    isEditable = false
    isSelectable = false
    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

/// Rounded chip rendering one active filter inside the search field.
private final class SearchTokenChipView: NSView {
  static let height: CGFloat = 26
  static let minimumWidth: CGFloat = 44
  private static let cornerRadius: CGFloat = 6
  private static let horizontalPadding: CGFloat = 6
  private static let iconTextSpacing: CGFloat = 4
  private static let iconSize: CGFloat = 14
  private static let maximumTitleWidth: CGFloat = 120
  private static let selectedBackgroundOpacity: CGFloat = 0.35
  private static let font = NSFont.systemFont(ofSize: 14, weight: .regular)

  let token: SearchToken

  var onClick: (() -> Void)?

  var isSelected = false {
    didSet {
      guard isSelected != oldValue else {
        return
      }

      needsDisplay = true
    }
  }

  private let imageView = NSImageView()

  init(token: SearchToken) {
    self.token = token
    super.init(frame: .zero)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: Self.horizontalPadding * 2 + iconWidth + titleWidth, height: Self.height)
  }

  override func draw(_ dirtyRect: NSRect) {
    drawBackground()

    let titleX = Self.horizontalPadding + iconWidth
    let titleHeight = ceil(Self.font.ascender - Self.font.descender)
    let titleRect = NSRect(
      x: titleX,
      y: ((bounds.height - titleHeight) / 2).rounded(),
      width: max(0, bounds.width - titleX - Self.horizontalPadding),
      height: titleHeight
    )

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    NSAttributedString(
      string: token.title,
      attributes: [
        .font: Self.font,
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: paragraphStyle
      ]
    ).draw(in: titleRect)
  }

  override func layout() {
    super.layout()

    guard imageView.image != nil else {
      return
    }

    imageView.frame = NSRect(
      x: Self.horizontalPadding,
      y: ((bounds.height - Self.iconSize) / 2).rounded(),
      width: Self.iconSize,
      height: Self.iconSize
    )
  }

  override func mouseDown(with event: NSEvent) {
    onClick?()
  }

  private func drawBackground() {
    let path = NSBezierPath(
      roundedRect: bounds,
      xRadius: Self.cornerRadius,
      yRadius: Self.cornerRadius
    )

    // Selection is a tinted wash rather than a solid accent fill, so the label
    // and the icon stay readable through it.
    let fillColor = isSelected
      ? NSColor.controlAccentColor.withAlphaComponent(Self.selectedBackgroundOpacity)
      : NSColor.quaternaryLabelColor
    fillColor.setFill()
    path.fill()
  }

  private var iconWidth: CGFloat {
    imageView.image == nil ? 0 : Self.iconSize + Self.iconTextSpacing
  }

  private var titleWidth: CGFloat {
    min(Self.maximumTitleWidth, ceil(token.title.size(withAttributes: [.font: Self.font]).width))
  }

  private func configure() {
    toolTip = token.title
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.image = token.image
    imageView.isHidden = token.image == nil
    addSubview(imageView)
  }
}

/// Keeps the single line text centered inside the taller search field.
private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {

  override func drawingRect(forBounds rect: NSRect) -> NSRect {
    let textSize = cellSize(forBounds: rect)
    let verticalInset = max(0, floor((rect.height - textSize.height) / 2))
    return rect.insetBy(dx: 0, dy: verticalInset)
  }

  override func edit(
    withFrame rect: NSRect,
    in controlView: NSView,
    editor textObj: NSText,
    delegate: Any?,
    event: NSEvent?
  ) {
    super.edit(
      withFrame: drawingRect(forBounds: rect),
      in: controlView,
      editor: textObj,
      delegate: delegate,
      event: event
    )
  }

  override func select(
    withFrame rect: NSRect,
    in controlView: NSView,
    editor textObj: NSText,
    delegate: Any?,
    start selStart: Int,
    length selLength: Int
  ) {
    super.select(
      withFrame: drawingRect(forBounds: rect),
      in: controlView,
      editor: textObj,
      delegate: delegate,
      start: selStart,
      length: selLength
    )
  }
}
