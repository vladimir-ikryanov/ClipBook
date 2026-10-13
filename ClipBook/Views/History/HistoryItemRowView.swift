import AppKit
import ImageIO
import UniformTypeIdentifiers

extension NSFont {
  // Auto Layout asks for a preview field's height many times a pass, and a layout manager
  // is too heavy to make for each question, so the height is kept for each font.
  private static var historyLineHeights: [NSFont: CGFloat] = [:]

  var historyLineHeight: CGFloat {
    if let lineHeight = Self.historyLineHeights[self] {
      return lineHeight
    }

    let lineHeight = NSLayoutManager().defaultLineHeight(for: self)
    Self.historyLineHeights[self] = lineHeight
    return lineHeight
  }
}

private enum HistorySelectionAppearance {
  static func textColor(for view: NSView, isSelected: Bool, defaultColor: NSColor = .labelColor) -> NSColor {
    guard isSelected else {
      return defaultColor
    }

    return view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua ? .black : .white
  }
}

// Keeps the cell from switching to the emphasized text style when the row is selected;
// the row views manage their own text colors.
private class NormalBackgroundTextFieldCell: NSTextFieldCell {
  override var backgroundStyle: NSView.BackgroundStyle {
    get {
      .normal
    }
    set {
      super.backgroundStyle = .normal
    }
  }
}

// Draws the text in the vertical middle of the field, so a preview that needs one line sits
// centered in the space reserved for two, and a longer one fills both lines.
private final class VerticallyCenteredTextFieldCell: NormalBackgroundTextFieldCell {
  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    super.drawInterior(withFrame: centeredFrame(in: cellFrame), in: controlView)
  }

  private func centeredFrame(in cellFrame: NSRect) -> NSRect {
    let measuringBounds = NSRect(
      x: 0,
      y: 0,
      width: cellFrame.width,
      height: CGFloat.greatestFiniteMagnitude
    )
    let contentHeight = min(ceil(cellSize(forBounds: measuringBounds).height), cellFrame.height)
    guard contentHeight < cellFrame.height else {
      return cellFrame
    }

    return NSRect(
      x: cellFrame.minX,
      y: cellFrame.minY + floor((cellFrame.height - contentHeight) / 2),
      width: cellFrame.width,
      height: contentHeight
    )
  }
}

// The color of the symbols a row draws in place of line breaks, tabs and leading spaces,
// and the look of the dots it draws in place of hidden content.
private enum HistoryPreviewSymbolAppearance {
  static func color(for view: NSView) -> NSColor {
    view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .darkGray : .lightGray
  }

  static func applyMaskStyle(
    to attributedString: NSMutableAttributedString,
    text: String,
    font: NSFont,
    in view: NSView
  ) {
    let ranges = SensitiveContent.maskRanges(in: text)
    guard !ranges.isEmpty else {
      return
    }

    let textAttributes = attributedString.attributes(at: 0, effectiveRange: nil)
    for range in ranges {
      attributedString.addAttributes(SensitiveContent.maskAttributes(for: font), range: range)
      // The dots are as dark as the main text, whatever the color of the line they are in.
      attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
      SensitiveContent.addSpacing(beforeMaskAt: range, in: attributedString)
    }

    // A line takes its height and baseline from the fonts in it. A line of nothing but
    // dots would take them from the smaller font of the dots and sit off the middle of
    // the row, so it ends with a space in the font of the text, which puts the dots
    // where they are in a line that has text around them.
    if ranges.count == 1, ranges[0].length == attributedString.length {
      attributedString.append(NSAttributedString(string: " ", attributes: textAttributes))
    }
  }
}

private enum HistorySearchMatchHighlighter {
  static let highlightColor = NSColor.systemBlue

  static func attributedString(
    text: String,
    font: NSFont,
    textColor: NSColor,
    searchQuery: String,
    paragraphStyle: NSParagraphStyle? = nil
  ) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(
      string: text,
      attributes: makeBaseAttributes(font: font, textColor: textColor, paragraphStyle: paragraphStyle)
    )
    applyHighlight(to: attributedString, text: text, searchQuery: searchQuery)
    return attributedString
  }

  static func applyHighlight(to attributedString: NSMutableAttributedString, text: String, searchQuery: String) {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return
    }

    var searchRange = text.startIndex..<text.endIndex
    while let range = text.range(
      of: query,
      options: [.caseInsensitive, .diacriticInsensitive],
      range: searchRange
    ) {
      attributedString.addAttribute(.foregroundColor, value: highlightColor, range: NSRange(range, in: text))
      searchRange = range.upperBound..<text.endIndex
    }
  }

  private static func makeBaseAttributes(
    font: NSFont,
    textColor: NSColor,
    paragraphStyle: NSParagraphStyle?
  ) -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textColor
    ]
    if let paragraphStyle {
      attributes[.paragraphStyle] = paragraphStyle
    }
    return attributes
  }
}

final class HistoryFixedTextColorLabel: NSTextField {
  // What the shown attributed string was made from. It is made again only when one of
  // these changes, since the label checks it before every draw.
  private struct RenderedState: Equatable {
    let text: String
    let font: NSFont?
    let textColor: NSColor
    let searchQuery: String
    let paragraphStyle: NSParagraphStyle?
    let lineBreakMode: NSLineBreakMode
    let appearanceName: NSAppearance.Name
  }

  private var renderedState: RenderedState?
  private var isUpdating = false

  /// The text the label shows. `stringValue` can differ from it: hidden content gets a
  /// trailing space in the font of the text.
  private(set) var text = ""

  override var font: NSFont? {
    didSet {
      applyPreferredTextColor()
    }
  }

  var preferredTextColor: NSColor = .labelColor {
    didSet {
      applyPreferredTextColor()
    }
  }
  var searchHighlightQuery = "" {
    didSet {
      applyPreferredTextColor()
    }
  }
  var preferredParagraphStyle: NSParagraphStyle? {
    didSet {
      applyPreferredTextColor()
    }
  }

  override var lineBreakMode: NSLineBreakMode {
    didSet {
      applyPreferredTextColor()
    }
  }

  /// Sets everything a row changes when it shows another item, making the text once.
  func update(
    text: String,
    font: NSFont,
    textColor: NSColor,
    searchQuery: String,
    lineBreakMode: NSLineBreakMode
  ) {
    isUpdating = true
    self.text = text
    self.font = font
    preferredTextColor = textColor
    searchHighlightQuery = searchQuery
    preferredParagraphStyle = nil
    self.lineBreakMode = lineBreakMode
    isUpdating = false
    applyPreferredTextColor()
  }

  override func draw(_ dirtyRect: NSRect) {
    applyPreferredTextColor()
    super.draw(dirtyRect)
  }

  private func applyPreferredTextColor() {
    guard !isUpdating else {
      return
    }

    if let fieldCell = cell as? NSTextFieldCell {
      fieldCell.backgroundStyle = .normal
    }
    let state = RenderedState(
      text: text,
      font: font,
      textColor: preferredTextColor,
      searchQuery: searchHighlightQuery,
      paragraphStyle: preferredParagraphStyle,
      lineBreakMode: lineBreakMode,
      appearanceName: effectiveAppearance.name
    )
    guard state != renderedState else {
      return
    }

    renderedState = state
    var resolvedColor = preferredTextColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      resolvedColor = preferredTextColor.usingColorSpace(.deviceRGB) ?? preferredTextColor
    }
    let attributedString = NSMutableAttributedString(
      attributedString: HistorySearchMatchHighlighter.attributedString(
        text: text,
        font: font ?? .systemFont(ofSize: NSFont.systemFontSize),
        textColor: resolvedColor,
        searchQuery: searchHighlightQuery,
        paragraphStyle: preferredParagraphStyle ?? makeLineBreakParagraphStyle()
      )
    )
    HistoryPreviewSymbolAppearance.applyMaskStyle(
      to: attributedString,
      text: text,
      font: font ?? .systemFont(ofSize: NSFont.systemFontSize),
      in: self
    )
    attributedStringValue = attributedString
  }

  // The attributed string's paragraph style wins over the field's own line break mode, and
  // the default one wraps by word, which cuts text that doesn't fit at a word boundary with
  // no ellipsis. The field's mode is carried over, so the cut is shown where it is made.
  private func makeLineBreakParagraphStyle() -> NSParagraphStyle {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = lineBreakMode
    return paragraphStyle
  }
}

private final class QuickPasteLabel: NSTextField {
  var preferredTextColor: NSColor = .tertiaryLabelColor {
    didSet {
      textColor = preferredTextColor
      needsDisplay = true
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    if textColor != preferredTextColor {
      textColor = preferredTextColor
    }
    super.draw(dirtyRect)
  }
}

enum HistoryTextPreviewFormatter {
  static let returnSymbol = " ⏎ "
  static let tabSymbol = "→"
  static let leadingSpaceSymbol = "·"
  static let layoutCharacterLimit = 2_000

  // Line breaks are shown as return symbols instead of actual breaks, so multi-line text
  // flows as one compact wrapped paragraph in the row view.
  static func displayString(from text: String, characterLimit: Int? = layoutCharacterLimit) -> String {
    boundedString(from: trimmingLeadingWhitespace(text), characterLimit: characterLimit)
      .split(omittingEmptySubsequences: false) { character in
        character.isNewline
      }
      .map { line in
        isBlankLine(line) ? "" : displayLine(from: String(line))
      }
      .joined(separator: returnSymbol)
  }

  // Leading spaces and line breaks are left out of the preview. Text made only of
  // whitespace is kept as is, so its row still shows what it holds.
  private static func trimmingLeadingWhitespace(_ text: String) -> Substring {
    guard let firstVisibleIndex = text.firstIndex(where: { !$0.isWhitespace }) else {
      return text[...]
    }

    return text[firstVisibleIndex...]
  }

  private static func boundedString(from text: Substring, characterLimit: Int?) -> String {
    guard let characterLimit, characterLimit > 0,
          let limitIndex = text.index(text.startIndex, offsetBy: characterLimit, limitedBy: text.endIndex),
          limitIndex != text.endIndex else {
      return String(text)
    }

    return String(text[..<limitIndex]) + "..."
  }

  private static func isBlankLine(_ line: Substring) -> Bool {
    line.unicodeScalars.allSatisfy { scalar in
      CharacterSet.whitespaces.contains(scalar)
    }
  }

  private static func displayLine(from line: String) -> String {
    var result = ""
    var index = line.startIndex

    while index < line.endIndex {
      switch line[index] {
      case " ":
        result += leadingSpaceSymbol
      case "\t":
        result += tabSymbol
      default:
        return result + line[index...].replacingOccurrences(of: "\t", with: tabSymbol)
      }

      index = line.index(after: index)
    }

    return result
  }
}

// The text preview keeps a fixed height for its line count. Text that fits on one line is
// drawn centered in that space; longer text wraps and is cut with an ellipsis at the end.
// A row keeps its preview fields and updates them for each item it shows.
private final class HistoryTextPreviewField: NSTextField {
  private var previewText = ""
  private var displayText = ""
  private var searchQuery = ""
  private var textFont = HistoryRow.makePrimaryFont()
  private var lineCount = 1
  private var wrappingMode: NSLineBreakMode = .byWordWrapping
  private var textHeight: CGFloat = 0
  private var isUpdating = false
  var preferredTextColor: NSColor = .labelColor {
    didSet {
      if !isUpdating, preferredTextColor != oldValue {
        attributedStringValue = makeAttributedPreviewString()
      }
    }
  }

  private var textLineBreakMode: NSLineBreakMode {
    lineCount > 1 ? wrappingMode : .byTruncatingTail
  }

  init() {
    super.init(frame: .zero)
    cell = VerticallyCenteredTextFieldCell(textCell: "")
    isEditable = false
    isSelectable = false
    isBordered = false
    drawsBackground = false
    backgroundColor = .clear
    allowsDefaultTighteningForTruncation = true
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    if let cell = cell as? NSTextFieldCell {
      cell.backgroundStyle = .normal
      cell.truncatesLastVisibleLine = true
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(
    previewText: String,
    searchQuery: String,
    font: NSFont,
    textColor: NSColor,
    maximumNumberOfLines: Int,
    wrappingMode: NSLineBreakMode
  ) {
    if previewText != self.previewText {
      self.previewText = previewText
      displayText = HistoryTextPreviewFormatter.displayString(from: previewText)
    }
    self.searchQuery = searchQuery
    self.wrappingMode = wrappingMode
    if font != textFont || maximumNumberOfLines != lineCount || textHeight == 0 {
      textFont = font
      lineCount = maximumNumberOfLines
      textHeight = HistoryRow.textPreviewHeight(font: font, lineCount: maximumNumberOfLines)
      invalidateIntrinsicContentSize()
    }
    self.font = textFont
    lineBreakMode = textLineBreakMode
    self.maximumNumberOfLines = lineCount
    if let cell = cell as? NSTextFieldCell {
      cell.wraps = lineCount > 1
      cell.usesSingleLineMode = lineCount == 1
      cell.lineBreakMode = textLineBreakMode
    }
    isUpdating = true
    preferredTextColor = textColor
    isUpdating = false
    attributedStringValue = makeAttributedPreviewString()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    attributedStringValue = makeAttributedPreviewString()
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: textHeight)
  }

  private func makeAttributedPreviewString() -> NSAttributedString {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = textLineBreakMode
    var resolvedColor = preferredTextColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      resolvedColor = preferredTextColor.usingColorSpace(.deviceRGB) ?? preferredTextColor
    }
    let attributedString = NSMutableAttributedString(
      string: displayText,
      attributes: [
        .font: textFont,
        .foregroundColor: resolvedColor,
        .paragraphStyle: paragraphStyle
      ]
    )

    HistorySearchMatchHighlighter.applyHighlight(
      to: attributedString,
      text: displayText,
      searchQuery: searchQuery
    )

    applySecondaryColor(
      to: attributedString,
      for: HistoryTextPreviewFormatter.returnSymbol,
      in: displayText
    )
    applySecondaryColor(
      to: attributedString,
      for: HistoryTextPreviewFormatter.tabSymbol,
      in: displayText
    )
    applySecondaryColor(
      to: attributedString,
      for: HistoryTextPreviewFormatter.leadingSpaceSymbol,
      in: displayText
    )
    HistoryPreviewSymbolAppearance.applyMaskStyle(
      to: attributedString,
      text: displayText,
      font: textFont,
      in: self
    )

    return attributedString
  }

  private func applySecondaryColor(
    to attributedString: NSMutableAttributedString,
    for symbol: String,
    in displayText: String
  ) {
    var searchRange = displayText.startIndex..<displayText.endIndex
    while let range = displayText.range(of: symbol, range: searchRange) {
      attributedString.addAttribute(.foregroundColor, value: previewSymbolColor, range: NSRange(range, in: displayText))
      searchRange = range.upperBound..<displayText.endIndex
    }
  }

  private var previewSymbolColor: NSColor {
    HistoryPreviewSymbolAppearance.color(for: self)
  }
}

/// How a picture fills the type icon box of a row.
enum HistoryTypeIconImageStyle: Equatable {
  /// The picture is fit to the box and keeps its own shape and corners: image previews.
  case picture
  /// The picture keeps its own shape and is drawn at the box size without a background: file icons.
  case icon
  /// A small picture centered inside the box background: small favicons.
  case small
  /// Like `picture`, but fit inside a background of the given color in the shape of the
  /// box whenever that color is not clear in the box's appearance: rendered SVG, which
  /// would otherwise blend into the row.
  case pictureWithBackdrop(NSColor)
}

// Every row has the same layout: a 34pt type box on the left, one or two lines of text in
// the middle, an optional preview next to the text, and the accessory controls (tags,
// favorite star, quick paste shortcut, source app icon) on the right. Everything is
// centered vertically inside the fixed-height row.
//
// A cell is reused for many items, and it keeps its subviews for all of them: it updates
// the labels, previews and controls it already has, and only changes which of them are in
// the layout. Making new controls for every row that scrolled in was slow, and on macOS 27
// every control removed from a view in a window also left a few AppKit records on its
// superview for as long as the window stayed open, about 7 MB for each scroll through a
// 3,000-item history. Taking out and putting back the same control leaves nothing behind.
class HistoryItemRowView: NSTableCellView {
  var filePreviewCache: FilePreviewCache?
  private let typeIconView = HistoryItemTypeIconView()
  private let selectionOrderColumn = NSView()
  private let selectionOrderBadgeView = HistorySelectionOrderBadgeView()
  private var selectionOrderColumnWidthConstraint: NSLayoutConstraint?
  private var showsSelectionOrderColumn = false
  private let rowStack = NSStackView()
  private let textColumn = NSStackView()
  private var trailingView: NSView?
  private var rowStackLeadingConstraint: NSLayoutConstraint?
  private var rowStackTrailingConstraint: NSLayoutConstraint?
  private var selectionTitleFields: [NSTextField] = []
  private var itemTags: [Tag] = []
  private(set) var rowTableWidth: CGFloat?
  private(set) var searchQuery = ""
  private(set) var linkPreview: LinkPreview?
  private(set) var showsLinkPreview = false
  private var configuredItem: ClipboardItem?
  private var detectsSensitiveContent = false
  /// True while the row shows dots in place of the item's sensitive content.
  private(set) var hidesSensitiveContent = false
  private var onToggleSensitiveContentVisibility: (() -> Void)?

  // The views a configuration asks for. They are put in the layout once the subclass has
  // filled the row, and only when they differ from the ones already there.
  private var pendingLines: [NSView] = []
  private var pendingTrailingView: NSView?

  // Labels and text previews handed out in order while the row is filled, and taken
  // again from the start for the next item.
  private var labels: [HistoryFixedTextColorLabel] = []
  private var nextLabelIndex = 0
  private var textPreviewFields: [HistoryTextPreviewField] = []
  private var nextTextPreviewFieldIndex = 0

  // The accessory controls are made once and shown or hidden for each item.
  private let accessoryControlsView = NSStackView()
  private let sensitiveContentButton = NSButton()
  private let tagIconsView = NSStackView()
  private var tagIconViews: [NSImageView] = []
  private let favoriteView = FavoriteView.make(isFavorite: false)
  private let quickPasteField = QuickPasteLabel(labelWithString: "")
  private let sourceAppIconView = NSImageView()
  private var measuredAccessoryControlsWidth: CGFloat?

  /// The width of the accessory controls the row shows, 0 when it shows none.
  var accessoryControlsWidth: CGFloat {
    if let measuredAccessoryControlsWidth {
      return measuredAccessoryControlsWidth
    }

    let width = accessoryControlsView.isHidden ? 0 : accessoryControlsView.fittingSize.width
    measuredAccessoryControlsWidth = width
    return width
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var backgroundStyle: NSView.BackgroundStyle {
    get { super.backgroundStyle }
    set {
      super.backgroundStyle = newValue
      updateSelectionAppearance()
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateSelectionAppearance()
  }

  // The table places the cell view a few points inside the row view, whose edges are where
  // the selection shape is drawn. The content insets are measured from those edges, so the
  // icon box sits as far from the selection's left edge as from its top and bottom.
  override func layout() {
    if let rowView = superview {
      let leadingOffset = frame.minX - rowView.bounds.minX
      let trailingOffset = rowView.bounds.maxX - frame.maxX
      rowStackLeadingConstraint?.constant = max(0, HistoryRow.contentHorizontalInset - leadingOffset)
      rowStackTrailingConstraint?.constant = -max(0, HistoryRow.contentHorizontalInset - trailingOffset)
    }
    super.layout()
  }

  func configure(
    item: ClipboardItem,
    quickPasteIndex: Int?,
    tableWidth: CGFloat? = nil,
    searchQuery: String = "",
    itemTags: [Tag] = [],
    linkPreview: LinkPreview? = nil,
    showsLinkPreview: Bool = false,
    detectsSensitiveContent: Bool = false,
    revealsSensitiveContent: Bool = false,
    onToggleSensitiveContentVisibility: (() -> Void)? = nil
  ) {
    selectionTitleFields = []
    nextLabelIndex = 0
    nextTextPreviewFieldIndex = 0
    pendingLines = []
    pendingTrailingView = nil
    configuredItem = item
    self.itemTags = itemTags
    rowTableWidth = tableWidth
    self.searchQuery = searchQuery
    self.linkPreview = linkPreview
    self.showsLinkPreview = showsLinkPreview
    self.detectsSensitiveContent = detectsSensitiveContent
    self.onToggleSensitiveContentVisibility = onToggleSensitiveContentVisibility
    let isMasked = SensitiveContent.isMasked(item, detectsAutomatically: detectsSensitiveContent)
    hidesSensitiveContent = isMasked && !revealsSensitiveContent

    configureAccessoryControls(item: item, quickPasteIndex: quickPasteIndex, isMasked: isMasked)
    typeIconView.configure(kind: item.kind, systemImageName: typeIconSystemImageName(for: item))
    typeIconView.showsLockBadge = isMasked
    configureContent(item: item, quickPasteIndex: quickPasteIndex)
    applyPendingLines()
    applyPendingTrailingView()
    updateSelectionAppearance()
  }

  // MARK: - Subclass hooks

  func typeIconSystemImageName(for item: ClipboardItem) -> String {
    item.kind.systemImage
  }

  /// Fills the row for the item: the text lines, the type box content and any preview
  /// next to the text. The default shows the item's content title on one line.
  func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    setLines(primary: makePrimaryLabel(text: item.contentTitle), secondary: nil)
  }

  /// The line shown under a title the user gave the item, in place of the item's own lines.
  func makeTitledSummaryLine(for item: ClipboardItem) -> NSView {
    makeSecondaryLabel(text: item.contentTitle)
  }

  // MARK: - Layout API for subclasses

  /// Shows one line centered in the row, or two lines when `secondary` is given. An item
  /// with a title shows the title first and a one-line summary of its content second.
  func setLines(primary: NSView, secondary: NSView?) {
    if let item = configuredItem, let title = item.itemTitle {
      pendingLines = [makeItemTitleLabel(text: title), makeTitledSummaryLine(for: item)]
      return
    }

    pendingLines = [primary] + (secondary.map { [$0] } ?? [])
  }

  /// Shows a preview between the text and the accessory controls. A subclass passes the
  /// same view for every item it shows one for.
  func setTrailingView(_ view: NSView) {
    view.translatesAutoresizingMaskIntoConstraints = false
    view.setContentHuggingPriority(.required, for: .horizontal)
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
    pendingTrailingView = view
  }

  // The text keeps a small gap to its preview and the last of them a bigger gap to the
  // accessory controls.
  private func updateContentSpacing() {
    guard let trailingView else {
      rowStack.setCustomSpacing(HistoryRow.contentAccessorySpacing, after: textColumn)
      return
    }

    rowStack.setCustomSpacing(HistoryRow.mainSpacing, after: textColumn)
    rowStack.setCustomSpacing(HistoryRow.contentAccessorySpacing, after: trailingView)
  }

  /// The width left for a trailing preview next to text of at least `minimumTextWidth`.
  func availableTrailingWidth(minimumTextWidth: CGFloat) -> CGFloat {
    let tableWidth = rowTableWidth ?? bounds.width
    let accessoryWidth = accessoryControlsWidth > 0
      ? accessoryControlsWidth + HistoryRow.contentAccessorySpacing
      : 0
    return max(
      0,
      tableWidth
        - HistoryRow.contentHorizontalInset * 2
        - HistoryRow.typeIconBoxSize
        - HistoryRow.typeIconContentSpacing
        - minimumTextWidth
        - HistoryRow.mainSpacing
        - accessoryWidth
    )
  }

  /// A one-line label in the primary text style. It takes the selection text color
  /// unless `keepsTextColor` is set, for text that is dimmed on purpose.
  func makePrimaryLabel(
    text: String,
    textColor: NSColor = .labelColor,
    keepsTextColor: Bool = false
  ) -> HistoryFixedTextColorLabel {
    let field = makeLabel(text: contentText(text), font: HistoryRow.makePrimaryFont(), textColor: textColor)
    if !keepsTextColor {
      registerSelectionTitleField(field)
    }
    return field
  }

  func makeSecondaryLabel(
    text: String,
    textColor: NSColor = .secondaryLabelColor,
    lineBreakMode: NSLineBreakMode = .byTruncatingTail
  ) -> HistoryFixedTextColorLabel {
    makeLabel(text: text, font: HistoryRow.makeDetailsFont(), textColor: textColor, lineBreakMode: lineBreakMode)
  }

  func makeItemTitleLabel(text: String) -> HistoryFixedTextColorLabel {
    let field = makeLabel(text: text, font: HistoryRow.makeItemTitleFont(), textColor: .labelColor)
    registerSelectionTitleField(field)
    return field
  }

  /// A text preview with line breaks and tabs shown as symbols. It reserves the height of
  /// `maximumNumberOfLines` lines and centers shorter text in it. Text that spans more lines
  /// wraps with `wrappingMode`: by word for prose, by character for a URL, so its lines fill
  /// the width instead of breaking at its punctuation.
  func makeTextPreviewField(
    text: String,
    maximumNumberOfLines: Int = HistoryRow.textPreviewMaximumNumberOfLines,
    font: NSFont = HistoryRow.makePrimaryFont(),
    textColor: NSColor = .labelColor,
    wrappingMode: NSLineBreakMode = .byWordWrapping
  ) -> NSView {
    if nextTextPreviewFieldIndex == textPreviewFields.count {
      textPreviewFields.append(HistoryTextPreviewField())
    }
    let field = textPreviewFields[nextTextPreviewFieldIndex]
    nextTextPreviewFieldIndex += 1
    field.update(
      previewText: contentText(text),
      searchQuery: searchQuery,
      font: font,
      textColor: textColor,
      maximumNumberOfLines: maximumNumberOfLines,
      wrappingMode: wrappingMode
    )
    return field
  }

  /// The item's content as the row shows it: with its sensitive parts replaced by dots
  /// until the user asks to see them.
  private func contentText(_ text: String) -> String {
    guard hidesSensitiveContent, let configuredItem else {
      return text
    }

    return SensitiveContent.maskedText(
      text,
      for: configuredItem,
      detectsAutomatically: detectsSensitiveContent
    )
  }

  /// A one-line label that highlights the search query. The row hands out its own labels
  /// again for every item, so a subclass sets up a label each time it asks for one.
  func makeLabel(
    text: String,
    font: NSFont,
    textColor: NSColor,
    lineBreakMode: NSLineBreakMode = .byTruncatingTail
  ) -> HistoryFixedTextColorLabel {
    if nextLabelIndex == labels.count {
      labels.append(HistoryFixedTextColorLabel(labelWithString: ""))
    }
    let field = labels[nextLabelIndex]
    nextLabelIndex += 1
    field.update(
      text: text,
      font: font,
      textColor: textColor,
      searchQuery: searchQuery,
      lineBreakMode: lineBreakMode
    )
    field.maximumNumberOfLines = 1
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return field
  }

  func registerSelectionTitleField(_ field: NSTextField) {
    selectionTitleFields.append(field)
  }

  // MARK: - Type icon box

  func configureTypeIconColorSwatch(_ color: NSColor, toolTip: String?) {
    typeIconView.configure(colorSwatch: color, toolTip: toolTip)
  }

  func configureTypeIconImage(
    _ image: NSImage,
    style: HistoryTypeIconImageStyle,
    toolTip: String?,
    alpha: CGFloat = 1
  ) {
    typeIconView.configure(image: image, style: style, toolTip: toolTip, alpha: alpha)
  }

  /// Shows the picture of a text that is an SVG document in place of the type symbol,
  /// like the thumbnail of an image. A picture that would blend into the row gets a
  /// background it stays visible on. Hidden content keeps the symbol, since the picture
  /// would give it away. A picture drawn before shows at once; otherwise the symbol stays
  /// until the picture is drawn in the background.
  func configureTypeIconSVGPreview(for item: ClipboardItem) {
    guard !hidesSensitiveContent else {
      return
    }

    let cachedRendering = SVGImageRenderer.shared.rendering(for: item) { [weak self] rendering in
      // The row may show another item by now, or the same one edited or hidden since.
      guard let self,
            let rendering,
            let configuredItem = self.configuredItem,
            configuredItem.id == item.id,
            configuredItem.text == item.text,
            !self.hidesSensitiveContent else {
        return
      }

      self.configureTypeIconSVGThumbnail(rendering, toolTip: item.contentTitle)
    }
    if let cachedRendering {
      configureTypeIconSVGThumbnail(cachedRendering, toolTip: item.contentTitle)
    }
  }

  private func configureTypeIconSVGThumbnail(_ rendering: SVGImageRenderer.Rendering, toolTip: String) {
    configureTypeIconImage(
      rendering.thumbnail,
      style: .pictureWithBackdrop(rendering.backgroundColor(matching: .clear)),
      toolTip: toolTip
    )
  }

  // MARK: - Selection order column

  /// Shows the item's place in a multiple selection, an empty circle for a row that is not
  /// selected while the column is shown, or nothing. The column slides in and out when
  /// `animated`; rows being configured for display take the new state at once.
  func setSelectionOrderBadge(number: Int?, showsPlaceholder: Bool, animated: Bool = false) {
    selectionOrderBadgeView.number = number
    let shows = number != nil || showsPlaceholder
    guard shows != showsSelectionOrderColumn else {
      return
    }

    showsSelectionOrderColumn = shows
    let width = shows ? HistoryRow.selectionOrderColumnWidth : 0
    let alpha: CGFloat = shows ? 1 : 0

    guard animated, window != nil else {
      selectionOrderColumnWidthConstraint?.constant = width
      selectionOrderBadgeView.alphaValue = alpha
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = HistoryRow.selectionOrderColumnAnimationDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      context.allowsImplicitAnimation = true
      selectionOrderColumnWidthConstraint?.animator().constant = width
      selectionOrderBadgeView.animator().alphaValue = alpha
      layoutSubtreeIfNeeded()
    }
  }

  // MARK: - File helpers

  func isFirstFileImage(_ item: ClipboardItem) -> Bool {
    guard let filePath = item.filePaths.first else {
      return false
    }

    return filePreviewCache?.isImageFile(at: filePath) ?? ClipboardItem.isImageFile(at: filePath)
  }

  func isConfigured(for item: ClipboardItem) -> Bool {
    configuredItem?.id == item.id
  }

  /// The preview of a file at the given size: an image thumbnail for a picture, the
  /// file icon otherwise. The cache calls `completion` once a thumbnail is generated.
  func filePreviewImage(
    filePath: String,
    targetSize: CGSize,
    completion: ((NSImage) -> Void)?
  ) -> NSImage {
    guard let filePreviewCache else {
      if ClipboardItem.isImageFile(at: filePath), let image = NSImage(contentsOfFile: filePath) {
        return image
      }

      return NSWorkspace.shared.icon(forFile: filePath)
    }

    return filePreviewCache.image(forFileAt: filePath, targetSize: targetSize) { image in
      completion?(image)
    }
  }

  func imageDimensions(forFileAt filePath: String) -> (width: Int, height: Int)? {
    guard filePreviewCache?.isImageFile(at: filePath) ?? ClipboardItem.isImageFile(at: filePath) else {
      return nil
    }

    if let displaySize = filePreviewCache?.displaySizeForImageFile(at: filePath) {
      return (Int(displaySize.width.rounded()), Int(displaySize.height.rounded()))
    }

    let fileURL = URL(fileURLWithPath: filePath)
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
      return nil
    }

    return (width, height)
  }

  // MARK: - Private

  private func configure() {
    typeIconView.translatesAutoresizingMaskIntoConstraints = false
    configureSelectionOrderColumn()

    textColumn.orientation = .vertical
    textColumn.distribution = .fill
    textColumn.spacing = HistoryRow.lineSpacing
    textColumn.alignment = .leading
    textColumn.translatesAutoresizingMaskIntoConstraints = false
    textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
    textColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textColumn.setContentHuggingPriority(.required, for: .vertical)

    makeAccessoryControls()

    rowStack.orientation = .horizontal
    rowStack.distribution = .fill
    rowStack.alignment = .centerY
    rowStack.spacing = HistoryRow.accessorySpacing
    rowStack.translatesAutoresizingMaskIntoConstraints = false
    rowStack.addArrangedSubview(selectionOrderColumn)
    rowStack.addArrangedSubview(typeIconView)
    rowStack.addArrangedSubview(textColumn)
    rowStack.addArrangedSubview(accessoryControlsView)
    rowStack.setCustomSpacing(0, after: selectionOrderColumn)
    rowStack.setCustomSpacing(HistoryRow.typeIconContentSpacing, after: typeIconView)
    updateContentSpacing()

    addSubview(rowStack)

    let leadingConstraint = rowStack.leadingAnchor.constraint(
      equalTo: leadingAnchor,
      constant: HistoryRow.contentHorizontalInset
    )
    let trailingConstraint = rowStack.trailingAnchor.constraint(
      equalTo: trailingAnchor,
      constant: -HistoryRow.contentHorizontalInset
    )
    rowStackLeadingConstraint = leadingConstraint
    rowStackTrailingConstraint = trailingConstraint

    NSLayoutConstraint.activate([
      typeIconView.widthAnchor.constraint(equalToConstant: HistoryRow.typeIconBoxSize),
      typeIconView.heightAnchor.constraint(equalToConstant: HistoryRow.typeIconBoxSize),
      leadingConstraint,
      trailingConstraint,
      rowStack.centerYAnchor.constraint(equalTo: centerYAnchor),
      rowStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: HistoryRow.contentVerticalInset),
      rowStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -HistoryRow.contentVerticalInset)
    ])
  }

  // The column is a clipping container whose width animates between zero and its full
  // width, so the circle slides in from under the row's leading edge and the content moves
  // right with it.
  private func configureSelectionOrderColumn() {
    selectionOrderColumn.translatesAutoresizingMaskIntoConstraints = false
    selectionOrderColumn.wantsLayer = true
    selectionOrderColumn.layer?.masksToBounds = true
    selectionOrderColumn.setContentHuggingPriority(.required, for: .horizontal)
    selectionOrderColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
    selectionOrderBadgeView.translatesAutoresizingMaskIntoConstraints = false
    selectionOrderBadgeView.alphaValue = 0
    selectionOrderColumn.addSubview(selectionOrderBadgeView)

    let widthConstraint = selectionOrderColumn.widthAnchor.constraint(equalToConstant: 0)
    selectionOrderColumnWidthConstraint = widthConstraint

    NSLayoutConstraint.activate([
      widthConstraint,
      selectionOrderColumn.heightAnchor.constraint(equalToConstant: HistoryRow.selectionOrderBadgeSize),
      selectionOrderBadgeView.widthAnchor.constraint(equalToConstant: HistoryRow.selectionOrderBadgeSize),
      selectionOrderBadgeView.heightAnchor.constraint(equalToConstant: HistoryRow.selectionOrderBadgeSize),
      selectionOrderBadgeView.leadingAnchor.constraint(equalTo: selectionOrderColumn.leadingAnchor),
      selectionOrderBadgeView.centerYAnchor.constraint(equalTo: selectionOrderColumn.centerYAnchor)
    ])
  }

  // Rows of the same kind usually ask for the same views in the same order, and then the
  // text column is left as it is.
  private func applyPendingLines() {
    guard !textColumn.arrangedSubviews.elementsEqual(pendingLines, by: ===) else {
      return
    }

    textColumn.arrangedSubviews.forEach { view in
      textColumn.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    pendingLines.forEach { view in
      view.translatesAutoresizingMaskIntoConstraints = false
      textColumn.addArrangedSubview(view)
      view.widthAnchor.constraint(equalTo: textColumn.widthAnchor).isActive = true
    }
  }

  private func applyPendingTrailingView() {
    guard pendingTrailingView !== trailingView else {
      return
    }

    if let trailingView {
      rowStack.removeArrangedSubview(trailingView)
      trailingView.removeFromSuperview()
    }
    if let pendingTrailingView {
      let textColumnIndex = rowStack.arrangedSubviews.firstIndex(of: textColumn) ?? rowStack.arrangedSubviews.count - 1
      rowStack.insertArrangedSubview(pendingTrailingView, at: textColumnIndex + 1)
    }
    trailingView = pendingTrailingView
    updateContentSpacing()
  }

  private func configureAccessoryControls(item: ClipboardItem, quickPasteIndex: Int?, isMasked: Bool) {
    measuredAccessoryControlsWidth = nil
    guard isMasked || hasVisibleAccessoryControls(item: item, quickPasteIndex: quickPasteIndex) else {
      accessoryControlsView.isHidden = true
      return
    }

    sensitiveContentButton.isHidden = !isMasked
    if isMasked {
      let label = hidesSensitiveContent
        ? L10n.string("Show Sensitive Content")
        : L10n.string("Hide Sensitive Content")
      sensitiveContentButton.toolTip = label
      sensitiveContentButton.setAccessibilityLabel(label)
    }
    configureTagIcons()
    favoriteView.isHidden = !item.isFavorite
    quickPasteField.stringValue = quickPasteIndex.map { "⌘\($0)" } ?? ""
    quickPasteField.isHidden = quickPasteIndex == nil
    configureSourceAppIcon(for: item)
    accessoryControlsView.isHidden = false
  }

  private func updateSelectionAppearance() {
    let isSelected = backgroundStyle == .emphasized
    let titleColor = HistorySelectionAppearance.textColor(
      for: self,
      isSelected: isSelected
    )

    selectionTitleFields.forEach { field in
      if let fixedColorField = field as? HistoryFixedTextColorLabel {
        fixedColorField.preferredTextColor = titleColor
      } else {
        field.textColor = titleColor
      }
    }
    quickPasteField.preferredTextColor = makeQuickPasteTextColor(isSelected: isSelected)
    if !sensitiveContentButton.isHidden {
      sensitiveContentButton.image = makeSensitiveContentButtonImage(isSelected: isSelected)
    }
  }

  private func makeQuickPasteTextColor(isSelected: Bool) -> NSColor {
    guard isSelected,
          effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua else {
      return .tertiaryLabelColor
    }

    return .darkGray
  }

  // The controls sit in this order, and a stack view leaves the hidden ones out.
  private func makeAccessoryControls() {
    configureSensitiveContentButton()

    tagIconsView.orientation = .horizontal
    tagIconsView.distribution = .fill
    tagIconsView.spacing = HistoryRow.tagIconSpacing
    tagIconsView.alignment = .centerY
    tagIconsView.translatesAutoresizingMaskIntoConstraints = false
    tagIconsView.setContentHuggingPriority(.required, for: .horizontal)
    tagIconsView.setContentCompressionResistancePriority(.required, for: .horizontal)

    quickPasteField.preferredTextColor = .tertiaryLabelColor
    quickPasteField.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    quickPasteField.alignment = .right

    sourceAppIconView.imageScaling = .scaleProportionallyDown
    sourceAppIconView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      sourceAppIconView.widthAnchor.constraint(equalToConstant: HistoryRow.sourceAppIconSize),
      sourceAppIconView.heightAnchor.constraint(equalToConstant: HistoryRow.sourceAppIconSize)
    ])

    [sensitiveContentButton, tagIconsView, favoriteView, quickPasteField, sourceAppIconView].forEach { view in
      view.setContentHuggingPriority(.required, for: .horizontal)
      accessoryControlsView.addArrangedSubview(view)
    }
    sourceAppIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
    accessoryControlsView.orientation = .horizontal
    accessoryControlsView.distribution = .fill
    accessoryControlsView.spacing = HistoryRow.accessorySpacing
    accessoryControlsView.alignment = .centerY
    accessoryControlsView.translatesAutoresizingMaskIntoConstraints = false
    accessoryControlsView.setContentHuggingPriority(.required, for: .horizontal)
    accessoryControlsView.setContentCompressionResistancePriority(.required, for: .horizontal)
    accessoryControlsView.isHidden = true
  }

  // An eye shows the hidden content and a crossed out eye hides it again, as in a
  // password field.
  private func configureSensitiveContentButton() {
    sensitiveContentButton.target = self
    sensitiveContentButton.action = #selector(toggleSensitiveContentVisibility)
    sensitiveContentButton.isBordered = false
    sensitiveContentButton.imagePosition = .imageOnly
    sensitiveContentButton.refusesFirstResponder = true
    sensitiveContentButton.translatesAutoresizingMaskIntoConstraints = false
    sensitiveContentButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    sensitiveContentButton.isHidden = true
  }

  // The eye takes the color of the quick paste shortcut next to it. The color is part of
  // the image, because a selected row draws a template image in white.
  private func makeSensitiveContentButtonImage(isSelected: Bool) -> NSImage {
    let configuration = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .regular)
    guard let symbol = NSImage(
      systemSymbolName: hidesSensitiveContent ? "eye" : "eye.slash",
      accessibilityDescription: nil
    )?.withSymbolConfiguration(configuration) else {
      return NSImage()
    }

    // The symbol is filled with the color by hand. As a palette color of the symbol, a
    // translucent color such as this one is drawn fainter than it is in text.
    let color = makeQuickPasteTextColor(isSelected: isSelected)
    let appearance = effectiveAppearance
    let image = NSImage(size: symbol.size, flipped: false) { rect in
      appearance.performAsCurrentDrawingAppearance {
        symbol.draw(in: rect)
        color.set()
        rect.fill(using: .sourceIn)
      }
      return true
    }
    image.isTemplate = false
    return image
  }

  // The row is configured again in response, which changes the button, so that waits
  // until the button is done with the click.
  @objc private func toggleSensitiveContentVisibility() {
    let toggle = onToggleSensitiveContentVisibility
    DispatchQueue.main.async {
      toggle?()
    }
  }

  private func configureSourceAppIcon(for item: ClipboardItem) {
    let icon = HistorySourceAppIcon.image(
      bundleIdentifier: item.sourceBundleIdentifier,
      appName: item.sourceAppName
    )
    sourceAppIconView.image = icon
    sourceAppIconView.toolTip = item.sourceAppName
    sourceAppIconView.isHidden = icon == nil
  }

  private func hasVisibleAccessoryControls(item: ClipboardItem, quickPasteIndex: Int?) -> Bool {
    item.isFavorite || quickPasteIndex != nil || !itemTags.isEmpty || item.hasSourceApp
  }

  private func configureTagIcons() {
    while tagIconViews.count < itemTags.count {
      let imageView = makeTagIconView()
      tagIconViews.append(imageView)
      tagIconsView.addArrangedSubview(imageView)
    }

    for (index, imageView) in tagIconViews.enumerated() {
      guard index < itemTags.count else {
        imageView.isHidden = true
        continue
      }

      let tag = itemTags[index]
      imageView.image = HistorySymbolIcon.make(
        systemName: "circle.fill",
        tintColor: NSColor(tagHexString: tag.color) ?? .labelColor,
        pointSize: HistoryRow.tagIconSize,
        weight: .regular
      )
      imageView.toolTip = tag.name
      imageView.isHidden = false
    }
    tagIconsView.isHidden = itemTags.isEmpty
  }

  private func makeTagIconView() -> NSImageView {
    let imageView = NSImageView()
    imageView.imageScaling = .scaleProportionallyDown
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: HistoryRow.tagIconSize),
      imageView.heightAnchor.constraint(equalToConstant: HistoryRow.tagIconSize)
    ])
    return imageView
  }
}

// Resolves and caches source application icons so table scrolling never repeats
// application URL lookups or icon loads for the same app.
enum HistorySourceAppIcon {
  private static var cache: [String: NSImage] = [:]

  // The resolved icons are shared, so the requested size is part of the cache
  // key: mutating the size of a cached image would resize it everywhere it is
  // already displayed.
  static func image(
    bundleIdentifier: String?,
    appName: String?,
    size: CGFloat = HistoryRow.sourceAppIconSize
  ) -> NSImage? {
    guard let identifier = bundleIdentifier ?? appName else {
      return nil
    }

    let cacheKey = "\(identifier)|\(size)"
    if let cachedIcon = cache[cacheKey] {
      return cachedIcon
    }

    let icon = resolveIcon(bundleIdentifier: bundleIdentifier, appName: appName)
    icon.size = NSSize(width: size, height: size)
    cache[cacheKey] = icon
    return icon
  }

  private static func resolveIcon(bundleIdentifier: String?, appName: String?) -> NSImage {
    if let bundleIdentifier,
       let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
      return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    if let appName, let applicationURL = NSWorkspace.shared.applicationURL(named: appName) {
      return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    return NSWorkspace.shared.icon(for: .application)
  }
}

private enum HistorySymbolIcon {
  static func make(
    systemName: String,
    tintColor: NSColor,
    pointSize: CGFloat = 15,
    weight: NSFont.Weight = .regular
  ) -> NSImage? {
    make(systemName: systemName, paletteColors: [tintColor], pointSize: pointSize, weight: weight)
  }

  static func make(
    systemName: String,
    paletteColors: [NSColor],
    pointSize: CGFloat = 15,
    weight: NSFont.Weight = .regular
  ) -> NSImage? {
    let key = CacheKey(systemName: systemName, paletteColors: paletteColors, pointSize: pointSize, weight: weight)
    if let image = cache[key] {
      return image
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
      .applying(NSImage.SymbolConfiguration(paletteColors: paletteColors))
    let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
    cache[key] = image
    return image
  }

  // Every row that scrolls in asks for its type symbol and tag dots, and there are only a
  // few different ones, so each is made once.
  private struct CacheKey: Hashable {
    let systemName: String
    let paletteColors: [NSColor]
    let pointSize: CGFloat
    let weight: NSFont.Weight
  }

  private static var cache: [CacheKey: NSImage?] = [:]
}

// The circle a row shows in multiple selection: filled with the item's place in the
// selection, or an empty ring for a row that is not selected.
private final class HistorySelectionOrderBadgeView: NSView {
  private static let fontSize: CGFloat = 11
  private static let smallFontSize: CGFloat = 8
  private static let ringLineWidth: CGFloat = 1.5

  var number: Int? {
    didSet {
      if oldValue != number {
        needsDisplay = true
      }
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let number else {
      let inset = Self.ringLineWidth / 2
      let path = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
      NSColor.tertiaryLabelColor.setStroke()
      path.lineWidth = Self.ringLineWidth
      path.stroke()
      return
    }

    NSColor.controlAccentColor.setFill()
    NSBezierPath(ovalIn: bounds).fill()

    let text = "\(number)" as NSString
    let fontSize = number < 100 ? Self.fontSize : Self.smallFontSize
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
      .foregroundColor: NSColor.alternateSelectedControlTextColor
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
      at: NSPoint(
        x: bounds.midX - textSize.width / 2,
        y: bounds.midY - textSize.height / 2
      ),
      withAttributes: attributes
    )
  }
}

// The square at the left of every row. It shows the type symbol on a translucent rounded
// background, or in place of it a color swatch, an image preview, a file icon or a favicon.
// In multiple selection it shows the selection order badge instead.
private final class HistoryItemTypeIconView: NSView {
  private enum Content {
    case kind(ClipboardKind, systemImageName: String)
    case colorSwatch(NSColor)
    case image(NSImage, style: HistoryTypeIconImageStyle, alpha: CGFloat)
  }

  // The box background sits inside the view so it stays a little smaller than pictures,
  // file icons and color swatches, which use the whole view.
  private static let boxInset: CGFloat = 2
  // The swatch is a solid disc inside a translucent ring of the same color. The ring's
  // outer edge sits on the box outline, so the whole circle is exactly the box size.
  private static let swatchBorderWidth: CGFloat = 2
  private static let swatchBorderAlpha: CGFloat = 0.5
  private static let smallImageSize: CGFloat = 18
  private static let backdropPadding: CGFloat = 4
  // The lock of an item with sensitive content sits in the bottom right corner of the box
  // background, over the edge of whatever the box shows, so both can be told at a glance.
  private static let lockBadgeSize: CGFloat = 14
  private static let lockBadgeInset: CGFloat = 5
  private static let lockBadgeSymbolSize: CGFloat = 12.5
  private static let kindIconDarkColor = NSColor(
    srgbRed: 0x7E / 255.0,
    green: 0x7F / 255.0,
    blue: 0x81 / 255.0,
    alpha: 1
  )
  private static let kindIconLightColor = NSColor(
    srgbRed: 0x7E / 255.0,
    green: 0x7F / 255.0,
    blue: 0x82 / 255.0,
    alpha: 1
  )

  private let symbolImageView = NSImageView()
  private let lockBadgeView = NSImageView()
  private var content: Content?

  var showsLockBadge = false {
    didSet {
      lockBadgeView.isHidden = !showsLockBadge
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    symbolImageView.frame = NSRect(
      x: (newSize.width - Self.smallImageSize) / 2,
      y: (newSize.height - Self.smallImageSize) / 2,
      width: Self.smallImageSize,
      height: Self.smallImageSize
    )
    lockBadgeView.frame = NSRect(
      x: newSize.width - Self.lockBadgeSize - Self.lockBadgeInset,
      y: Self.lockBadgeInset,
      width: Self.lockBadgeSize,
      height: Self.lockBadgeSize
    )
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    switch content {
    case .kind, .none:
      drawBox()
    case .colorSwatch(let color):
      drawSwatch(color)
    case .image(let image, let style, let alpha):
      switch style {
      case .picture, .icon:
        drawImage(image, in: bounds, alpha: alpha)
      case .small:
        drawBox()
      case .pictureWithBackdrop(let backdropColor):
        // The color may differ by appearance, and drawing resolves it for this view's.
        guard (backdropColor.usingColorSpace(.sRGB)?.alphaComponent ?? 0) > 0 else {
          drawImage(image, in: bounds, alpha: alpha)
          break
        }

        backdropColor.setFill()
        boxPath.fill()
        let inset = Self.boxInset + Self.backdropPadding
        drawImage(image, in: bounds.insetBy(dx: inset, dy: inset), alpha: alpha)
      }
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    configureKindIconImage()
    needsDisplay = true
  }

  func configure(kind: ClipboardKind, systemImageName: String) {
    content = .kind(kind, systemImageName: systemImageName)
    configureKindIconImage()
    symbolImageView.toolTip = kind.title
    toolTip = kind.title
    updateSymbolVisibility()
    needsDisplay = true
  }

  func configure(colorSwatch color: NSColor, toolTip: String?) {
    content = .colorSwatch(color)
    self.toolTip = toolTip
    updateSymbolVisibility()
    needsDisplay = true
  }

  func configure(image: NSImage, style: HistoryTypeIconImageStyle, toolTip: String?, alpha: CGFloat) {
    content = .image(image, style: style, alpha: alpha)
    if style == .small {
      symbolImageView.image = image
      symbolImageView.alphaValue = alpha
    }
    symbolImageView.toolTip = toolTip
    self.toolTip = toolTip
    updateSymbolVisibility()
    needsDisplay = true
  }

  private func configure() {
    symbolImageView.imageScaling = .scaleProportionallyDown
    symbolImageView.imageAlignment = .alignCenter
    symbolImageView.translatesAutoresizingMaskIntoConstraints = true
    translatesAutoresizingMaskIntoConstraints = false
    addSubview(symbolImageView)

    lockBadgeView.image = HistorySymbolIcon.make(
      systemName: "lock.circle.fill",
      paletteColors: [.white, .systemGreen],
      pointSize: Self.lockBadgeSymbolSize,
      weight: .regular
    )
    lockBadgeView.imageScaling = .scaleNone
    lockBadgeView.imageAlignment = .alignCenter
    lockBadgeView.translatesAutoresizingMaskIntoConstraints = true
    lockBadgeView.isHidden = true
    addSubview(lockBadgeView)
  }

  private var showsSymbol: Bool {
    switch content {
    case .kind:
      return true
    case .image(_, let style, _):
      return style == .small
    case .colorSwatch, .none:
      return false
    }
  }

  private func updateSymbolVisibility() {
    symbolImageView.isHidden = !showsSymbol
  }

  private var boxPath: NSBezierPath {
    NSBezierPath.continuousRoundedRect(
      bounds.insetBy(dx: Self.boxInset, dy: Self.boxInset),
      cornerRadius: HistoryRow.typeIconBoxCornerRadius
    )
  }

  private func drawBox() {
    HistoryRow.typeIconBoxColor.setFill()
    boxPath.fill()
  }

  private func drawSwatch(_ color: NSColor) {
    let fillInset = Self.boxInset + Self.swatchBorderWidth
    let fillPath = NSBezierPath(ovalIn: bounds.insetBy(dx: fillInset, dy: fillInset))
    color.setFill()
    fillPath.fill()

    // The ring is stroked along its middle so it fills the band just outside the disc.
    let ringInset = Self.boxInset + Self.swatchBorderWidth / 2
    let ringPath = NSBezierPath(ovalIn: bounds.insetBy(dx: ringInset, dy: ringInset))
    color.withAlphaComponent(Self.swatchBorderAlpha).setStroke()
    ringPath.lineWidth = Self.swatchBorderWidth
    ringPath.stroke()
  }

  private func drawImage(_ image: NSImage, in rect: NSRect, alpha: CGFloat) {
    let imageRect = aspectFitRect(for: image.size, in: rect)
    image.draw(
      in: imageRect,
      from: NSRect(origin: .zero, size: image.size),
      operation: .sourceOver,
      fraction: alpha,
      respectFlipped: true,
      hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
    )
  }

  private func aspectFitRect(for size: NSSize, in rect: NSRect) -> NSRect {
    guard size.width > 0, size.height > 0 else {
      return rect
    }

    let scale = min(rect.width / size.width, rect.height / size.height)
    let fittedSize = NSSize(width: size.width * scale, height: size.height * scale)
    return NSRect(
      x: rect.midX - fittedSize.width / 2,
      y: rect.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    ).integral
  }

  private func configureKindIconImage() {
    guard case .kind(let kind, let systemImageName) = content else {
      return
    }

    symbolImageView.alphaValue = 1
    symbolImageView.image = HistorySymbolIcon.make(
      systemName: systemImageName.isEmpty ? kind.systemImage : systemImageName,
      tintColor: kindIconTintColor,
      pointSize: HistoryRow.typeIconSize,
      weight: .regular
    )
  }

  private var kindIconTintColor: NSColor {
    effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? Self.kindIconDarkColor
      : Self.kindIconLightColor
  }
}

private extension NSColor {
  convenience init?(tagHexString: String) {
    let hex = tagHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let value = Int(hex, radix: 16) else {
      return nil
    }

    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}
