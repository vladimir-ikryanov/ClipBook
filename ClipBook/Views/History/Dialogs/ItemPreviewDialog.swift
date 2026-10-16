import AppKit
import Quartz
import WebKit

@MainActor
final class ItemPreviewDialogController: NSViewController {
  enum Presentation {
    /// A sheet of its own, with a toolbar, sized to fit the item.
    case sheet
    /// The preview pane of the history window, which decides its size. It
    /// follows the history selection without ever taking the focus.
    case pane
  }

  static let minimumContentSize = NSSize(width: 360, height: 300)
  // The toolbar sits outside the content view, so its height has to be reserved
  // separately when the sheet is sized against the available screen space.
  static let toolbarHeight = ItemPreviewToolbar.height
  private static let contentInset: CGFloat = 6
  private static let defaultContentSize = NSSize(width: 640, height: 520)
  // Text-like items (text, rich text, email, link) get a shorter dialog: the
  // height covers the preview and the details bar together.
  private static let compactDialogHeight: CGFloat = 400
  // An email is a single address, so it needs even less room than the other
  // text-like items.
  private static let emailDialogHeight: CGFloat = 300
  // Quick Look previews of files that are not images, and of folders. Like
  // the compact height, the height covers the preview and the details bar.
  private static let fileDialogSize = NSSize(width: 600, height: 400)
  // An image file names itself in the title bar and carries the widest toolbar,
  // so its dialog is kept wide enough for both. The other files show a single
  // toolbar item and fit their name into whatever width their preview asks for.
  private static let imageFileMinimumDialogWidth = ItemPreviewToolbar.minimumTitleBarWidth
  private static let colorContentSize = NSSize(width: 420, height: 340)
  // A web page needs room to lay itself out the way it does in a browser. The
  // height covers the preview and the details bar together, and both sides are
  // clamped to what the screen allows.
  private static let webPageDialogSize = NSSize(width: 1280, height: 680)
  // Like the file preview, the height covers the preview and the details bar.
  // The picture is drawn from its markup, so it is scaled to fill the room.
  private static let svgDialogSize = NSSize(width: 560, height: 460)
  private static let svgContentPadding: CGFloat = 24
  private static let colorSwatchDiameter: CGFloat = 180
  private static let colorContentHorizontalMargin: CGFloat = 16
  private static let colorContentVerticalMargin: CGFloat = 16
  // Kept small vertically, so the first line sits close to the toolbar. The
  // inset applies to the bottom too, so the last line gets the rest of its gap
  // above the details panel from `textBottomSpacing`.
  private static let textContainerInset = NSSize(width: 14, height: 4)
  private static let textBottomSpacing: CGFloat = 10

  private enum PreviewContent {
    case image(NSImage)
    case fileQuickLook(URL)
    case fileList([String])
    case color(NSColor, String)
    case svg(SVGImageRenderer.Rendering)
    case webPage(URL)
    case text(NSAttributedString)
  }

  private(set) var item: ClipboardItem
  private let loadFormatting: (ClipboardItem) -> ClipboardItem
  private let detectsSensitiveContent: Bool
  // Whether the user asked to see the hidden content of the item for now.
  private(set) var revealsSensitiveContent: Bool
  private let maximumContentSize: NSSize
  private let toolbar: ItemPreviewToolbar
  private var contentView: NSView?
  // The text view of the in-place editor, present only while editing, and
  // the text it started from, to tell whether there is anything to save.
  private weak var editingTextView: NSTextView?
  private var originalEditingText = ""
  // Set when the sheet was presented only to edit the item, so leaving the
  // edit mode dismisses the whole preview instead of falling back to it.
  private var closesWhenEditingEnds = false
  // Model updates that arrive while editing are applied once the edit ends,
  // so the editor is not torn down underneath the user.
  private var pendingItem: ClipboardItem?
  private var pendingRevealsSensitiveContent = false
  // The size the preview asks for. It is applied to the window directly rather
  // than through `preferredContentSize`: once AppKit has seen a preferred size
  // on a sheet it holds the sheet at that size, and every later resize is
  // ignored, the user dragging an edge included.
  private(set) var windowContentSize: NSSize = .zero
  // A sheet the user has resized keeps the size they chose instead of jumping
  // back to the size of whichever item they move to next.
  private var hasUserResizedWindow = false
  // Created eagerly on first access, because the dialog size depends on how
  // tall the details bar is before the view hierarchy exists.
  private lazy var detailsView = ItemPreviewDetailsView(
    item: item,
    style: presentation == .sheet ? .floating : .docked
  )
  // The web page preview of a link, and the two views layered over it while it
  // loads or when it fails to.
  private weak var webView: WKWebView?
  private weak var webLoadingIndicator: NSProgressIndicator?
  private weak var webMessageField: NSTextField?
  // Whether an SVG document is previewed as its markup rather than its picture,
  // as the user chose in the toolbar. It holds for every item while the preview
  // is open.
  private var showsSVGMarkup = false
  var onCancel: (() -> Void)?
  var onToggleFavorite: ((ClipboardItem) -> Void)?
  var onToggleSensitiveContentVisibility: ((ClipboardItem) -> Void)?
  var onCopyTextFromImage: ((ClipboardItem) -> Void)?
  var onCopyTextFromQRCode: ((ClipboardItem) -> Void)?
  // Both present a panel or hand the item to another application, so the
  // preview gets out of the way first.
  var onSaveAsFile: ((ClipboardItem) -> Void)?
  var onOpenInApplication: ((ClipboardItem) -> Void)?
  var onShowInFinder: ((ClipboardItem) -> Void)?
  // Called with the edited text when the in-place editor is saved. Saving
  // may change the kind of the item; the preview follows the model update.
  var onSave: ((ClipboardItem, String) -> Void)?
  var moreActionsMenuProvider: ((ClipboardItem) -> NSMenu?)?
  var tagsMenuProvider: ((ClipboardItem) -> NSMenu?)?
  // Gives the presenter a chance to handle keys the sheet does not consume itself,
  // e.g. arrow keys that move the history selection while the preview stays open.
  var onKeyDown: ((NSEvent) -> Bool)?
  // A read-only history (after the trial) is previewed without editing and
  // without selecting its text to copy.
  private let isReadOnly: Bool
  private let presentation: Presentation
  // Called in the pane when the content the focus was in goes away, so the
  // focus can go back to the history list instead of being left nowhere.
  var onContentFocusLost: (() -> Void)?
  // A web page in the pane would load for every link the selection passes
  // over, so the pane shows pages only when link previews are wanted.
  var showsWebPages = true {
    didSet {
      guard showsWebPages != oldValue, item.kind == .link else {
        return
      }
      reinstallContentView()
    }
  }
  // The details panel can be turned off in the pane, which then gives its
  // room to the preview.
  var showsDetails = true {
    didSet {
      guard showsDetails != oldValue else {
        return
      }
      detailsView.isHidden = !showsDetails
      detailsFadeView.isHidden = !showsDetailsFade
      reinstallContentView()
    }
  }
  // The pane can show the details alone, as a bar the height of its fields,
  // while the preview is hidden. Showing the preview again fills in the
  // content above the same bar.
  var showsPreview = true {
    didSet {
      guard showsPreview != oldValue else {
        return
      }
      detailsView.showsTopSeparator = showsPreview
      detailsFadeView.isHidden = !showsDetailsFade
      reinstallContentView()
    }
  }

  /// How the pane sets out the details under the preview: next to each other,
  /// or listed one per row when the pane has the height for it.
  var detailsArrangement: ItemPreviewDetailsView.Arrangement {
    get { detailsView.arrangement }
    set {
      detailsView.arrangement = newValue
      updateDetailsFade()
    }
  }

  // Listed details have no line above them, so the preview fades out into
  // them instead of being cut off where they begin.
  private let detailsFadeView = HistoryListFadeView()
  private static let detailsFadeHeight: CGFloat = 24

  private var showsDetailsFade: Bool {
    presentation == .pane && showsPreview && showsDetails && detailsView.arrangement == .list
  }

  private func updateDetailsFade() {
    detailsFadeView.isHidden = !showsDetailsFade
    updateDetailsInset()
  }

  /// The height the details need at the given width, which is the height of
  /// the pane while it shows only them.
  func detailsHeight(forWidth width: CGFloat) -> CGFloat {
    detailsView.preferredHeight(forWidth: width)
  }

  // A page loads only once the selection has rested on its link for a moment,
  // so moving through the list in the pane does not start a load per link.
  private static let paneWebPageLoadDelay: TimeInterval = 0.3

  init(
    item: ClipboardItem,
    maximumContentSize: NSSize,
    detectsSensitiveContent: Bool,
    revealsSensitiveContent: Bool,
    isReadOnly: Bool = false,
    presentation: Presentation = .sheet,
    loadFormatting: @escaping (ClipboardItem) -> ClipboardItem
  ) {
    self.item = item
    self.isReadOnly = isReadOnly
    self.presentation = presentation
    self.loadFormatting = loadFormatting
    self.detectsSensitiveContent = detectsSensitiveContent
    self.revealsSensitiveContent = revealsSensitiveContent
    self.maximumContentSize = maximumContentSize
    self.toolbar = ItemPreviewToolbar(
      item: item,
      sensitiveContent: SensitiveContentPresentation(
        isMasked: SensitiveContent.isMasked(item, detectsAutomatically: detectsSensitiveContent),
        isRevealed: revealsSensitiveContent
      ),
      isReadOnly: isReadOnly
    )
    super.init(nibName: nil, bundle: nil)
    toolbar.delegate = self
  }

  func makeToolbar() -> NSToolbar {
    toolbar.makeToolbar()
  }

  func makeCloseAccessory() -> NSTitlebarAccessoryViewController {
    toolbar.makeCloseAccessory()
  }

  // The sheet shares the background of the history window, so the toolbar,
  // the content and the details bar read as one plain surface.
  static func configureWindow(_ window: NSWindow) {
    window.backgroundColor = HistoryAppearance.backgroundColor
    // The toolbar and the content share one surface, so no line between them.
    // A transparent title bar also drops the hairline of the toolbar's hard
    // scroll pocket, which the separator style alone does not control.
    window.titlebarSeparatorStyle = .none
    window.titlebarAppearsTransparent = true
    // The sheet's corners follow the rounded toolbar controls, as they do on
    // macOS 26; presenting the sheet resets the frame, hence the second call.
    window.applyMacOS26CornerRadiusIfNeeded()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // The visible title lives in the toolbar accessory; the window title only
  // names the sheet for accessibility.
  var dialogTitle: String {
    "\(L10n.string("Type")): \(ItemPreviewDetailsView.typeName(for: item))"
  }

  private var sensitiveContent: SensitiveContentPresentation {
    SensitiveContentPresentation(
      isMasked: SensitiveContent.isMasked(item, detectsAutomatically: detectsSensitiveContent),
      isRevealed: revealsSensitiveContent
    )
  }

  override func loadView() {
    // Nothing is built for a preview the pane hides.
    let content = presentation == .sheet || showsPreview ? makeContent(for: item) : nil
    let contentSize = content.map(dialogContentSize(for:)) ?? Self.minimumContentSize
    let rootView = ItemPreviewKeyHandlingView(
      frame: NSRect(origin: .zero, size: contentSize)
    )
    // The pane leaves the keys to the history list and its search field.
    rootView.acceptsFocus = presentation == .sheet
    rootView.onCancel = { [weak self] in
      guard let self, !self.isEditing else {
        return
      }
      self.onCancel?()
    }
    rootView.onEscape = { [weak self] in
      self?.handleEscape()
    }
    rootView.onKeyDown = { [weak self] event in
      guard let self, !self.isEditing else {
        return false
      }
      return self.onKeyDown?(event) ?? false
    }
    rootView.onSaveKeyEquivalent = { [weak self] in
      guard let self, self.isEditing else {
        return false
      }
      // ⌘S with nothing changed simply leaves the edit mode.
      if self.hasUnsavedChanges {
        self.saveEditing()
      } else {
        self.cancelEditing()
      }
      return true
    }

    view = rootView

    detailsView.isHidden = !showsDetails
    rootView.addSubview(detailsView)
    switch presentation {
    case .sheet:
      // The details float over the preview as a centered capsule: as wide as
      // their fields when the dialog allows it, and as wide as the dialog
      // minus the margin otherwise, with the fields wrapping inside.
      NSLayoutConstraint.activate([
        detailsView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
        detailsView.leadingAnchor.constraint(
          greaterThanOrEqualTo: rootView.leadingAnchor,
          constant: ItemPreviewDetailsView.horizontalFloatingMargin
        ),
        detailsView.bottomAnchor.constraint(
          equalTo: rootView.bottomAnchor,
          constant: -ItemPreviewDetailsView.floatingMargin
        )
      ])
    case .pane:
      // The details are a bar across the bottom of the pane, and the preview
      // ends where the bar begins.
      NSLayoutConstraint.activate([
        detailsView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        detailsView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        detailsView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
      ])
      // Kept in front of whichever preview is installed under it, like the
      // details themselves.
      detailsFadeView.translatesAutoresizingMaskIntoConstraints = false
      detailsFadeView.wantsLayer = true
      detailsFadeView.layer?.zPosition = 1
      rootView.addSubview(detailsFadeView)
      NSLayoutConstraint.activate([
        detailsFadeView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        detailsFadeView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        detailsFadeView.bottomAnchor.constraint(equalTo: detailsView.topAnchor),
        detailsFadeView.heightAnchor.constraint(equalToConstant: Self.detailsFadeHeight)
      ])
      detailsFadeView.isHidden = !showsDetailsFade
    }

    windowContentSize = contentSize
    detailsView.showsTopSeparator = showsPreview
    if let content {
      installContentView(for: content)
    }
  }

  // Replaces the previewed item in place, so the sheet can follow the history
  // selection without being dismissed and re-presented.
  func update(item: ClipboardItem, revealsSensitiveContent: Bool) {
    if isEditing {
      pendingItem = item
      pendingRevealsSensitiveContent = revealsSensitiveContent
      return
    }

    let previousItem = self.item
    let previousSensitiveContent = sensitiveContent
    self.item = item
    self.revealsSensitiveContent = revealsSensitiveContent
    toolbar.update(item: item, sensitiveContent: sensitiveContent)
    if presentation == .sheet {
      view.window?.title = dialogTitle
    }
    // The details are rebuilt unconditionally, because values such as the copy
    // count and the last copy date change without the preview content changing.
    detailsView.update(item: item)

    // Metadata changes such as toggling the favorite state must not rebuild the
    // content view, otherwise the preview scrolls back to the top.
    guard !Self.hasEqualPreviewContent(previousItem, item)
            || previousSensitiveContent.hidesContent != sensitiveContent.hidesContent else {
      return
    }

    guard presentation == .sheet else {
      installPaneContentView(for: showsPreview ? makeContent(for: item) : nil)
      return
    }

    let content = makeContent(for: item)

    let contentSize = dialogContentSize(for: content)
    windowContentSize = contentSize

    if !hasUserResizedWindow {
      view.window?.setContentSize(contentSize)
    }
    installContentView(for: content)
    view.window?.makeFirstResponder(view)
  }

  // The pane never takes the focus. When it had it, in its text for instance,
  // the focus is handed back once that text is gone. Without content, while
  // the pane hides the preview, only the details are left.
  private func installPaneContentView(for content: PreviewContent?) {
    let hadFocus = (view.window?.firstResponder as? NSView)?.isDescendant(of: view) == true
    if let content {
      installContentView(for: content)
    } else {
      tearDownContentView()
      contentView = nil
    }
    if hadFocus {
      onContentFocusLost?()
    }
  }

  // Rebuilds the preview of the same item, after a change in how it is shown.
  private func reinstallContentView() {
    guard isViewLoaded, !isEditing else {
      return
    }
    if presentation == .pane {
      installPaneContentView(for: showsPreview ? makeContent(for: item) : nil)
    } else {
      installContentView(for: makeContent(for: item))
    }
  }

  // A resize changes how much of the name fits next to the toolbar items, and
  // how many lines the details panel wraps onto.
  override func viewDidLayout() {
    super.viewDidLayout()
    if presentation == .sheet {
      toolbar.refreshAccessoryLayout()
    }
    updateDetailsInset()
    refreshTextViewport()
  }

  // A text view installed into a dialog that is already laid out prepares its
  // text only for the part the details panel does not cover, and leaves the
  // rest blank until the user scrolls. Laying the viewport out again once the
  // dialog settles draws the text all the way down under the panel.
  private func refreshTextViewport() {
    guard let textView = (contentView as? NSScrollView)?.documentView as? NSTextView else {
      return
    }
    textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
  }

  override func cancelOperation(_ sender: Any?) {
    handleEscape()
  }

  // Escape closes the preview, cancels an edit that changed nothing, and asks
  // what to do with an edit that did.
  private func handleEscape() {
    guard isEditing else {
      onCancel?()
      return
    }
    guard hasUnsavedChanges else {
      cancelEditing()
      return
    }
    confirmDiscardingChanges()
  }

  // Keeps the details bar and the Restore button in step with the editor.
  private func editingTextChanged() {
    guard let editingTextView else {
      return
    }
    detailsView.showLength(of: editingTextView.string)
    toolbar.setRestoreEnabled(hasUnsavedChanges)
  }

  private var hasUnsavedChanges: Bool {
    guard let editingTextView else {
      return false
    }
    return editingTextView.string != originalEditingText
  }

  private func confirmDiscardingChanges() {
    guard let window = view.window else {
      return
    }

    let alert = NSAlert()
    alert.messageText = L10n.string("Save changes?")
    alert.informativeText = L10n.string(
      "The text has unsaved changes. You can save them or discard them."
    )
    let saveButton = alert.addButton(withTitle: L10n.string("Save"))
    let discardButton = alert.addButton(withTitle: L10n.string("Don't Save"))
    let cancelButton = alert.addButton(withTitle: L10n.string("Cancel"))
    saveButton.keyEquivalent = "\r"
    discardButton.hasDestructiveAction = true
    cancelButton.keyEquivalent = "\u{1b}"
    // Save stays the default action, while the keyboard focus starts on Cancel
    // so an accidental Space keeps the edit.
    alert.window.initialFirstResponder = cancelButton
    // The preview is a sheet of the history panel and hidden from screen
    // capture along with it; the alert on top has to be hidden too.
    if let historyWindow = window.sheetParent as? HistoryContentWindow {
      alert.window.setSharingTypeIncludingAttachedWindows(historyWindow.screenCaptureSharingType)
    }

    alert.beginSheetModal(for: window) { [weak self] response in
      guard let self else {
        return
      }
      switch response {
      case .alertFirstButtonReturn:
        self.saveEditing()
      case .alertSecondButtonReturn:
        self.cancelEditing()
      default:
        self.view.window?.makeFirstResponder(self.editingTextView)
      }
    }
  }

  // MARK: - Editing

  var isEditing: Bool {
    toolbar.isEditing
  }

  // Replaces the preview with an editable text view and switches the toolbar
  // to Cancel/Save. Only kinds whose content is text can be edited.
  // `closesWhenFinished` is used when the sheet is presented for editing: the
  // preview was never asked for, so it goes away together with the editor.
  func beginEditing(closesWhenFinished: Bool = false) {
    guard !isEditing, !isReadOnly, item.kind.canEditTextContent else {
      return
    }

    closesWhenEditingEnds = closesWhenFinished
    toolbar.setEditing(true)
    installEditor(text: item.text ?? item.previewText)
  }

  func cancelEditing() {
    guard isEditing else {
      return
    }
    endEditing()
  }

  // Puts the original text back without leaving the edit mode.
  func restoreEditingText() {
    guard isEditing, let editingTextView, hasUnsavedChanges else {
      return
    }

    editingTextView.string = originalEditingText
    editingTextView.setSelectedRange(NSRange(location: originalEditingText.count, length: 0))
    editingTextView.undoManager?.removeAllActions()
    editingTextChanged()
    view.window?.makeFirstResponder(editingTextView)
  }

  func saveEditing() {
    guard isEditing, let editingTextView else {
      return
    }

    // Saved before the editor is torn down, so the resulting model update is
    // parked as the pending item and applied by endEditing().
    onSave?(item, editingTextView.string)
    endEditing()
  }

  // Restores the regular preview of the current item and applies any model
  // update that was held back while editing, or dismisses the sheet when it
  // was presented for editing in the first place.
  private func endEditing() {
    toolbar.setEditing(false)
    editingTextView = nil
    // The details were following the editor, so they go back to the item.
    detailsView.update(item: item)

    guard !closesWhenEditingEnds else {
      closesWhenEditingEnds = false
      onCancel?()
      return
    }

    installContentView(for: makeContent(for: item))
    view.window?.makeFirstResponder(view)

    if let pendingItem {
      self.pendingItem = nil
      update(item: pendingItem, revealsSensitiveContent: pendingRevealsSensitiveContent)
    }
  }

  private func installEditor(text: String) {
    tearDownContentView()

    let scrollView = makeTextScrollView(frame: contentFrame)
    let textView = scrollView.documentView as? NSTextView
    textView?.isEditable = true
    textView?.isRichText = false
    textView?.importsGraphics = false
    textView?.allowsUndo = true
    textView?.isAutomaticQuoteSubstitutionEnabled = false
    textView?.isAutomaticDashSubstitutionEnabled = false
    textView?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    textView?.textColor = .labelColor
    textView?.string = text
    // Compared against later edits as the text view stores it, so any
    // normalization done on assignment does not count as a change.
    originalEditingText = textView?.string ?? text
    textView?.delegate = self
    editingTextView = textView
    editingTextChanged()

    addContentView(scrollView)
    view.window?.makeFirstResponder(textView)
  }

  // The preview fills the dialog; the details panel floats over its bottom.
  private var contentFrame: NSRect {
    NSRect(
      x: Self.contentInset,
      y: Self.contentInset,
      width: max(0, view.bounds.width - Self.contentInset * 2),
      height: max(0, view.bounds.height - Self.contentInset * 2)
    )
  }

  private func installContentView(for content: PreviewContent) {
    tearDownContentView()
    addContentView(makeContentView(for: content, frame: contentFrame))
  }

  /// Stops what the preview has going, such as a page loading, before the
  /// pane lets go of it.
  func tearDownContent() {
    tearDownContentView()
  }

  private func tearDownContentView() {
    if let quickLookView = contentView as? QLPreviewView {
      quickLookView.close()
    }
    tearDownWebPageContentView()
    contentView?.removeFromSuperview()
  }

  private func addContentView(_ newContentView: NSView) {
    newContentView.translatesAutoresizingMaskIntoConstraints = false
    // Kept under the floating details panel, which blurs whatever the preview
    // shows beneath it.
    view.addSubview(newContentView, positioned: .below, relativeTo: detailsView)

    let constraints = [
      newContentView.leadingAnchor.constraint(
        equalTo: view.leadingAnchor,
        constant: Self.contentInset
      ),
      newContentView.trailingAnchor.constraint(
        equalTo: view.trailingAnchor,
        constant: -Self.contentInset
      ),
      newContentView.topAnchor.constraint(equalTo: view.topAnchor, constant: Self.contentInset),
      // In the pane the preview stops at the details bar rather than going
      // on underneath it.
      presentation == .pane && !detailsView.isHidden
        ? newContentView.bottomAnchor.constraint(equalTo: detailsView.topAnchor)
        : newContentView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -Self.contentInset
          )
    ]
    NSLayoutConstraint.activate(constraints)
    contentView = newContentView
    updateDetailsInset()
    // The new view is laid out on the next pass, so its viewport is refreshed
    // once that pass is over.
    DispatchQueue.main.async { [weak self] in
      self?.refreshTextViewport()
    }
  }

  // MARK: - Content

  private func makeContent(for item: ClipboardItem) -> PreviewContent {
    // Rich text is shown with its formatting, which history items come without.
    let item = item.kind == .richText ? loadFormatting(item) : item
    guard sensitiveContent.hidesContent else {
      return Self.makeContent(for: item, showsSVGMarkup: showsSVGMarkup, showsWebPages: showsWebPages)
    }

    // The page of a link would show what its address hides, so a link with hidden
    // content is previewed as text, like the other kinds.
    if item.kind == .richText,
       let rtfData = item.rtfData,
       let attributedText = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
      return .text(Self.withStyledMask(SensitiveContent.maskedAttributedText(
        attributedText,
        for: item,
        detectsAutomatically: detectsSensitiveContent
      )))
    }

    return .text(Self.withStyledMask(Self.plainTextContent(SensitiveContent.maskedText(
      item.previewText,
      for: item,
      detectsAutomatically: detectsSensitiveContent,
      characterLimit: SensitiveContent.previewCharacterLimit
    ))))
  }

  // The dots that stand for hidden content are drawn smaller and spread apart, so they do
  // not read as text.
  private static func withStyledMask(_ attributedText: NSAttributedString) -> NSAttributedString {
    let styledText = NSMutableAttributedString(attributedString: attributedText)
    for range in SensitiveContent.maskRanges(in: attributedText.string) {
      let font = attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        ?? .systemFont(ofSize: NSFont.systemFontSize)
      styledText.addAttributes(SensitiveContent.maskAttributes(for: font), range: range)
      styledText.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
      SensitiveContent.addSpacing(beforeMaskAt: range, in: styledText)
    }
    return styledText
  }

  private static func makeContent(
    for item: ClipboardItem,
    showsSVGMarkup: Bool,
    showsWebPages: Bool
  ) -> PreviewContent {
    // Text that is an SVG document is previewed as the picture it draws, unless
    // the user switched the preview to its markup.
    if !showsSVGMarkup, let rendering = SVGImageRenderer.shared.rendering(for: item) {
      return .svg(rendering)
    }

    switch item.kind {
    case .image:
      if let imageURL = item.assetURL, let image = NSImage(contentsOf: imageURL) {
        return .image(image)
      }
      return .text(plainTextContent(item.previewText))
    case .file:
      return fileContent(for: item)
    case .color:
      if let color = NSColor(colorItemText: item.previewText) {
        return .color(color, item.previewText.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      return .text(plainTextContent(item.previewText))
    case .link:
      if showsWebPages, let browserURL = item.browserURL, Self.isWebPageURL(browserURL) {
        return .webPage(browserURL)
      }
      return .text(plainTextContent(item.previewText))
    case .richText:
      if let rtfData = item.rtfData,
         let attributedText = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
        return .text(attributedText)
      }
      return .text(plainTextContent(item.previewText))
    case .text, .email:
      return .text(plainTextContent(item.previewText))
    }
  }

  // Only pages the web view can actually load are previewed as one; anything
  // else, such as a mailto: or a custom scheme, falls back to its text.
  private static func isWebPageURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else {
      return false
    }

    return scheme == "http" || scheme == "https"
  }

  private static func fileContent(for item: ClipboardItem) -> PreviewContent {
    guard item.filePaths.count == 1, let filePath = item.filePaths.first else {
      return .fileList(item.filePaths)
    }

    guard FileManager.default.fileExists(atPath: filePath) else {
      return .fileList(item.filePaths)
    }

    if ClipboardItem.isImageFile(at: filePath), let image = NSImage(contentsOfFile: filePath) {
      return .image(image)
    }

    return .fileQuickLook(URL(fileURLWithPath: filePath))
  }

  private static func hasEqualPreviewContent(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
    lhs.id == rhs.id
      && lhs.kind == rhs.kind
      && lhs.text == rhs.text
      && lhs.hasFormatting == rhs.hasFormatting
      && lhs.htmlDigest == rhs.htmlDigest
      && lhs.assetPath == rhs.assetPath
      && lhs.filePaths == rhs.filePaths
    // The link preview details are deliberately left out: the preview shows the
    // page itself, so metadata arriving later must not rebuild the content view
    // and reload the page underneath the user.
  }

  private static func plainTextContent(_ text: String) -> NSAttributedString {
    NSAttributedString(
      string: text,
      attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor.labelColor
      ]
    )
  }

  // MARK: - Sizing

  // The dialog is as tall as the preview plus the room the floating details
  // panel takes, which depends on how many lines the fields wrap onto at the
  // resulting width.
  private func dialogContentSize(for content: PreviewContent) -> NSSize {
    let previewSize = previewContentSize(for: content)
    // The details panel is kept on a single line whenever the screen allows
    // it, so the dialog is widened rather than letting the fields wrap.
    var width = min(
      maximumContentSize.width,
      max(
        previewSize.width,
        detailsView.preferredWidth + ItemPreviewDetailsView.horizontalFloatingMargin * 2
      )
    )
    if item.kind == .file, item.firstFileIsImage, !item.isMultipleFileItem {
      width = min(maximumContentSize.width, max(width, Self.imageFileMinimumDialogWidth))
    }
    let detailsHeight = detailsView.reservedHeight(forWidth: width)

    return NSSize(
      width: width,
      height: min(
        maximumContentSize.height,
        max(Self.minimumContentSize.height, previewSize.height + detailsHeight)
      )
    )
  }

  // The height the details panel takes away from the preview. It is measured
  // at the widest the dialog can get, because the preview width is not known
  // yet.
  private var reservedDetailsHeight: CGFloat {
    detailsView.reservedHeight(forWidth: maximumContentSize.width)
  }

  // Scrollable previews get extra room at the bottom, so their last rows can
  // be scrolled out from under the floating details panel. Scrolled all the
  // way down, the content ends right at the top edge of the panel. The panel
  // wraps onto more lines as the dialog narrows, so this follows every layout.
  private func updateDetailsInset() {
    guard let scrollView = contentView as? NSScrollView else {
      return
    }

    // Before the first layout the panel has no frame yet, so its top edge is
    // estimated from the height it needs at the width of the dialog. A hidden
    // panel covers nothing, and neither does the bar of the pane, which the
    // preview ends above.
    let panelTop = detailsView.isHidden || presentation == .pane
      ? Self.contentInset
      : detailsView.frame.height > 0
      ? detailsView.frame.maxY
      : detailsView.reservedHeight(forWidth: view.bounds.width) - ItemPreviewDetailsView.floatingMargin
    let spacing = scrollView.documentView is NSTextView ? Self.textBottomSpacing : 0
    // Scrolled all the way down, the last line ends above the fade.
    let fadeHeight = showsDetailsFade ? Self.detailsFadeHeight : 0
    let bottomInset = max(0, panelTop - Self.contentInset + spacing + fadeHeight)
    guard scrollView.automaticallyAdjustsContentInsets
            || abs(scrollView.contentInsets.bottom - bottomInset) > 0.5 else {
      return
    }

    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    // The scroller keeps running the full height of the preview.
    scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: -bottomInset, right: 0)
  }

  private var availablePreviewSize: NSSize {
    NSSize(
      width: maximumContentSize.width,
      height: max(
        Self.minimumContentSize.height / 2,
        maximumContentSize.height - reservedDetailsHeight
      )
    )
  }

  private func previewContentSize(for content: PreviewContent) -> NSSize {
    switch content {
    case .image(let image):
      return imageDialogContentSize(for: image.size)
    case .fileQuickLook:
      return clampedContentSize(
        NSSize(
          width: Self.fileDialogSize.width,
          height: Self.fileDialogSize.height - reservedDetailsHeight
        )
      )
    case .fileList(let filePaths):
      return clampedContentSize(
        NSSize(width: 560, height: CGFloat(filePaths.count) * 52 + 48)
      )
    case .color:
      return clampedContentSize(Self.colorContentSize)
    case .svg:
      return clampedContentSize(
        NSSize(
          width: Self.svgDialogSize.width,
          height: Self.svgDialogSize.height - reservedDetailsHeight
        )
      )
    case .webPage:
      return clampedContentSize(
        NSSize(
          width: Self.webPageDialogSize.width,
          height: Self.webPageDialogSize.height - reservedDetailsHeight
        )
      )
    case .text:
      let dialogHeight = item.kind == .email ? Self.emailDialogHeight : Self.compactDialogHeight
      return clampedContentSize(
        NSSize(
          width: Self.defaultContentSize.width,
          height: dialogHeight - reservedDetailsHeight
        )
      )
    }
  }

  private func clampedContentSize(_ size: NSSize) -> NSSize {
    let availableSize = availablePreviewSize
    return NSSize(
      width: min(availableSize.width, max(Self.minimumContentSize.width, size.width)),
      height: min(availableSize.height, size.height)
    )
  }

  // The room an image can take in the preview without being scaled down.
  private var availableImageSize: NSSize {
    let previewSize = availablePreviewSize
    return NSSize(
      width: max(1, previewSize.width - Self.contentInset * 2),
      height: max(1, previewSize.height - Self.contentInset * 2)
    )
  }

  // The pane decides its own size, so an image there is always centred in the
  // room it gets and only ever scaled down to fit.
  private func imageFitsAtNaturalSize(_ imageSize: NSSize) -> Bool {
    guard presentation == .sheet else {
      return true
    }

    let availableSize = availableImageSize
    return imageSize.width <= availableSize.width && imageSize.height <= availableSize.height
  }

  private func imageDialogContentSize(for imageSize: NSSize) -> NSSize {
    let previewSize = availablePreviewSize
    let availableSize = availableImageSize
    let imageScale = min(
      1,
      availableSize.width / max(imageSize.width, 1),
      availableSize.height / max(imageSize.height, 1)
    )

    return NSSize(
      width: min(
        previewSize.width,
        max(Self.minimumContentSize.width, imageSize.width * imageScale + Self.contentInset * 2)
      ),
      height: min(
        previewSize.height,
        imageSize.height * imageScale + Self.contentInset * 2
      )
    )
  }

  // MARK: - Content views

  private func makeContentView(for content: PreviewContent, frame: NSRect) -> NSView {
    switch content {
    case .image(let image):
      return makeImageContentView(image: image, frame: frame)
    case .fileQuickLook(let fileURL):
      return makeQuickLookContentView(fileURL: fileURL, frame: frame)
    case .fileList(let filePaths):
      return makeFileListContentView(filePaths: filePaths, frame: frame)
    case .color(let color, let colorText):
      return makeColorContentView(color: color, colorText: colorText, frame: frame)
    case .svg(let rendering):
      return makeSVGContentView(rendering: rendering, frame: frame)
    case .webPage(let url):
      return makeWebPageContentView(url: url, frame: frame)
    case .text(let attributedText):
      return makeTextContentView(attributedText: attributedText, frame: frame)
    }
  }

  private func makeImageContentView(image: NSImage, frame: NSRect) -> NSView {
    // An image that fits is shown at its own size rather than blown up to the
    // dialog, which the details panel often makes much wider than the image.
    // It is centred in the room above the panel, and only ever scaled down, in
    // case that room shrinks.
    if imageFitsAtNaturalSize(image.size) {
      let imageView = NSImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.imageAlignment = .alignCenter
      imageView.imageScaling = .scaleProportionallyDown
      imageView.image = image
      imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
      imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      let containerView = AboveDetailsPreviewContentView(frame: frame, detailsView: detailsView)
      containerView.addSubview(imageView)
      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: containerView.previewArea.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: containerView.previewArea.bottomAnchor),
        imageView.leadingAnchor.constraint(equalTo: containerView.previewArea.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: containerView.previewArea.trailingAnchor)
      ])
      return containerView
    }

    let imageView = NSImageView(frame: frame)
    imageView.imageAlignment = .alignCenter
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.image = image
    // No corner rounding here: the image is shown as it is, and a scaled image
    // rarely fills the view all the way into its corners anyway.
    // The image view must never push the dialog around: the sheet size is
    // decided up front, and the image is scaled to whatever room is left.
    imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    return imageView
  }

  private func makeQuickLookContentView(fileURL: URL, frame: NSRect) -> NSView {
    guard let previewView = QLPreviewView(frame: frame, style: .normal) else {
      return makeFileListContentView(filePaths: [fileURL.path], frame: frame)
    }

    previewView.shouldCloseWithWindow = true
    previewView.previewItem = fileURL as NSURL
    return previewView
  }

  private func makeFileListContentView(filePaths: [String], frame: NSRect) -> NSView {
    let rowsStack = NSStackView()
    rowsStack.orientation = .vertical
    rowsStack.distribution = .fill
    rowsStack.alignment = .leading
    rowsStack.spacing = 6
    rowsStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    rowsStack.translatesAutoresizingMaskIntoConstraints = false

    for filePath in filePaths {
      rowsStack.addArrangedSubview(makeFileListRow(filePath: filePath))
    }

    let documentView = ItemPreviewFlippedView()
    documentView.translatesAutoresizingMaskIntoConstraints = false
    documentView.addSubview(rowsStack)

    let scrollView = OverlayScrollView(frame: frame)
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = true
    scrollView.backgroundColor = .textBackgroundColor
    scrollView.borderType = .noBorder
    scrollView.documentView = documentView

    NSLayoutConstraint.activate([
      rowsStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
      rowsStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
      rowsStack.topAnchor.constraint(equalTo: documentView.topAnchor),
      rowsStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
      documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
      documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
      documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
    ])

    return scrollView
  }

  private func makeFileListRow(filePath: String) -> NSView {
    let fileURL = URL(fileURLWithPath: filePath)
    let fileExists = FileManager.default.fileExists(atPath: filePath)

    let iconView = NSImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.image = fileExists
      ? NSWorkspace.shared.icon(forFile: filePath)
      : NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)
    iconView.imageScaling = .scaleProportionallyUpOrDown

    let nameField = NSTextField(labelWithString: fileURL.lastPathComponent)
    nameField.font = .systemFont(ofSize: 13, weight: .medium)
    nameField.textColor = .labelColor
    nameField.lineBreakMode = .byTruncatingMiddle

    let pathField = NSTextField(labelWithString: fileURL.deletingLastPathComponent().path)
    pathField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    pathField.textColor = .secondaryLabelColor
    pathField.lineBreakMode = .byTruncatingMiddle

    let labelsStack = NSStackView(views: [nameField, pathField])
    labelsStack.orientation = .vertical
    labelsStack.distribution = .fill
    labelsStack.alignment = .leading
    labelsStack.spacing = 1

    let rowStack = NSStackView(views: [iconView, labelsStack])
    rowStack.orientation = .horizontal
    rowStack.distribution = .fill
    rowStack.alignment = .centerY
    rowStack.spacing = 8
    rowStack.toolTip = filePath

    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 32),
      iconView.heightAnchor.constraint(equalToConstant: 32)
    ])

    return rowStack
  }

  private func makeColorContentView(color: NSColor, colorText: String, frame: NSRect) -> NSView {
    // A circle rather than a rectangle, so the swatch reads as a colour sample
    // instead of a filled area of the dialog.
    let swatchView = ColorSwatchView(color: color)
    swatchView.translatesAutoresizingMaskIntoConstraints = false

    let colorField = NSTextField(labelWithString: colorText)
    colorField.translatesAutoresizingMaskIntoConstraints = false
    colorField.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
    colorField.textColor = .labelColor
    colorField.lineBreakMode = .byTruncatingMiddle
    colorField.alignment = .center
    // The swatch gives way when room is short, never the name of the colour.
    colorField.setContentCompressionResistancePriority(.required, for: .vertical)

    let contentStack = NSStackView(views: [swatchView, colorField])
    contentStack.orientation = .vertical
    contentStack.alignment = .centerX
    contentStack.spacing = 16
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    // As large as the full size allows, and smaller in a preview too short for
    // it, such as the pane of the history window.
    let preferredDiameter = swatchView.widthAnchor.constraint(equalToConstant: Self.colorSwatchDiameter)
    preferredDiameter.priority = .defaultHigh
    NSLayoutConstraint.activate([
      preferredDiameter,
      swatchView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.colorSwatchDiameter),
      swatchView.heightAnchor.constraint(equalTo: swatchView.widthAnchor)
    ])

    // Centred in the room above the details panel rather than in the whole preview.
    let containerView = AboveDetailsPreviewContentView(frame: frame, detailsView: detailsView)
    containerView.addSubview(contentStack)
    NSLayoutConstraint.activate([
      contentStack.centerXAnchor.constraint(equalTo: containerView.previewArea.centerXAnchor),
      contentStack.centerYAnchor.constraint(equalTo: containerView.previewArea.centerYAnchor),
      contentStack.leadingAnchor.constraint(
        greaterThanOrEqualTo: containerView.leadingAnchor,
        constant: Self.colorContentHorizontalMargin
      ),
      contentStack.trailingAnchor.constraint(
        lessThanOrEqualTo: containerView.trailingAnchor,
        constant: -Self.colorContentHorizontalMargin
      ),
      contentStack.topAnchor.constraint(
        greaterThanOrEqualTo: containerView.previewArea.topAnchor,
        constant: Self.colorContentVerticalMargin
      ),
      contentStack.bottomAnchor.constraint(
        lessThanOrEqualTo: containerView.previewArea.bottomAnchor,
        constant: -Self.colorContentVerticalMargin
      )
    ])
    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    return containerView
  }

  private func makeSVGContentView(rendering: SVGImageRenderer.Rendering, frame: NSRect) -> NSView {
    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.imageAlignment = .alignCenter
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.image = rendering.image
    imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

    // Centred in the room above the details panel, on a background the picture
    // stays visible on.
    let containerView = ItemPreviewCanvasView(
      frame: frame,
      detailsView: detailsView,
      backgroundColor: rendering.backgroundColor(matching: .textBackgroundColor)
    )
    containerView.addSubview(imageView)
    let padding = Self.svgContentPadding
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: containerView.previewArea.topAnchor, constant: padding),
      imageView.bottomAnchor.constraint(equalTo: containerView.previewArea.bottomAnchor, constant: -padding),
      imageView.leadingAnchor.constraint(equalTo: containerView.previewArea.leadingAnchor, constant: padding),
      imageView.trailingAnchor.constraint(equalTo: containerView.previewArea.trailingAnchor, constant: -padding)
    ])
    return containerView
  }

  private func makeWebPageContentView(url: URL, frame: NSRect) -> NSView {
    let containerView = NSView(frame: frame)
    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

    let configuration = WKWebViewConfiguration()
    // A preview is not a browser: it never starts playing media on its own.
    configuration.mediaTypesRequiringUserActionForPlayback = .all

    let webView = WKWebView(frame: containerView.bounds, configuration: configuration)
    webView.autoresizingMask = [.width, .height]
    webView.allowsBackForwardNavigationGestures = false
    webView.navigationDelegate = self
    webView.uiDelegate = self
    containerView.addSubview(webView)
    self.webView = webView

    // A page takes a moment to arrive, and an empty preview reads as broken.
    let loadingIndicator = NSProgressIndicator()
    loadingIndicator.style = .spinning
    loadingIndicator.isIndeterminate = true
    loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(loadingIndicator)
    loadingIndicator.startAnimation(nil)
    webLoadingIndicator = loadingIndicator

    let messageField = NSTextField(labelWithString: "")
    messageField.font = .systemFont(ofSize: 13)
    messageField.textColor = .secondaryLabelColor
    messageField.alignment = .center
    messageField.lineBreakMode = .byWordWrapping
    messageField.maximumNumberOfLines = 3
    messageField.isHidden = true
    messageField.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(messageField)
    webMessageField = messageField

    NSLayoutConstraint.activate([
      loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      messageField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      messageField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      messageField.widthAnchor.constraint(
        lessThanOrEqualTo: containerView.widthAnchor,
        multiplier: 0.8
      )
    ])

    guard presentation == .pane else {
      webView.load(URLRequest(url: url))
      return containerView
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.paneWebPageLoadDelay) { [weak webView] in
      // The preview has moved on when the web view is gone or no longer shown.
      guard let webView, webView.navigationDelegate != nil else {
        return
      }
      webView.load(URLRequest(url: url))
    }
    return containerView
  }

  // Called when a load ends, successfully or not. A failed load leaves the web
  // view blank, so the reason is spelled out instead.
  private func finishWebPageLoading(errorMessage: String?) {
    webLoadingIndicator?.stopAnimation(nil)
    webLoadingIndicator?.isHidden = true

    guard let errorMessage else {
      webMessageField?.isHidden = true
      return
    }

    webMessageField?.stringValue = errorMessage
    webMessageField?.isHidden = false
    webView?.isHidden = true
  }

  // The web view keeps loading after it leaves the view hierarchy, so it is
  // stopped when the preview moves on to another item or to the editor.
  private func tearDownWebPageContentView() {
    guard let webView else {
      return
    }

    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    self.webView = nil
    webLoadingIndicator = nil
    webMessageField = nil
  }

  private func makeTextContentView(attributedText: NSAttributedString, frame: NSRect) -> NSView {
    let scrollView = makeTextScrollView(frame: frame)
    (scrollView.documentView as? NSTextView)?.textStorage?.setAttributedString(attributedText)
    return scrollView
  }

  // Shared by the read-only text preview and the in-place editor, so both
  // look the same apart from being editable.
  private func makeTextScrollView(frame: NSRect) -> NSScrollView {
    // The text view AppKit sets up for scrolling is moved into a scroll view
    // that keeps its scroller hidden while the text is still.
    let textHost = NSTextView.scrollableTextView()
    let hostedTextView = textHost.documentView
    textHost.documentView = nil

    // The frame is set after the text view is in, the way AppKit sizes its own
    // scroll view, so the text view grows with it to the full width.
    let scrollView = OverlayScrollView(frame: textHost.frame)
    scrollView.documentView = hostedTextView
    scrollView.frame = frame
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = true
    scrollView.borderType = .noBorder

    if let textView = scrollView.documentView as? NSTextView {
      textView.isEditable = false
      textView.isSelectable = !isReadOnly
      textView.drawsBackground = true
      textView.backgroundColor = .textBackgroundColor
      textView.textContainerInset = Self.textContainerInset
    }

    return scrollView
  }
}

extension ItemPreviewDialogController: WKNavigationDelegate, WKUIDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    finishWebPageLoading(errorMessage: nil)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    handleWebPageFailure(error)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    handleWebPageFailure(error)
  }

  // A page that asks for a new window, such as a target="_blank" link, is handed
  // to the default browser rather than opened inside the preview.
  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if let url = navigationAction.request.url {
      NSWorkspace.shared.open(url)
    }
    return nil
  }

  // Replacing one load with another cancels the first one, which is not a
  // failure worth showing.
  private func handleWebPageFailure(_ error: Error) {
    let error = error as NSError
    guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else {
      return
    }

    finishWebPageLoading(errorMessage: error.localizedDescription)
  }
}

extension ItemPreviewDialogController: NSWindowDelegate {
  // Only a drag on the edge of the sheet ends a live resize, so this is the
  // point where the size stops following the previewed item.
  func windowDidEndLiveResize(_ notification: Notification) {
    hasUserResizedWindow = true
    windowContentSize = view.window?.contentRect(forFrameRect: view.window?.frame ?? .zero).size
      ?? windowContentSize
  }
}

extension ItemPreviewDialogController: NSTextViewDelegate {
  func textDidChange(_ notification: Notification) {
    editingTextChanged()
  }
}

extension ItemPreviewDialogController: ItemPreviewToolbarDelegate {
  func itemPreviewToolbarDidRequestClose(_ toolbar: ItemPreviewToolbar) {
    // Closing during an edit asks about the changes, exactly like Escape.
    handleEscape()
  }

  func itemPreviewToolbarDidRequestToggleFavorite(_ toolbar: ItemPreviewToolbar) {
    onToggleFavorite?(item)
    // Toolbar clicks move the focus away from the content, which would stop the
    // arrow keys from moving the history selection while the preview stays open.
    view.window?.makeFirstResponder(view)
  }

  func itemPreviewToolbarDidRequestToggleSensitiveContentVisibility(_ toolbar: ItemPreviewToolbar) {
    onToggleSensitiveContentVisibility?(item)
    view.window?.makeFirstResponder(view)
  }

  func itemPreviewToolbarDidRequestEdit(_ toolbar: ItemPreviewToolbar) {
    beginEditing()
  }

  // The dialog keeps its size, so switching back and forth does not make it jump.
  func itemPreviewToolbar(_ toolbar: ItemPreviewToolbar, didSelectSVGMarkup showsMarkup: Bool) {
    guard showsSVGMarkup != showsMarkup else {
      return
    }

    showsSVGMarkup = showsMarkup
    installContentView(for: makeContent(for: item))
    view.window?.makeFirstResponder(view)
  }

  func itemPreviewToolbarDidRequestSave(_ toolbar: ItemPreviewToolbar) {
    saveEditing()
  }

  func itemPreviewToolbarDidRequestRestore(_ toolbar: ItemPreviewToolbar) {
    restoreEditingText()
  }

  func itemPreviewToolbarDidRequestCopyTextFromImage(_ toolbar: ItemPreviewToolbar) {
    onCopyTextFromImage?(item)
    view.window?.makeFirstResponder(view)
  }

  func itemPreviewToolbarDidRequestCopyTextFromQRCode(_ toolbar: ItemPreviewToolbar) {
    onCopyTextFromQRCode?(item)
    view.window?.makeFirstResponder(view)
  }

  func itemPreviewToolbarDidRequestSaveAsFile(_ toolbar: ItemPreviewToolbar) {
    onSaveAsFile?(item)
  }

  func itemPreviewToolbarDidRequestOpenInApplication(_ toolbar: ItemPreviewToolbar) {
    onOpenInApplication?(item)
  }

  func itemPreviewToolbarDidRequestShowInFinder(_ toolbar: ItemPreviewToolbar) {
    onShowInFinder?(item)
  }

  func itemPreviewToolbarMoreActionsMenu(_ toolbar: ItemPreviewToolbar) -> NSMenu? {
    moreActionsMenuProvider?(item)
  }

  func itemPreviewToolbarTagsMenu(_ toolbar: ItemPreviewToolbar) -> NSMenu? {
    tagsMenuProvider?(item)
  }
}

// Covers only the room above the floating details panel through `previewArea`, so
// content can sit between the toolbar and the panel rather than in the middle of the
// whole preview.
private class AboveDetailsPreviewContentView: NSView {
  let previewArea = NSLayoutGuide()
  private weak var detailsView: NSView?
  private var previewAreaBottomConstraint: NSLayoutConstraint?

  init(frame: NSRect, detailsView: NSView) {
    self.detailsView = detailsView
    super.init(frame: frame)

    addLayoutGuide(previewArea)
    NSLayoutConstraint.activate([
      previewArea.topAnchor.constraint(equalTo: topAnchor),
      previewArea.leadingAnchor.constraint(equalTo: leadingAnchor),
      previewArea.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // The details panel is a sibling in the dialog, so the preview area can only reach its
  // top edge once this view is in the dialog too.
  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    previewAreaBottomConstraint?.isActive = false
    previewAreaBottomConstraint = nil

    guard superview != nil, let detailsView else {
      return
    }

    let constraint = detailsView.isHidden
      ? previewArea.bottomAnchor.constraint(equalTo: bottomAnchor)
      : previewArea.bottomAnchor.constraint(equalTo: detailsView.topAnchor)
    constraint.isActive = true
    previewAreaBottomConstraint = constraint
  }
}

// Fills the whole preview with a color that may differ by appearance, which a layer
// background would keep at the color of the appearance it was set in.
private final class ItemPreviewCanvasView: AboveDetailsPreviewContentView {
  private let canvasColor: NSColor

  init(frame: NSRect, detailsView: NSView, backgroundColor: NSColor) {
    canvasColor = backgroundColor
    super.init(frame: frame, detailsView: detailsView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_ dirtyRect: NSRect) {
    canvasColor.setFill()
    dirtyRect.fill()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

// A colour sample drawn as a circle of whatever size it is given, with a
// hairline that keeps a pale colour visible against the background.
private final class ColorSwatchView: NSView {
  private let color: NSColor

  init(color: NSColor) {
    self.color = color
    super.init(frame: .zero)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override func updateLayer() {
    layer?.backgroundColor = color.cgColor
    layer?.borderWidth = 1
    var borderColor = NSColor.separatorColor.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      borderColor = NSColor.separatorColor.cgColor
    }
    layer?.borderColor = borderColor
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = min(bounds.width, bounds.height) / 2
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

private final class ItemPreviewFlippedView: NSView {
  override var isFlipped: Bool {
    true
  }
}

private final class ItemPreviewKeyHandlingView: NSView {
  var onCancel: (() -> Void)?
  var onEscape: (() -> Void)?
  var onKeyDown: ((NSEvent) -> Bool)?
  var onSaveKeyEquivalent: (() -> Bool)?
  var acceptsFocus = true

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool {
    acceptsFocus
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  // The background is a layer fill rather than a draw(_:) fill, because fills
  // drawn into the dirty rect are composited over the sibling views on macOS 26.
  override func updateLayer() {
    layer?.backgroundColor = HistoryAppearance.backgroundCGColor(for: self)
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  // ⌘S saves the in-place edit, wherever the focus is inside the sheet.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if modifiers == [.command], event.charactersIgnoringModifiers?.lowercased() == "s",
       onSaveKeyEquivalent?() == true {
      return true
    }
    // A shortcut that carries a modifier is offered to the window as a key
    // equivalent and never reaches keyDown(with:), so it is handed to the same
    // handler from here. That is what lets the shortcuts of the history window,
    // such as copying the item, work while the sheet is open.
    if !modifiers.isEmpty, !selectedTextOwnsCopy(event), onKeyDown?(event) == true {
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  // Text selected inside the preview keeps ⌘C for itself, so copying a part of
  // the text still works; the whole item is copied when nothing is selected.
  private func selectedTextOwnsCopy(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers == [.command],
          event.charactersIgnoringModifiers?.lowercased() == "c",
          let textView = window?.firstResponder as? NSTextView else {
      return false
    }

    return textView.selectedRange().length > 0
  }

  override func keyDown(with event: NSEvent) {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if event.keyCode == 53 {
      onEscape?()
      return
    }
    if event.keyCode == 49, modifiers.isEmpty {
      onCancel?()
      return
    }

    if onKeyDown?(event) == true {
      return
    }

    super.keyDown(with: event)
  }
}
