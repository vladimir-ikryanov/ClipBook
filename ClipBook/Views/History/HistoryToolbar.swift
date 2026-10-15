import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum HistorySelectionDirection {
  case up
  case down
}

@MainActor
protocol HistoryToolbarDelegate: AnyObject {
  func historyToolbar(_ toolbar: HistoryToolbar, didChangeSearchQuery query: String)
  func historyToolbar(_ toolbar: HistoryToolbar, didRequestMoveSelection direction: HistorySelectionDirection)
  func historyToolbar(_ toolbar: HistoryToolbar, didSelectSortOption sortOption: HistorySortOption)
  func historyToolbar(_ toolbar: HistoryToolbar, didSetFilterContentType contentType: HistoryFilterContentType, isSelected: Bool)
  func historyToolbar(_ toolbar: HistoryToolbar, didSetFilterTagID tagID: Tag.ID, isSelected: Bool)
  func historyToolbar(
    _ toolbar: HistoryToolbar,
    didSetFilterSourceApplicationID sourceApplicationID: HistorySourceApplication.ID,
    isSelected: Bool
  )
  func historyToolbar(_ toolbar: HistoryToolbar, didRequestClearFilterGroup group: SearchTokenGroup)
  func historyToolbarDidRequestClearFilters(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestToggleSortOrder(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestPaste(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestCopy(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestCopyTextFromImage(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestCopyTextFromQRCode(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestOpenInBrowser(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestMergeSelection(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestTogglePin(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestToggleCopySequenceMode(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestTogglePreviewPane(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestToggleDetails(_ toolbar: HistoryToolbar)
  func historyToolbarDidRequestCommandDialog(_ toolbar: HistoryToolbar)
}

@MainActor
final class HistoryToolbar: NSObject, NSToolbarDelegate, SearchTokenFieldDelegate {
  private static let toolbarIdentifier = NSToolbar.Identifier("HistoryWindowToolbar")
  private static let searchIdentifier = NSToolbarItem.Identifier("HistoryToolbarSearch")
  private static let sortIdentifier = NSToolbarItem.Identifier("HistoryToolbarSort")
  private static let pasteIdentifier = NSToolbarItem.Identifier("HistoryToolbarPaste")
  private static let copyIdentifier = NSToolbarItem.Identifier("HistoryToolbarCopy")
  private static let openInBrowserIdentifier = NSToolbarItem.Identifier("HistoryToolbarOpenInBrowser")
  private static let copyTextFromImageIdentifier = NSToolbarItem.Identifier("HistoryToolbarCopyTextFromImage")
  private static let copyTextFromQRCodeIdentifier = NSToolbarItem.Identifier("HistoryToolbarCopyTextFromQRCode")
  private static let mergeIdentifier = NSToolbarItem.Identifier("HistoryToolbarMerge")
  private static let pinIdentifier = NSToolbarItem.Identifier("HistoryToolbarPin")
  private static let copySequenceIdentifier = NSToolbarItem.Identifier("HistoryToolbarCopySequence")
  private static let commandIdentifier = NSToolbarItem.Identifier("HistoryToolbarCommand")
  private static var copyTextFromImageLabel: String { L10n.string("Copy Text from Image") }
  private static let copyTextFromImageSymbolName = "text.viewfinder"
  private static var copyTextFromQRCodeLabel: String { L10n.string("Copy Text from QR Code") }
  private static let copyTextFromQRCodeSymbolName = "qrcode.viewfinder"
  private static let searchFontSize: CGFloat = 18
  private static let minimumCollapsedSearchFieldWidth: CGFloat = 160
  private static let searchTrailingGap: CGFloat = 12
  private static let searchItemHeight: CGFloat = 52
  private static let searchLogoSize: CGFloat = 20
  private static let searchLogoLeadingPadding: CGFloat = -7
  private static let legacySearchReservedTitlebarWidth: CGFloat = 64
  private static let searchLogoTextSpacing: CGFloat = 11
  private static let pasteTargetIconSize: CGFloat = 22
  private static let copySuccessDuration: TimeInterval = 1
  private static let copyIconFadeDuration: TimeInterval = 0.16
  private static let copyIconFadeFrameCount = 8
  private static var searchContentLeadingPadding: CGFloat {
    if #available(macOS 26.0, *) {
      return searchLogoLeadingPadding
    }

    return searchLogoLeadingPadding - legacySearchReservedTitlebarWidth
  }

  private enum ToolbarAction: Int, CaseIterable, Hashable {
    case paste
    case copy
    case openInBrowser
    case copyTextFromImage
    case copyTextFromQRCode
    case merge
  }

  weak var delegate: HistoryToolbarDelegate?

  private let searchLogoView = NSImageView()
  private let searchField = SearchTokenField()
  private let suggestionsPopup = SearchSuggestionsPopup()
  private lazy var searchContainer = makeSearchContainer()
  private lazy var searchCursorView = SearchTextCursorView(
    textFrameInWindow: { [weak self] in
      self?.searchTextFrameOutsideItem()
    },
    isInsideText: { [weak self] point in
      self?.searchField.textAreaFrameInWindow.contains(point) ?? false
    }
  )
  private lazy var searchItem = makeSearchItem()
  private lazy var sortItem = makeSortItem()
  private lazy var actionItems = makeActionItems()
  private lazy var pinItem = makePinItem()
  private lazy var copySequenceItem = makeCopySequenceItem()
  private lazy var commandItem = makeCommandItem()
  private weak var toolbar: NSToolbar?
  private var canPaste = false
  private var canCopy = false
  // The Trash puts items back with the button that pastes them elsewhere.
  private var isShowingTrash = false
  private var pasteItemCount: Int?
  private var copyItemCount: Int?
  private var showsCopy = true
  private var showsOpenInBrowser = false
  private var showsCopyTextFromImage = false
  private var showsCopyTextFromQRCode = false
  private var showsMerge = false
  private var sortOption: HistorySortOption = .lastCopyTime
  private var isSortReversed = false
  private var selectedFilterContentTypes: Set<HistoryFilterContentType> = []
  private var filterTags: [Tag] = []
  private var selectedFilterTagIDs: Set<Tag.ID> = []
  private var filterSourceApplications: [HistorySourceApplication] = []
  private var selectedFilterSourceApplicationIDs: Set<HistorySourceApplication.ID> = []
  private var isPinned = false
  private var isCopySequenceModeEnabled = false
  private var isPreviewPaneShown = false
  private var showsDetails = false
  private var togglePreviewShortcut = ""
  private var toggleDetailsShortcut = ""
  private var previewPanePosition: HistoryPreviewPanePosition = .bottom
  // The copy sequence mode the sort menu was built for: the menu leaves sorting
  // out in that mode.
  private var sortMenuIsForCopySequenceMode = false
  private var isShowingCopySuccess = false
  private var copySuccessResetWorkItem: DispatchWorkItem?
  private var copyIconAnimationWorkItems: [DispatchWorkItem] = []
  private var copyIconAnimationID = 0
  private var resolvedPlaceholderColor: NSColor?
  private var searchContainerWidthConstraint: NSLayoutConstraint?
  private var windowObservers: [NSObjectProtocol] = []
  private var searchClickMonitor: Any?
  private var isSearchContainerWidthUpdateScheduled = false
  /// Width of the empty search field: wide enough for the whole placeholder,
  /// whose length depends on the app language.
  private var collapsedSearchFieldWidth = HistoryToolbar.minimumCollapsedSearchFieldWidth

  deinit {
    copySuccessResetWorkItem?.cancel()
    copyIconAnimationWorkItems.forEach { $0.cancel() }

    windowObservers.forEach(NotificationCenter.default.removeObserver)
    if let searchClickMonitor {
      NSEvent.removeMonitor(searchClickMonitor)
    }
  }

  func makeToolbar() -> NSToolbar {
    let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    if #available(macOS 15.0, *) {
      toolbar.allowsDisplayModeCustomization = false
    }
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconOnly
    toolbar.sizeMode = .regular
    self.toolbar = toolbar
    return toolbar
  }

  func update(
    searchQuery: String,
    isPinned: Bool,
    isCopySequenceModeEnabled: Bool,
    canPaste: Bool,
    canCopy: Bool,
    pasteItemCount: Int? = nil,
    copyItemCount: Int? = nil,
    showsCopyTextFromImage: Bool,
    showsCopyTextFromQRCode: Bool,
    showsOpenInBrowser: Bool,
    showsMerge: Bool,
    sortOption: HistorySortOption,
    isSortReversed: Bool,
    isReadOnly: Bool = false,
    isShowingTrash: Bool = false
  ) {
    self.isPinned = isPinned
    updatePinItem(isPinned: isPinned)
    updateCopySequenceItem(isCopySequenceModeEnabled: isCopySequenceModeEnabled)
    updateSortItem(sortOption: sortOption, isSortReversed: isSortReversed)
    self.canPaste = canPaste
    self.canCopy = canCopy
    self.isShowingTrash = isShowingTrash
    self.pasteItemCount = pasteItemCount
    self.copyItemCount = copyItemCount
    updateActionsGroup(
      // A read-only history keeps Copy next to Paste, both disabled, so the
      // toolbar shows what a license brings back.
      showsCopy: canCopy || isReadOnly,
      showsCopyTextFromImage: showsCopyTextFromImage,
      showsCopyTextFromQRCode: showsCopyTextFromQRCode,
      showsOpenInBrowser: showsOpenInBrowser,
      showsMerge: showsMerge
    )
    updateActionButtons()

    let singleLineSearchQuery = Self.singleLineSearchQuery(from: searchQuery)
    if searchField.text != singleLineSearchQuery {
      searchField.text = singleLineSearchQuery
    }

    scheduleSearchContainerWidthUpdate()
  }

  func refreshLocalization() {
    updateSearchItemLocalization()
    updateSearchPlaceholder()
    updateSortItemLocalization()
    updateActionButtons()
    updatePinItem(isPinned: isPinned)
    updateCopySequenceItem(isCopySequenceModeEnabled: isCopySequenceModeEnabled)
    updateCommandItemLocalization()
  }

  func focusSearchFieldAndHandleKeyDown(with event: NSEvent) {
    searchField.handleKeyDown(with: event)
  }

  /// Puts the caret at the end of the query so the field is ready to be
  /// extended rather than replaced by the next keystroke.
  func focusSearchField() {
    searchField.focusText()
    searchField.moveCaretToEnd()
  }

  func clearSearchAndFocus() {
    suggestionsPopup.hide()
    searchField.text = ""
    delegate?.historyToolbar(self, didChangeSearchQuery: "")
    clearSearchTokens()
    searchField.focusText()
  }

  /// `true` while the search field holds free text or at least one filter chip.
  var hasSearchInput: Bool {
    !searchField.text.isEmpty || !searchField.tokens.isEmpty
  }

  var isShowingSearchSuggestions: Bool {
    suggestionsPopup.isVisible
  }

  func hideSearchSuggestions() {
    suggestionsPopup.hide()
  }

  /// Lets the suggestion list claim the keys the history window would otherwise
  /// consume before they reach the search field editor.
  func handleSearchSuggestionsKeyDown(_ event: NSEvent) -> Bool {
    guard suggestionsPopup.isVisible, searchField.isEditing else {
      return false
    }

    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers.isEmpty else {
      return false
    }

    switch event.keyCode {
    case 53:
      suggestionsPopup.hide()
      return true
    case 36, 76, 48:
      guard let suggestion = suggestionsPopup.selectedSuggestion else {
        return false
      }

      acceptSuggestion(suggestion)
      return true
    case 125:
      suggestionsPopup.moveSelection(by: 1)
      return true
    case 126:
      suggestionsPopup.moveSelection(by: -1)
      return true
    default:
      return false
    }
  }

  func updateFilterState(
    selectedContentTypes: Set<HistoryFilterContentType>,
    tags: [Tag],
    selectedTagIDs: Set<Tag.ID>,
    sourceApplications: [HistorySourceApplication],
    selectedSourceApplicationIDs: Set<HistorySourceApplication.ID>
  ) {
    guard selectedContentTypes != selectedFilterContentTypes
            || tags != filterTags
            || selectedTagIDs != selectedFilterTagIDs
            || sourceApplications != filterSourceApplications
            || selectedSourceApplicationIDs != selectedFilterSourceApplicationIDs else {
      return
    }

    selectedFilterContentTypes = selectedContentTypes
    filterTags = tags
    selectedFilterTagIDs = selectedTagIDs
    filterSourceApplications = sourceApplications
    selectedFilterSourceApplicationIDs = selectedSourceApplicationIDs

    updateSearchTokens()

    if let item = sortItem as? NSMenuToolbarItem {
      item.menu = makeSortMenu()
    }
  }

  func showCopySuccessIndicator() {
    copySuccessResetWorkItem?.cancel()
    isShowingCopySuccess = true
    animateCopyActionItem(to: currentCopyActionImage())

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else {
        return
      }

      self.isShowingCopySuccess = false
      self.copySuccessResetWorkItem = nil
      self.animateCopyActionItem(to: self.currentCopyActionImage())
    }
    copySuccessResetWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.copySuccessDuration, execute: workItem)
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [
      Self.searchIdentifier,
      .flexibleSpace,
      Self.pasteIdentifier,
      Self.copyIdentifier
    ]
      + Self.groupSeparatorIdentifiers
      + [Self.sortIdentifier]
      + Self.groupSeparatorIdentifiers
      + [
        Self.copySequenceIdentifier,
        Self.commandIdentifier,
        Self.pinIdentifier
      ]
  }

  // On macOS 26 neighbouring toolbar buttons share one glass background. The
  // More button sits in a group of its own between the item actions and the
  // window controls, and without a menu indicator nothing sets it apart, so
  // a space on each side splits the buttons into their groups.
  private static var groupSeparatorIdentifiers: [NSToolbarItem.Identifier] {
    if #available(macOS 26.0, *) {
      return [.space]
    }

    return []
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [
      Self.searchIdentifier,
      .flexibleSpace,
      .space,
      Self.pasteIdentifier,
      Self.copyIdentifier,
      Self.openInBrowserIdentifier,
      Self.copyTextFromImageIdentifier,
      Self.copyTextFromQRCodeIdentifier,
      Self.mergeIdentifier,
      Self.sortIdentifier,
      Self.copySequenceIdentifier,
      Self.commandIdentifier,
      Self.pinIdentifier
    ]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case Self.searchIdentifier:
      return searchItem
    case Self.sortIdentifier:
      return sortItem
    case Self.pasteIdentifier:
      return actionItems[.paste]
    case Self.copyIdentifier:
      return actionItems[.copy]
    case Self.openInBrowserIdentifier:
      return actionItems[.openInBrowser]
    case Self.copyTextFromImageIdentifier:
      return actionItems[.copyTextFromImage]
    case Self.copyTextFromQRCodeIdentifier:
      return actionItems[.copyTextFromQRCode]
    case Self.mergeIdentifier:
      return actionItems[.merge]
    case Self.commandIdentifier:
      return commandItem
    case Self.copySequenceIdentifier:
      return copySequenceItem
    case Self.pinIdentifier:
      return pinItem
    default:
      return nil
    }
  }

  // MARK: - SearchTokenFieldDelegate

  func searchTokenFieldDidChangeText(_ field: SearchTokenField) {
    // Unconfirmed input method text is not what the user is searching for yet,
    // so the search runs once the conversion is confirmed. Only the field grows
    // meanwhile, so the composed text stays visible.
    if field.isComposingText {
      suggestionsPopup.hide()
      updateSearchContainerWidth()
      return
    }

    let singleLineSearchQuery = Self.singleLineSearchQuery(from: field.text)
    if field.text != singleLineSearchQuery {
      field.text = singleLineSearchQuery
    }

    delegate?.historyToolbar(self, didChangeSearchQuery: field.text)
    updateSearchContainerWidth()
    updateSearchSuggestions()
  }

  func searchTokenField(_ field: SearchTokenField, didRemoveToken token: SearchToken) {
    setFilter(for: token.kind, isSelected: false)
    updateSearchContainerWidth()
    updateSearchSuggestions()
  }

  func searchTokenField(_ field: SearchTokenField, didRequestMoveSelection direction: HistorySelectionDirection) {
    guard !suggestionsPopup.isVisible else {
      suggestionsPopup.moveSelection(by: direction == .down ? 1 : -1)
      return
    }

    delegate?.historyToolbar(self, didRequestMoveSelection: direction)
  }

  func searchTokenField(_ field: SearchTokenField, didReceiveCommand command: SearchTokenFieldCommand) -> Bool {
    switch command {
    case .cancel:
      if suggestionsPopup.isVisible {
        suggestionsPopup.hide()
        return true
      }

      guard hasSearchInput else {
        return false
      }

      clearSearchAndFocus()
      return true
    case .commit, .complete:
      guard suggestionsPopup.isVisible, let suggestion = suggestionsPopup.selectedSuggestion else {
        return false
      }

      acceptSuggestion(suggestion)
      return true
    }
  }

  // MARK: - Search tokens and suggestions

  /// Rebuilds the chips from the filters currently applied to the history, so
  /// the field and the filter menus never disagree. Chips follow the order of
  /// the filter menus: types first, then apps, then tags, each in menu order.
  private func updateSearchTokens() {
    var tokens: [SearchToken] = []

    for contentType in HistoryFilterContentType.allCases where selectedFilterContentTypes.contains(contentType) {
      tokens.append(
        SearchToken(
          kind: .contentType(contentType),
          title: contentType.searchTokenTitle,
          image: SearchSuggestionIcon.contentTypeImage(for: contentType)
        )
      )
    }

    for application in filterSourceApplications where selectedFilterSourceApplicationIDs.contains(application.id) {
      tokens.append(
        SearchToken(
          kind: .sourceApplication(application.id),
          title: application.name,
          image: SearchSuggestionIcon.applicationImage(for: application)
        )
      )
    }

    for tag in filterTags where selectedFilterTagIDs.contains(tag.id) {
      tokens.append(
        SearchToken(
          kind: .tag(tag.id),
          title: tag.name,
          image: SearchSuggestionIcon.tagImage(for: tag)
        )
      )
    }

    searchField.setTokens(tokens)
    updateSearchContainerWidth()
    updateSearchSuggestions()
  }

  private func updateSearchSuggestions() {
    guard searchField.isEditing, let window = searchContainer.window else {
      suggestionsPopup.hide()
      return
    }

    let activeKinds = Set(searchField.tokens.map(\.kind))
    let suggestions = SearchSuggestionProvider.suggestions(
      for: searchField.text,
      tags: filterTags,
      sourceApplications: filterSourceApplications,
      activeKinds: activeKinds
    )

    guard !suggestions.isEmpty, let anchorFrame = searchField.textAreaFrameInScreen else {
      suggestionsPopup.hide()
      return
    }

    suggestionsPopup.update(
      suggestions: suggestions,
      anchoredTo: anchorFrame,
      in: window,
      appearance: searchContainer.appearance ?? searchContainer.effectiveAppearance
    )
  }

  private func acceptSuggestion(_ suggestion: SearchSuggestion) {
    suggestionsPopup.hide()

    // Show the chip right away, in the slot the model round trip will put it
    // in, so the chips do not reorder once the same token comes back.
    var tokens = searchField.tokens
    if !tokens.contains(where: { $0.kind == suggestion.token.kind }) {
      tokens.append(suggestion.token)
      tokens.sort { tokenOrder(for: $0) < tokenOrder(for: $1) }
    }
    searchField.setTokens(tokens)
    updateSearchContainerWidth()

    if !searchField.text.isEmpty {
      searchField.text = ""
      delegate?.historyToolbar(self, didChangeSearchQuery: "")
    }

    setFilter(for: suggestion.token.kind, isSelected: true)
    searchField.focusText()
  }

  /// Position of a chip: its group first, then its place in that group's menu.
  private func tokenOrder(for token: SearchToken) -> (Int, Int) {
    switch token.kind {
    case .contentType(let contentType):
      return (token.kind.group.rawValue, HistoryFilterContentType.allCases.firstIndex(of: contentType) ?? .max)
    case .sourceApplication(let sourceApplicationID):
      return (token.kind.group.rawValue, filterSourceApplications.firstIndex { $0.id == sourceApplicationID } ?? .max)
    case .tag(let tagID):
      return (token.kind.group.rawValue, filterTags.firstIndex { $0.id == tagID } ?? .max)
    }
  }

  private func setFilter(for kind: SearchTokenKind, isSelected: Bool) {
    switch kind {
    case .contentType(let contentType):
      delegate?.historyToolbar(self, didSetFilterContentType: contentType, isSelected: isSelected)
    case .tag(let tagID):
      delegate?.historyToolbar(self, didSetFilterTagID: tagID, isSelected: isSelected)
    case .sourceApplication(let sourceApplicationID):
      delegate?.historyToolbar(self, didSetFilterSourceApplicationID: sourceApplicationID, isSelected: isSelected)
    }
  }

  private func clearSearchTokens() {
    guard !searchField.tokens.isEmpty else {
      return
    }

    searchField.setTokens([])
    updateSearchContainerWidth()
    delegate?.historyToolbarDidRequestClearFilters(self)
  }

  /// On macOS 27 the toolbar positions its item views from the window's layout
  /// pass only: laying out the items' shared container leaves the item frames
  /// where they were, so anything measured right after a width change reads
  /// stale geometry and the search field's own view is left centered inside an
  /// item that has not grown yet.
  private static var toolbarLayoutRequiresWindowPass: Bool {
    if #available(macOS 27.0, *) {
      return true
    }

    return false
  }

  /// `true` while the toolbar has moved some of its items into the overflow
  /// menu, which happens when the expanded search field no longer fits.
  private var hasOverflowItems: Bool {
    guard let toolbar, let visibleItems = toolbar.visibleItems else {
      return false
    }

    return visibleItems.count < toolbar.items.count
  }

  private func layOutToolbarItems(in container: NSView) {
    if Self.toolbarLayoutRequiresWindowPass {
      container.window?.layoutIfNeeded()
    }

    container.layoutSubtreeIfNeeded()
  }

  /// The search field stays compact while it is empty and expands up to the
  /// toolbar buttons as soon as it holds text or a filter chip.
  private func updateSearchContainerWidth() {
    guard let searchContainerWidthConstraint else {
      return
    }

    let width = hasSearchInput
      ? max(collapsedSearchFieldWidth, expandedSearchContainerWidth())
      : collapsedSearchFieldWidth

    guard abs(searchContainerWidthConstraint.constant - width) > 0.5 else {
      return
    }

    searchContainerWidthConstraint.constant = width
    searchContainer.superview?.needsLayout = true
    searchContainer.layoutSubtreeIfNeeded()
    // The suggestion list is anchored right after this, so the toolbar has to
    // have placed the field at its new size by then.
    if Self.toolbarLayoutRequiresWindowPass {
      searchContainer.window?.layoutIfNeeded()
    }
  }

  /// Toolbar layout runs after the notification that triggered the change, so
  /// the remeasure is deferred to the next turn of the run loop.
  private func scheduleSearchContainerWidthUpdate() {
    guard !isSearchContainerWidthUpdateScheduled else {
      return
    }

    isSearchContainerWidthUpdateScheduled = true
    DispatchQueue.main.async { [weak self] in
      self?.isSearchContainerWidthUpdateScheduled = false
      self?.updateSearchContainerWidth()
    }
  }

  /// Width that lets the search field take the flexible space between it and
  /// the toolbar buttons.
  ///
  /// The buttons are held to the trailing edge by a flexible space, so what the
  /// field has to leave free is the room they occupy. Measuring that, rather
  /// than the position of the flexible space itself, keeps the result stable
  /// while the field grows into it.
  private func expandedSearchContainerWidth() -> CGFloat {
    guard let searchContainerWidthConstraint,
          let (itemView, container) = searchItemLayoutContext() else {
      return collapsedSearchFieldWidth
    }

    // Measure against the collapsed layout. At that width no item is pushed
    // into the toolbar's overflow menu, so the buttons report the room they
    // really need; measuring the expanded layout instead would feed the field's
    // own growth back into the result.
    //
    // On macOS 27 the item views animate every width change, so the layout is
    // only collapsed when items really have overflowed; otherwise the current
    // layout is measured as is, which yields the same result once the
    // expanded field fits.
    let currentWidth = searchContainerWidthConstraint.constant
    let measuresCollapsedLayout = !Self.toolbarLayoutRequiresWindowPass || hasOverflowItems
    if measuresCollapsedLayout, currentWidth != collapsedSearchFieldWidth {
      searchContainerWidthConstraint.constant = collapsedSearchFieldWidth
      layOutToolbarItems(in: container)
    }
    defer {
      if searchContainerWidthConstraint.constant != currentWidth {
        searchContainerWidthConstraint.constant = currentWidth
        layOutToolbarItems(in: container)
      }
    }

    let itemFrame = itemView.frame
    // Background views span the whole bar, so only the item views laid out
    // after the search field are of interest. Ordering by width as well keeps a
    // fully collapsed flexible space ahead of the button it sits against.
    let trailingViews = container.subviews
      .filter { view in
        view !== itemView
          && !view.isHidden
          && view.frame.minX >= itemFrame.maxX - 1
          && view.frame.width < container.bounds.width
      }
      .sorted { ($0.frame.minX, $0.frame.width) < ($1.frame.minX, $1.frame.width) }

    guard let flexibleSpaceView = trailingViews.first,
          flexibleSpaceView.frame.minX <= itemFrame.maxX + 1,
          let buttonsLeadingEdge = trailingViews.dropFirst().map({ $0.frame.minX }).min() else {
      return collapsedSearchFieldWidth
    }

    let buttonsWidth = container.bounds.maxX - buttonsLeadingEdge
    // AppKit wraps a view based item in a slightly wider container view; that
    // padding is not available to the search field.
    let wrapperPadding = max(0, itemFrame.width - searchContainer.frame.width)
    return container.bounds.width
      - itemFrame.minX
      - buttonsWidth
      - wrapperPadding
      - Self.searchTrailingGap
  }

  /// AppKit wraps view based toolbar items in private views, so the item and
  /// its siblings are found by walking up to the first shared container rather
  /// than assuming a fixed hierarchy.
  private func searchItemLayoutContext() -> (itemView: NSView, container: NSView)? {
    var view: NSView = searchContainer
    while let superview = view.superview {
      if superview.subviews.count > 1 {
        return (view, superview)
      }

      view = superview
    }

    return nil
  }

  private func makeSearchItem() -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: Self.searchIdentifier)
    item.isBordered = false
    Self.applyPlainStyle(to: item)
    item.visibilityPriority = .high
    item.view = searchContainer
    updateSearchItemLocalization(item: item)
    return item
  }

  private func updateSearchItemLocalization(item: NSToolbarItem? = nil) {
    let item = item ?? searchItem
    item.label = L10n.string("Search")
    item.paletteLabel = L10n.string("Search")
    item.toolTip = L10n.string("Search history")
  }

  private func makeSearchContainer() -> NSView {
    let container = SearchFieldContainerView(searchField: searchField)
    container.onEffectiveAppearanceChange = { [weak self] appearance in
      self?.updateSearchAppearance(appearance)
    }
    if #unavailable(macOS 26.0) {
      container.onLayout = { [weak self] in
        self?.searchContentDidLayOut()
      }
      searchField.onLayout = { [weak self] in
        self?.updateSearchTextCursorArea()
      }
    }
    container.translatesAutoresizingMaskIntoConstraints = false
    configureSearchLogoView()
    configureSearchField()
    container.addSubview(searchLogoView)
    container.addSubview(searchField)

    let containerWidthConstraint = container.widthAnchor.constraint(equalToConstant: collapsedSearchFieldWidth)
    searchContainerWidthConstraint = containerWidthConstraint

    NSLayoutConstraint.activate([
      searchLogoView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Self.searchContentLeadingPadding),
      searchLogoView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      searchLogoView.widthAnchor.constraint(equalToConstant: Self.searchLogoSize),
      searchLogoView.heightAnchor.constraint(equalToConstant: Self.searchLogoSize),

      searchField.leadingAnchor.constraint(equalTo: searchLogoView.trailingAnchor, constant: Self.searchLogoTextSpacing),
      searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      containerWidthConstraint,
      container.heightAnchor.constraint(equalToConstant: Self.searchItemHeight)
    ])

    observeWindowNotifications()
    if #unavailable(macOS 26.0) {
      observeSearchContentClicks()
    }

    return container
  }

  /// Before macOS 26 the logo and the start of the field lie outside the
  /// toolbar item, where the window's hit testing never reaches them, so a
  /// click there went to the title bar instead of the field.
  private func observeSearchContentClicks() {
    guard searchClickMonitor == nil else {
      return
    }

    searchClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self, self.handleSearchContentClick(event) else {
          return event
        }

        return nil
      }
    }
  }

  /// The text field's text cursor is limited to the part of it inside the
  /// toolbar item, so before macOS 26 a view behind the window's content shows
  /// it over the rest of the field.
  private func updateSearchTextCursorArea() {
    guard let window = searchContainer.window, let contentView = window.contentView else {
      searchCursorView.removeFromSuperview()
      return
    }

    if searchCursorView.superview !== contentView {
      searchCursorView.removeFromSuperview()
      searchCursorView.frame = contentView.bounds
      searchCursorView.autoresizingMask = [.width, .height]
      contentView.addSubview(searchCursorView, positioned: .below, relativeTo: nil)
    }

    searchCursorView.updateTrackingAreas()
  }

  /// The part of the search text area outside the toolbar item, in window
  /// coordinates.
  private func searchTextFrameOutsideItem() -> NSRect? {
    guard searchContainer.window != nil, !searchContainer.isHiddenOrHasHiddenAncestor else {
      return nil
    }

    let itemFrame = searchContainer.convert(searchContainer.bounds, to: nil)
    let textFrame = searchField.textAreaFrameInWindow
    guard textFrame.minX < itemFrame.minX else {
      return nil
    }

    var frame = textFrame
    frame.size.width = min(textFrame.maxX, itemFrame.minX) - textFrame.minX
    return frame
  }

  private func handleSearchContentClick(_ event: NSEvent) -> Bool {
    guard let window = searchContainer.window,
          event.window === window,
          window.attachedSheet == nil,
          !searchContainer.isHiddenOrHasHiddenAncestor else {
      return false
    }

    let point = event.locationInWindow
    let itemFrame = searchContainer.convert(searchContainer.bounds, to: nil)
    let contentFrame = searchContainer.convert(searchLogoView.frame.union(searchField.frame), to: nil)
    guard contentFrame.contains(point), !itemFrame.contains(point) else {
      return false
    }

    searchField.handleMouseDown(with: event)
    return true
  }

  private func searchContentDidLayOut() {
    if #unavailable(macOS 14.0) {
      allowSearchContentOverflow()
    }

    updateSearchTextCursorArea()
  }

  /// Before macOS 26 the logo and the field are moved back over the room the
  /// toolbar keeps for the hidden window buttons, outside the item's bounds.
  /// Views stopped clipping their subviews only in macOS 14, so before that
  /// the clipping is turned off on the views between the search content and
  /// the first one that holds it whole.
  private func allowSearchContentOverflow() {
    guard searchContainer.window != nil else {
      return
    }

    searchContainer.wantsLayer = true
    searchLogoView.wantsLayer = true
    searchField.wantsLayer = true

    let contentFrame = searchContainer.convert(
      searchLogoView.frame.union(searchField.frame),
      to: nil
    )
    var view: NSView? = searchContainer
    while let current = view {
      if current !== searchContainer,
         current.convert(current.bounds, to: nil).contains(contentFrame) {
        break
      }

      current.layer?.masksToBounds = false
      view = current.superview
    }
  }

  private func observeWindowNotifications() {
    guard windowObservers.isEmpty else {
      return
    }

    // The suggestion list is a child window, so it has to be dismissed as soon
    // as the history window stops being key (hidden, or another window
    // activated).
    windowObservers.append(
      observeOwnWindow(NSWindow.didResignKeyNotification) { toolbar in
        toolbar.suggestionsPopup.hide()
      }
    )

    // A wider window leaves more room between the search field and the toolbar
    // buttons, so an expanded field has to be remeasured.
    windowObservers.append(
      observeOwnWindow(NSWindow.didResizeNotification) { toolbar in
        toolbar.scheduleSearchContainerWidthUpdate()
      }
    )
  }

  private func observeOwnWindow(
    _ name: Notification.Name,
    handler: @escaping (HistoryToolbar) -> Void
  ) -> NSObjectProtocol {
    NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
      MainActor.assumeIsolated {
        guard let self, notification.object as? NSWindow === self.searchContainer.window else {
          return
        }

        handler(self)
      }
    }
  }

  private func configureSearchLogoView() {
    searchLogoView.translatesAutoresizingMaskIntoConstraints = false
    searchLogoView.image = Self.searchLogoImage()
    searchLogoView.contentTintColor = .placeholderTextColor
    searchLogoView.imageScaling = .scaleProportionallyUpOrDown
  }

  private func configureSearchField() {
    let searchFont = NSFont.systemFont(ofSize: Self.searchFontSize, weight: .light)
    searchField.font = searchFont
    updateSearchPlaceholder()
    searchField.delegate = self
    searchField.onTokensWidthChange = { [weak self] in
      self?.updateSearchContainerWidth()
    }
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.heightAnchor.constraint(equalToConstant: SearchTokenField.height).isActive = true
  }

  private func updateSearchPlaceholder() {
    let searchFont = searchField.font ?? NSFont.systemFont(ofSize: Self.searchFontSize, weight: .light)
    searchField.placeholderAttributedString = NSAttributedString(
      string: L10n.string("Type to search..."),
      attributes: [
        .font: searchFont,
        .foregroundColor: resolvedPlaceholderColor ?? NSColor.placeholderTextColor
      ]
    )
    updateCollapsedSearchFieldWidth()
  }

  private func updateCollapsedSearchFieldWidth() {
    // The field starts after the logo, so the room the logo takes in the
    // container is added to the placeholder's own width.
    let searchFieldLeadingOffset = Self.searchContentLeadingPadding
      + Self.searchLogoSize
      + Self.searchLogoTextSpacing
    let width = max(
      Self.minimumCollapsedSearchFieldWidth,
      searchFieldLeadingOffset + searchField.placeholderFittingWidth
    )
    guard abs(collapsedSearchFieldWidth - width) > 0.5 else {
      return
    }

    collapsedSearchFieldWidth = width
    updateSearchContainerWidth()
  }

  // On macOS 26 the Liquid Glass toolbar item wrapper can keep a stale
  // appearance after a light/dark switch, so the search views cannot rely on
  // the appearance they inherit from the toolbar hierarchy. This applies the
  // window's (correct) appearance to the search container explicitly and
  // resolves the colors to static values under that appearance.
  func applyAppearance(_ appearance: NSAppearance) {
    searchContainer.appearance = appearance
    updateSearchAppearance(appearance)
  }

  private func updateSearchAppearance(_ appearance: NSAppearance) {
    var placeholderColor = NSColor.placeholderTextColor
    appearance.performAsCurrentDrawingAppearance {
      placeholderColor = NSColor.placeholderTextColor.usingColorSpace(.sRGB) ?? placeholderColor
    }

    resolvedPlaceholderColor = placeholderColor
    searchLogoView.contentTintColor = placeholderColor
    updateSearchPlaceholder()
    searchLogoView.needsDisplay = true
    searchField.needsDisplay = true
  }

  private func makeSortItem() -> NSToolbarItem {
    let item = HistoryMenuToolbarItem(itemIdentifier: Self.sortIdentifier)
    item.isBordered = true
    Self.applyPlainStyle(to: item)
    item.visibilityPriority = .high
    item.showsIndicator = false
    updateSortItemLocalization(item: item)
    return item
  }

  private func updateSortItemLocalization(item: NSMenuToolbarItem? = nil) {
    let item = item ?? sortItem as? NSMenuToolbarItem
    let label = L10n.string("More")
    item?.label = label
    item?.paletteLabel = label
    item?.toolTip = L10n.string("More options")
    item?.image = Self.symbolImage(symbolName: "ellipsis", label: label)
    item?.menu = makeSortMenu()
  }

  // The toolbar is updated on every change of the history and the selection,
  // and building the menus with their tag and app icons each time kept the
  // main thread busy whenever the history appeared. The menu is built again
  // only when what it shows changes.
  private func updateSortItem(sortOption: HistorySortOption, isSortReversed: Bool) {
    guard sortOption != self.sortOption
            || isSortReversed != self.isSortReversed
            || isCopySequenceModeEnabled != sortMenuIsForCopySequenceMode else {
      return
    }

    self.sortOption = sortOption
    self.isSortReversed = isSortReversed

    if let item = sortItem as? NSMenuToolbarItem {
      item.menu = makeSortMenu()
    }
  }

  private func makeSortMenu() -> NSMenu {
    sortMenuIsForCopySequenceMode = isCopySequenceModeEnabled
    let menu = NSMenu()
    if !isCopySequenceModeEnabled {
      let sortByItem = NSMenuItem(title: L10n.string("Sort By"), action: nil, keyEquivalent: "")
      sortByItem.image = Self.symbolImage(symbolName: "arrow.up.arrow.down", label: L10n.string("Sort By"))
      sortByItem.submenu = makeSortByMenu()
      menu.addItem(sortByItem)
      menu.addItem(.separator())
    }

    let filterByItem = NSMenuItem(title: L10n.string("Filter By"), action: nil, keyEquivalent: "")
    filterByItem.image = Self.symbolImage(symbolName: "line.3.horizontal.decrease", label: L10n.string("Filter By"))
    filterByItem.submenu = makeFilterByMenu()
    menu.addItem(filterByItem)
    menu.addItem(.separator())
    menu.addItem(makePreviewPaneMenuItem())
    menu.addItem(makeDetailsMenuItem())

    menu.showsItemImagesRegardlessOfSystemSetting()
    return menu
  }

  private var hasActiveFilter: Bool {
    !selectedFilterContentTypes.isEmpty
      || !selectedFilterTagIDs.isEmpty
      || !selectedFilterSourceApplicationIDs.isEmpty
  }

  private func makeSortByMenu() -> NSMenu {
    let menu = NSMenu()

    for option in HistorySortOption.allCases {
      let item = NSMenuItem(title: option.title, action: #selector(selectSortOption(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = option.rawValue
      item.state = option == sortOption ? .on : .off
      menu.addItem(item)
    }

    menu.addItem(.separator())

    let reverseItem = NSMenuItem(title: L10n.string("Reverse Order"), action: #selector(toggleSortOrder), keyEquivalent: "")
    reverseItem.target = self
    reverseItem.state = isSortReversed ? .on : .off
    menu.addItem(reverseItem)

    return menu
  }

  /// Every submenu is a set of toggles: picking an entry adds it to the filter
  /// or removes it again, and the "All ..." entry clears that group.
  private func makeFilterByMenu() -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    let typeItem = NSMenuItem(title: L10n.string("Type"), action: nil, keyEquivalent: "")
    typeItem.image = Self.symbolImage(symbolName: "list.bullet", label: L10n.string("Type"))
    typeItem.submenu = makeFilterTypeMenu()
    menu.addItem(typeItem)

    let tagsItem = NSMenuItem(title: L10n.string("Tags"), action: nil, keyEquivalent: "")
    tagsItem.image = Self.symbolImage(symbolName: "circle", label: L10n.string("Tags"))
    tagsItem.submenu = makeFilterTagsMenu()
    menu.addItem(tagsItem)

    let appsItem = NSMenuItem(title: L10n.string("Apps"), action: nil, keyEquivalent: "")
    appsItem.image = Self.symbolImage(symbolName: "rectangle.grid.2x2", label: L10n.string("Apps"))
    appsItem.submenu = makeFilterAppsMenu()
    menu.addItem(appsItem)

    menu.addItem(.separator())

    let clearItem = NSMenuItem(title: L10n.string("Clear Filter"), action: #selector(clearFilters), keyEquivalent: "")
    clearItem.target = self
    clearItem.image = Self.symbolImage(symbolName: "xmark.circle", label: L10n.string("Clear Filter"))
    clearItem.isEnabled = hasActiveFilter
    menu.addItem(clearItem)

    return menu
  }

  private func makeFilterTypeMenu() -> NSMenu {
    let menu = NSMenu()

    for contentType in HistoryFilterContentType.allCases {
      // The Trash lists the deleted items instead of narrowing the history,
      // so it sits apart from the filters that do.
      if contentType == .trash {
        menu.addItem(.separator())
      }
      let item = NSMenuItem(title: contentType.title, action: #selector(selectFilterContentType(_:)), keyEquivalent: "")
      item.target = self
      item.image = Self.symbolImage(symbolName: contentType.systemImage, label: contentType.title)
      item.representedObject = contentType.rawValue
      if contentType == .all {
        item.state = selectedFilterContentTypes.isEmpty ? .on : .off
      } else {
        item.state = selectedFilterContentTypes.contains(contentType) ? .on : .off
      }
      menu.addItem(item)

      // Favorites narrows whichever kinds are picked instead of being one of
      // them, so it sits apart from the kinds.
      if contentType == .all || contentType == .favorites {
        menu.addItem(.separator())
      }
    }

    return menu
  }

  private func makeFilterTagsMenu() -> NSMenu {
    let menu = NSMenu()

    let allTagsItem = NSMenuItem(title: L10n.string("All Tags"), action: #selector(selectFilterTag(_:)), keyEquivalent: "")
    allTagsItem.target = self
    allTagsItem.image = Self.symbolImage(symbolName: "circle", label: L10n.string("All Tags"))
    allTagsItem.state = selectedFilterTagIDs.isEmpty ? .on : .off
    menu.addItem(allTagsItem)

    if !filterTags.isEmpty {
      menu.addItem(.separator())
    }

    for tag in filterTags {
      let item = NSMenuItem(title: tag.name, action: #selector(selectFilterTag(_:)), keyEquivalent: "")
      item.target = self
      item.image = HistoryFilterIcon.tagIcon(for: tag)
      item.representedObject = tag.id
      item.state = selectedFilterTagIDs.contains(tag.id) ? .on : .off
      menu.addItem(item)
    }

    return menu
  }

  private func makeFilterAppsMenu() -> NSMenu {
    let menu = NSMenu()

    let allAppsItem = NSMenuItem(title: L10n.string("All Apps"), action: #selector(selectFilterSourceApplication(_:)), keyEquivalent: "")
    allAppsItem.target = self
    allAppsItem.image = Self.symbolImage(symbolName: "rectangle.grid.2x2", label: L10n.string("All Apps"))
    allAppsItem.state = selectedFilterSourceApplicationIDs.isEmpty ? .on : .off
    menu.addItem(allAppsItem)

    if !filterSourceApplications.isEmpty {
      menu.addItem(.separator())
    }

    for sourceApplication in filterSourceApplications {
      let item = NSMenuItem(title: sourceApplication.name, action: #selector(selectFilterSourceApplication(_:)), keyEquivalent: "")
      item.target = self
      item.image = HistoryFilterIcon.applicationIcon(for: sourceApplication)
      item.representedObject = sourceApplication.id
      item.state = selectedFilterSourceApplicationIDs.contains(sourceApplication.id) ? .on : .off
      menu.addItem(item)
    }

    return menu
  }

  private func makeActionItems() -> [ToolbarAction: NSToolbarItem] {
    Dictionary(uniqueKeysWithValues: ToolbarAction.allCases.map { action in
      (action, makeActionItem(for: action))
    })
  }

  private func makeActionItem(for action: ToolbarAction) -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: Self.itemIdentifier(for: action))
    item.target = self
    item.action = #selector(performActionItem(_:))
    item.isBordered = true
    Self.applyPlainStyle(to: item)
    item.visibilityPriority = .standard
    updateActionItem(item, for: action, targetApp: Self.pasteTargetApplication())
    return item
  }

  private func updateActionsGroup(
    showsCopy: Bool,
    showsCopyTextFromImage: Bool,
    showsCopyTextFromQRCode: Bool,
    showsOpenInBrowser: Bool,
    showsMerge: Bool
  ) {
    guard showsCopy != self.showsCopy
            || showsCopyTextFromImage != self.showsCopyTextFromImage
            || showsCopyTextFromQRCode != self.showsCopyTextFromQRCode
            || showsOpenInBrowser != self.showsOpenInBrowser
            || showsMerge != self.showsMerge else {
      return
    }

    self.showsCopy = showsCopy
    self.showsCopyTextFromImage = showsCopyTextFromImage
    self.showsCopyTextFromQRCode = showsCopyTextFromQRCode
    self.showsOpenInBrowser = showsOpenInBrowser
    self.showsMerge = showsMerge
    updateToolbarActionItemsVisibility()
  }

  private func updateToolbarActionItemsVisibility() {
    guard let toolbar else {
      return
    }

    var actions: [ToolbarAction] = [.paste]
    if showsCopy {
      actions.append(.copy)
    }
    if showsOpenInBrowser {
      actions.append(.openInBrowser)
    }
    if showsCopyTextFromImage {
      actions.append(.copyTextFromImage)
    }
    if showsCopyTextFromQRCode {
      actions.append(.copyTextFromQRCode)
    }
    if showsMerge {
      actions.append(.merge)
    }

    let visibleActions = Set(actions)
    for action in [ToolbarAction.copy, .copyTextFromImage, .copyTextFromQRCode, .openInBrowser, .merge] where !visibleActions.contains(action) {
      if let index = toolbarIndex(for: action) {
        toolbar.removeItem(at: index)
      }
    }

    for action in actions {
      insertToolbarActionItemIfNeeded(action)
    }

    toolbar.validateVisibleItems()
  }

  private func updateActionButtons() {
    let targetApp = Self.pasteTargetApplication()

    for action in ToolbarAction.allCases {
      guard let item = actionItems[action] else {
        continue
      }
      updateActionItem(item, for: action, targetApp: targetApp)
    }
  }

  private func currentCopyActionImage() -> NSImage? {
    actionImage(for: .copy, targetApp: Self.pasteTargetApplication())
  }

  private func animateCopyActionItem(to targetImage: NSImage?) {
    guard let item = actionItems[.copy] else {
      return
    }

    cancelCopyIconAnimation()
    let animationID = copyIconAnimationID
    let sourceImage = item.image
    guard sourceImage != nil, targetImage != nil else {
      item.image = targetImage
      return
    }

    for frameIndex in 1...Self.copyIconFadeFrameCount {
      let progress = CGFloat(frameIndex) / CGFloat(Self.copyIconFadeFrameCount)
      let delay = Self.copyIconFadeDuration * TimeInterval(frameIndex) / TimeInterval(Self.copyIconFadeFrameCount)
      let isFinalFrame = frameIndex == Self.copyIconFadeFrameCount
      let workItem = DispatchWorkItem { [weak self, weak item] in
        guard self?.copyIconAnimationID == animationID else {
          return
        }

        item?.image = isFinalFrame
          ? targetImage
          : Self.blendedImage(from: sourceImage, to: targetImage, progress: progress) ?? targetImage
      }
      copyIconAnimationWorkItems.append(workItem)
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
  }

  private func cancelCopyIconAnimation() {
    copyIconAnimationID += 1
    copyIconAnimationWorkItems.forEach { $0.cancel() }
    copyIconAnimationWorkItems.removeAll()
  }

  private func updateActionItem(_ item: NSToolbarItem, for action: ToolbarAction, targetApp: NSRunningApplication?) {
    let label = actionLabel(for: action, targetApp: targetApp)
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = actionImage(for: action, targetApp: targetApp)
    item.isEnabled = isActionEnabled(action)
  }

  private func actionLabel(for action: ToolbarAction, targetApp: NSRunningApplication?) -> String {
    switch action {
    case .paste:
      if isShowingTrash {
        return L10n.string("Put Back")
      }

      if let pasteItemCount {
        if let appName = targetApp?.localizedName {
          return L10n.string("Paste %d Items to %@", pasteItemCount, appName)
        }

        return L10n.string("Paste %d Items to Active App", pasteItemCount)
      }

      if let appName = targetApp?.localizedName {
        return L10n.string("Paste to %@", appName)
      }

      return L10n.string("Paste to Active App")
    case .copy:
      if let copyItemCount {
        return L10n.string("Copy %d Items to Clipboard", copyItemCount)
      }

      return L10n.string("Copy to Clipboard")
    case .copyTextFromImage:
      return Self.copyTextFromImageLabel
    case .copyTextFromQRCode:
      return Self.copyTextFromQRCodeLabel
    case .openInBrowser:
      return L10n.string("Open in Browser")
    case .merge:
      return L10n.string("Merge")
    }
  }

  private func actionImage(for action: ToolbarAction, targetApp: NSRunningApplication?) -> NSImage? {
    switch action {
    case .paste:
      if isShowingTrash {
        return Self.symbolImage(symbolName: "arrow.uturn.backward", label: actionLabel(for: action, targetApp: targetApp))
      }

      return Self.applicationIcon(for: targetApp)
    case .copy:
      if isShowingCopySuccess {
        return Self.symbolImage(symbolName: "checkmark", label: actionLabel(for: action, targetApp: targetApp), color: .systemGreen)
      }
      return Self.symbolImage(symbolName: "square.on.square", label: actionLabel(for: action, targetApp: targetApp))
    case .copyTextFromImage:
      return Self.symbolImage(symbolName: Self.copyTextFromImageSymbolName, label: actionLabel(for: action, targetApp: targetApp))
    case .copyTextFromQRCode:
      return Self.symbolImage(symbolName: Self.copyTextFromQRCodeSymbolName, label: actionLabel(for: action, targetApp: targetApp))
    case .openInBrowser:
      return Self.symbolImage(symbolName: "globe", label: actionLabel(for: action, targetApp: targetApp))
    case .merge:
      return Self.symbolImage(symbolName: "arrow.down.and.line.horizontal.and.arrow.up", label: actionLabel(for: action, targetApp: targetApp))
    }
  }

  private func isActionEnabled(_ action: ToolbarAction) -> Bool {
    switch action {
    case .paste:
      return canPaste
    case .copy:
      return canCopy
    case .copyTextFromImage:
      return showsCopyTextFromImage
    case .copyTextFromQRCode:
      return showsCopyTextFromQRCode
    case .openInBrowser:
      return showsOpenInBrowser
    case .merge:
      return showsMerge
    }
  }

  private func makePinItem() -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: Self.pinIdentifier)
    item.target = self
    item.action = #selector(togglePin)
    item.isBordered = true
    item.visibilityPriority = .high
    updatePinItem(isPinned: false, item: item)
    return item
  }

  private func makeCopySequenceItem() -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: Self.copySequenceIdentifier)
    item.target = self
    item.action = #selector(toggleCopySequenceMode)
    item.isBordered = true
    item.visibilityPriority = .high
    updateCopySequenceItem(isCopySequenceModeEnabled: isCopySequenceModeEnabled, item: item)
    return item
  }

  /// Showing or hiding the preview pane lives in the sort menu, whose item
  /// names where the pane sits, at the bottom or on the right of the window.
  func updatePreviewPane(
    isShown: Bool,
    showsDetails: Bool,
    position: HistoryPreviewPanePosition,
    togglePreviewShortcut: String,
    toggleDetailsShortcut: String
  ) {
    guard isShown != isPreviewPaneShown
            || showsDetails != self.showsDetails
            || position != previewPanePosition
            || togglePreviewShortcut != self.togglePreviewShortcut
            || toggleDetailsShortcut != self.toggleDetailsShortcut else {
      return
    }

    isPreviewPaneShown = isShown
    self.showsDetails = showsDetails
    previewPanePosition = position
    self.togglePreviewShortcut = togglePreviewShortcut
    self.toggleDetailsShortcut = toggleDetailsShortcut
    if let item = sortItem as? NSMenuToolbarItem {
      item.menu = makeSortMenu()
    }
  }

  private func makePreviewPaneMenuItem() -> NSMenuItem {
    let title = isPreviewPaneShown ? L10n.string("Hide Preview") : L10n.string("Show Preview")
    let item = NSMenuItem(title: title, action: #selector(togglePreviewPane), keyEquivalent: "")
    item.target = self
    let symbolName: String
    switch previewPanePosition {
    case .bottom:
      symbolName = "rectangle.bottomhalf.inset.filled"
    case .right:
      symbolName = "rectangle.righthalf.inset.filled"
    }
    item.image = Self.symbolImage(symbolName: symbolName, label: title)
      ?? Self.symbolImage(symbolName: "eye", label: title)
    HistoryItemContextMenu.applyShortcut(togglePreviewShortcut, to: item)
    return item
  }

  private func makeDetailsMenuItem() -> NSMenuItem {
    let title = showsDetails ? L10n.string("Hide Details") : L10n.string("Show Details")
    let item = NSMenuItem(title: title, action: #selector(toggleDetails), keyEquivalent: "")
    item.target = self
    item.image = Self.symbolImage(symbolName: "info.circle", label: title)
    HistoryItemContextMenu.applyShortcut(toggleDetailsShortcut, to: item)
    return item
  }

  private func makeCommandItem() -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: Self.commandIdentifier)
    item.target = self
    item.action = #selector(showCommandDialog)
    item.isBordered = true
    Self.applyPlainStyle(to: item)
    item.visibilityPriority = .high
    updateCommandItemLocalization(item: item)
    return item
  }

  private func updateCommandItemLocalization(item: NSToolbarItem? = nil) {
    let item = item ?? commandItem
    let label = L10n.string("Command")
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = Self.symbolImage(symbolName: "command", label: label)
  }

  private func updatePinItem(isPinned: Bool, item: NSToolbarItem? = nil) {
    let item = item ?? pinItem
    let label = isPinned ? L10n.string("Stop always displaying") : L10n.string("Always display")
    let symbolName = isPinned ? "pin.fill" : "pin"

    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = Self.symbolImage(symbolName: symbolName, label: label)
    Self.applyToggleStyle(to: item, isOn: isPinned)
  }

  private func updateCopySequenceItem(isCopySequenceModeEnabled: Bool, item: NSToolbarItem? = nil) {
    self.isCopySequenceModeEnabled = isCopySequenceModeEnabled
    let item = item ?? copySequenceItem
    let label = isCopySequenceModeEnabled
      ? L10n.string("Disable Copy Sequence")
      : L10n.string("Enable Copy Sequence")

    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    // The button keeps its regular style; only the icon is tinted, so the
    // enabled state reads from the icon rather than from the background.
    item.image = isCopySequenceModeEnabled
      ? Self.symbolImage(
          symbolName: "square.stack.3d.up.fill",
          label: label,
          color: .controlAccentColor
        )
      : Self.symbolImage(symbolName: "square.stack.3d.up", label: label)
    Self.applyPlainStyle(to: item)
  }

  private static func applyPlainStyle(to item: NSToolbarItem) {
    if #available(macOS 26.0, *) {
      item.style = .plain
    }
  }

  private static func applyToggleStyle(to item: NSToolbarItem, isOn: Bool) {
    if #available(macOS 26.0, *) {
      item.style = isOn ? .prominent : .plain
      item.backgroundTintColor = nil
    }
  }

  private func insertToolbarActionItemIfNeeded(_ action: ToolbarAction) {
    guard let toolbar, toolbarIndex(for: action) == nil else {
      return
    }

    let actionOrder: [ToolbarAction] = [.paste, .copy, .openInBrowser, .copyTextFromImage, .copyTextFromQRCode, .merge]
    let previousIndex = actionOrder
      .prefix { $0 != action }
      .reversed()
      .compactMap(toolbarIndex(for:))
      .first

    // The first action goes at the end of the actions group, which ends
    // before the space that keeps it apart from the More button.
    let actionsGroupEndIndex = toolbarIndex(for: Self.sortIdentifier)
      .map { $0 - Self.groupSeparatorIdentifiers.count }
    let insertionIndex = previousIndex.map { $0 + 1 } ?? actionsGroupEndIndex ?? toolbar.items.count
    toolbar.insertItem(withItemIdentifier: Self.itemIdentifier(for: action), at: insertionIndex)
  }

  private func toolbarIndex(for action: ToolbarAction) -> Int? {
    toolbarIndex(for: Self.itemIdentifier(for: action))
  }

  private func toolbarIndex(for identifier: NSToolbarItem.Identifier) -> Int? {
    toolbar?.items.firstIndex { $0.itemIdentifier == identifier }
  }

  @objc private func performActionItem(_ sender: NSToolbarItem) {
    guard let action = Self.action(for: sender.itemIdentifier) else {
      return
    }

    switch action {
    case .paste:
      delegate?.historyToolbarDidRequestPaste(self)
    case .copy:
      delegate?.historyToolbarDidRequestCopy(self)
    case .copyTextFromImage:
      delegate?.historyToolbarDidRequestCopyTextFromImage(self)
    case .copyTextFromQRCode:
      delegate?.historyToolbarDidRequestCopyTextFromQRCode(self)
    case .openInBrowser:
      delegate?.historyToolbarDidRequestOpenInBrowser(self)
    case .merge:
      delegate?.historyToolbarDidRequestMergeSelection(self)
    }
  }

  @objc private func selectSortOption(_ sender: NSMenuItem) {
    guard let rawValue = sender.representedObject as? String,
          let sortOption = HistorySortOption(rawValue: rawValue) else {
      return
    }

    delegate?.historyToolbar(self, didSelectSortOption: sortOption)
  }

  @objc private func toggleSortOrder() {
    delegate?.historyToolbarDidRequestToggleSortOrder(self)
  }

  @objc private func selectFilterContentType(_ sender: NSMenuItem) {
    guard let rawValue = sender.representedObject as? String,
          let contentType = HistoryFilterContentType(rawValue: rawValue) else {
      return
    }

    guard contentType != .all else {
      delegate?.historyToolbar(self, didRequestClearFilterGroup: .contentType)
      return
    }

    delegate?.historyToolbar(
      self,
      didSetFilterContentType: contentType,
      isSelected: !selectedFilterContentTypes.contains(contentType)
    )
  }

  @objc private func selectFilterTag(_ sender: NSMenuItem) {
    guard let tagID = sender.representedObject as? Tag.ID else {
      delegate?.historyToolbar(self, didRequestClearFilterGroup: .tag)
      return
    }

    delegate?.historyToolbar(self, didSetFilterTagID: tagID, isSelected: !selectedFilterTagIDs.contains(tagID))
  }

  @objc private func selectFilterSourceApplication(_ sender: NSMenuItem) {
    guard let sourceApplicationID = sender.representedObject as? HistorySourceApplication.ID else {
      delegate?.historyToolbar(self, didRequestClearFilterGroup: .sourceApplication)
      return
    }

    delegate?.historyToolbar(
      self,
      didSetFilterSourceApplicationID: sourceApplicationID,
      isSelected: !selectedFilterSourceApplicationIDs.contains(sourceApplicationID)
    )
  }

  @objc private func clearFilters() {
    delegate?.historyToolbarDidRequestClearFilters(self)
  }

  @objc private func togglePin() {
    delegate?.historyToolbarDidRequestTogglePin(self)
  }

  @objc private func toggleCopySequenceMode() {
    delegate?.historyToolbarDidRequestToggleCopySequenceMode(self)
  }

  @objc private func togglePreviewPane() {
    delegate?.historyToolbarDidRequestTogglePreviewPane(self)
  }

  @objc private func toggleDetails() {
    delegate?.historyToolbarDidRequestToggleDetails(self)
  }

  @objc private func showCommandDialog() {
    delegate?.historyToolbarDidRequestCommandDialog(self)
  }

  private static func symbolImage(symbolName: String, label: String) -> NSImage? {
    guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label) else {
      return nil
    }
    let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    return image.withSymbolConfiguration(configuration)
  }

  private static func symbolImage(symbolName: String, label: String, color: NSColor) -> NSImage? {
    guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label) else {
      return nil
    }
    // A single palette color paints every layer of the symbol in full, so the
    // icon matches the solid accent fill of the prominent toolbar buttons.
    // Hierarchical rendering would fade the secondary layers and look darker.
    let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
      .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let configuredImage = image.withSymbolConfiguration(configuration)
    configuredImage?.isTemplate = false
    return configuredImage
  }

  private static func blendedImage(from sourceImage: NSImage?, to targetImage: NSImage?, progress: CGFloat) -> NSImage? {
    guard let sourceImage, let targetImage else {
      return targetImage ?? sourceImage
    }

    let size = NSSize(
      width: max(sourceImage.size.width, targetImage.size.width),
      height: max(sourceImage.size.height, targetImage.size.height)
    )
    let blendedImage = NSImage(size: size)
    blendedImage.lockFocus()
    draw(sourceImage, centeredIn: size, fraction: 1 - progress)
    draw(targetImage, centeredIn: size, fraction: progress)
    blendedImage.unlockFocus()
    blendedImage.isTemplate = false
    return blendedImage
  }

  private static func draw(_ image: NSImage, centeredIn size: NSSize, fraction: CGFloat) {
    let rect = NSRect(
      x: (size.width - image.size.width) / 2,
      y: (size.height - image.size.height) / 2,
      width: image.size.width,
      height: image.size.height
    )
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: fraction)
  }

  private static func itemIdentifier(for action: ToolbarAction) -> NSToolbarItem.Identifier {
    switch action {
    case .paste:
      return pasteIdentifier
    case .copy:
      return copyIdentifier
    case .copyTextFromImage:
      return copyTextFromImageIdentifier
    case .copyTextFromQRCode:
      return copyTextFromQRCodeIdentifier
    case .openInBrowser:
      return openInBrowserIdentifier
    case .merge:
      return mergeIdentifier
    }
  }

  private static func action(for itemIdentifier: NSToolbarItem.Identifier) -> ToolbarAction? {
    switch itemIdentifier {
    case pasteIdentifier:
      return .paste
    case copyIdentifier:
      return .copy
    case copyTextFromImageIdentifier:
      return .copyTextFromImage
    case copyTextFromQRCodeIdentifier:
      return .copyTextFromQRCode
    case openInBrowserIdentifier:
      return .openInBrowser
    case mergeIdentifier:
      return .merge
    default:
      return nil
    }
  }

  private static func pasteTargetApplication() -> NSRunningApplication? {
    let clipBookBundleIdentifier = Bundle.main.bundleIdentifier
    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
       frontmostApplication.bundleIdentifier != clipBookBundleIdentifier {
      return frontmostApplication
    }

    return NSWorkspace.shared.runningApplications.first { application in
      application.bundleIdentifier != clipBookBundleIdentifier
        && application.activationPolicy == .regular
        && !application.isHidden
    }
  }

  private static func searchLogoImage() -> NSImage? {
    let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
    image?.isTemplate = true
    return image
  }

  private static func applicationIcon(for application: NSRunningApplication?) -> NSImage {
    let icon: NSImage
    if let bundleURL = application?.bundleURL {
      icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
    } else {
      icon = NSWorkspace.shared.icon(for: .application)
    }

    icon.size = NSSize(width: Self.pasteTargetIconSize, height: Self.pasteTargetIconSize)
    return icon
  }

  private static func singleLineSearchQuery(from query: String) -> String {
    query.components(separatedBy: .newlines).joined(separator: " ")
  }
}

// The toolbar enables its items again on every validation unless it is asked,
// so the actions that can't run right now are disabled here.
extension HistoryToolbar: NSToolbarItemValidation {
  func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
    guard let action = actionItems.first(where: { $0.value === item })?.key else {
      return true
    }

    return isActionEnabled(action)
  }
}

/// AppKit disables every toolbar item while a sheet is attached and restores
/// the state it recorded once the sheet ends. When the window is ordered out
/// with a sheet on it (running a command from the command palette, or hiding
/// the window while an item preview is open), the item is recorded as disabled
/// and comes back disabled. Other items recover on the next validation, but
/// NSMenuToolbarItem's validate() does nothing, so the item stays disabled
/// for good. AppKit does not validate items while a sheet is attached, so
/// enabling the item here does not enable it under a sheet.
private final class HistoryMenuToolbarItem: NSMenuToolbarItem {
  override func validate() {
    isEnabled = true
  }
}

/// Shows the text cursor over a part of the window without taking clicks.
///
/// AppKit picks the cursor for the view that hit testing finds under the mouse,
/// which outside the toolbar item is the title bar, so cursor rectangles and
/// cursor update tracking areas would be overridden. The cursor is set on
/// every move inside the area instead.
private final class SearchTextCursorView: NSView {
  private let textFrameInWindow: () -> NSRect?
  private let isInsideText: (NSPoint) -> Bool
  private var trackingArea: NSTrackingArea?

  init(textFrameInWindow: @escaping () -> NSRect?, isInsideText: @escaping (NSPoint) -> Bool) {
    self.textFrameInWindow = textFrameInWindow
    self.isInsideText = isInsideText
    super.init(frame: .zero)
    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    let rect = textFrameInWindow().map { convert($0, from: nil) } ?? .zero
    guard rect != trackingArea?.rect else {
      return
    }

    if let trackingArea {
      removeTrackingArea(trackingArea)
      self.trackingArea = nil
    }

    guard !rect.isEmpty else {
      return
    }

    let trackingArea = NSTrackingArea(
      rect: rect,
      options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
      owner: self
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    NSCursor.iBeam.set()
  }

  override func mouseMoved(with event: NSEvent) {
    NSCursor.iBeam.set()
  }

  // Leaving to the right enters the part of the field inside the toolbar item,
  // where the text field shows the same cursor, whatever order the two events
  // come in.
  override func mouseExited(with event: NSEvent) {
    if isInsideText(event.locationInWindow) {
      NSCursor.iBeam.set()
    } else {
      NSCursor.arrow.set()
    }
  }
}

private final class SearchFieldContainerView: NSView {
  private weak var searchField: SearchTokenField?
  var onEffectiveAppearanceChange: ((NSAppearance) -> Void)?
  var onLayout: (() -> Void)?

  init(searchField: SearchTokenField) {
    self.searchField = searchField
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let searchField else {
      return super.hitTest(point)
    }

    guard bounds.contains(point) else {
      return nil
    }

    return searchField.hitTest(point) ?? searchField
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    onEffectiveAppearanceChange?(effectiveAppearance)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    onLayout?()
  }

  override func layout() {
    super.layout()
    onLayout?()
  }
}
