import AppKit
import Combine
import UniformTypeIdentifiers

private enum HistoryShortcutAction {
  case closeHistory
  case selectNextItem
  case selectPreviousItem
  case pasteSelected
  case pasteSelectedSecondary
  case pasteAndDeleteSelected
  case pasteAndDeleteSelectedSecondary
  case copySelected
  case copySelectedSecondary
  case deleteItem
  case toggleFavorite
  case showInFinder
  case openInBrowser
  case editItem
  case renameItem
  case transformItem
  case toggleSensitiveContentVisibility
  case focusSearchField
  case openSettings
  case showCommandPalette
  case showInHistory
  case togglePreviewPane
  case toggleDetails
}

private extension HistoryShortcutAction {
  /// Whether the shortcut still works once the trial is over and the history
  /// is read-only: it moves around, looks at or organizes items rather than
  /// using them.
  var isAvailableInReadOnlyHistory: Bool {
    switch self {
    case .closeHistory, .selectNextItem, .selectPreviousItem, .toggleFavorite,
         .toggleSensitiveContentVisibility, .focusSearchField, .openSettings,
         .showCommandPalette, .showInHistory, .togglePreviewPane, .toggleDetails:
      return true
    case .pasteSelected, .pasteSelectedSecondary, .pasteAndDeleteSelected,
         .pasteAndDeleteSelectedSecondary, .copySelected, .copySelectedSecondary,
         .deleteItem, .showInFinder, .openInBrowser, .editItem, .renameItem, .transformItem:
      return false
    }
  }
}

private struct OpenWithApplication {
  let url: URL
  let name: String
  let icon: NSImage
}

private final class HistoryMenuCommandAction: NSObject {
  let run: () -> Void
  let isAvailableInReadOnlyHistory: Bool

  init(isAvailableInReadOnlyHistory: Bool = false, run: @escaping () -> Void) {
    self.isAvailableInReadOnlyHistory = isAvailableInReadOnlyHistory
    self.run = run
  }
}

private struct HistoryMultiTagMenuSelection {
  let items: [ClipboardItem]
  let tag: Tag
}

@MainActor
final class HistoryContentViewController: NSViewController {
  private static let minimumViewSize = NSSize(width: 640, height: 400)
  private static let searchDebounceDelay: TimeInterval = 0.5

  private let model: AppModel
  private let coordinator: AppCoordinator
  private var cancellables: Set<AnyCancellable> = []
  private var selectionModelUpdatesOriginatingFromList = 0
  private var isSelectionSyncFromModelScheduled = false
  private weak var historyToolbar: HistoryToolbar?
  private var pendingSearchQuery: String?
  private var needsListReload = false
  private var searchQueryDebounceWorkItem: DispatchWorkItem?
  private var copyTextFromImageTitle: String { L10n.string("Copy Text from Image") }
  private let copyTextFromImageSystemImageName = "text.viewfinder"
  private var copyTextFromQRCodeTitle: String { L10n.string("Copy Text from QR Code") }
  private let copyTextFromQRCodeSystemImageName = "qrcode.viewfinder"
  private var isNewTagSheetPresented = false

  private let listPaneView = History()
  private let previewPane = HistoryPreviewPane()
  private lazy var splitView = HistoryPreviewSplitView(listView: listPaneView, previewPane: previewPane)
  // Shows the selected item in the preview pane. It is the controller of the
  // preview sheet, presented as a pane, and exists while the pane is shown and
  // has an item.
  private var previewPaneController: ItemPreviewDialogController?
  // The settings the pane's controller was made with, which it can't change.
  private var previewPaneControllerConfiguration: PreviewPaneControllerConfiguration?
  private var isPreviewPaneUpdateScheduled = false
  private var commandPalette: CommandPalette?
  private var commandPaletteOutsideClickMonitor: OutsideClickDismissalMonitor?
  private var isModalSheetPresentationPending = false
  private weak var previewSheetWindow: NSWindow?
  private weak var previewSheetController: ItemPreviewDialogController?
  // Retained while the preview sheet is open, because it is the target of the
  // "More actions" menu items and NSMenuItem does not retain its target.
  private var previewActionsMenu: ItemPreviewActionsMenu?
  private var previewTagsMenu: ItemPreviewTagsMenu?

  var isCommandPalettePresented: Bool {
    commandPalette != nil
  }

  var isModalPresentationPending: Bool {
    isModalSheetPresentationPending
  }

  var isTagSheetPresented: Bool {
    isNewTagSheetPresented
  }

  func canSplit(_ item: ClipboardItem) -> Bool {
    coordinator.canSplit(item)
  }

  /// `true` when items may be used. Otherwise the attempt is pointed out, and
  /// the caller does nothing.
  private func allowsUsingItems() -> Bool {
    guard coordinator.isHistoryReadOnly else {
      return true
    }

    coordinator.notifyReadOnlyHistoryActionAttempt()
    return false
  }

  private static let menuActionsAvailableInReadOnlyHistory: Set<Selector> = [
    #selector(favoriteMenuItem(_:)),
    #selector(sensitiveContentVisibilityMenuItem(_:)),
    #selector(previewMenuItem(_:)),
    #selector(showInHistoryMenuItem(_:)),
    #selector(toggleTagMenuItem(_:)),
    #selector(applyTagMenuItem(_:)),
    #selector(newTagMenuItem(_:)),
    #selector(editTagsMenuItem(_:)),
    #selector(togglePreviewPaneDetailsMenuItem(_:)),
    #selector(hidePreviewPaneMenuItem(_:))
  ]

  /// Whether a context menu action still works once the trial is over and the
  /// history is read-only. The actions that use items stay in the menu,
  /// disabled, so the menu shows what a license brings back.
  func isMenuActionAvailable(_ action: Selector, representedObject: Any?) -> Bool {
    guard coordinator.isHistoryReadOnly else {
      return true
    }

    if action == #selector(runContextMenuCommandItem(_:)) {
      return (representedObject as? HistoryMenuCommandAction)?.isAvailableInReadOnlyHistory == true
    }

    return Self.menuActionsAvailableInReadOnlyHistory.contains(action)
  }

  func canPasteAndDelete(_ item: ClipboardItem) -> Bool {
    canPasteAndDelete([item])
  }

  // A missing file can only be pasted as its path, which is rarely a one-off,
  // so it gets no paste-and-delete action.
  private func canPasteAndDelete(_ items: [ClipboardItem]) -> Bool {
    !items.contains(where: \.isMissingSingleFileItem) && coordinator.canPasteAndDelete(items)
  }

  init(model: AppModel, coordinator: AppCoordinator) {
    self.model = model
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
    listPaneView.filePreviewCache = coordinator.filePreviewCache
    listPaneView.loadFormatting = { [weak coordinator] item in coordinator?.loadingFormatting(of: item) ?? item }
    bindModel()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    searchQueryDebounceWorkItem?.cancel()
  }

  func attachToolbar(_ toolbar: HistoryToolbar) {
    historyToolbar = toolbar
    updateToolbarState()
    updatePreviewPaneToolbarItem()
  }

  override func loadView() {
    let initialSize = initialViewSize()
    view = HistoryKeyHandlingView(frame: NSRect(origin: .zero, size: initialSize))
    (view as? HistoryKeyHandlingView)?.configureBackground()
    (view as? HistoryKeyHandlingView)?.onSearchKeyDown = { [weak self] event in
      self?.historyToolbar?.focusSearchFieldAndHandleKeyDown(with: event)
    }
    // The content view reliably receives appearance changes, while the toolbar
    // hierarchy may not (stale Liquid Glass wrappers on macOS 26), so forward
    // the change to the toolbar from here.
    (view as? HistoryKeyHandlingView)?.onEffectiveAppearanceChange = { [weak self] appearance in
      self?.historyToolbar?.applyAppearance(appearance)
    }

    listPaneView.delegate = self

    configurePreviewPane()
    view.addSubview(splitView)

    NSLayoutConstraint.activate([
      splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      splitView.topAnchor.constraint(equalTo: view.topAnchor),
      splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func initialViewSize() -> NSSize {
    let savedSize = model.preferences.historyWindowSize
    return NSSize(
      width: max(savedSize.width, Self.minimumViewSize.width),
      height: max(savedSize.height, Self.minimumViewSize.height)
    )
  }

  func selectFirstHistoryItem() {
    selectFirstHistoryItem(syncsList: true)
  }

  /// Selects the item the history opens with: the first item, or the item that
  /// was selected when the history was closed if the selection is remembered
  /// and that item is still listed.
  func selectHistoryItemOnOpen() {
    if isViewLoaded {
      // The pointer may rest over the list where the history opens.
      listPaneView.pauseHoverSelectionUntilPointerMoves()
    }

    guard model.preferences.rememberHistorySelection,
          let selectedItemID = model.selectedItemID,
          model.filteredItems.contains(where: { $0.id == selectedItemID }) else {
      selectFirstHistoryItem()
      return
    }

    model.selectedItemIDs = [selectedItemID]
    model.selectedItemIDsInSelectionOrder = [selectedItemID]

    guard isViewLoaded else {
      return
    }

    syncSelectionFromModel()
    updateToolbarState()
    listPaneView.scrollSelectionIntoView()
  }

  private func selectFirstHistoryItem(syncsList: Bool) {
    model.selectedItemID = model.filteredItems.first?.id
    model.selectedItemIDs = model.selectedItemID.map { [$0] } ?? []
    model.selectedItemIDsInSelectionOrder = model.selectedItemID.map { [$0] } ?? []

    guard syncsList, isViewLoaded else {
      return
    }

    syncSelectionFromModel()
    updateToolbarState()
  }

  /// The list insets its content by the safe area, which AppKit changes without
  /// laying the list out again, so it is laid out once the change is in place
  /// and again once the title bar has finished animating it.
  func safeAreaDidChange() {
    guard isViewLoaded else {
      return
    }

    for delay in [0, 0.35] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        self?.listPaneView.needsLayout = true
        // The pane on the right starts below the toolbar and its accessories.
        self?.splitView.needsLayout = true
      }
    }
  }

  func refreshVisibleFilePreviews() {
    guard isViewLoaded else {
      return
    }

    listPaneView.refreshVisibleFilePreviewRows()
  }

  /// Content the user asked to see is hidden again once the window is gone, so it is not
  /// on screen the next time the history is opened.
  func hideRevealedSensitiveContent() {
    guard isViewLoaded else {
      return
    }

    listPaneView.hideRevealedSensitiveContent()
    setNeedsPreviewPaneUpdate()
  }

  func exitMultipleSelectionMode() {
    guard isViewLoaded else {
      return
    }

    listPaneView.exitKeyboardMultipleSelectionMode()
  }

  func clearSearchAfterHiddenInterval() {
    guard isSearchActive else {
      return
    }

    searchQueryDebounceWorkItem?.cancel()
    searchQueryDebounceWorkItem = nil
    pendingSearchQuery = nil
    applySearchQuery("", shouldResetSelection: !model.preferences.rememberHistorySelection)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    reloadList()
    updateToolbarState()
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    listPaneView.scrollInitialSelectionIntoViewIfNeeded()
    listPaneView.focusTableView()
  }

  private func bindModel() {
    // Each change marks the list as stale the moment it is made, and the list
    // is reloaded once on the main run loop after it. Changes made together,
    // such as an insert that also moves the selection or the frame of the
    // window saved field by field, reload it once instead of once per change.
    model.$items
      .handleEvents(receiveOutput: { [weak self] _ in self?.setNeedsListReload() })
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.reloadListIfNeeded()
        self?.refreshPreviewSheetItem()
        self?.setNeedsPreviewPaneUpdate()
      }
      .store(in: &cancellables)

    reloadListOnChange(of: model.$tags)

    model.$selectedItemID
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.handleSelectionModelDidChange()
      }
      .store(in: &cancellables)

    model.$selectedItemIDs
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.handleSelectionModelDidChange()
      }
      .store(in: &cancellables)

    // Only the preferences the list and the toolbar show reload them. Others,
    // such as the frame of the window saved each time it hides, leave them be.
    // $preferences publishes before the new value is stored, so the values it
    // delivers are compared rather than the ones read back from the model.
    reloadListOnChange(of: model.$preferences.map(HistoryListPreferences.init).removeDuplicates())

    model.$preferences
      .map(\.pasteOnClick)
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] pasteOnClick in
        self?.listPaneView.selectsItemOnHover = pasteOnClick
      }
      .store(in: &cancellables)

    model.$preferences
      .map(HistoryToolbarPreferences.init)
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.updateToolbarState()
      }
      .store(in: &cancellables)

    coordinator.$licenseState
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self else {
          return
        }

        self.listPaneView.isReadOnly = self.coordinator.isHistoryReadOnly
        self.updateToolbarState()
        self.setNeedsPreviewPaneUpdate()
      }
      .store(in: &cancellables)

    model.$preferences
      .map(HistoryPreviewPanePreferences.init)
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] preferences in
        self?.applyPreviewPanePreferences(preferences)
      }
      .store(in: &cancellables)

    coordinator.$trialNotice
      .map { $0 != nil }
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] showsNotice in
        self?.listPaneView.showsNoticeAbove = showsNotice
      }
      .store(in: &cancellables)

    model.$localizationRevision
      .handleEvents(receiveOutput: { [weak self] _ in self?.setNeedsListReload() })
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.historyToolbar?.refreshLocalization()
        self?.previewPane.refreshLocalization()
        self?.reloadListIfNeeded()
      }
      .store(in: &cancellables)

    reloadListOnChange(of: model.$searchQuery)
    reloadListOnChange(of: model.$historySortOption)
    reloadListOnChange(of: model.$isHistorySortReversed)
    reloadListOnChange(of: model.$selectedHistoryFilterContentTypes)
    reloadListOnChange(of: model.$selectedHistoryFilterTagIDs)
    reloadListOnChange(of: model.$selectedHistoryFilterSourceApplicationIDs)
    reloadListOnChange(of: model.$trashedItems)
  }

  private func reloadListOnChange<Value>(of publisher: some Publisher<Value, Never>) {
    publisher
      .handleEvents(receiveOutput: { [weak self] _ in self?.setNeedsListReload() })
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.reloadListIfNeeded()
      }
      .store(in: &cancellables)
  }

  private func setNeedsListReload() {
    needsListReload = true
  }

  // A reload made in the meantime, by a change that reloads the list right
  // away, leaves nothing to do here.
  private func reloadListIfNeeded() {
    guard needsListReload else {
      return
    }

    reloadList()
  }

  private func reloadList() {
    needsListReload = false
    let items = model.filteredItems
    listPaneView.reload(
      items: items,
      availableTags: model.availableTags,
      selectedItemID: model.selectedItemID,
      selectedItemIDs: model.selectedItemIDs,
      searchQuery: model.searchQuery,
      // The Trash has no quick paste, so its rows show no number shortcuts.
      showCommandNumberShortcut: model.preferences.showCommandNumberShortcut && !model.isShowingTrash,
      showPreviewForLinks: model.preferences.showPreviewForLinks,
      detectSensitiveContent: model.preferences.detectSensitiveContent,
      showDividers: model.preferences.showHistoryDividers,
      preferPastingAsPlainText: model.preferences.preferPastingAsPlainText,
      groupPinnedFavorites: model.preferences.pinFavoritesToTop && !model.isShowingTrash,
      sectionDate: historySectionDate(for: model.historySortOption),
      isShowingTrash: model.isShowingTrash
    ) { [weak self] firstItem in
      self?.model.selectedItemID = firstItem.id
      self?.model.selectedItemIDs = [firstItem.id]
      self?.model.selectedItemIDsInSelectionOrder = [firstItem.id]
    }
    updateToolbarFilterState()
    updateToolbarState()
    setNeedsPreviewPaneUpdate()
  }

  private func updateToolbarFilterState() {
    historyToolbar?.updateFilterState(
      selectedContentTypes: model.selectedHistoryFilterContentTypes,
      tags: model.availableTags,
      selectedTagIDs: model.selectedHistoryFilterTagIDs,
      sourceApplications: model.availableHistorySourceApplications,
      selectedSourceApplicationIDs: model.selectedHistoryFilterSourceApplicationIDs
    )
  }

  private func historySectionDate(for sortOption: HistorySortOption) -> ((ClipboardItem) -> Date?)? {
    // The Trash lists items by when they were deleted, whatever the sort.
    guard !model.isShowingTrash else {
      return { $0.deletedAt }
    }

    guard !model.preferences.copySequenceModeEnabled else {
      return { $0.copiedAt }
    }

    switch sortOption {
    case .lastCopyTime:
      return { $0.copiedAt }
    case .firstCopyTime:
      return { $0.firstCopiedAt }
    case .numberOfCopies, .size:
      return nil
    }
  }

  private func syncSelectionFromModel() {
    listPaneView.syncSelection(selectedItemID: model.selectedItemID, selectedItemIDs: model.selectedItemIDs) { [weak self] firstItem in
      self?.model.selectedItemID = firstItem.id
      self?.model.selectedItemIDs = [firstItem.id]
      self?.model.selectedItemIDsInSelectionOrder = [firstItem.id]
    }
  }

  private func handleSelectionModelDidChange() {
    guard selectionModelUpdatesOriginatingFromList == 0 else {
      selectionModelUpdatesOriginatingFromList -= 1
      return
    }

    scheduleSelectionSyncFromModel()
  }

  private func scheduleSelectionSyncFromModel() {
    guard !isSelectionSyncFromModelScheduled else {
      return
    }

    isSelectionSyncFromModelScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      self.isSelectionSyncFromModelScheduled = false
      self.syncSelectionFromModel()
      self.updateToolbarState()
      self.setNeedsPreviewPaneUpdate()
    }
  }

  private func scheduleSearchQueryUpdate(_ query: String) {
    searchQueryDebounceWorkItem?.cancel()

    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      let shouldResetSelection = isSearchActive
      pendingSearchQuery = nil
      applySearchQuery(query, shouldResetSelection: shouldResetSelection)
      return
    }

    pendingSearchQuery = query
    let workItem = DispatchWorkItem { [weak self] in
      self?.applyPendingSearchQuery(query)
    }
    searchQueryDebounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.searchDebounceDelay, execute: workItem)
  }

  private func applyPendingSearchQuery(_ query: String) {
    guard pendingSearchQuery == query else {
      return
    }

    pendingSearchQuery = nil
    searchQueryDebounceWorkItem = nil
    applySearchQuery(query)
  }

  private func applySearchQuery(_ query: String, shouldResetSelection: Bool = false) {
    guard model.searchQuery != query else {
      updateToolbarState()
      if shouldResetSelection {
        selectFirstHistoryItem()
      }
      return
    }

    model.searchQuery = query
    if shouldResetSelection {
      selectFirstHistoryItem(syncsList: false)
    }
  }

  private var isSearchActive: Bool {
    let query = pendingSearchQuery ?? model.searchQuery
    return !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func updateToolbarState() {
    let selectedItems = model.selectedItems
    let selectedItem = selectedItems.count == 1 ? selectedItems.first : nil
    let hasSelection = !selectedItems.isEmpty
    let hasMultipleSelection = selectedItems.count > 1
    // A read-only history keeps the buttons that use items, disabled, so they
    // don't jump around once a license is activated.
    let canUseItems = !coordinator.isHistoryReadOnly
    // The Trash offers putting items back in place of pasting, and nothing else.
    guard !model.isShowingTrash else {
      historyToolbar?.update(
        searchQuery: pendingSearchQuery ?? model.searchQuery,
        isPinned: !model.preferences.hideOnFocusLoss,
        isCopySequenceModeEnabled: model.preferences.copySequenceModeEnabled,
        canPaste: canUseItems && hasSelection,
        canCopy: false,
        showsCopyTextFromImage: false,
        showsCopyTextFromQRCode: false,
        showsOpenInBrowser: false,
        showsMerge: false,
        sortOption: model.historySortOption,
        isSortReversed: model.isHistorySortReversed,
        isShowingTrash: true
      )
      return
    }

    let canMergeSelection = canUseItems && hasMultipleSelection && coordinator.canMerge(selectedItems)
    let pasteItemCount = selectedItem?.isMultipleFileItem == true ? selectedItem?.filePaths.count : nil
    let copyItemCount = selectedItem?.isMultipleFileItem == true ? selectedItem?.filePaths.count : nil
    historyToolbar?.update(
      searchQuery: pendingSearchQuery ?? model.searchQuery,
      isPinned: !model.preferences.hideOnFocusLoss,
      isCopySequenceModeEnabled: model.preferences.copySequenceModeEnabled,
      canPaste: canUseItems && hasSelection,
      canCopy: canUseItems && (selectedItem != nil || canMergeSelection),
      pasteItemCount: pasteItemCount,
      copyItemCount: copyItemCount,
      showsCopyTextFromImage: canUseItems && !hasMultipleSelection && selectedItem?.canCopyTextFromImage == true,
      showsCopyTextFromQRCode: canUseItems && !hasMultipleSelection && selectedItem?.canCopyTextFromQRCode == true,
      showsOpenInBrowser: canUseItems && !hasMultipleSelection && selectedItem?.browserURL != nil,
      showsMerge: canMergeSelection,
      sortOption: model.historySortOption,
      isSortReversed: model.isHistorySortReversed,
      isReadOnly: !canUseItems
    )
  }

  private func setHistoryFilterContentType(_ contentType: HistoryFilterContentType, isSelected: Bool) {
    guard contentType != .all else {
      clearHistoryFilterGroup(.contentType)
      return
    }

    var contentTypes = model.selectedHistoryFilterContentTypes
    if isSelected {
      contentTypes.insert(contentType)
    } else {
      contentTypes.remove(contentType)
    }
    guard contentTypes != model.selectedHistoryFilterContentTypes else {
      return
    }
    model.selectedHistoryFilterContentTypes = contentTypes
    selectFirstHistoryItem(syncsList: false)
  }

  private func setHistoryFilterTagID(_ tagID: Tag.ID, isSelected: Bool) {
    var tagIDs = model.selectedHistoryFilterTagIDs
    if isSelected {
      tagIDs.insert(tagID)
    } else {
      tagIDs.remove(tagID)
    }
    guard tagIDs != model.selectedHistoryFilterTagIDs else {
      return
    }
    model.selectedHistoryFilterTagIDs = tagIDs
    selectFirstHistoryItem(syncsList: false)
  }

  private func setHistoryFilterSourceApplicationID(_ sourceApplicationID: HistorySourceApplication.ID, isSelected: Bool) {
    var sourceApplicationIDs = model.selectedHistoryFilterSourceApplicationIDs
    if isSelected {
      sourceApplicationIDs.insert(sourceApplicationID)
    } else {
      sourceApplicationIDs.remove(sourceApplicationID)
    }
    guard sourceApplicationIDs != model.selectedHistoryFilterSourceApplicationIDs else {
      return
    }
    model.selectedHistoryFilterSourceApplicationIDs = sourceApplicationIDs
    selectFirstHistoryItem(syncsList: false)
  }

  private func clearHistoryFilterGroup(_ group: SearchTokenGroup) {
    switch group {
    case .contentType:
      guard !model.selectedHistoryFilterContentTypes.isEmpty else {
        return
      }
      model.selectedHistoryFilterContentTypes = []
    case .tag:
      guard !model.selectedHistoryFilterTagIDs.isEmpty else {
        return
      }
      model.selectedHistoryFilterTagIDs = []
    case .sourceApplication:
      guard !model.selectedHistoryFilterSourceApplicationIDs.isEmpty else {
        return
      }
      model.selectedHistoryFilterSourceApplicationIDs = []
    }
    selectFirstHistoryItem(syncsList: false)
  }

  private func clearHistoryFilters() {
    guard model.isHistoryFilterActive else {
      return
    }
    model.clearHistoryFilters()
    selectFirstHistoryItem(syncsList: false)
  }

  /// `true` when the item can be shown among its neighbors, which only makes
  /// sense while a search or a filter hides the rest of the history.
  var canShowInHistory: Bool {
    isSearchActive || model.isHistoryFilterActive
  }

  /// Leaves the search and the filters and selects the item in the full
  /// history, scrolled to the middle of the list so the items copied around
  /// it can be looked through.
  func showInHistory(_ item: ClipboardItem) {
    guard canShowInHistory, model.items.contains(where: { $0.id == item.id }) else {
      return
    }

    searchQueryDebounceWorkItem?.cancel()
    searchQueryDebounceWorkItem = nil
    pendingSearchQuery = nil
    historyToolbar?.hideSearchSuggestions()

    model.selectedItemID = item.id
    model.selectedItemIDs = [item.id]
    model.selectedItemIDsInSelectionOrder = [item.id]
    model.searchQuery = ""
    model.clearHistoryFilters()

    reloadList()
    listPaneView.focusTableView()
    listPaneView.scrollItemToCenter(item.id)
  }

  private func performNumberKeyAction(at index: Int) {
    guard !model.isShowingTrash else {
      return
    }

    let itemIndex = index - 1
    let items = model.filteredItems
    guard items.indices.contains(itemIndex) else {
      return
    }

    let item = items[itemIndex]
    switch HistoryItemActionPreference(preferenceValue: model.preferences.numberKeyAction) {
    case .copy:
      copy(item)
    case .paste:
      coordinator.paste(item)
    }
  }

  private func performDoubleClickAction(for item: ClipboardItem) {
    guard !model.isShowingTrash else {
      return
    }

    switch HistoryItemActionPreference(preferenceValue: model.preferences.doubleClickAction) {
    case .copy:
      copy(item)
    case .paste:
      coordinator.paste(item, variant: item.kind.selectedShortcutVariant(preferences: model.preferences))
    }
  }

  func handleHistoryWindowKeyDown(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {

    if isEscapeKeyEvent(event), commandPalette != nil {
      closeCommandPalette()
      return true
    }

    // The search suggestions take priority over the window shortcuts, otherwise
    // Return would paste and Escape would clear the whole query.
    if historyToolbar?.handleSearchSuggestionsKeyDown(event) == true {
      return true
    }

    if handleUndoKeyDown(event, firstResponder: firstResponder) {
      return true
    }

    if previewPaneTextSelectionOwnsCopy(event, firstResponder: firstResponder) {
      return false
    }

    if handlePreviewKeyDown(event, firstResponder: firstResponder) {
      return true
    }

    if let index = quickNumberIndex(for: event) {
      performNumberKeyAction(at: index)
      return true
    }

    if handleKeyboardMultipleSelectionKeyDown(event, firstResponder: firstResponder) {
      return true
    }

    if handleShiftSelectionKeyDown(event, firstResponder: firstResponder) {
      return true
    }

    for (shortcut, action) in historyShortcutBindings {
      guard KeyboardShortcutParser.event(event, matches: shortcut) else {
        continue
      }

      if isPlainTextShortcut(shortcut), isTextInputFocused(firstResponder) {
        return false
      }

      if action == .closeHistory, isEscapeKeyEvent(event) {
        handleEscapeFromWindow()
        return true
      }

      performHistoryShortcutAction(action)
      return true
    }

    return false
  }

  /// Cmd+Z undoes deleting items and putting them back, and Shift+Cmd+Z
  /// redoes it. While the search field has typing to undo, the keys are left
  /// to it.
  private func handleUndoKeyDown(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
    let isUndo = KeyboardShortcutParser.event(event, matches: "cmd+z")
    let isRedo = KeyboardShortcutParser.event(event, matches: "shift+cmd+z")
    guard isUndo || isRedo else {
      return false
    }

    if isTextInputFocused(firstResponder) {
      let textUndoManager = firstResponder?.undoManager
      if isUndo ? textUndoManager?.canUndo == true : textUndoManager?.canRedo == true {
        return false
      }
    }

    if isUndo {
      coordinator.undoHistoryChange()
    } else {
      coordinator.redoHistoryChange()
    }
    return true
  }

  private func handlePreviewKeyDown(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers.isEmpty, event.keyCode == 49 else {
      return false
    }

    let searchQuery = pendingSearchQuery ?? model.searchQuery
    if isTextInputFocused(firstResponder), !searchQuery.isEmpty {
      return false
    }

    if let item = model.selectedItem {
      showPreview(for: item)
    }
    return true
  }














  private func showPreview(for item: ClipboardItem, startsInEditMode: Bool = false) {
    // The preview edits and uses the item, which an item in the Trash is not
    // open to.
    guard !model.isShowingTrash,
          previewSheetWindow == nil,
          view.window?.attachedSheet == nil,
          let window = view.window else {
      return
    }

    let maximumFrameSize = NSSize(
      width: (window.screen?.visibleFrame.width ?? window.frame.width) * 0.7,
      height: (window.screen?.visibleFrame.height ?? window.frame.height) * 0.7
    )
    var maximumContentSize = NSWindow.contentRect(
      forFrameRect: NSRect(origin: .zero, size: maximumFrameSize),
      styleMask: [.titled, .resizable]
    ).size
    maximumContentSize.height = max(
      ItemPreviewDialogController.minimumContentSize.height,
      maximumContentSize.height - ItemPreviewDialogController.toolbarHeight
    )
    let dialogController = ItemPreviewDialogController(
      item: item,
      maximumContentSize: maximumContentSize,
      detectsSensitiveContent: model.preferences.detectSensitiveContent,
      revealsSensitiveContent: listPaneView.revealsSensitiveContent(of: item),
      isReadOnly: coordinator.isHistoryReadOnly,
      loadFormatting: { [weak coordinator] item in coordinator?.loadingFormatting(of: item) ?? item }
    )
    let dialogWindow = NSWindow(contentViewController: dialogController)
    // The sheet style is set up front: beginSheet adds it otherwise, and that
    // change takes the height of the hidden title bar away from the content,
    // so the sheet would show up shorter than the size it asked for.
    dialogWindow.styleMask = [.titled, .resizable, .docModalWindow]
    dialogWindow.title = dialogController.dialogTitle
    dialogWindow.titleVisibility = .hidden
    dialogWindow.toolbar = dialogController.makeToolbar()
    dialogWindow.toolbarStyle = .unified
    dialogWindow.addTitlebarAccessoryViewController(dialogController.makeCloseAccessory())
    ItemPreviewDialogController.configureWindow(dialogWindow)
    dialogWindow.isReleasedWhenClosed = false
    dialogWindow.contentMinSize = ItemPreviewDialogController.minimumContentSize
    dialogWindow.contentMaxSize = maximumContentSize
    dialogWindow.maxSize = maximumFrameSize
    dialogWindow.setContentSize(dialogController.windowContentSize)
    // The dialog watches for the user resizing the sheet.
    dialogWindow.delegate = dialogController
    previewSheetWindow = dialogWindow
    previewSheetController = dialogController

    let dismissPreview = { [weak window, weak dialogWindow] in
      guard let window, let dialogWindow else {
        return
      }
      window.endSheet(dialogWindow)
    }
    let actionsMenu = ItemPreviewActionsMenu(
      makeItemMenu: { [weak self] item in
        self?.makeItemContextMenu(for: item) ?? NSMenu()
      },
      dismissPreview: dismissPreview
    )
    previewActionsMenu = actionsMenu
    let tagsMenu = ItemPreviewTagsMenu(
      makeItemMenu: { [weak self] item in
        self?.makeItemContextMenu(for: item) ?? NSMenu()
      },
      dismissPreview: dismissPreview
    )
    previewTagsMenu = tagsMenu

    dialogController.onCancel = dismissPreview
    dialogController.onToggleFavorite = { [weak self] item in
      self?.coordinator.toggleFavorite(item)
    }
    dialogController.onToggleSensitiveContentVisibility = { [weak self] item in
      self?.toggleSensitiveContentVisibility(of: item)
    }
    dialogController.onCopyTextFromImage = { [weak self] item in
      self?.copyTextFromImage(item)
    }
    dialogController.onCopyTextFromQRCode = { [weak self] item in
      self?.copyTextFromQRCode(item)
    }
    dialogController.onSaveAsFile = { [weak self] item in
      dismissPreview()
      DispatchQueue.main.async {
        self?.showSaveImageAsFilePanel(for: item)
      }
    }
    dialogController.onOpenInApplication = { [weak self] item in
      dismissPreview()
      DispatchQueue.main.async {
        self?.coordinator.openInAssociatedApplication(item)
      }
    }
    dialogController.onShowInFinder = { [weak self] item in
      dismissPreview()
      DispatchQueue.main.async {
        self?.coordinator.showInFinder(item)
      }
    }
    dialogController.onSave = { [weak self] item, text in
      self?.coordinator.editContent(item, text: text)
    }
    dialogController.moreActionsMenuProvider = { [weak actionsMenu] item in
      actionsMenu?.makeMenu(for: item)
    }
    dialogController.tagsMenuProvider = { [weak tagsMenu] item in
      tagsMenu?.makeMenu(for: item)
    }
    // Let the arrow keys (or custom selection shortcuts) move the history
    // selection while the preview sheet stays open, like Quick Look in Finder.
    dialogController.onKeyDown = { [weak self] event in
      self?.handlePreviewSheetKeyDown(event) ?? false
    }

    // Entered before the sheet is on screen, so the user never sees the
    // regular toolbar being replaced by the editing one.
    if startsInEditMode {
      dialogController.beginEditing(closesWhenFinished: true)
    }

    window.beginSheet(dialogWindow) { [weak self] _ in
      self?.previewSheetWindow = nil
      self?.previewActionsMenu = nil
      self?.previewTagsMenu = nil
    }
    // beginSheet reapplies the sheet material, so the opaque configuration has
    // to be set again after the sheet is on screen.
    ItemPreviewDialogController.configureWindow(dialogWindow)
    if !startsInEditMode {
      dialogWindow.makeFirstResponder(dialogController.view)
    }
  }

  private func handlePreviewSheetKeyDown(_ event: NSEvent) -> Bool {
    let preferences = model.preferences
    if KeyboardShortcutParser.event(event, matches: preferences.selectNextItemShortcut) {
      listPaneView.moveSelection(.down)
      return true
    }
    if KeyboardShortcutParser.event(event, matches: preferences.selectPreviousItemShortcut) {
      listPaneView.moveSelection(.up)
      return true
    }
    if KeyboardShortcutParser.event(event, matches: preferences.editItemShortcut),
       let previewSheetController {
      editItem(previewSheetController.item)
      return true
    }
    if handlePreviewSheetItemActionKeyDown(event) {
      return true
    }

    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers.isEmpty else {
      return false
    }

    switch event.keyCode {
    case 125:
      listPaneView.moveSelection(.down)
      return true
    case 126:
      listPaneView.moveSelection(.up)
      return true
    default:
      return false
    }
  }

  // Pasting, copying and opening a link in the browser act on the previewed
  // item the same way they act on the selected item of the history list, so the
  // preview is a place to act on the item and not only to look at it.
  private func handlePreviewSheetItemActionKeyDown(_ event: NSEvent) -> Bool {
    guard let item = previewSheetController?.item else {
      return false
    }

    let preferences = model.preferences
    // The preview of a read-only history stays open, so the notice above the
    // history is in sight to say why nothing happened.
    if coordinator.isHistoryReadOnly {
      let itemActionShortcuts = [
        preferences.pasteSelectedShortcut,
        preferences.pasteSelectedSecondaryShortcut,
        preferences.pasteAndDeleteSelectedShortcut,
        preferences.pasteAndDeleteSelectedSecondaryShortcut,
        preferences.copySelectedShortcut,
        preferences.copySelectedSecondaryShortcut,
        preferences.openInBrowserShortcut
      ]
      guard itemActionShortcuts.contains(where: { KeyboardShortcutParser.event(event, matches: $0) }) else {
        return false
      }

      coordinator.notifyReadOnlyHistoryActionAttempt()
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.pasteSelectedShortcut) {
      let variant = item.kind.selectedShortcutVariant(preferences: preferences)
      dismissPreviewSheet { [weak self] in
        self?.coordinator.paste(item, variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.pasteSelectedSecondaryShortcut),
       let variant = item.kind.selectedSecondaryShortcutVariant(preferences: preferences) {
      dismissPreviewSheet { [weak self] in
        self?.coordinator.paste(item, variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.pasteAndDeleteSelectedShortcut),
       canPasteAndDelete(item) {
      let variant = item.kind.selectedShortcutVariant(preferences: preferences)
      dismissPreviewSheet { [weak self] in
        self?.coordinator.pasteAndDelete([item], variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.pasteAndDeleteSelectedSecondaryShortcut),
       canPasteAndDelete(item),
       let variant = item.kind.selectedSecondaryShortcutVariant(preferences: preferences) {
      dismissPreviewSheet { [weak self] in
        self?.coordinator.pasteAndDelete([item], variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.copySelectedShortcut) {
      let variant = item.kind.selectedCopyShortcutVariant(preferences: preferences)
      dismissPreviewSheet { [weak self] in
        self?.copy(item, variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.copySelectedSecondaryShortcut),
       let variant = item.kind.selectedSecondaryCopyShortcutVariant(preferences: preferences) {
      dismissPreviewSheet { [weak self] in
        self?.copy(item, variant: variant)
      }
      return true
    }

    if KeyboardShortcutParser.event(event, matches: preferences.openInBrowserShortcut),
       item.browserURL != nil {
      dismissPreviewSheet { [weak self] in
        self?.openInBrowserAndHideHistory(item)
      }
      return true
    }

    return false
  }

  // The preview leaves the screen before the action runs: a paste has to reach
  // the application behind the history window, and the copy indicator of the
  // toolbar would otherwise be hidden by the sheet.
  private func dismissPreviewSheet(then action: @escaping @MainActor () -> Void) {
    guard let previewSheetWindow, let window = view.window else {
      action()
      return
    }

    window.endSheet(previewSheetWindow)
    DispatchQueue.main.async(execute: action)
  }

  // Keeps the previewed item in sync with the model, so changes made from the
  // preview itself (tags, favorite) show up in its toolbar and details, and so
  // the next tag toggle starts from the current tags rather than stale ones.
  private func refreshPreviewSheetItem() {
    guard let previewSheetController, let previewSheetWindow else {
      return
    }

    // An item that is gone from the model (deleted, or saved as empty text)
    // has nothing left to preview.
    guard let item = model.items.first(where: { $0.id == previewSheetController.item.id }) else {
      view.window?.endSheet(previewSheetWindow)
      return
    }

    guard item != previewSheetController.item else {
      return
    }

    previewSheetController.update(
      item: item,
      revealsSensitiveContent: listPaneView.revealsSensitiveContent(of: item)
    )
  }

  private func updatePreviewSheet(for item: ClipboardItem?) {
    guard let previewSheetController, previewSheetWindow != nil else {
      return
    }
    guard let item, previewSheetController.item != item else {
      return
    }

    previewSheetController.update(
      item: item,
      revealsSensitiveContent: listPaneView.revealsSensitiveContent(of: item)
    )
  }

  // MARK: - Preview pane

  private func configurePreviewPane() {
    let preferences = model.preferences
    splitView.isPreviewShown = preferences.showPreviewPane
    splitView.preferredPaneHeight = preferences.previewPaneHeight.map { CGFloat($0) }
    splitView.preferredPaneWidthRatio = preferences.previewPaneWidthRatio.map { CGFloat($0) }
    splitView.onPositionChange = { [weak self] _ in
      self?.updatePreviewPaneToolbarItem()
    }
    splitView.onPreferredPaneSizeChange = { [weak self] in
      self?.savePreviewPaneSize()
    }
    splitView.onListBottomFadeChange = { [weak self] height in
      self?.listPaneView.additionalBottomContentInset = height
    }
    splitView.detailsPaneHeight = { [weak self] width in
      self?.previewPaneController?.detailsHeight(forWidth: width) ?? 0
    }
    previewPane.grabberMenu = makePreviewPaneMenu(showsDetails: preferences.showPreviewPaneDetails)
    updatePreviewPaneToolbarItem()
  }

  // $preferences publishes before the new value is stored, so the delivered
  // values are used here; the pane itself is updated once they are stored.
  private func applyPreviewPanePreferences(_ preferences: HistoryPreviewPanePreferences) {
    guard isViewLoaded else {
      return
    }

    splitView.preferredPaneHeight = preferences.previewPaneHeight.map { CGFloat($0) }
    splitView.preferredPaneWidthRatio = preferences.previewPaneWidthRatio.map { CGFloat($0) }
    previewPane.grabberMenu = makePreviewPaneMenu(showsDetails: preferences.showPreviewPaneDetails)
    previewPaneController?.showsWebPages = preferences.showPreviewForLinks
    updatePreviewPaneToolbarItem(preferences)
    // The pane changes its shape and its content together, in this pass, so
    // showing or hiding a part of it never leaves a frame with neither.
    updatePreviewPane(
      showsPreview: preferences.showPreviewPane,
      showsDetails: preferences.showPreviewPaneDetails,
      showsWebPages: preferences.showPreviewForLinks,
      detectsSensitiveContent: preferences.detectSensitiveContent
    )
  }

  private func updatePreviewPaneToolbarItem(_ preferences: HistoryPreviewPanePreferences? = nil) {
    let preferences = preferences ?? HistoryPreviewPanePreferences(model.preferences)
    historyToolbar?.updatePreviewPane(
      isShown: preferences.showPreviewPane,
      showsDetails: preferences.showPreviewPaneDetails,
      position: splitView.position,
      togglePreviewShortcut: preferences.togglePreviewPaneShortcut,
      toggleDetailsShortcut: preferences.toggleDetailsShortcut
    )
  }

  /// Shows or hides the details of the selected item: under its preview, or
  /// in a pane of their own while the preview is hidden.
  private func toggleDetails() {
    var preferences = model.preferences
    preferences.showPreviewPaneDetails.toggle()
    model.preferences = preferences
    coordinator.persistPreferences()
  }

  private func togglePreviewPane() {
    var preferences = model.preferences
    preferences.showPreviewPane.toggle()
    model.preferences = preferences
    coordinator.persistPreferences()
  }

  private func savePreviewPaneSize() {
    var preferences = model.preferences
    preferences.previewPaneHeight = splitView.preferredPaneHeight.map { Double($0) }
    preferences.previewPaneWidthRatio = splitView.preferredPaneWidthRatio.map { Double($0) }
    guard preferences != model.preferences else {
      return
    }

    model.preferences = preferences
    coordinator.persistPreferences()
  }

  private func makePreviewPaneMenu(showsDetails: Bool) -> NSMenu {
    let menu = NSMenu()
    let detailsItem = NSMenuItem(
      title: L10n.string("Show Details"),
      action: #selector(togglePreviewPaneDetailsMenuItem(_:)),
      keyEquivalent: ""
    )
    detailsItem.target = self
    detailsItem.state = showsDetails ? .on : .off
    menu.addItem(detailsItem)
    menu.addItem(.separator())
    let hideItem = NSMenuItem(
      title: L10n.string("Hide Preview"),
      action: #selector(hidePreviewPaneMenuItem(_:)),
      keyEquivalent: ""
    )
    hideItem.target = self
    menu.addItem(hideItem)
    return menu
  }

  @objc func togglePreviewPaneDetailsMenuItem(_ sender: NSMenuItem) {
    toggleDetails()
  }

  @objc func hidePreviewPaneMenuItem(_ sender: NSMenuItem) {
    guard model.preferences.showPreviewPane else {
      return
    }
    togglePreviewPane()
  }

  // The selection changes in many ways, often several at once, so the pane
  // catches up once per pass of the run loop.
  private func setNeedsPreviewPaneUpdate() {
    guard !isPreviewPaneUpdateScheduled else {
      return
    }

    isPreviewPaneUpdateScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      self.isPreviewPaneUpdateScheduled = false
      self.updatePreviewPane()
    }
  }

  private func updatePreviewPane() {
    let preferences = model.preferences
    updatePreviewPane(
      showsPreview: preferences.showPreviewPane,
      showsDetails: preferences.showPreviewPaneDetails,
      showsWebPages: preferences.showPreviewForLinks,
      detectsSensitiveContent: preferences.detectSensitiveContent
    )
  }

  // One preview controller fills the pane whichever parts of it are shown:
  // the preview with or without the details under it, or the details alone
  // while the preview is hidden. Showing or hiding a part changes what the
  // same controller shows, rather than replacing it.
  private func updatePreviewPane(
    showsPreview: Bool,
    showsDetails: Bool,
    showsWebPages: Bool,
    detectsSensitiveContent: Bool
  ) {
    guard isViewLoaded else {
      return
    }

    splitView.isPreviewShown = showsPreview
    // An empty list has nothing to show, while the selected item may still
    // name one that a search has just hidden.
    let selectedItem = model.filteredItems.isEmpty ? nil : model.selectedItem
    guard showsPreview || showsDetails, let item = selectedItem else {
      tearDownPreviewPaneController()
      splitView.isDetailsPaneShown = false
      return
    }

    let revealsSensitiveContent = listPaneView.revealsSensitiveContent(of: item)
    let configuration = PreviewPaneControllerConfiguration(
      detectsSensitiveContent: detectsSensitiveContent,
      isReadOnly: coordinator.isHistoryReadOnly
    )
    if let previewPaneController, previewPaneControllerConfiguration == configuration {
      previewPaneController.showsWebPages = showsWebPages
      previewPaneController.showsDetails = showsDetails
      previewPaneController.showsPreview = showsPreview
      if previewPaneController.item != item
          || previewPaneController.revealsSensitiveContent != revealsSensitiveContent {
        previewPaneController.update(item: item, revealsSensitiveContent: revealsSensitiveContent)
      }
    } else {
      tearDownPreviewPaneController()
      let controller = ItemPreviewDialogController(
        item: item,
        maximumContentSize: Self.previewPaneMaximumContentSize,
        detectsSensitiveContent: configuration.detectsSensitiveContent,
        revealsSensitiveContent: revealsSensitiveContent,
        isReadOnly: configuration.isReadOnly,
        presentation: .pane,
        loadFormatting: { [weak coordinator] item in coordinator?.loadingFormatting(of: item) ?? item }
      )
      controller.showsDetails = showsDetails
      controller.showsWebPages = showsWebPages
      controller.showsPreview = showsPreview
      controller.onContentFocusLost = { [weak self] in
        self?.listPaneView.focusTableView()
      }
      controller.onCancel = { [weak self] in
        self?.listPaneView.focusTableView()
      }
      addChild(controller)
      previewPane.contentView = controller.view
      previewPaneController = controller
      previewPaneControllerConfiguration = configuration
    }

    splitView.isDetailsPaneShown = !showsPreview
    // Alone, the details are as tall as they need, which depends on the item.
    splitView.needsLayout = true
  }

  // Only used for the size the preview starts out with, before the pane
  // gives it its own.
  private static let previewPaneMaximumContentSize = NSSize(width: 800, height: 600)

  private func tearDownPreviewPaneController() {
    guard let previewPaneController else {
      return
    }

    previewPaneController.tearDownContent()
    previewPane.contentView = nil
    previewPaneController.removeFromParent()
    self.previewPaneController = nil
    previewPaneControllerConfiguration = nil
  }

  // Text selected in the preview pane keeps ⌘C for itself, as it does in the
  // preview sheet; the whole item is copied when nothing is selected.
  private func previewPaneTextSelectionOwnsCopy(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
    guard KeyboardShortcutParser.event(event, matches: "cmd+c"),
          let textView = firstResponder as? NSTextView,
          textView.isDescendant(of: previewPane) else {
      return false
    }

    return textView.selectedRange().length > 0
  }

  private var historyShortcutBindings: [(String, HistoryShortcutAction)] {
    let preferences = model.preferences
    return [
      (preferences.closeHistoryShortcut, .closeHistory),
      (preferences.closeHistorySecondaryShortcut, .closeHistory),
      (preferences.closeHistoryTertiaryShortcut, .closeHistory),
      (preferences.selectNextItemShortcut, .selectNextItem),
      (preferences.selectPreviousItemShortcut, .selectPreviousItem),
      (preferences.pasteSelectedShortcut, .pasteSelected),
      (preferences.pasteSelectedSecondaryShortcut, .pasteSelectedSecondary),
      (preferences.pasteAndDeleteSelectedShortcut, .pasteAndDeleteSelected),
      (preferences.pasteAndDeleteSelectedSecondaryShortcut, .pasteAndDeleteSelectedSecondary),
      (preferences.copySelectedShortcut, .copySelected),
      (preferences.copySelectedSecondaryShortcut, .copySelectedSecondary),
      (preferences.deleteItemShortcut, .deleteItem),
      (preferences.toggleFavoriteShortcut, .toggleFavorite),
      (preferences.showInFinderShortcut, .showInFinder),
      (preferences.showInHistoryShortcut, .showInHistory),
      (preferences.openInBrowserShortcut, .openInBrowser),
      (preferences.editItemShortcut, .editItem),
      (preferences.renameItemShortcut, .renameItem),
      (preferences.transformItemShortcut, .transformItem),
      (preferences.toggleSensitiveContentShortcut, .toggleSensitiveContentVisibility),
      (preferences.focusSearchFieldShortcut, .focusSearchField),
      (preferences.togglePreviewPaneShortcut, .togglePreviewPane),
      (preferences.toggleDetailsShortcut, .toggleDetails),
      (preferences.showCommandPaletteShortcut, .showCommandPalette),
      (preferences.openSettingsShortcut, .openSettings)
    ]
  }

  private func handleEscapeFromWindow() {
    if historyToolbar?.hasSearchInput == true {
      historyToolbar?.clearSearchAndFocus()
      return
    }

    coordinator.hideHistoryPanel()
  }

  private func isEscapeKeyEvent(_ event: NSEvent) -> Bool {
    event.charactersIgnoringModifiers == "\u{1b}"
  }

  /// Arrow keys only drive the list selection once the list itself has focus.
  /// Up and down move focus there from the search field, which is what tells
  /// the two apart: until then the arrows belong to the text being typed.
  private func isHistoryListFocused(_ firstResponder: NSResponder?) -> Bool {
    guard let view = firstResponder as? NSView else {
      return false
    }

    return view === listPaneView.tableView || view.isDescendant(of: listPaneView.tableView)
  }

  private func isTextInputFocused(_ firstResponder: NSResponder?) -> Bool {
    if let textView = firstResponder as? NSTextView {
      return textView.isEditable
    }

    return firstResponder is NSTextField
  }

  private func handleKeyboardMultipleSelectionKeyDown(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
    guard isHistoryListFocused(firstResponder) else {
      return false
    }

    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if modifiers.isEmpty {
      switch event.keyCode {
      case 124:
        listPaneView.updateKeyboardMultipleSelection(.addCurrent)
        return true
      case 123:
        listPaneView.updateKeyboardMultipleSelection(.removeCurrent)
        return true
      case 126:
        guard listPaneView.isKeyboardMultipleSelectionMode else {
          return false
        }
        listPaneView.moveKeyboardMultipleSelectionFocus(.up)
        return true
      case 125:
        guard listPaneView.isKeyboardMultipleSelectionMode else {
          return false
        }
        listPaneView.moveKeyboardMultipleSelectionFocus(.down)
        return true
      default:
        return false
      }
    }

    return false
  }

  private func handleShiftSelectionKeyDown(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
    guard isHistoryListFocused(firstResponder) else {
      return false
    }

    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers == .shift else {
      return false
    }

    switch event.keyCode {
    case 126:
      listPaneView.extendSelection(.up)
      return true
    case 125:
      listPaneView.extendSelection(.down)
      return true
    default:
      return false
    }
  }

  private func performHistoryShortcutAction(_ action: HistoryShortcutAction) {
    guard action.isAvailableInReadOnlyHistory || allowsUsingItems() else {
      return
    }

    if model.isShowingTrash, performTrashShortcutAction(action) {
      return
    }

    switch action {
    case .closeHistory:
      coordinator.hideHistoryPanel()
    case .selectNextItem:
      listPaneView.moveSelection(.down)
    case .selectPreviousItem:
      selectPreviousItemOrFocusSearchField()
    case .pasteSelected:
      pasteSelectedItemFromShortcut()
    case .pasteSelectedSecondary:
      pasteSelectedItemWithSecondaryActionFromShortcut()
    case .pasteAndDeleteSelected:
      guard canPasteAndDelete(model.selectedItems) else {
        return
      }
      coordinator.pasteAndDeleteSelection()
    case .pasteAndDeleteSelectedSecondary:
      pasteAndDeleteSelectedItemWithSecondaryActionFromShortcut()
    case .copySelected:
      copySelectedItemFromShortcut()
    case .copySelectedSecondary:
      copySelectedItemWithSecondaryActionFromShortcut()
    case .deleteItem:
      coordinator.deleteSelection()
    case .toggleFavorite:
      guard let item = model.selectedItem else {
        return
      }
      coordinator.toggleFavorite(item)
    case .showInFinder:
      guard let item = model.selectedItem else {
        return
      }
      coordinator.showInFinder(item)
    case .openInBrowser:
      guard let item = model.selectedItem else {
        return
      }
      openInBrowserAndHideHistory(item)
    case .editItem:
      guard let item = model.selectedItem else {
        return
      }
      editItem(item)
    case .renameItem:
      guard let item = model.selectedItem else {
        return
      }
      showRenameDialog(for: item)
    case .transformItem:
      guard let item = model.selectedItem else {
        return
      }
      showTransformCommandPalette(for: item)
    case .toggleSensitiveContentVisibility:
      guard let item = model.selectedItem else {
        return
      }
      toggleSensitiveContentVisibility(of: item)
    case .focusSearchField:
      focusSearchField()
    case .openSettings:
      coordinator.openSettings()
    case .showCommandPalette:
      showCommandPalette()
    case .showInHistory:
      guard let item = model.selectedItem else {
        return
      }
      showInHistory(item)
    case .togglePreviewPane:
      togglePreviewPane()
    case .toggleDetails:
      toggleDetails()
    }
  }

  /// The Trash only lets items be put back or deleted for good. The paste
  /// shortcuts put the selected items back, the delete shortcut deletes them
  /// for good, and the shortcuts that use or change items do nothing. Returns
  /// false for the shortcuts that work the same as in the history.
  private func performTrashShortcutAction(_ action: HistoryShortcutAction) -> Bool {
    switch action {
    case .pasteSelected, .pasteSelectedSecondary:
      coordinator.putBack(model.selectedItems)
      return true
    case .deleteItem:
      coordinator.deleteImmediately(model.selectedItems)
      return true
    case .pasteAndDeleteSelected, .pasteAndDeleteSelectedSecondary, .copySelected, .copySelectedSecondary,
         .toggleFavorite, .showInFinder, .openInBrowser, .editItem, .renameItem, .transformItem, .showInHistory:
      return true
    case .closeHistory, .selectNextItem, .selectPreviousItem, .toggleSensitiveContentVisibility,
         .focusSearchField, .openSettings, .showCommandPalette, .togglePreviewPane, .toggleDetails:
      return false
    }
  }

  private func focusSearchField() {
    historyToolbar?.focusSearchField()
  }

  /// Moving up past the first item hands focus back to the search field, so the
  /// keyboard can leave the list the same way Down entered it.
  private func selectPreviousItemOrFocusSearchField() {
    guard !listPaneView.moveSelection(.up) else {
      return
    }

    guard isHistoryListFocused(view.window?.firstResponder) else {
      return
    }

    focusSearchField()
  }

  private func quickNumberIndex(for event: NSEvent) -> Int? {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    guard modifiers == .command,
          let character = event.charactersIgnoringModifiers?.first,
          let digit = character.wholeNumberValue,
          (1...9).contains(digit) else {
      return nil
    }

    return digit
  }

  private func isPlainTextShortcut(_ shortcut: String) -> Bool {
    let parts = shortcut.lowercased().split(separator: "+").map(String.init)
    guard parts.count == 1, let key = parts.first else {
      return false
    }

    return key.count == 1 || key == "space"
  }

  private func pasteSelectedItemFromShortcut() {
    coordinator.pasteSelection()
  }

  private func pasteSelectedItemWithSecondaryActionFromShortcut() {
    // Several items have no secondary paste variant of their own, so the
    // shortcut asks which key to press between them for this one paste.
    let selectedItems = model.selectedItems
    if selectedItems.count > 1 {
      showPasteInterItemActionCommandPalette(for: selectedItems)
      return
    }

    guard let item = model.selectedItem,
          let variant = item.kind.selectedSecondaryShortcutVariant(preferences: model.preferences) else {
      return
    }

    coordinator.paste(item, variant: variant)
  }

  private func pasteAndDeleteSelectedItemWithSecondaryActionFromShortcut() {
    guard let item = model.selectedItem,
          canPasteAndDelete(item),
          let variant = item.kind.selectedSecondaryShortcutVariant(preferences: model.preferences) else {
      return
    }

    coordinator.pasteAndDelete([item], variant: variant)
  }

  private func copySelectedItemFromShortcut() {
    let selectedItems = model.selectedItems
    if selectedItems.count > 1 {
      guard coordinator.canMerge(selectedItems) else {
        return
      }
      copyMergedSelection()
      return
    }

    guard let item = selectedItems.first ?? model.selectedItem else {
      return
    }

    copy(item, variant: item.kind.selectedCopyShortcutVariant(preferences: model.preferences))
  }

  private func copySelectedItemWithSecondaryActionFromShortcut() {
    guard let item = model.selectedItem,
          let variant = item.kind.selectedSecondaryCopyShortcutVariant(preferences: model.preferences) else {
      return
    }

    copy(item, variant: variant)
  }

  @discardableResult
  private func copy(_ item: ClipboardItem, variant: PasteVariant = .standard) -> Bool {
    let didCopy = coordinator.copy(item, variant: variant)
    showCopySuccessIndicatorIfNeeded(didCopy)
    return didCopy
  }

  @discardableResult
  private func copyPlainText(_ item: ClipboardItem) -> Bool {
    let didCopy = coordinator.copyPlainText(item)
    showCopySuccessIndicatorIfNeeded(didCopy)
    return didCopy
  }

  @discardableResult
  private func copyText(_ text: String) -> Bool {
    let didCopy = coordinator.copyText(text)
    showCopySuccessIndicatorIfNeeded(didCopy)
    return didCopy
  }

  @discardableResult
  private func copyMergedSelection() -> Bool {
    let didCopy = coordinator.copyMergedSelection()
    showCopySuccessIndicatorIfNeeded(didCopy)
    return didCopy
  }

  @discardableResult
  private func copyMerged(_ items: [ClipboardItem]) -> Bool {
    let didCopy = coordinator.copyMerged(items)
    showCopySuccessIndicatorIfNeeded(didCopy)
    return didCopy
  }

  private func showCopySuccessIndicatorIfNeeded(_ didCopy: Bool) {
    guard didCopy else {
      return
    }

    historyToolbar?.showCopySuccessIndicator()
  }

  private func openInBrowserAndHideHistory(_ item: ClipboardItem) {
    guard item.browserURL != nil else {
      return
    }

    coordinator.openInBrowser(item)
    coordinator.hideHistoryPanel()
  }

  @objc func pasteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.paste(item)
  }

  @objc func pasteAndDeleteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.pasteAndDelete([item], variant: .standard)
  }

  @objc func pastePlainTextAndDeleteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.pasteAndDelete([item], variant: .plainText)
  }

  @objc func pasteFilePathAndDeleteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.pasteAndDelete([item], variant: .filePath)
  }

  @objc func pastePlainTextMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.paste(item, variant: .plainText)
  }

  @objc func pasteFilePathMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.paste(item, variant: .filePath)
  }

  @objc func copyMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    copy(item)
  }

  @objc func copyFilePathMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    copy(item, variant: .filePath)
  }

  @objc func copyPlainTextMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    copyPlainText(item)
  }

  @objc func favoriteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.toggleFavorite(item)
  }

  @objc func sensitiveMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    toggleSensitive(item)
  }

  @objc func sensitiveContentVisibilityMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    toggleSensitiveContentVisibility(of: item)
  }

  func hidesSensitiveContent(of item: ClipboardItem) -> Bool {
    isSensitiveContentMasked(in: item) && !listPaneView.revealsSensitiveContent(of: item)
  }

  func isSensitiveContentMasked(in item: ClipboardItem) -> Bool {
    SensitiveContent.isMasked(item, detectsAutomatically: model.preferences.detectSensitiveContent)
  }

  // An item with content to hide, marked by the user or found by the app, becomes one
  // the user wants shown, and any other item becomes one the user wants hidden.
  private func toggleSensitive(_ item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    let isSensitive = !isSensitiveContentMasked(in: item)
    listPaneView.setRevealsSensitiveContent(false, of: item)
    coordinator.setSensitive(isSensitive, for: item)
  }

  private func toggleSensitiveContentVisibility(of item: ClipboardItem) {
    guard isSensitiveContentMasked(in: item) else {
      return
    }

    let reveals = !listPaneView.revealsSensitiveContent(of: item)
    listPaneView.setRevealsSensitiveContent(reveals, of: item)
    setNeedsPreviewPaneUpdate()

    guard let previewSheetController, previewSheetWindow != nil,
          previewSheetController.item.id == item.id else {
      return
    }
    previewSheetController.update(item: previewSheetController.item, revealsSensitiveContent: reveals)
  }

  @objc func applyTransformMenuItem(_ sender: NSMenuItem) {
    guard let selection = sender.representedObject as? HistoryTransformMenuSelection else {
      return
    }

    coordinator.transform(selection.item, using: selection.transform)
  }

  @objc func splitMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }

    coordinator.split(item)
  }

  @objc func renameMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }

    showRenameDialog(for: item)
  }

  @objc func editMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }

    editItem(item)
  }

  @objc func copyTextFromImageMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    copyTextFromImage(item)
  }

  @objc func copyTextFromQRCodeMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    copyTextFromQRCode(item)
  }

  @objc func saveImageAsFileMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    showSaveImageAsFilePanel(for: item)
  }

  @objc func openInBrowserMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    openInBrowserAndHideHistory(item)
  }

  @objc func updateLinkMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.updateLink(item)
  }

  @objc func toggleTagMenuItem(_ sender: NSMenuItem) {
    guard let selection = sender.representedObject as? HistoryTagMenuSelection else {
      return
    }
    coordinator.toggleTag(selection.tag, for: selection.item)
  }

  @objc func applyTagMenuItem(_ sender: NSMenuItem) {
    guard let selection = sender.representedObject as? HistoryMultiTagMenuSelection else {
      return
    }

    let tagID = selection.tag.id
    let allItemsHaveTag = selection.items.allSatisfy { $0.tags.contains(tagID) }

    if allItemsHaveTag {
      for item in selection.items where item.tags.contains(tagID) {
        coordinator.toggleTag(selection.tag, for: item)
      }
      return
    }

    for item in selection.items where !item.tags.contains(tagID) {
      coordinator.addTag(selection.tag, to: item)
    }
  }

  @objc func newTagMenuItem(_ sender: NSMenuItem) {
    if let item = sender.representedObject as? ClipboardItem {
      showNewTagSheet(for: [item])
      return
    }

    guard let items = sender.representedObject as? [ClipboardItem], !items.isEmpty else {
      return
    }

    showNewTagSheet(for: items)
  }

  @objc func editTagsMenuItem(_ sender: NSMenuItem) {
    coordinator.openSettings(section: .tags)
  }

  @objc func runContextMenuCommandItem(_ sender: NSMenuItem) {
    guard let action = sender.representedObject as? HistoryMenuCommandAction else {
      return
    }

    action.run()
  }

  private func showNewTagSheet(for items: [ClipboardItem]) {
    guard !items.isEmpty else {
      return
    }

    guard let window = view.window else {
      return
    }

    let sheetController = NewTagDialog()
    let sheetWindow = NSWindow(contentViewController: sheetController)
    sheetWindow.styleMask = [.titled]
    sheetWindow.titleVisibility = .hidden
    sheetWindow.titlebarAppearsTransparent = true
    sheetWindow.backgroundColor = .windowBackgroundColor
    sheetWindow.isReleasedWhenClosed = false

    isNewTagSheetPresented = true
    sheetController.onCancel = { [weak self, weak sheetWindow] in
      guard let self, let sheetWindow else {
        return
      }
      window.endSheet(sheetWindow)
      self.isNewTagSheetPresented = false
    }
    sheetController.onCreate = { [weak self, weak sheetWindow] tagName, color in
      guard let self, let sheetWindow else {
        return
      }

      if let existingTag = self.model.availableTags.first(where: { $0.name.localizedCaseInsensitiveCompare(tagName) == .orderedSame }) {
        for item in items {
          self.coordinator.addTag(existingTag, to: item)
        }
      } else {
        guard let firstItem = items.first else {
          window.endSheet(sheetWindow)
          self.isNewTagSheetPresented = false
          return
        }

        self.coordinator.createTag(name: tagName, color: color, for: firstItem)
        guard let createdTag = self.model.availableTags.first(where: { $0.name.localizedCaseInsensitiveCompare(tagName) == .orderedSame }) else {
          window.endSheet(sheetWindow)
          self.isNewTagSheetPresented = false
          return
        }

        for item in items.dropFirst() {
          self.coordinator.addTag(createdTag, to: item)
        }
      }
      window.endSheet(sheetWindow)
      self.isNewTagSheetPresented = false
    }

    window.beginSheet(sheetWindow) { [weak self] _ in
      self?.isNewTagSheetPresented = false
    }
  }

  @objc func previewMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    showPreview(for: item)
  }

  @objc func showInHistoryMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    showInHistory(item)
  }

  @objc func showInFinderMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.showInFinder(item)
  }

  @objc func openInAssociatedApplicationMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.openInAssociatedApplication(item)
  }

  @objc func openWithMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }

    showOpenWithCommandPalette(for: item)
  }

  @objc func deleteMenuItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? ClipboardItem else {
      return
    }
    coordinator.delete(item)
  }
}

extension HistoryContentViewController: HistoryDelegate {
  func listPane(_ pane: History, didSelectItems items: [ClipboardItem], focusedItem: ClipboardItem?) {
    let selectedItemIDs = Set(items.map(\.id))
    let selectedItemIDsInSelectionOrder = items.map(\.id)
    let selectedItemID = focusedItem?.id

    if model.selectedItemIDs != selectedItemIDs {
      selectionModelUpdatesOriginatingFromList += 1
      model.selectedItemIDs = selectedItemIDs
    }
    if model.selectedItemIDsInSelectionOrder != selectedItemIDsInSelectionOrder {
      model.selectedItemIDsInSelectionOrder = selectedItemIDsInSelectionOrder
    }
    if model.selectedItemID != selectedItemID {
      selectionModelUpdatesOriginatingFromList += 1
      model.selectedItemID = selectedItemID
    }
    updateToolbarState()
    updatePreviewSheet(for: focusedItem ?? items.first)
    setNeedsPreviewPaneUpdate()
  }

  func listPane(_ pane: History, didClickItem item: ClipboardItem) {
    guard model.preferences.pasteOnClick, !coordinator.isHistoryReadOnly, !model.isShowingTrash else {
      return
    }

    coordinator.paste(item, variant: item.kind.selectedShortcutVariant(preferences: model.preferences))
  }

  func listPane(_ pane: History, didDoubleClickItem item: ClipboardItem) {
    performDoubleClickAction(for: item)
  }

  func listPane(_ pane: History, didReceiveSearchKeyDown event: NSEvent) {
    historyToolbar?.focusSearchFieldAndHandleKeyDown(with: event)
  }

  func listPane(_ pane: History, actionsMenuFor selectedItems: [ClipboardItem], focusedItem: ClipboardItem?) -> NSMenu {
    if model.isShowingTrash {
      let items = selectedItems.count > 1 ? selectedItems : [focusedItem ?? selectedItems.first].compactMap { $0 }
      return makeTrashContextMenu(for: items)
    }

    guard selectedItems.count > 1 else {
      guard let item = focusedItem ?? selectedItems.first else {
        return NSMenu()
      }
      return makeItemContextMenu(for: item)
    }

    return makeMultipleSelectionContextMenu(for: selectedItems)
  }

  /// The commands of the Trash as a menu, Settings and Empty Trash aside.
  private func makeTrashContextMenu(for items: [ClipboardItem]) -> NSMenu {
    let menu = NSMenu()
    guard !items.isEmpty else {
      return menu
    }

    var previousSection: Int?
    for command in trashItemCommands(for: items) {
      if let previousSection, previousSection != command.section {
        menu.addItem(.separator())
      }
      menu.addItem(makeContextMenuItem(for: command))
      previousSection = command.section
    }
    menu.showsItemImagesRegardlessOfSystemSetting()
    return menu
  }

  func makeItemContextMenu(for item: ClipboardItem) -> NSMenu {
    HistoryItemContextMenu(
      target: self,
      availableTags: model.availableTags,
      preferences: model.preferences
    ).makeMenu(for: item)
  }

  func listPane(_ pane: History, shouldLoadLinkPreviewFor item: ClipboardItem) {
    // A preview loaded for an item in the Trash would not be saved.
    guard !model.isShowingTrash else {
      return
    }

    coordinator.loadLinkPreviewIfNeeded(for: item)
  }

  func listPane(_ pane: History, didChangeMultipleSelectionWith change: HistoryMultipleSelectionChange) {
    switch change {
    case .added:
      coordinator.playSound(.selectionAdd)
    case .removed:
      coordinator.playSound(.selectionRemove)
    }
  }

  func listPane(_ pane: History, moveFavorites itemIDs: [UUID], before targetItemID: UUID?) {
    coordinator.moveFavorites(itemIDs, before: targetItemID)
  }

  func listPane(_ pane: History, didRequestTogglingSensitiveContentVisibilityOf item: ClipboardItem) {
    toggleSensitiveContentVisibility(of: item)
  }
}

extension HistoryContentViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard let action = menuItem.action else {
      return true
    }

    return isMenuActionAvailable(action, representedObject: menuItem.representedObject)
  }
}

extension HistoryContentViewController: HistoryToolbarDelegate {
  func historyToolbar(_ toolbar: HistoryToolbar, didChangeSearchQuery query: String) {
    scheduleSearchQueryUpdate(query)
  }

  func historyToolbar(_ toolbar: HistoryToolbar, didRequestMoveSelection direction: HistorySelectionDirection) {
    listPaneView.moveSelection(direction)
    listPaneView.focusTableView()
  }

  func historyToolbar(_ toolbar: HistoryToolbar, didSelectSortOption sortOption: HistorySortOption) {
    model.historySortOption = sortOption
    model.preferences.historySortOption = sortOption.rawValue
    coordinator.persistPreferences()
  }

  func historyToolbar(
    _ toolbar: HistoryToolbar,
    didSetFilterContentType contentType: HistoryFilterContentType,
    isSelected: Bool
  ) {
    setHistoryFilterContentType(contentType, isSelected: isSelected)
  }

  func historyToolbar(_ toolbar: HistoryToolbar, didSetFilterTagID tagID: Tag.ID, isSelected: Bool) {
    setHistoryFilterTagID(tagID, isSelected: isSelected)
  }

  func historyToolbar(
    _ toolbar: HistoryToolbar,
    didSetFilterSourceApplicationID sourceApplicationID: HistorySourceApplication.ID,
    isSelected: Bool
  ) {
    setHistoryFilterSourceApplicationID(sourceApplicationID, isSelected: isSelected)
  }

  func historyToolbar(_ toolbar: HistoryToolbar, didRequestClearFilterGroup group: SearchTokenGroup) {
    clearHistoryFilterGroup(group)
  }

  func historyToolbarDidRequestClearFilters(_ toolbar: HistoryToolbar) {
    clearHistoryFilters()
  }

  func historyToolbarDidRequestToggleSortOrder(_ toolbar: HistoryToolbar) {
    model.isHistorySortReversed.toggle()
    model.preferences.isHistorySortReversed = model.isHistorySortReversed
    coordinator.persistPreferences()
  }

  func historyToolbarDidRequestPaste(_ toolbar: HistoryToolbar) {
    guard !model.isShowingTrash else {
      coordinator.putBack(model.selectedItems)
      return
    }

    coordinator.pasteSelection()
  }

  func historyToolbarDidRequestCopy(_ toolbar: HistoryToolbar) {
    let selectedItems = model.selectedItems
    if selectedItems.count > 1 {
      guard coordinator.canMerge(selectedItems) else {
        return
      }
      copyMergedSelection()
      return
    }

    guard let item = selectedItems.first else {
      return
    }

    copy(item)
  }

  func historyToolbarDidRequestCopyTextFromImage(_ toolbar: HistoryToolbar) {
    copyTextFromImage()
  }

  func historyToolbarDidRequestCopyTextFromQRCode(_ toolbar: HistoryToolbar) {
    copyTextFromQRCode()
  }

  func historyToolbarDidRequestOpenInBrowser(_ toolbar: HistoryToolbar) {
    guard let item = model.selectedItem else {
      return
    }
    openInBrowserAndHideHistory(item)
  }

  func historyToolbarDidRequestMergeSelection(_ toolbar: HistoryToolbar) {
    coordinator.mergeSelection()
  }

  func historyToolbarDidRequestTogglePin(_ toolbar: HistoryToolbar) {
    coordinator.toggleHistoryPanelPin()
    updateToolbarState()
  }

  func historyToolbarDidRequestToggleCopySequenceMode(_ toolbar: HistoryToolbar) {
    coordinator.toggleCopySequenceMode()
    reloadList()
  }

  func historyToolbarDidRequestTogglePreviewPane(_ toolbar: HistoryToolbar) {
    togglePreviewPane()
  }

  func historyToolbarDidRequestToggleDetails(_ toolbar: HistoryToolbar) {
    toggleDetails()
  }

  func historyToolbarDidRequestCommandDialog(_ toolbar: HistoryToolbar) {
    showCommandPalette()
  }

  private func showCommandPalette() {
    let isHistoryReadOnly = coordinator.isHistoryReadOnly
    presentCommandPalette(
      commands: makeCommandPaletteCommands().filter { !isHistoryReadOnly || $0.isAvailableInReadOnlyHistory },
      maximumContentSize: NSSize(width: 400, height: 450),
      searchPlaceholderText: L10n.string("Search for actions...")
    )
  }

  private func makeMultipleSelectionContextMenu(for items: [ClipboardItem]) -> NSMenu {
    let preferences = model.preferences
    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)
    let pasteAndDeleteTitle = L10n.string("Paste %d Items to %@ & Delete", items.count, appName)
    let commands = multipleSelectionCommandPaletteCommands(
      for: items,
      appName: appName,
      appIcon: appIcon,
      preferences: preferences
    ).filter { command in
      command.title != L10n.string("Delete All")
        && command.title != pasteAndDeleteTitle
        && command.title != L10n.string("Settings...")
        && !command.showsOnlyWhenSearching
    }

    let menu = NSMenu()
    var previousSection: Int?
    var insertedTags = false
    for command in commands {
      if let previousSection, previousSection != command.section {
        if !insertedTags {
          menu.addItem(.separator())
          menu.addItem(makeMultipleSelectionTagsMenuItem(for: items))
          insertedTags = true
        }
        menu.addItem(.separator())
      }
      menu.addItem(makeContextMenuItem(for: command))
      previousSection = command.section
    }

    if !insertedTags {
      if !menu.items.isEmpty {
        menu.addItem(.separator())
      }
      menu.addItem(makeMultipleSelectionTagsMenuItem(for: items))
    }

    if canPasteAndDelete(items), let pasteItem = menu.items.first {
      let pasteAndDeleteItem = HistoryItemContextMenu.makePasteAndDeleteMenuItem(
        title: pasteAndDeleteTitle,
        after: pasteItem,
        shortcut: preferences.pasteAndDeleteSelectedShortcut
      )
      pasteAndDeleteItem.action = #selector(runContextMenuCommandItem(_:))
      pasteAndDeleteItem.target = self
      pasteAndDeleteItem.representedObject = HistoryMenuCommandAction { [weak self] in
        self?.coordinator.pasteAndDelete(items)
      }
      menu.insertItem(pasteAndDeleteItem, at: 1)
    }

    menu.showsItemImagesRegardlessOfSystemSetting()
    return menu
  }

  private func makeContextMenuItem(for command: CommandPaletteCommand) -> NSMenuItem {
    let menuItem = NSMenuItem(
      title: command.title,
      action: #selector(runContextMenuCommandItem(_:)),
      keyEquivalent: ""
    )
    HistoryItemContextMenu.applyShortcut(command.shortcut, to: menuItem)
    let image = command.image
      ?? NSImage(systemSymbolName: command.systemImageName, accessibilityDescription: command.title)
    menuItem.image = command.isDestructive
      ? image?.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemRed)) ?? image
      : image
    if command.isDestructive {
      menuItem.attributedTitle = NSAttributedString(
        string: command.title,
        attributes: [.foregroundColor: NSColor.systemRed]
      )
    }
    menuItem.target = self
    menuItem.representedObject = HistoryMenuCommandAction(
      isAvailableInReadOnlyHistory: command.isAvailableInReadOnlyHistory,
      run: command.action
    )
    return menuItem
  }

  private func makeMultipleSelectionTagsMenuItem(for items: [ClipboardItem]) -> NSMenuItem {
    let menuItem = NSMenuItem(title: L10n.string("Tags..."), action: nil, keyEquivalent: "")
    menuItem.image = NSImage(systemSymbolName: "circle", accessibilityDescription: L10n.string("Tags"))

    let submenu = NSMenu()
    let selectedTagIDsByItemID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, Set($0.tags)) })
    for tag in model.availableTags {
      let tagItem = NSMenuItem(title: tag.name, action: #selector(applyTagMenuItem(_:)), keyEquivalent: "")
      tagItem.target = self
      tagItem.image = NSImage.tagMenuIcon(color: NSColor(tagHexString: tag.color))
      let appliedCount = selectedTagIDsByItemID.values.reduce(0) { partialResult, tagIDs in
        tagIDs.contains(tag.id) ? partialResult + 1 : partialResult
      }
      if appliedCount == items.count {
        tagItem.state = .on
      } else if appliedCount > 0 {
        tagItem.state = .mixed
      } else {
        tagItem.state = .off
      }
      tagItem.representedObject = HistoryMultiTagMenuSelection(items: items, tag: tag)
      submenu.addItem(tagItem)
    }

    if !model.availableTags.isEmpty {
      submenu.addItem(.separator())
    }

    let newTagItem = NSMenuItem(title: L10n.string("New Tag..."), action: #selector(newTagMenuItem(_:)), keyEquivalent: "")
    newTagItem.target = self
    newTagItem.image = NSImage(systemSymbolName: "plus", accessibilityDescription: L10n.string("New Tag"))
    newTagItem.representedObject = items
    submenu.addItem(newTagItem)

    menuItem.submenu = submenu
    return menuItem
  }

  private func makeCommandPaletteCommands() -> [CommandPaletteCommand] {
    let preferences = model.preferences
    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)
    let selectedItems = model.selectedItems
    if model.isShowingTrash {
      return trashItemCommands(for: selectedItems) + [
        settingsCommand(section: 2, shortcut: preferences.openSettingsShortcut),
        emptyTrashCommand(section: 3)
      ]
    }

    if selectedItems.count > 1 {
      return multipleSelectionCommandPaletteCommands(
        for: selectedItems,
        appName: appName,
        appIcon: appIcon,
        preferences: preferences
      )
    }

    guard let item = model.selectedItem ?? selectedItems.first else {
      return [
        settingsCommand(section: 0, shortcut: preferences.openSettingsShortcut),
        deleteAllCommand(section: 1)
      ]
    }

    if item.isMissingSingleFileItem {
      return missingFileCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    }

    if item.isMultipleFileItem {
      return multipleFilesItemCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    }

    switch item.kind {
    case .text, .richText:
      return textCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    case .file:
      return fileCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    case .image:
      return imageCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    case .link:
      return linkCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    default:
      return textCommandPaletteCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
    }
  }

  private func multipleSelectionCommandPaletteCommands(
    for items: [ClipboardItem],
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    var commands = pasteMultipleItemsCommands(
      items,
      appName: appName,
      appIcon: appIcon,
      shortcut: preferences.pasteSelectedShortcut,
      section: 0
    ) + [
      pasteMultipleItemsWithActionCommand(
        items,
        appName: appName,
        appIcon: appIcon,
        shortcut: preferences.pasteSelectedSecondaryShortcut,
        section: 0
      )
    ] + pasteMultipleItemsWithKeyCommands(items, appIcon: appIcon, section: 0)
    if coordinator.canMerge(items) {
      commands.append(copyMultipleItemsCommand(items, shortcut: preferences.copySelectedShortcut, section: 0))
      commands.append(mergeMultipleItemsCommand(items, section: 0))
    }
    commands.append(contentsOf: [
      favoriteMultipleItemsCommand(
        items,
        shortcut: preferences.toggleFavoriteShortcut,
        section: 1
      ),
      settingsCommand(section: 3, shortcut: preferences.openSettingsShortcut),
      deleteMultipleItemsCommand(items, shortcut: preferences.deleteItemShortcut, section: 4),
      deleteAllCommand(section: 4)
    ])
    return commands
  }

  private func textCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    let pasteAndCopyCommands = item.kind == .richText
      ? richTextPasteAndCopyCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)
      : plainTextPasteAndCopyCommands(for: item, appName: appName, appIcon: appIcon, preferences: preferences)

    var itemCommands = [
      editCommand(for: item, shortcut: preferences.editItemShortcut, section: 1),
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 1),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 1),
      transformCommand(for: item, shortcut: preferences.transformItemShortcut, section: 1)
    ]
    itemCommands.append(contentsOf: sensitiveContentCommands(
      for: item,
      shortcut: preferences.toggleSensitiveContentShortcut,
      section: 1
    ))
    if coordinator.canSplit(item) {
      itemCommands.append(splitCommand(for: item, section: 1))
    }
    itemCommands.append(contentsOf: previewCommands(for: item, section: 1))

    return pasteAndCopyCommands + itemCommands + [
      settingsCommand(section: 3, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 4),
      deleteAllCommand(section: 4)
    ]
  }

  // A plain text item has no formatting to strip, so the "as plain text"
  // variants would only duplicate the regular paste and copy commands.
  private func plainTextPasteAndCopyCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    pasteCommandPair(
      title: L10n.string("Paste to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste to %@ & Delete", appName),
      shortcut: preferences.pasteSelectedShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .standard
    ) { [weak self] in
      self?.coordinator.paste(item)
    } + [
      command(
        title: L10n.string("Copy to Clipboard"),
        shortcut: preferences.copySelectedShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item)
      }
    ]
  }

  // Rich text can be pasted either with its formatting or as plain text, so
  // both variants are listed, the preferred one first and on the primary
  // shortcut.
  private func richTextPasteAndCopyCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    let plainTextPasteCommands = pasteCommandPair(
      title: L10n.string("Paste as Plain Text to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste as Plain Text to %@ & Delete", appName),
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.pasteSelectedShortcut
        : preferences.pasteSelectedSecondaryShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .plainText
    ) { [weak self] in
      self?.coordinator.paste(item, variant: .plainText)
    }
    let standardPasteCommands = pasteCommandPair(
      title: L10n.string("Paste to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste to %@ & Delete", appName),
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.pasteSelectedSecondaryShortcut
        : preferences.pasteSelectedShortcut,
      systemImageName: "textformat",
      image: appIcon,
      section: 0,
      items: [item],
      variant: .standard
    ) { [weak self] in
      self?.coordinator.paste(item)
    }
    let pasteCommands = preferences.preferPastingAsPlainText
      ? plainTextPasteCommands + standardPasteCommands
      : standardPasteCommands + plainTextPasteCommands
    let plainTextCopyCommand = command(
      title: L10n.string("Copy as Plain Text to Clipboard"),
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.copySelectedShortcut
        : preferences.copySelectedSecondaryShortcut,
      systemImageName: "square.on.square",
      section: 0
    ) { [weak self] in
      self?.copyPlainText(item)
    }
    let standardCopyCommand = command(
      title: L10n.string("Copy to Clipboard"),
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.copySelectedSecondaryShortcut
        : preferences.copySelectedShortcut,
      systemImageName: "square.on.square",
      section: 0
    ) { [weak self] in
      self?.copy(item)
    }
    let copyCommands = preferences.preferPastingAsPlainText
      ? [plainTextCopyCommand, standardCopyCommand]
      : [standardCopyCommand, plainTextCopyCommand]
    return pasteCommands + copyCommands
  }

  private func fileCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    pasteCommandPair(
      title: L10n.string("Paste to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste to %@ & Delete", appName),
      shortcut: preferences.pasteSelectedShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .standard
    ) { [weak self] in
      self?.coordinator.paste(item)
    } + pasteCommandPair(
      title: L10n.string("Paste Path to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste Path to %@ & Delete", appName),
      shortcut: preferences.pasteSelectedSecondaryShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .filePath
    ) { [weak self] in
      self?.coordinator.paste(item, variant: .filePath)
    } + [
      command(
        title: L10n.string("Copy to Clipboard"),
        shortcut: preferences.copySelectedShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item)
      },
      command(
        title: L10n.string("Copy Path to Clipboard"),
        shortcut: preferences.copySelectedSecondaryShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item, variant: .filePath)
      }
    ] + copyTextFromImageCommands(for: item, section: 1)
      + copyTextFromQRCodeCommands(for: item, section: 1) + [
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 1),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 1)
    ] + previewCommands(for: item, section: 1) + [
      showInFinderCommand(for: item, shortcut: preferences.showInFinderShortcut, section: 2),
      openInAssociatedApplicationCommand(for: item, section: 2),
      openWithCommand(for: item, section: 2),
      settingsCommand(section: 4, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 5),
      deleteAllCommand(section: 5)
    ]
  }

  private func missingFileCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    [
      command(
        title: L10n.string("Paste Path to %@", appName),
        shortcut: preferences.pasteSelectedSecondaryShortcut,
        systemImageName: "arrow.turn.down.left",
        image: appIcon,
        section: 0
      ) { [weak self] in
        self?.coordinator.paste(item, variant: .filePath)
      },
      command(
        title: L10n.string("Copy Path to Clipboard"),
        shortcut: preferences.copySelectedSecondaryShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item, variant: .filePath)
      }
    ] + copyTextFromImageCommands(for: item, section: 1)
      + copyTextFromQRCodeCommands(for: item, section: 1) + [
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 1),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 1)
    ] + previewCommands(for: item, section: 1) + [
      settingsCommand(section: 3, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 4),
      deleteAllCommand(section: 4)
    ]
  }

  private func multipleFilesItemCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    pasteCommandPair(
      title: L10n.string("Paste %d Items to %@", item.filePaths.count, appName),
      pasteAndDeleteTitle: L10n.string("Paste %d Items to %@ & Delete", item.filePaths.count, appName),
      shortcut: preferences.pasteSelectedShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .standard
    ) { [weak self] in
      self?.coordinator.paste(item)
    } + [
      command(
        title: L10n.string("Copy %d Items to Clipboard", item.filePaths.count),
        shortcut: preferences.copySelectedShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item)
      },
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 1),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 1)
    ] + previewCommands(for: item, section: 1) + [
      settingsCommand(section: 3, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 4),
      deleteAllCommand(section: 4)
    ]
  }

  private func imageCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    pasteCommandPair(
      title: L10n.string("Paste to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste to %@ & Delete", appName),
      shortcut: preferences.pasteSelectedShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .standard
    ) { [weak self] in
      self?.coordinator.paste(item)
    } + [
      command(
        title: L10n.string("Copy to Clipboard"),
        shortcut: preferences.copySelectedShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item)
      }
    ] + copyTextFromImageCommands(for: item, section: 1)
      + copyTextFromQRCodeCommands(for: item, section: 1) + [
      saveImageAsFileCommand(for: item, section: 1),
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 1),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 1)
    ] + previewCommands(for: item, section: 1) + [
      openInAssociatedApplicationCommand(for: item, section: 2),
      openWithCommand(for: item, section: 2),
      settingsCommand(section: 4, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 5),
      deleteAllCommand(section: 5)
    ]
  }

  private func linkCommandPaletteCommands(
    for item: ClipboardItem,
    appName: String,
    appIcon: NSImage,
    preferences: AppPreferences
  ) -> [CommandPaletteCommand] {
    // A link has no formatting to strip, so a separate "as plain text" copy
    // would only duplicate the regular one, as the context menu shows.
    let copyCommands = [
      command(
        title: L10n.string("Copy to Clipboard"),
        shortcut: preferences.copySelectedShortcut,
        systemImageName: "square.on.square",
        section: 0
      ) { [weak self] in
        self?.copy(item)
      }
    ]
    var linkCommands: [CommandPaletteCommand] = [
      command(
        title: "Open in Browser",
        shortcut: preferences.openInBrowserShortcut,
        systemImageName: "safari",
        section: 1
      ) { [weak self] in
        self?.openInBrowserAndHideHistory(item)
      }
    ]
    if preferences.showPreviewForLinks {
      linkCommands.append(
        command(
          title: L10n.string("Update Link Preview"),
          shortcut: nil,
          systemImageName: "arrow.clockwise",
          section: 1
        ) { [weak self] in
          self?.coordinator.updateLink(item)
        }
      )
    }

    return pasteCommandPair(
      title: L10n.string("Paste to %@", appName),
      pasteAndDeleteTitle: L10n.string("Paste to %@ & Delete", appName),
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.pasteSelectedShortcut
        : preferences.pasteSelectedSecondaryShortcut,
      image: appIcon,
      section: 0,
      items: [item],
      variant: .plainText
    ) { [weak self] in
      self?.coordinator.paste(item, variant: .plainText)
    } + copyCommands + linkCommands + [
      editCommand(for: item, shortcut: preferences.editItemShortcut, section: 2),
      favoriteCommand(for: item, shortcut: preferences.toggleFavoriteShortcut, section: 2),
      renameCommand(for: item, shortcut: preferences.renameItemShortcut, section: 2),
      transformCommand(for: item, shortcut: preferences.transformItemShortcut, section: 2)
    ] + sensitiveContentCommands(
      for: item,
      shortcut: preferences.toggleSensitiveContentShortcut,
      section: 2
    ) + previewCommands(for: item, section: 2) + [
      settingsCommand(section: 4, shortcut: preferences.openSettingsShortcut),
      deleteCommand(for: item, shortcut: preferences.deleteItemShortcut, section: 5),
      deleteAllCommand(section: 5)
    ]
  }

  private func command(
    title: String,
    description: String? = nil,
    shortcut: String?,
    systemImageName: String,
    image: NSImage? = nil,
    showsIcon: Bool = true,
    sectionTitle: String? = nil,
    section: Int,
    isDestructive: Bool = false,
    isChecked: Bool = false,
    showsOnlyWhenSearching: Bool = false,
    isAvailableInReadOnlyHistory: Bool = false,
    alternateAction: (() -> Void)? = nil,
    action: @escaping () -> Void
  ) -> CommandPaletteCommand {
    CommandPaletteCommand(
      title: L10n.string(forKey: title),
      description: description.map { L10n.string(forKey: $0) },
      shortcut: shortcut,
      image: image,
      systemImageName: systemImageName,
      showsIcon: showsIcon,
      sectionTitle: sectionTitle.map { L10n.string(forKey: $0) },
      section: section,
      isDestructive: isDestructive,
      isChecked: isChecked,
      showsOnlyWhenSearching: showsOnlyWhenSearching,
      isAvailableInReadOnlyHistory: isAvailableInReadOnlyHistory,
      action: action,
      alternateAction: alternateAction
    )
  }

  private func pasteMultipleItemsCommands(
    _ items: [ClipboardItem],
    appName: String,
    appIcon: NSImage,
    shortcut: String?,
    section: Int
  ) -> [CommandPaletteCommand] {
    // The description names the key from the settings, so it is clear what the
    // paste shortcut is about to do without opening the settings.
    let key = coordinator.defaultMultiPasteKey
    return pasteCommandPair(
      title: L10n.string("Paste %d Items to %@", items.count, appName),
      pasteAndDeleteTitle: L10n.string("Paste %d Items to %@ & Delete", items.count, appName),
      description: key == .none ? nil : L10n.string("Presses %@ between items.", key.title),
      shortcut: shortcut,
      image: appIcon,
      section: section,
      items: items,
      variant: nil
    ) { [weak self] in
      self?.pasteMultipleItems(items, interItemAction: nil)
    }
  }

  private func pasteMultipleItemsWithActionCommand(
    _ items: [ClipboardItem],
    appName: String,
    appIcon: NSImage,
    shortcut: String?,
    section: Int
  ) -> CommandPaletteCommand {
    command(
      title: L10n.string("Paste %d Items with Another Key Between...", items.count),
      shortcut: shortcut,
      systemImageName: "arrow.turn.down.left",
      image: appIcon,
      section: section
    ) { [weak self] in
      self?.showPasteInterItemActionCommandPalette(for: items)
    }
  }

  /// One command per key, found by typing the key name, so a one-off key does
  /// not need the second palette.
  private func pasteMultipleItemsWithKeyCommands(
    _ items: [ClipboardItem],
    appIcon: NSImage,
    section: Int
  ) -> [CommandPaletteCommand] {
    let defaultKey = coordinator.defaultMultiPasteKey
    return PasteInterItemAction.allCases.filter { $0 != defaultKey }.map { key in
      command(
        title: L10n.string("Paste %d Items with %@ Between", items.count, key.title),
        shortcut: nil,
        systemImageName: "arrow.turn.down.left",
        image: appIcon,
        section: section,
        showsOnlyWhenSearching: true
      ) { [weak self] in
        self?.pasteMultipleItems(items, interItemAction: key)
      }
    }
  }

  /// Without a key the items are pasted with the key from the settings.
  private func pasteMultipleItems(_ items: [ClipboardItem], interItemAction: PasteInterItemAction?) {
    let variants = Dictionary(uniqueKeysWithValues: items.map { item in
      (item.id, item.kind.selectedShortcutVariant(preferences: model.preferences))
    })
    coordinator.paste(items, variants: variants, interItemAction: interItemAction)
  }

  private func showPasteInterItemActionCommandPalette(for items: [ClipboardItem]) {
    guard allowsUsingItems() else {
      return
    }

    closeCommandPalette()
    DispatchQueue.main.async { [weak self] in
      self?.presentCommandPalette(
        commands: self?.makePasteInterItemActionCommandPaletteCommands(for: items) ?? [],
        maximumContentSize: NSSize(width: 360, height: 360),
        searchPlaceholderText: L10n.string("Search for keys..."),
        footerText: L10n.string("↩ Paste    ⌘↩ Paste and Set as Default")
      )
    }
  }

  private func makePasteInterItemActionCommandPaletteCommands(for items: [ClipboardItem]) -> [CommandPaletteCommand] {
    // The key from the settings comes first, so Return right after opening the
    // palette pastes the usual way.
    let defaultKey = coordinator.defaultMultiPasteKey
    let keys = [defaultKey] + PasteInterItemAction.allCases.filter { $0 != defaultKey }
    return keys.map { key in
      command(
        title: key.title,
        shortcut: nil,
        systemImageName: key.systemImageName,
        showsIcon: true,
        sectionTitle: L10n.string("Press Between Items"),
        section: 0,
        isChecked: key == defaultKey,
        alternateAction: { [weak self] in
          self?.coordinator.setDefaultMultiPasteKey(key)
          self?.pasteMultipleItems(items, interItemAction: key)
        }
      ) { [weak self] in
        self?.pasteMultipleItems(items, interItemAction: key)
      }
    }
  }

  private func mergeMultipleItemsCommand(
    _ items: [ClipboardItem],
    section: Int
  ) -> CommandPaletteCommand {
    command(
      title: L10n.string("Merge %d Items", items.count),
      shortcut: nil,
      systemImageName: "arrow.down.and.line.horizontal.and.arrow.up",
      section: section
    ) { [weak self] in
      self?.coordinator.merge(items)
    }
  }

  private func copyMultipleItemsCommand(
    _ items: [ClipboardItem],
    shortcut: String?,
    section: Int
  ) -> CommandPaletteCommand {
    command(
      title: L10n.string("Copy %d Items to Clipboard", items.count),
      shortcut: shortcut,
      systemImageName: "square.on.square",
      section: section
    ) { [weak self] in
      self?.copyMerged(items)
    }
  }

  private func favoriteMultipleItemsCommand(
    _ items: [ClipboardItem],
    shortcut: String?,
    section: Int
  ) -> CommandPaletteCommand {
    let shouldRemoveFromFavorites = items.allSatisfy(\.isFavorite)
    let title = shouldRemoveFromFavorites
      ? L10n.string("Remove %d Items from Favorites", items.count)
      : L10n.string("Add %d Items to Favorites", items.count)
    return command(
      title: title,
      shortcut: shortcut,
      systemImageName: "star",
      section: section,
      isAvailableInReadOnlyHistory: true
    ) { [weak self] in
      self?.coordinator.setFavorite(!shouldRemoveFromFavorites, for: items)
    }
  }

  private func deleteMultipleItemsCommand(
    _ items: [ClipboardItem],
    shortcut: String?,
    section: Int
  ) -> CommandPaletteCommand {
    command(
      title: L10n.string("Delete %d Items", items.count),
      shortcut: shortcut,
      systemImageName: "trash",
      section: section,
      isDestructive: true
    ) { [weak self] in
      self?.coordinator.delete(items)
    }
  }

  private func renameCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    command(title: L10n.string("Rename..."), shortcut: shortcut, systemImageName: "rectangle.and.pencil.and.ellipsis", section: section) { [weak self] in
      self?.showRenameDialog(for: item)
    }
  }

  private func editCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    command(title: "Edit...", shortcut: shortcut, systemImageName: "square.and.pencil", section: section) { [weak self] in
      self?.closeCommandPalette()
      DispatchQueue.main.async { [weak self] in
        self?.editItem(item)
      }
    }
  }

  private func showRenameDialog(for item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    closeCommandPalette()
    guard let window = view.window else {
      model.lastError = L10n.string("Cannot rename this item right now.")
      return
    }

    let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 228, height: 22))
    inputField.stringValue = item.itemTitle ?? ""
    inputField.placeholderString = L10n.string("Item name")
    inputField.lineBreakMode = .byTruncatingTail
    if let cell = inputField.cell as? NSTextFieldCell {
      cell.isScrollable = true
      cell.usesSingleLineMode = true
      cell.wraps = false
      cell.lineBreakMode = .byTruncatingTail
    }

    let alert = NSAlert()
    alert.messageText = L10n.string("Rename Item")
    alert.informativeText = L10n.string("Enter a title for this clipboard history item. Leave it empty to clear the title.")
    alert.addButton(withTitle: L10n.string("Rename"))
    alert.addButton(withTitle: L10n.string("Cancel"))
    alert.accessoryView = inputField
    alert.window.initialFirstResponder = inputField

    alert.beginSheetModal(for: window) { [weak self] response in
      switch response {
      case .alertFirstButtonReturn:
        self?.coordinator.rename(item, title: inputField.stringValue)
      default:
        return
      }
    }
  }

  // Editing happens in the preview sheet: it is presented (or reused, when it
  // is already showing the item) and switched to its edit mode.

















  private func editItem(_ item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    guard item.kind.canEditTextContent else {
      model.lastError = L10n.string("%@ cannot be edited.", item.kind.title)
      return
    }

    closeCommandPalette()
    if let previewSheetController, previewSheetWindow != nil {
      if previewSheetController.item.id != item.id {
        previewSheetController.update(
          item: item,
          revealsSensitiveContent: listPaneView.revealsSensitiveContent(of: item)
        )
      }
      previewSheetController.beginEditing()
      return
    }

    // Presented straight in edit mode, so the regular toolbar never flashes.
    showPreview(for: item, startsInEditMode: true)
    if previewSheetController == nil {
      model.lastError = L10n.string("Cannot edit this item right now.")
    }
  }

  private func copyTextFromImageCommands(for item: ClipboardItem, section: Int) -> [CommandPaletteCommand] {
    guard item.canCopyTextFromImage else {
      return []
    }

    return [command(
      title: copyTextFromImageTitle,
      shortcut: nil,
      systemImageName: copyTextFromImageSystemImageName,
      section: section
    ) { [weak self] in
      self?.copyTextFromImage()
    }]
  }

  private func copyTextFromImage() {
    guard let item = model.selectedItem else {
      return
    }
    copyTextFromImage(item)
  }

  private func copyTextFromQRCodeCommands(for item: ClipboardItem, section: Int) -> [CommandPaletteCommand] {
    guard item.canCopyTextFromQRCode else {
      return []
    }

    return [command(
      title: copyTextFromQRCodeTitle,
      shortcut: nil,
      systemImageName: copyTextFromQRCodeSystemImageName,
      section: section
    ) { [weak self] in
      self?.copyTextFromQRCode()
    }]
  }

  private func copyTextFromQRCode() {
    guard let item = model.selectedItem else {
      return
    }
    copyTextFromQRCode(item)
  }

  private func copyTextFromQRCode(_ item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    guard item.canCopyTextFromQRCode else {
      model.lastError = L10n.string("%@ does not contain a QR code.", item.kind.title)
      return
    }

    guard let text = item.qrCodeText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
      model.lastError = L10n.string("No QR code was found in this image.")
      return
    }

    copyText(text)
  }

  private func copyTextFromImage(_ item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    guard item.canCopyTextFromImage else {
      model.lastError = L10n.string("%@ does not contain image text.", item.kind.title)
      return
    }

    guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
      model.lastError = L10n.string("No text was found in this image.")
      return
    }

    copyText(text)
  }

  private func saveImageAsFileCommand(for item: ClipboardItem, section: Int) -> CommandPaletteCommand {
    command(title: L10n.string("Save as File..."), shortcut: nil, systemImageName: "square.and.arrow.down", section: section) { [weak self] in
      self?.showSaveImageAsFilePanel(for: item)
    }
  }

  private func showSaveImageAsFilePanel(for item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    isModalSheetPresentationPending = true
    closeCommandPalette()

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      guard let window = self.view.window else {
        self.isModalSheetPresentationPending = false
        self.model.lastError = L10n.string("Cannot save this image right now.")
        return
      }

      self.coordinator.saveImageAsFile(item, presenting: window) { [weak self] in
        self?.isModalSheetPresentationPending = false
      }
    }
  }

  private func favoriteCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    let title = item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites")
    return command(
      title: title,
      shortcut: shortcut,
      systemImageName: "star",
      section: section,
      isAvailableInReadOnlyHistory: true
    ) { [weak self] in
      self?.coordinator.toggleFavorite(item)
    }
  }

  private func sensitiveContentCommands(
    for item: ClipboardItem,
    shortcut: String?,
    section: Int
  ) -> [CommandPaletteCommand] {
    guard item.kind.canHoldSensitiveContent else {
      return []
    }

    guard isSensitiveContentMasked(in: item) else {
      return [
        command(
          title: L10n.string("Mark as Sensitive"),
          shortcut: nil,
          systemImageName: "lock",
          section: section
        ) { [weak self] in
          self?.toggleSensitive(item)
        }
      ]
    }

    let hidesContent = hidesSensitiveContent(of: item)
    return [
      command(
        title: hidesContent
          ? L10n.string("Show Sensitive Content")
          : L10n.string("Hide Sensitive Content"),
        shortcut: shortcut,
        systemImageName: hidesContent ? "eye" : "eye.slash",
        section: section,
        isAvailableInReadOnlyHistory: true
      ) { [weak self] in
        self?.toggleSensitiveContentVisibility(of: item)
      },
      command(
        title: L10n.string("Mark as Not Sensitive"),
        shortcut: nil,
        systemImageName: "lock.open",
        section: section
      ) { [weak self] in
        self?.toggleSensitive(item)
      }
    ]
  }

  private func transformCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    command(title: L10n.string("Transform..."), shortcut: shortcut, systemImageName: "wand.and.sparkles", section: section) { [weak self] in
      self?.showTransformCommandPalette(for: item)
    }
  }

  private func splitCommand(for item: ClipboardItem, section: Int) -> CommandPaletteCommand {
    command(title: L10n.string("Split"), shortcut: nil, systemImageName: "arrow.up.and.line.horizontal.and.arrow.down", section: section) { [weak self] in
      self?.coordinator.split(item)
    }
  }

  private func showTransformCommandPalette(for item: ClipboardItem) {
    guard allowsUsingItems() else {
      return
    }

    guard item.canTransformText else {
      model.lastError = L10n.string("%@ cannot be transformed.", item.kind.title)
      return
    }

    closeCommandPalette()
    DispatchQueue.main.async { [weak self] in
      self?.presentCommandPalette(
        commands: self?.makeTransformCommandPaletteCommands(for: item) ?? [],
        maximumContentSize: NSSize(width: 400, height: 460),
        searchPlaceholderText: L10n.string("Search for transforms...")
      )
    }
  }

  private func makeTransformCommandPaletteCommands(for item: ClipboardItem) -> [CommandPaletteCommand] {
    ClipboardTextTransform.sortedCases.map { transform in
      command(
        title: transform.title,
        description: transform.description,
        shortcut: nil,
        systemImageName: "textformat",
        showsIcon: false,
        sectionTitle: L10n.string("Format text"),
        section: 0
      ) { [weak self] in
        self?.coordinator.transform(item, using: transform)
      }
    }
  }

  private func previewCommands(for item: ClipboardItem, section: Int) -> [CommandPaletteCommand] {
    var commands = [
      command(title: "Preview", shortcut: "space", systemImageName: "eye", section: section, isAvailableInReadOnlyHistory: true) { [weak self] in
        self?.closeCommandPalette()
        DispatchQueue.main.async { [weak self] in
          self?.showPreview(for: item)
        }
      }
    ]
    commands.append(command(
      title: model.preferences.showPreviewPane ? "Hide Preview" : "Show Preview",
      shortcut: model.preferences.togglePreviewPaneShortcut,
      systemImageName: splitView.position == .bottom ? "rectangle.bottomhalf.inset.filled" : "rectangle.righthalf.inset.filled",
      section: section,
      isAvailableInReadOnlyHistory: true
    ) { [weak self] in
      self?.closeCommandPalette()
      self?.togglePreviewPane()
    })
    commands.append(command(
      title: model.preferences.showPreviewPaneDetails ? "Hide Details" : "Show Details",
      shortcut: model.preferences.toggleDetailsShortcut,
      systemImageName: "info.circle",
      section: section,
      isAvailableInReadOnlyHistory: true
    ) { [weak self] in
      self?.closeCommandPalette()
      self?.toggleDetails()
    })
    if canShowInHistory {
      commands.append(command(
        title: "Show in History",
        shortcut: model.preferences.showInHistoryShortcut,
        systemImageName: "clock.arrow.circlepath",
        section: section,
        isAvailableInReadOnlyHistory: true
      ) { [weak self] in
        self?.closeCommandPalette()
        DispatchQueue.main.async { [weak self] in
          self?.showInHistory(item)
        }
      })
    }
    return commands
  }

  private func showInFinderCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    command(
      title: "Show in Finder",
      shortcut: shortcut,
      systemImageName: "folder",
      image: Self.applicationIcon(
        bundleIdentifier: "com.apple.finder",
        fallbackSystemImageName: "folder",
        title: "Show in Finder"
      ),
      section: section
    ) { [weak self] in
      self?.coordinator.showInFinder(item)
    }
  }

  private func openInAssociatedApplicationCommand(for item: ClipboardItem, section: Int) -> CommandPaletteCommand {
    let application = item.quickLookURL.flatMap {
      AssociatedApplication.forOpening($0, iconSize: NSSize(width: 22, height: 22))
    }
    let title = application.map { AssociatedApplication.openTitle(forName: $0.name) }
      ?? L10n.string("Open")

    return command(
      title: title,
      shortcut: nil,
      systemImageName: "app",
      image: application?.icon,
      section: section
    ) { [weak self] in
      self?.coordinator.openInAssociatedApplication(item)
    }
  }

  private func openWithCommand(for item: ClipboardItem, section: Int) -> CommandPaletteCommand {
    command(title: "Open With...", shortcut: nil, systemImageName: "square.and.arrow.up", section: section) { [weak self] in
      self?.showOpenWithCommandPalette(for: item)
    }
  }

  private func showOpenWithCommandPalette(for item: ClipboardItem) {
    guard let url = item.quickLookURL else {
      model.lastError = L10n.string("%@ cannot be opened with another app.", item.kind.title)
      return
    }

    let commands = makeOpenWithCommandPaletteCommands(for: item, url: url)
    guard !commands.isEmpty else {
      model.lastError = L10n.string("No applications were found for %@.", url.lastPathComponent)
      return
    }

    closeCommandPalette()
    DispatchQueue.main.async { [weak self] in
      self?.presentCommandPalette(
        commands: commands,
        maximumContentSize: NSSize(width: 400, height: 350),
        searchPlaceholderText: L10n.string("Search for apps...")
      )
    }
  }

  private func makeOpenWithCommandPaletteCommands(for item: ClipboardItem, url: URL) -> [CommandPaletteCommand] {
    let defaultApplication = NSWorkspace.shared.urlForApplication(toOpen: url)
      .map(makeOpenWithApplication)
    let defaultApplicationPath = defaultApplication?.url.standardizedFileURL.path
    let recommendedApplications = NSWorkspace.shared.urlsForApplications(toOpen: url)
      .filter { $0.standardizedFileURL.path != defaultApplicationPath }
      .uniquedByStandardizedPath()
      .map(makeOpenWithApplication)
      .sorted { lhs, rhs in
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }

    var commands: [CommandPaletteCommand] = []
    if let defaultApplication {
      commands.append(openWithApplicationCommand(defaultApplication, item: item, sectionTitle: L10n.string("Default"), section: 0))
    }
    commands.append(contentsOf: recommendedApplications.map { application in
      openWithApplicationCommand(application, item: item, sectionTitle: L10n.string("Recommended"), section: 1)
    })
    return commands
  }

  private func makeOpenWithApplication(for applicationURL: URL) -> OpenWithApplication {
    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    icon.size = NSSize(width: 22, height: 22)

    return OpenWithApplication(
      url: applicationURL,
      name: FileManager.default.displayName(atPath: applicationURL.path),
      icon: icon
    )
  }

  private func openWithApplicationCommand(
    _ application: OpenWithApplication,
    item: ClipboardItem,
    sectionTitle: String,
    section: Int
  ) -> CommandPaletteCommand {
    command(
      title: application.name,
      shortcut: nil,
      systemImageName: "app",
      image: application.icon,
      sectionTitle: sectionTitle,
      section: section
    ) { [weak self] in
      self?.coordinator.open(item, with: application.url)
    }
  }

  private func settingsCommand(
    title: String = "Settings...",
    section: Int,
    shortcut: String?
  ) -> CommandPaletteCommand {
    command(title: title, shortcut: shortcut, systemImageName: "gearshape", section: section, isAvailableInReadOnlyHistory: true) { [weak self] in
      self?.coordinator.openSettings()
    }
  }

  /// A paste command followed by its paste-and-delete twin, so the two read as
  /// variants of the same action. The twin takes the paste-and-delete shortcut
  /// that corresponds to the paste command's own shortcut. Items that cannot
  /// be deleted this way get the paste command alone.
  private func pasteCommandPair(
    title: String,
    pasteAndDeleteTitle: String,
    description: String? = nil,
    shortcut: String?,
    systemImageName: String = "arrow.turn.down.left",
    image: NSImage,
    section: Int,
    items: [ClipboardItem],
    variant: PasteVariant?,
    paste: @escaping () -> Void
  ) -> [CommandPaletteCommand] {
    let pasteCommand = command(
      title: title,
      description: description,
      shortcut: shortcut,
      systemImageName: systemImageName,
      image: image,
      section: section,
      action: paste
    )
    guard canPasteAndDelete(items) else {
      return [pasteCommand]
    }

    return [
      pasteCommand,
      command(
        title: pasteAndDeleteTitle,
        description: description,
        shortcut: pasteAndDeleteShortcut(matching: shortcut),
        systemImageName: systemImageName,
        image: image,
        section: section
      ) { [weak self] in
        self?.coordinator.pasteAndDelete(items, variant: variant)
      }
    ]
  }

  private func pasteAndDeleteShortcut(matching shortcut: String?) -> String? {
    let preferences = model.preferences
    if shortcut == preferences.pasteSelectedShortcut {
      return preferences.pasteAndDeleteSelectedShortcut
    }
    if shortcut == preferences.pasteSelectedSecondaryShortcut {
      return preferences.pasteAndDeleteSelectedSecondaryShortcut
    }
    return nil
  }

  private func deleteCommand(for item: ClipboardItem, shortcut: String?, section: Int) -> CommandPaletteCommand {
    command(title: "Delete", shortcut: shortcut, systemImageName: "trash", section: section, isDestructive: true) { [weak self] in
      self?.coordinator.delete(item)
    }
  }

  /// Putting the items back and deleting them for good, the only things the
  /// Trash does with its items.
  private func trashItemCommands(for items: [ClipboardItem]) -> [CommandPaletteCommand] {
    guard !items.isEmpty else {
      return []
    }

    let preferences = model.preferences
    return [
      command(
        title: items.count == 1 ? L10n.string("Put Back") : L10n.string("Put Back %d Items", items.count),
        shortcut: preferences.pasteSelectedShortcut,
        systemImageName: "arrow.uturn.backward",
        section: 0
      ) { [weak self] in
        self?.coordinator.putBack(items)
      },
      command(
        title: items.count == 1 ? L10n.string("Delete Immediately...") : L10n.string("Delete %d Items Immediately...", items.count),
        shortcut: preferences.deleteItemShortcut,
        systemImageName: "trash",
        section: 1,
        isDestructive: true
      ) { [weak self] in
        // The confirmation is a sheet, which waits for the palette to close.
        self?.closeCommandPalette()
        self?.coordinator.deleteImmediately(items)
      }
    ]
  }

  private func emptyTrashCommand(section: Int) -> CommandPaletteCommand {
    command(title: L10n.string("Empty Trash..."), shortcut: nil, systemImageName: "trash.slash", section: section, isDestructive: true) { [weak self] in
      self?.closeCommandPalette()
      self?.coordinator.emptyTrash()
    }
  }

  private func deleteAllCommand(section: Int) -> CommandPaletteCommand {
    command(title: "Delete All", shortcut: nil, systemImageName: "trash", section: section, isDestructive: true) { [weak self] in
      self?.coordinator.clearHistoryWithWarningIfNeeded()
    }
  }

  private static func pasteTargetApplicationName(for application: NSRunningApplication?) -> String {
    application?.localizedName ?? L10n.string("Active App")
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

  private static func applicationIcon(for application: NSRunningApplication?) -> NSImage {
    let icon: NSImage
    if let bundleURL = application?.bundleURL {
      icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
    } else {
      icon = NSWorkspace.shared.icon(for: .application)
    }

    icon.size = NSSize(width: 22, height: 22)
    return icon
  }

  private static func applicationIcon(
    bundleIdentifier: String,
    fallbackSystemImageName: String,
    title: String
  ) -> NSImage? {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
      return NSImage(systemSymbolName: fallbackSystemImageName, accessibilityDescription: title)
    }

    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    icon.size = NSSize(width: 22, height: 22)
    return icon
  }

  private func closeCommandPalette() {
    guard let palette = commandPalette else {
      return
    }

    commandPaletteOutsideClickMonitor?.invalidate()
    commandPaletteOutsideClickMonitor = nil
    commandPalette = nil
    dismiss(palette)
  }

  private func presentCommandPalette(
    commands: [CommandPaletteCommand],
    maximumContentSize: NSSize,
    searchPlaceholderText: String = "Search for actions...",
    footerText: String? = nil
  ) {
    guard commandPalette == nil else {
      return
    }

    let palette = CommandPalette(
      commands: commands,
      maximumContentSize: maximumContentSize,
      searchPlaceholderText: searchPlaceholderText,
      dismissalShortcut: model.preferences.showCommandPaletteShortcut,
      footerText: footerText
    )
    palette.onDismiss = { [weak self, weak palette] in
      guard let self, self.commandPalette === palette else {
        return
      }

      self.commandPaletteOutsideClickMonitor?.invalidate()
      self.commandPaletteOutsideClickMonitor = nil
      self.commandPalette = nil
    }
    commandPalette = palette
    present(palette, animator: CommandPaletteSheetAnimator())
    DispatchQueue.main.async { [weak self, weak palette] in
      guard let self,
            let palette,
            self.commandPalette === palette,
            let paletteWindow = palette.view.window else {
        return
      }

      self.commandPaletteOutsideClickMonitor = OutsideClickDismissalMonitor(window: paletteWindow) { [weak self] in
        self?.closeCommandPalette()
      }
    }
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

private extension NSImage {
  static func tagMenuIcon(color: NSColor?) -> NSImage? {
    guard let color else {
      return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: L10n.string("Tag"))
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
    return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: L10n.string("Tag"))?
      .withSymbolConfiguration(configuration)
  }
}

private extension ClipboardItem {
  var isMissingSingleFileItem: Bool {
    guard kind == .file,
          filePaths.count == 1,
          let filePath = filePaths.first else {
      return false
    }

    return !FileManager.default.fileExists(atPath: filePath)
  }

  var canTransformText: Bool {
    switch kind {
    case .text, .richText, .link, .email, .color:
      return text != nil
    case .image, .file:
      return false
    }
  }
}

private extension ClipboardKind {
  func selectedCopyShortcutVariant(preferences: AppPreferences) -> PasteVariant {
    switch self {
    case .text, .richText, .link, .email, .color:
      return preferences.preferPastingAsPlainText ? .plainText : .standard
    case .image, .file:
      return .standard
    }
  }

  func selectedShortcutVariant(preferences: AppPreferences) -> PasteVariant {
    switch self {
    case .text, .richText, .link, .email, .color:
      return preferences.preferPastingAsPlainText ? .plainText : .standard
    case .image, .file:
      return .standard
    }
  }

  func selectedSecondaryShortcutVariant(preferences: AppPreferences) -> PasteVariant? {
    switch self {
    case .text, .richText, .link, .email, .color:
      return preferences.preferPastingAsPlainText ? .standard : .plainText
    case .file:
      return .filePath
    case .image:
      return nil
    }
  }

  func selectedSecondaryCopyShortcutVariant(preferences: AppPreferences) -> PasteVariant? {
    switch self {
    case .text, .richText, .link, .email, .color:
      return preferences.preferPastingAsPlainText ? .standard : .plainText
    case .file:
      return .filePath
    case .image:
      return nil
    }
  }
}

private extension Array where Element == URL {
  func uniquedByStandardizedPath() -> [URL] {
    var seenPaths: Set<String> = []
    return filter { url in
      seenPaths.insert(url.standardizedFileURL.path).inserted
    }
  }
}

private final class HistoryKeyHandlingView: NSView {
  var onSearchKeyDown: ((NSEvent) -> Void)?
  var onEffectiveAppearanceChange: ((NSAppearance) -> Void)?

  func configureBackground() {
    wantsLayer = true
    updateBackgroundColor()
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateBackgroundColor()
    onEffectiveAppearanceChange?(effectiveAppearance)
  }

  override func keyDown(with event: NSEvent) {
    if isSearchKeyDown(event) {
      onSearchKeyDown?(event)
      return
    }

    super.keyDown(with: event)
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

  private func updateBackgroundColor() {
    layer?.backgroundColor = HistoryAppearance.backgroundCGColor(for: self)
  }
}

/// The preferences the history list shows.
private struct HistoryListPreferences: Equatable {
  let showCommandNumberShortcut: Bool
  let showPreviewForLinks: Bool
  let detectSensitiveContent: Bool
  let showHistoryDividers: Bool
  let preferPastingAsPlainText: Bool
  let pinFavoritesToTop: Bool
  let copySequenceModeEnabled: Bool

  init(_ preferences: AppPreferences) {
    showCommandNumberShortcut = preferences.showCommandNumberShortcut
    showPreviewForLinks = preferences.showPreviewForLinks
    detectSensitiveContent = preferences.detectSensitiveContent
    showHistoryDividers = preferences.showHistoryDividers
    preferPastingAsPlainText = preferences.preferPastingAsPlainText
    pinFavoritesToTop = preferences.pinFavoritesToTop
    copySequenceModeEnabled = preferences.copySequenceModeEnabled
  }
}

/// The preferences the preview pane follows.
private struct HistoryPreviewPanePreferences: Equatable {
  let showPreviewPane: Bool
  let showPreviewPaneDetails: Bool
  let showPreviewForLinks: Bool
  let detectSensitiveContent: Bool
  let previewPaneHeight: Double?
  let previewPaneWidthRatio: Double?
  // Shown next to the commands in the toolbar's More menu.
  let togglePreviewPaneShortcut: String
  let toggleDetailsShortcut: String

  init(_ preferences: AppPreferences) {
    showPreviewPane = preferences.showPreviewPane
    showPreviewPaneDetails = preferences.showPreviewPaneDetails
    showPreviewForLinks = preferences.showPreviewForLinks
    detectSensitiveContent = preferences.detectSensitiveContent
    previewPaneHeight = preferences.previewPaneHeight
    previewPaneWidthRatio = preferences.previewPaneWidthRatio
    togglePreviewPaneShortcut = preferences.togglePreviewPaneShortcut
    toggleDetailsShortcut = preferences.toggleDetailsShortcut
  }
}

/// What the controller of the preview pane is made with and can't change
/// afterwards, so a change of any of them makes a new controller.
private struct PreviewPaneControllerConfiguration: Equatable {
  let detectsSensitiveContent: Bool
  let isReadOnly: Bool
}

/// The preferences the history toolbar shows.
private struct HistoryToolbarPreferences: Equatable {
  let hideOnFocusLoss: Bool
  let copySequenceModeEnabled: Bool

  init(_ preferences: AppPreferences) {
    hideOnFocusLoss = preferences.hideOnFocusLoss
    copySequenceModeEnabled = preferences.copySequenceModeEnabled
  }
}
