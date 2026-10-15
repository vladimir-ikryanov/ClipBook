import AppKit

/// Where the preview pane sits in the history window. A tall window keeps the
/// list on top and the preview under it; a wide one puts them side by side.
enum HistoryPreviewPanePosition {
  case bottom
  case right
}

/// A card floating over the history window that holds the preview of the
/// selected item. It keeps a fixed gap to the window edges, and its corners
/// follow the corners of the window at that gap. Dragging the edge that faces
/// the list resizes it.
@MainActor
final class HistoryPreviewPane: NSView {
  /// The gap between the pane and the edges of the window.
  static var inset: CGFloat {
    if #available(macOS 26.0, *) {
      return 8
    }

    return 6
  }

  /// Concentric with the window corners: the corner radius of the window
  /// minus the gap the pane keeps to its edges.
  static var cornerRadius: CGFloat {
    max(windowCornerRadius - inset, 6)
  }

  private static var windowCornerRadius: CGFloat {
    if #available(macOS 26.0, *) {
      return NSWindow.macOS26CornerRadius
    }

    return 10
  }

  // The room kept above the preview at the bottom of the window, so its
  // text starts as far from the top edge as from the side edges. On the
  // right the preview's own inset is enough.
  private static let bottomContentTopInset: CGFloat = 10
  // How far into the pane its edge can be grabbed. It lies over the inset
  // of the preview, so it does not take clicks from the content.
  private static let resizeEdgeThickness: CGFloat = 6

  var position: HistoryPreviewPanePosition = .bottom {
    didSet {
      guard position != oldValue else {
        return
      }

      grabberView.position = position
      needsLayout = true
    }
  }

  /// The preview shown in the pane, or nil while nothing is selected.
  var contentView: NSView? {
    didSet {
      guard contentView !== oldValue else {
        return
      }

      oldValue?.removeFromSuperview()
      if let contentView {
        contentView.translatesAutoresizingMaskIntoConstraints = true
        contentView.autoresizingMask = [.width, .height]
        contentView.frame = contentFrame
        surfaceView.addSubview(contentView, positioned: .below, relativeTo: grabberView)
      }
      placeholderField.isHidden = contentView != nil
    }
  }

  var onResizeBegin: (() -> Void)? {
    get { grabberView.onDragBegin }
    set { grabberView.onDragBegin = newValue }
  }

  /// Called with how far the pointer moved since the drag began, in the
  /// direction that makes the pane larger.
  var onResize: ((CGFloat) -> Void)? {
    get { grabberView.onDrag }
    set { grabberView.onDrag = newValue }
  }

  var onResizeEnd: (() -> Void)? {
    get { grabberView.onDragEnd }
    set { grabberView.onDragEnd = newValue }
  }

  var onResizeReset: (() -> Void)? {
    get { grabberView.onDoubleClick }
    set { grabberView.onDoubleClick = newValue }
  }

  /// Whether the edge facing the list resizes the pane. A pane that holds only
  /// the details is as tall as they are, so it has no edge to drag and its
  /// content fills it.
  var isResizable = true {
    didSet {
      guard isResizable != oldValue else {
        return
      }

      grabberView.isHidden = !isResizable
      needsLayout = true
    }
  }

  var grabberMenu: NSMenu? {
    get { grabberView.menu }
    set { grabberView.menu = newValue }
  }

  private let surfaceView = HistoryPreviewPaneSurfaceView()
  private let grabberView = HistoryPreviewPaneGrabberView()
  private let placeholderField = NSTextField(labelWithString: "")

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func refreshLocalization() {
    placeholderField.stringValue = L10n.string("No item selected")
  }

  // A drag in the pane works on its content, never moves the window.
  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override func layout() {
    super.layout()

    surfaceView.frame = bounds
    switch position {
    case .bottom:
      grabberView.frame = NSRect(
        x: 0,
        y: bounds.height - Self.resizeEdgeThickness,
        width: bounds.width,
        height: Self.resizeEdgeThickness
      )
    case .right:
      grabberView.frame = NSRect(x: 0, y: 0, width: Self.resizeEdgeThickness, height: bounds.height)
    }
    contentView?.frame = contentFrame
    let placeholderSize = placeholderField.fittingSize
    placeholderField.frame = NSRect(
      x: contentFrame.midX - placeholderSize.width / 2,
      y: contentFrame.midY - placeholderSize.height / 2,
      width: placeholderSize.width,
      height: placeholderSize.height
    ).integral
    updateShadowPath()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateShadow()
  }

  private var contentFrame: NSRect {
    guard isResizable else {
      return bounds
    }

    switch position {
    case .bottom:
      return NSRect(
        x: 0,
        y: 0,
        width: bounds.width,
        height: max(0, bounds.height - Self.bottomContentTopInset)
      )
    case .right:
      return bounds
    }
  }

  private func configure() {
    // The shadow is drawn around the pane, so the pane itself does not clip;
    // the surface inside it is the part with the rounded corners.
    wantsLayer = true
    layer?.masksToBounds = false

    surfaceView.cornerRadius = Self.cornerRadius
    addSubview(surfaceView)

    placeholderField.font = .systemFont(ofSize: NSFont.systemFontSize)
    placeholderField.textColor = .tertiaryLabelColor
    placeholderField.alignment = .center
    surfaceView.addSubview(placeholderField)
    refreshLocalization()

    surfaceView.addSubview(grabberView)
    updateShadow()
  }

  // A light shadow lifts the pane off the history window. Against the dark
  // background a shadow barely shows, so it is deeper there, and the surface
  // gets a faint outline as well.
  private func updateShadow() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    layer?.shadowColor = NSColor.black.cgColor
    layer?.shadowOpacity = isDark ? 0.5 : 0.14
    layer?.shadowRadius = isDark ? 10 : 12
    layer?.shadowOffset = NSSize(width: 0, height: -1)
    updateShadowPath()
  }

  private func updateShadowPath() {
    layer?.shadowPath = CGPath(
      roundedRect: bounds,
      cornerWidth: Self.cornerRadius,
      cornerHeight: Self.cornerRadius,
      transform: nil
    )
  }
}

/// The rounded surface of the pane, filled with the background of the history
/// so the preview reads as part of it.
private final class HistoryPreviewPaneSurfaceView: NSView {
  var cornerRadius: CGFloat = 0 {
    didSet {
      layer?.cornerRadius = cornerRadius
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.masksToBounds = true
    layer?.cornerCurve = .continuous
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override func updateLayer() {
    layer?.backgroundColor = HistoryAppearance.backgroundCGColor(for: self)
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    layer?.borderWidth = isDark ? 1 : 0
    layer?.borderColor = NSColor(white: 1, alpha: 0.1).cgColor
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

/// The edge of the pane that faces the list. It shows nothing, only the
/// resize cursor, and dragging it resizes the pane. A double click puts the
/// pane back to its default size.
private final class HistoryPreviewPaneGrabberView: NSView {
  var position: HistoryPreviewPanePosition = .bottom {
    didSet {
      window?.invalidateCursorRects(for: self)
    }
  }

  var onDragBegin: (() -> Void)?
  var onDrag: ((CGFloat) -> Void)?
  var onDragEnd: (() -> Void)?
  var onDoubleClick: (() -> Void)?

  private var dragStartLocation: NSPoint?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setAccessibilityElement(true)
    setAccessibilityRole(.splitter)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    addCursorRect(bounds, cursor: position == .bottom ? .resizeUpDown : .resizeLeftRight)
  }

  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      onDoubleClick?()
      return
    }

    dragStartLocation = event.locationInWindow
    onDragBegin?()
  }

  override func mouseDragged(with event: NSEvent) {
    guard let dragStartLocation else {
      return
    }

    let location = event.locationInWindow
    switch position {
    case .bottom:
      onDrag?(location.y - dragStartLocation.y)
    case .right:
      onDrag?(dragStartLocation.x - location.x)
    }
  }

  override func mouseUp(with event: NSEvent) {
    guard dragStartLocation != nil else {
      return
    }

    dragStartLocation = nil
    onDragEnd?()
  }
}

/// A gradient from the background of the history up to clear, laid over the
/// bottom of the list. It never takes clicks, which go to the rows beneath.
private final class HistoryListFadeView: NSView {
  private let gradientLayer = CAGradientLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    layer?.addSublayer(gradientLayer)
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    gradientLayer.frame = bounds
    CATransaction.commit()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColors()
  }

  // Eased rather than linear, so the rows thin out gently at first and are
  // gone by the time they reach the pane.
  private func updateColors() {
    let color = HistoryAppearance.backgroundCGColor(for: self)
    let stops: [(location: CGFloat, alpha: CGFloat)] = [(0, 1), (0.3, 0.85), (0.65, 0.4), (1, 0)]
    gradientLayer.colors = stops.map { color.copy(alpha: $0.alpha) ?? color }
    gradientLayer.locations = stops.map { NSNumber(value: Double($0.location)) }
  }
}

/// Lays out the history list and the preview pane. The pane goes under the
/// list in a window taller than it is wide, and next to it otherwise.
@MainActor
final class HistoryPreviewSplitView: NSView {
  /// As tall as five rows of the history.
  static let defaultPaneHeight = HistoryRow.height * 5
  static let defaultPaneWidthRatio: CGFloat = 0.5
  private static let minimumPaneHeight: CGFloat = 120
  private static let minimumPaneWidth: CGFloat = 220
  // The room the list keeps whatever the size of the pane: a few rows below
  // the toolbar, or enough width for the text of a row.
  private static let minimumListHeight: CGFloat = 150
  private static let minimumListWidth: CGFloat = 260

  let listView: NSView
  let previewPane: HistoryPreviewPane

  var isPreviewShown = false {
    didSet {
      guard isPreviewShown != oldValue else {
        return
      }

      needsLayout = true
    }
  }

  /// Whether the pane shows the details of the selected item on their own,
  /// while the preview is hidden. The pane then sits at the bottom of the
  /// window whatever its shape, as tall as the details need.
  var isDetailsPaneShown = false {
    didSet {
      guard isDetailsPaneShown != oldValue else {
        return
      }

      needsLayout = true
    }
  }

  /// The height the details need at the given width.
  var detailsPaneHeight: ((CGFloat) -> CGFloat)?

  /// The height of the pane at the bottom, and the share of the width it
  /// takes on the right, as the user sized it. Nil keeps the default.
  var preferredPaneHeight: CGFloat? {
    didSet {
      needsLayout = true
    }
  }

  var preferredPaneWidthRatio: CGFloat? {
    didSet {
      needsLayout = true
    }
  }

  private(set) var position: HistoryPreviewPanePosition = .bottom
  var onPositionChange: ((HistoryPreviewPanePosition) -> Void)?
  /// Called once the user has finished resizing the pane, or reset its size.
  var onPreferredPaneSizeChange: (() -> Void)?

  /// Called with how much of the bottom of the list the fade covers, so the
  /// list can scroll its last row clear of it.
  var onListBottomFadeChange: ((CGFloat) -> Void)?

  private var resizeStartLength: CGFloat = 0
  // Fades the rows out just above a pane at the bottom of the window, so the
  // list runs into the pane rather than being cut off along its edge.
  private let listFadeView = HistoryListFadeView()
  private static let listFadeHeight: CGFloat = 32
  private var listBottomFade: CGFloat = 0

  init(listView: NSView, previewPane: HistoryPreviewPane) {
    self.listView = listView
    self.previewPane = previewPane
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false

    // Both are placed by layout() rather than by constraints.
    listView.translatesAutoresizingMaskIntoConstraints = true
    listView.autoresizingMask = []
    previewPane.translatesAutoresizingMaskIntoConstraints = true
    previewPane.autoresizingMask = []
    previewPane.isHidden = true
    addSubview(listView)
    listFadeView.isHidden = true
    addSubview(listFadeView)
    addSubview(previewPane)

    previewPane.onResizeBegin = { [weak self] in
      self?.beginResizingPane()
    }
    previewPane.onResize = { [weak self] translation in
      self?.resizePane(by: translation)
    }
    previewPane.onResizeEnd = { [weak self] in
      self?.onPreferredPaneSizeChange?()
    }
    previewPane.onResizeReset = { [weak self] in
      self?.resetPaneSize()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()

    let position: HistoryPreviewPanePosition = bounds.width > bounds.height ? .right : .bottom
    if position != self.position {
      self.position = position
      previewPane.position = position
      onPositionChange?(position)
    }

    let inset = HistoryPreviewPane.inset
    guard isPreviewShown else {
      previewPane.isResizable = false
      guard isDetailsPaneShown else {
        previewPane.isHidden = true
        listView.frame = bounds
        setListBottomFade(0)
        return
      }

      previewPane.isHidden = false
      let width = max(0, bounds.width - inset * 2)
      let height = (detailsPaneHeight?(width) ?? 0).rounded(.up)
      previewPane.frame = NSRect(x: inset, y: inset, width: width, height: height)
      placeListAbovePane()
      return
    }

    previewPane.isHidden = false
    previewPane.isResizable = true
    switch position {
    case .bottom:
      let height = paneHeight(preferred: preferredPaneHeight ?? Self.defaultPaneHeight)
      previewPane.frame = NSRect(
        x: inset,
        y: inset,
        width: max(0, bounds.width - inset * 2),
        height: height
      ).integral
      placeListAbovePane()
    case .right:
      let width = paneWidth(preferred: bounds.width * (preferredPaneWidthRatio ?? Self.defaultPaneWidthRatio))
      // The toolbar runs across the whole window, so the pane starts below it.
      let topInset = safeAreaInsets.top + inset
      previewPane.frame = NSRect(
        x: bounds.width - inset - width,
        y: inset,
        width: width,
        height: max(0, bounds.height - topInset - inset)
      ).integral
      listView.frame = NSRect(x: 0, y: 0, width: previewPane.frame.minX, height: bounds.height)
      // Side by side, the pane has no edge running across the list.
      setListBottomFade(0)
    }
  }

  private func placeListAbovePane() {
    let listMinY = previewPane.frame.maxY
    listView.frame = NSRect(x: 0, y: listMinY, width: bounds.width, height: max(0, bounds.height - listMinY))
    listFadeView.frame = NSRect(
      x: 0,
      y: listMinY,
      width: bounds.width,
      height: min(Self.listFadeHeight, listView.frame.height)
    )
    setListBottomFade(Self.listFadeHeight)
  }

  private func setListBottomFade(_ height: CGFloat) {
    listFadeView.isHidden = height == 0
    guard height != listBottomFade else {
      return
    }

    listBottomFade = height
    onListBottomFadeChange?(height)
  }

  private func paneHeight(preferred: CGFloat) -> CGFloat {
    let availableHeight = bounds.height - safeAreaInsets.top - HistoryPreviewPane.inset
    let maximumHeight = max(0, availableHeight - Self.minimumListHeight)
    return min(max(preferred, Self.minimumPaneHeight), maximumHeight).rounded()
  }

  private func paneWidth(preferred: CGFloat) -> CGFloat {
    let availableWidth = bounds.width - HistoryPreviewPane.inset
    let maximumWidth = max(0, availableWidth - Self.minimumListWidth)
    return min(max(preferred, Self.minimumPaneWidth), maximumWidth).rounded()
  }

  private func beginResizingPane() {
    switch position {
    case .bottom:
      resizeStartLength = previewPane.frame.height
    case .right:
      resizeStartLength = previewPane.frame.width
    }
  }

  // The size is kept within what the window allows, so a drag past the limit
  // turns around right where the pane stopped.
  private func resizePane(by translation: CGFloat) {
    switch position {
    case .bottom:
      preferredPaneHeight = paneHeight(preferred: resizeStartLength + translation)
    case .right:
      guard bounds.width > 0 else {
        return
      }
      preferredPaneWidthRatio = paneWidth(preferred: resizeStartLength + translation) / bounds.width
    }
    layoutSubtreeIfNeeded()
  }

  private func resetPaneSize() {
    switch position {
    case .bottom:
      preferredPaneHeight = nil
    case .right:
      preferredPaneWidthRatio = nil
    }
    onPreferredPaneSizeChange?()
  }
}
