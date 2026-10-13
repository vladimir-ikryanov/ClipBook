import AppKit

/// One row offered below the search field while the user is typing.
struct SearchSuggestion {
  let token: SearchToken
  /// Range of `token.title` matched by the typed text, highlighted in the row.
  let matchRange: NSRange?
}

/// Builds the suggestion list shown while typing in the search field.
///
/// Suggestions are grouped the same way the history filters are: content types
/// first, then the applications the items were copied from, then tags. Every
/// group accepts several tokens, so only the filters that are already applied
/// are left out.
enum SearchSuggestionProvider {
  static let defaultLimit = 8

  static func suggestions(
    for query: String,
    tags: [Tag],
    sourceApplications: [HistorySourceApplication],
    activeKinds: Set<SearchTokenKind>,
    limit: Int = defaultLimit
  ) -> [SearchSuggestion] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return []
    }

    var suggestions: [SearchSuggestion] = []

    suggestions += ranked(
      HistoryFilterContentType.allCases
        .filter { $0 != .all && !activeKinds.contains(.contentType($0)) }
        .compactMap { contentType in
          makeSuggestion(
            title: contentType.searchTokenTitle,
            query: query,
            kind: .contentType(contentType),
            image: SearchSuggestionIcon.contentTypeImage(for: contentType)
          )
        }
    )

    suggestions += ranked(
      sourceApplications
        .filter { !activeKinds.contains(.sourceApplication($0.id)) }
        .compactMap { application in
          makeSuggestion(
            title: application.name,
            query: query,
            kind: .sourceApplication(application.id),
            image: SearchSuggestionIcon.applicationImage(for: application)
          )
        }
    )

    suggestions += ranked(
      tags
        .filter { !activeKinds.contains(.tag($0.id)) }
        .compactMap { tag in
          makeSuggestion(
            title: tag.name,
            query: query,
            kind: .tag(tag.id),
            image: SearchSuggestionIcon.tagImage(for: tag)
          )
        }
    )

    return Array(suggestions.prefix(limit))
  }

  /// Keeps prefix matches ahead of matches found later in the title while
  /// preserving the order the candidates came in.
  private static func ranked(_ suggestions: [SearchSuggestion]) -> [SearchSuggestion] {
    let prefixMatches = suggestions.filter { $0.matchRange?.location == 0 }
    let otherMatches = suggestions.filter { $0.matchRange?.location != 0 }
    return prefixMatches + otherMatches
  }

  private static func makeSuggestion(
    title: String,
    query: String,
    kind: SearchTokenKind,
    image: NSImage?
  ) -> SearchSuggestion? {
    guard let matchRange = matchRange(of: query, in: title) else {
      return nil
    }

    return SearchSuggestion(
      token: SearchToken(kind: kind, title: title, image: image),
      matchRange: matchRange
    )
  }

  private static func matchRange(of query: String, in title: String) -> NSRange? {
    guard let range = title.range(
      of: query,
      options: [.caseInsensitive, .diacriticInsensitive],
      range: nil,
      locale: .current
    ) else {
      return nil
    }

    return NSRange(range, in: title)
  }
}

enum SearchSuggestionIcon {
  static let size: CGFloat = 16

  static func contentTypeImage(for contentType: HistoryFilterContentType) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      .applying(NSImage.SymbolConfiguration(hierarchicalColor: .controlAccentColor))
    return NSImage(systemSymbolName: contentType.systemImage, accessibilityDescription: contentType.searchTokenTitle)?
      .withSymbolConfiguration(configuration)
  }

  static func tagImage(for tag: Tag) -> NSImage? {
    HistoryFilterIcon.tagIcon(for: tag)
  }

  static func applicationImage(for sourceApplication: HistorySourceApplication) -> NSImage? {
    HistoryFilterIcon.applicationIcon(for: sourceApplication)
  }
}

/// Floating list of suggestions anchored below the search field.
///
/// It lives in a borderless child window so it can extend past the toolbar and
/// over the history list without disturbing the search field's focus.
@MainActor
final class SearchSuggestionsPopup {
  private static let rowHeight: CGFloat = 30
  /// Keeps the gap between the popup's edge and the selection highlight the
  /// same on every side.
  private static let verticalPadding: CGFloat =
    SearchSuggestionRowView.highlightInset - SearchSuggestionRowView.highlightVerticalInset
  private static let horizontalPadding: CGFloat = 8
  private static let iconTextSpacing: CGFloat = 8
  private static let minimumWidth: CGFloat = 120
  private static let maximumWidth: CGFloat = 340
  private static let anchorGap: CGFloat = 6

  var onSelect: ((SearchSuggestion) -> Void)?

  private let contentView = SearchSuggestionsContentView()
  private var panel: SearchSuggestionsPanel?
  private var rowViews: [SearchSuggestionRowView] = []
  private var suggestions: [SearchSuggestion] = []
  private var selectedIndex = 0

  var isVisible: Bool {
    panel?.isVisible == true
  }

  var selectedSuggestion: SearchSuggestion? {
    guard suggestions.indices.contains(selectedIndex) else {
      return nil
    }

    return suggestions[selectedIndex]
  }

  func update(
    suggestions: [SearchSuggestion],
    anchoredTo anchorFrameInScreen: NSRect,
    in parentWindow: NSWindow,
    appearance: NSAppearance?
  ) {
    guard !suggestions.isEmpty else {
      hide()
      return
    }

    let previousSelection = selectedSuggestion
    self.suggestions = suggestions
    selectedIndex = suggestions.firstIndex { $0.token == previousSelection?.token } ?? 0

    rebuildRows()
    let panel = ensurePanel(in: parentWindow)
    panel.appearance = appearance
    contentView.appearance = appearance
    panel.setFrame(frame(for: suggestions, anchoredTo: anchorFrameInScreen), display: true)
    // The shadow follows the masked, rounded shape only if it is recomputed
    // after the panel is resized.
    panel.invalidateShadow()
    updateRowHighlight()

    if !panel.isVisible {
      parentWindow.addChildWindow(panel, ordered: .above)
      panel.orderFront(nil)
    }
  }

  func hide() {
    guard let panel else {
      return
    }

    panel.parent?.removeChildWindow(panel)
    panel.orderOut(nil)
  }

  func moveSelection(by delta: Int) {
    guard !suggestions.isEmpty else {
      return
    }

    let count = suggestions.count
    selectedIndex = ((selectedIndex + delta) % count + count) % count
    updateRowHighlight()
  }

  // MARK: - Panel

  private func ensurePanel(in parentWindow: NSWindow) -> SearchSuggestionsPanel {
    // A hidden panel is replaced rather than shown again: once a window hidden
    // from screen capture is made capturable, the window server does not let
    // it be hidden again, and the panel follows the history window's setting.
    if let panel, panel.isVisible {
      return panel
    }

    let panel = SearchSuggestionsPanel(
      contentRect: NSRect(origin: .zero, size: NSSize(width: Self.minimumWidth, height: Self.rowHeight)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovable = false
    panel.hidesOnDeactivate = false
    panel.level = parentWindow.level
    panel.animationBehavior = .none
    panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    panel.contentView = contentView
    self.panel = panel
    return panel
  }

  private func frame(for suggestions: [SearchSuggestion], anchoredTo anchorFrameInScreen: NSRect) -> NSRect {
    let width = min(Self.maximumWidth, max(Self.minimumWidth, contentWidth(for: suggestions)))
    let height = CGFloat(suggestions.count) * Self.rowHeight + Self.verticalPadding * 2
    // Align the row titles with the text the user is typing, so the list reads
    // as a continuation of the search field.
    let titleInset = SearchSuggestionRowView.titleInset
    var origin = NSPoint(
      x: anchorFrameInScreen.minX - titleInset,
      y: anchorFrameInScreen.minY - Self.anchorGap - height
    )

    if let visibleFrame = NSScreen.screens
      .first(where: { $0.frame.intersects(anchorFrameInScreen) })?.visibleFrame {
      origin.x = min(max(visibleFrame.minX + 4, origin.x), visibleFrame.maxX - width - 4)
      origin.y = max(visibleFrame.minY + 4, origin.y)
    }

    return NSRect(origin: origin, size: NSSize(width: width, height: height))
  }

  private func contentWidth(for suggestions: [SearchSuggestion]) -> CGFloat {
    // Measured with the bold face used for the matched range, which is the
    // widest the title can render.
    let font = NSFont.systemFont(ofSize: SearchSuggestionRowView.titleFont.pointSize, weight: .bold)
    let titleWidth = suggestions.reduce(CGFloat(0)) { partialResult, suggestion in
      max(partialResult, ceil(suggestion.token.title.size(withAttributes: [.font: font]).width))
    }
    return SearchSuggestionRowView.titleInset
      + titleWidth
      + SearchSuggestionRowView.titleTrailingInset
      + 6
  }

  private func rebuildRows() {
    rowViews.forEach { $0.removeFromSuperview() }
    rowViews = suggestions.enumerated().map { index, suggestion in
      let rowView = SearchSuggestionRowView(suggestion: suggestion)
      rowView.onHover = { [weak self] in
        guard let self, self.selectedIndex != index else {
          return
        }

        self.selectedIndex = index
        self.updateRowHighlight()
      }
      rowView.onClick = { [weak self] in
        self?.onSelect?(suggestion)
      }
      contentView.addSubview(rowView)
      return rowView
    }

    contentView.rowHeight = Self.rowHeight
    contentView.verticalPadding = Self.verticalPadding
    contentView.needsLayout = true
  }

  private func updateRowHighlight() {
    for (index, rowView) in rowViews.enumerated() {
      rowView.isHighlighted = index == selectedIndex
    }
  }
}

private final class SearchSuggestionsPanel: NSPanel {
  override var canBecomeKey: Bool {
    false
  }

  override var canBecomeMain: Bool {
    false
  }
}

private final class SearchSuggestionsContentView: NSVisualEffectView {
  private static let cornerRadius: CGFloat = 10

  var rowHeight: CGFloat = 30
  var verticalPadding: CGFloat = 4

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isFlipped: Bool {
    true
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateBorderColor()
  }

  override func layout() {
    super.layout()

    var y = verticalPadding
    for subview in subviews {
      subview.frame = NSRect(x: 0, y: y, width: bounds.width, height: rowHeight)
      y += rowHeight
    }
  }

  private func configure() {
    material = .menu
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = Self.cornerRadius
    layer?.masksToBounds = true
    layer?.borderWidth = 1
    // The behind-window material is composited by the window server from this
    // mask, not from the layer's corner radius, so without it the blur (and the
    // window shadow) stays a sharp-cornered rectangle around the rounded popup.
    maskImage = Self.makeMaskImage()
    updateBorderColor()
  }

  private static func makeMaskImage() -> NSImage {
    let radius = cornerRadius
    let size = radius * 2 + 1
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
  }

  private func updateBorderColor() {
    var borderColor = NSColor.separatorColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      borderColor = NSColor.separatorColor.usingColorSpace(.sRGB) ?? borderColor
    }
    layer?.borderColor = borderColor.cgColor
  }
}

private final class SearchSuggestionRowView: NSView {
  static let titleFont = NSFont.systemFont(ofSize: 14, weight: .regular)
  private static let horizontalPadding: CGFloat = 8
  private static let iconTextSpacing: CGFloat = 8
  static let highlightInset: CGFloat = 4
  /// Rows sit next to each other, so the highlight only insets enough to leave a
  /// hairline gap between neighbours; the popup's own padding makes up the rest.
  static let highlightVerticalInset: CGFloat = 1
  private static let highlightCornerRadius: CGFloat = 6

  /// Distance from the popup's leading edge to the row title, used both to lay
  /// the rows out and to line the titles up with the text being typed.
  static var titleInset: CGFloat {
    horizontalPadding + highlightInset + SearchSuggestionIcon.size + iconTextSpacing
  }

  static var titleTrailingInset: CGFloat {
    horizontalPadding + highlightInset
  }

  var onHover: (() -> Void)?
  var onClick: (() -> Void)?

  var isHighlighted = false {
    didSet {
      guard isHighlighted != oldValue else {
        return
      }

      needsDisplay = true
      updateTitle()
    }
  }

  private let suggestion: SearchSuggestion
  private let imageView = NSImageView()
  private let titleField = NSTextField(labelWithString: "")

  init(suggestion: SearchSuggestion) {
    self.suggestion = suggestion
    super.init(frame: .zero)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isFlipped: Bool {
    true
  }

  override func draw(_ dirtyRect: NSRect) {
    guard isHighlighted else {
      return
    }

    let highlightRect = bounds.insetBy(dx: Self.highlightInset, dy: Self.highlightVerticalInset)
    let path = NSBezierPath(
      roundedRect: highlightRect,
      xRadius: Self.highlightCornerRadius,
      yRadius: Self.highlightCornerRadius
    )
    NSColor.selectedContentBackgroundColor.setFill()
    path.fill()
  }

  override func layout() {
    super.layout()

    let iconSize = SearchSuggestionIcon.size
    imageView.frame = NSRect(
      x: Self.horizontalPadding + Self.highlightInset,
      y: ((bounds.height - iconSize) / 2).rounded(),
      width: iconSize,
      height: iconSize
    )

    let titleX = Self.titleInset
    let titleHeight = ceil(titleField.intrinsicContentSize.height)
    titleField.frame = NSRect(
      x: titleX,
      y: ((bounds.height - titleHeight) / 2).rounded(),
      width: max(0, bounds.width - titleX - Self.titleTrailingInset),
      height: titleHeight
    )
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach { removeTrackingArea($0) }
    addTrackingArea(
      NSTrackingArea(
        rect: bounds,
        options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
        owner: self
      )
    )
  }

  override func mouseEntered(with event: NSEvent) {
    onHover?()
  }

  override func mouseDown(with event: NSEvent) {
    onClick?()
  }

  private func configure() {
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.image = suggestion.token.image
    addSubview(imageView)

    titleField.lineBreakMode = .byTruncatingTail
    titleField.maximumNumberOfLines = 1
    addSubview(titleField)
    updateTitle()
  }

  private func updateTitle() {
    let title = suggestion.token.title
    let color = isHighlighted ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor
    let attributedTitle = NSMutableAttributedString(
      string: title,
      attributes: [.font: Self.titleFont, .foregroundColor: color]
    )

    if let matchRange = suggestion.matchRange, matchRange.location != NSNotFound,
       NSMaxRange(matchRange) <= attributedTitle.length {
      attributedTitle.addAttribute(
        .font,
        value: NSFont.systemFont(ofSize: Self.titleFont.pointSize, weight: .bold),
        range: matchRange
      )
    }

    titleField.attributedStringValue = attributedTitle
  }
}
