import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import UniformTypeIdentifiers

private enum ClipboardImageExportError: LocalizedError {
  case unsupportedItem
  case missingImageFile

  var errorDescription: String? {
    switch self {
    case .unsupportedItem:
      return L10n.string("This clipboard item cannot be saved as an image file.")
    case .missingImageFile:
      return L10n.string("The image file for this clipboard item could not be found.")
    }
  }
}

@MainActor
final class AppCoordinator: ObservableObject {
  let model: AppModel
  
  private let preferencesStore: PreferencesStore
  private let historyStore: HistoryStore
  private let clipboardMonitor: PasteboardMonitor
  private let pasteService: PasteService
  private let globalShortcuts: GlobalShortcutService
  private let updateService: UpdateService
  private let licensingService: LicensingService
  private let fileManager: FileManager
  private let supportDirectory: URL
  let filePreviewCache: FilePreviewCache
  #if (CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)) || CLIPBOOK_COMMERCIAL_IN_TREE
  private static let v1PreferencesDomain = "com.ikryanov.clipbook"
  private static let v1LicenseKeyPreferenceKey = "license_key"
  #endif
  private let lastKnownBootTimeKey = "ClipBookLastKnownBootTime"
  private let linkPreviewFetcher = LinkPreviewFetcher()
  private var linkPreviewTasksByItemID: [UUID: Task<Void, Never>] = [:]
  private var pendingLinkPreviewModelUpdatesByItemID: [UUID: ClipboardItem] = [:]
  private var linkPreviewModelUpdateTask: Task<Void, Never>?
  private let soundService = SoundService()
  @Published var settingsSection: SettingsSection = .general
  private var historyWindow: HistoryWindow?
  private var settingsWindow: SettingsWindow?
  private var onboardingWindow: OnboardingWindow?
  private var cancellables: Set<AnyCancellable> = []
  private var pasteNextItemID: ClipboardItem.ID?
  private var isTrialSheetPresented = false
  private static let retentionCheckInterval: TimeInterval = 60 * 60
  private static let orphanedStoredFileMinimumAge: TimeInterval = 10 * 60
  private var retentionTimer: Timer?
  private var isRetentionPromptPresented = false
  private var isHistoryArchiveOperationRunning = false
  private var areGlobalShortcutsSuspended = false
  @Published private(set) var licenseState: LicensingService.State = .unavailable
  @Published private(set) var trialNotice: TrialNotice?
  /// Fires when something tried to use an item while the history is read-only,
  /// so the notice above the history can point out why nothing happened.
  let readOnlyHistoryActionAttempts = PassthroughSubject<Void, Never>()

  /// After the trial the history keeps showing and taking in new items, but
  /// its items can no longer be copied, pasted, edited or otherwise reused.
  var isHistoryReadOnly: Bool {
    licenseState.isTrialExpired
  }
  
  init(
    model: AppModel,
    preferencesStore: PreferencesStore,
    historyStore: HistoryStore,
    clipboardMonitor: PasteboardMonitor,
    pasteService: PasteService,
    globalShortcuts: GlobalShortcutService,
    updateService: UpdateService,
    licensingService: LicensingService,
    fileManager: FileManager,
    supportDirectory: URL
  ) {
    self.model = model
    self.preferencesStore = preferencesStore
    self.historyStore = historyStore
    self.clipboardMonitor = clipboardMonitor
    self.pasteService = pasteService
    self.globalShortcuts = globalShortcuts
    self.updateService = updateService
    self.licensingService = licensingService
    self.fileManager = fileManager
    self.supportDirectory = supportDirectory
    self.filePreviewCache = FilePreviewCache(
      directory: supportDirectory.appendingPathComponent("FilePreviews", isDirectory: true),
      fileManager: fileManager
    )
    licensingService.$state
      .sink { [weak self] state in
        self?.licenseState = state
        self?.updateTrialNotice()
      }
      .store(in: &cancellables)
  }
  
  func start() {
    model.preferences = preferencesStore.load()
    #if DEBUG
    applyDebugTrialDates()
    #endif
    #if (CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)) || CLIPBOOK_COMMERCIAL_IN_TREE
    activateV1LicenseKeyIfNeeded()
    #endif
    refreshLicensingState()
    model.historySortOption = HistorySortOption(preferenceValue: model.preferences.historySortOption)
    model.isHistorySortReversed = model.preferences.isHistorySortReversed
    applyLanguage()
    updateService.setAutomaticallyChecksForUpdates(model.preferences.checkForUpdatesAutomatically)
    var shouldSavePreferences = false
    if model.preferences.deleteItemShortcut == "delete" {
      model.preferences.deleteItemShortcut = AppPreferences.defaultDeleteItemShortcut
      shouldSavePreferences = true
    }
    if model.preferences.toggleFavoriteShortcut == "f" {
      model.preferences.toggleFavoriteShortcut = AppPreferences.defaultToggleFavoriteShortcut
      shouldSavePreferences = true
    }
    if shouldSavePreferences {
      preferencesStore.save(model.preferences)
    }
    loadHistory()
    clearHistoryAfterRebootIfNeeded()
    applyRetention()
    scheduleRetentionChecks()
    configurePanel()
    configureShortcuts()
    clipboardMonitor.delegate = self
    clipboardMonitor.start(preferences: model.preferences)
    applyAppearance()
    if !model.preferences.hasCompletedOnboarding {
      showOnboarding()
    } else if model.preferences.showMainWindowAtStartup {
      showHistoryPanel()
    }
  }
  
  func stop() {
    historyWindow?.saveWindowFrame()
    savePreferences()
    if model.preferences.clearHistoryOnQuit {
      clearHistory()
    }
    cancelLinkPreviewTasks()
    retentionTimer?.invalidate()
    clipboardMonitor.stop()
    globalShortcuts.unregisterAll()
  }
  
  /// The window a quit confirmation is shown on: the history window or
  /// Settings, whichever the user is in, or nil when neither is on screen.
  /// A dialog already open over it (an item preview, for instance) keeps its
  /// place and gets the confirmation on top of it.
  var quitConfirmationWindow: NSWindow? {
    let windows = [historyWindow?.window, settingsWindow?.window]
      .compactMap { $0 }
      .filter(\.isVisible)
    var window = windows.first { $0.isKeyWindow || $0.attachedSheet?.isKeyWindow == true } ?? windows.first
    while let sheet = window?.attachedSheet {
      window = sheet
    }
    return window
  }

  func showHistoryPanel(ignoresNextResignKey: Bool = false, activatesApp: Bool = false) {
    guard !isHistoryArchiveOperationRunning else {
      return
    }

    recordTrialUsage()
    configurePanel()
    interruptCopySequenceTracking()
    resetPasteNextPointer()
    if activatesApp {
      NSApp.activate(ignoringOtherApps: true)
    }
    historyWindow?.show(ignoresNextResignKey: ignoresNextResignKey)
    presentTrialSheetIfNeeded()
  }
  
  func hideHistoryPanel() {
    historyWindow?.hide()
  }

  // A pinned panel is meant to stay on screen, so pasting leaves it visible.
  // The panel is non-activating, which keeps the paste target frontmost even
  // while the panel holds key focus, so the keystroke still lands in the app
  // the user pasted into.
  //
  // When the target is not the frontmost app (a non-activating panel of
  // another app, such as Easydict's pinned window), that panel has to be key
  // to take the keystroke, and the window server does not reliably hand focus
  // back to it once this panel gives it up. The target window is made key
  // explicitly instead, and a pinned panel takes key focus back afterwards.
  private func hideHistoryWindowForPaste() {
    pasteService.resolvePasteTarget()
    let isPinned = !model.preferences.hideOnFocusLoss
    if !isPinned {
      historyWindow?.hideForPaste()
    }
    guard !pasteService.pasteTargetIsFrontmostApplication(),
          pasteService.giveKeyFocusToTargetWindow(),
          isPinned else {
      return
    }
    historyWindow?.retakeKeyFocusAfterPaste()
  }

  func toggleHistoryPanel() {
    guard !isHistoryArchiveOperationRunning else {
      return
    }

    configurePanel()
    guard historyWindow?.isVisible == false else {
      historyWindow?.toggle()
      return
    }

    recordTrialUsage()
    interruptCopySequenceTracking()
    resetPasteNextPointer()
    historyWindow?.toggle()
    presentTrialSheetIfNeeded()
  }

  func toggleHistoryPanelPin() {
    model.preferences.hideOnFocusLoss.toggle()
    savePreferences()
    historyWindow?.applyPreferences()
  }

  func toggleCopySequenceMode() {
    model.preferences.copySequenceModeEnabled.toggle()
    savePreferences()
  }
  
  func openSettings(section: SettingsSection = .general) {
    settingsSection = SettingsSection.visibleSections.contains(section) ? section : .general
    if settingsWindow == nil {
      settingsWindow = SettingsWindow(model: model, coordinator: self)
    }
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.show()
  }

  @discardableResult
  func beginExportHistoryArchive(
    progress: @escaping (ClipBookArchiveProgress) -> Void,
    completion: @escaping (Result<ClipBookArchiveExportResult, Error>) -> Void
  ) -> Bool {
    let panel = NSSavePanel()
    panel.title = L10n.string("Export History and Tags")
    panel.nameFieldStringValue = "ClipBook Export.clipbookarchive"
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false

    guard panel.runModal() == .OK, let url = panel.url else {
      return false
    }

    let items = model.items
    let tags = model.tags
    // FileManager is thread-safe; the archive is written on a background queue.
    nonisolated(unsafe) let fileManager = self.fileManager
    let supportDirectory = self.supportDirectory
    let reportProgress: (ClipBookArchiveProgress) -> Void = { progressValue in
      DispatchQueue.main.async {
        progress(progressValue)
      }
    }
    isHistoryArchiveOperationRunning = true

    nonisolated(unsafe) let historyStore = self.historyStore
    DispatchQueue.global(qos: .userInitiated).async {
      let archiveService = ClipBookArchiveService(fileManager: fileManager, supportDirectory: supportDirectory)
      do {
        // The archive keeps the formatting, which the history's items come without.
        let items = items.map { (try? historyStore.loadingFormatting(of: $0)) ?? $0 }
        try archiveService.export(items: items, tags: tags, to: url, progress: reportProgress)
        let result = ClipBookArchiveExportResult(url: url, itemCount: items.count, tagCount: tags.count)
        DispatchQueue.main.async {
          self.isHistoryArchiveOperationRunning = false
          completion(.success(result))
        }
      } catch {
        DispatchQueue.main.async {
          self.isHistoryArchiveOperationRunning = false
          completion(.failure(error))
        }
      }
    }

    return true
  }

  @discardableResult
  func beginImportHistoryArchive(
    progress: @escaping (ClipBookArchiveProgress) -> Void,
    completion: @escaping (Result<ClipBookArchiveImportResult, Error>) -> Void
  ) -> Bool {
    let panel = NSOpenPanel()
    panel.title = L10n.string("Import History and Tags")
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let url = panel.url else {
      return false
    }

    // The import runs on a background queue while clipboard monitoring is
    // stopped, so nothing else touches the store until it completes.
    nonisolated(unsafe) let fileManager = self.fileManager
    let supportDirectory = self.supportDirectory
    nonisolated(unsafe) let historyStore = self.historyStore
    let reportProgress: (ClipBookArchiveProgress) -> Void = { progressValue in
      DispatchQueue.main.async {
        progress(progressValue)
      }
    }
    isHistoryArchiveOperationRunning = true
    clipboardMonitor.stop()

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let archiveService = ClipBookArchiveService(fileManager: fileManager, supportDirectory: supportDirectory)
      do {
        let result = try archiveService.import(from: url, into: historyStore, progress: reportProgress)
        DispatchQueue.main.async { [weak self] in
          guard let self else {
            return
          }
          // Checked before anything can run the retention check again, which
          // would delete the expired items without asking.
          let expiredItems = self.expiredItems(among: result.itemIDs)
          self.isRetentionPromptPresented = !expiredItems.isEmpty
          self.clipboardMonitor.start(preferences: self.model.preferences)
          self.loadHistory()
          self.isHistoryArchiveOperationRunning = false
          completion(.success(result))
          if !expiredItems.isEmpty {
            self.confirmKeepingExpiredImportedItems(expiredItems)
          }
        }
      } catch {
        DispatchQueue.main.async { [weak self] in
          guard let self else {
            return
          }
          self.clipboardMonitor.start(preferences: self.model.preferences)
          self.isHistoryArchiveOperationRunning = false
          completion(.failure(error))
        }
      }
    }

    return true
  }

  func showOnboarding() {
    if onboardingWindow == nil {
      onboardingWindow = OnboardingWindow(model: model, coordinator: self)
    }
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    onboardingWindow?.show()
  }

  func completeOnboarding(openHistory: Bool = false) {
    model.preferences.hasCompletedOnboarding = true
    savePreferences()
    onboardingWindow?.close()
    onboardingWindow = nil
    NSApp.setActivationPolicy(.accessory)
    if openHistory {
      showHistoryPanel(ignoresNextResignKey: true, activatesApp: true)
    } else if model.preferences.showMainWindowAtStartup {
      showHistoryPanel()
    }
  }

  func onboardingDidClose() {
    onboardingWindow = nil
    restoreAccessoryActivationPolicyAfterWindowClose()
  }

  func settingsDidClose() {
    // A recorder that was still waiting for a combination must not leave the
    // global shortcuts off once the window is gone.
    setGlobalShortcutsSuspended(false)
    restoreAccessoryActivationPolicyAfterWindowClose()
  }

  // windowWillClose arrives while the window is still on screen. Leaving the
  // regular activation policy at that point can leave the window drawn on
  // screen while AppKit treats it as closed, so it ignores every click. The
  // switch waits until the window has been ordered out.
  private func restoreAccessoryActivationPolicyAfterWindowClose() {
    DispatchQueue.main.async { [weak self] in
      guard let self,
            self.settingsWindow?.window.isVisible != true,
            self.onboardingWindow == nil else {
        return
      }

      NSApp.setActivationPolicy(.accessory)
    }
  }
  
  func togglePaused() {
    model.isPaused.toggle()
    clipboardMonitor.isPaused = model.isPaused
  }
  
  func savePreferences() {
    preferencesStore.save(model.preferences)
    applyAppearance()
    applyLanguage()
    clipboardMonitor.updatePreferences(model.preferences)
    if !model.preferences.showPreviewForLinks {
      cancelLinkPreviewTasks()
    }
    LaunchAtLoginService.setEnabled(model.preferences.launchAtLogin)
    updateService.setAutomaticallyChecksForUpdates(model.preferences.checkForUpdatesAutomatically)
    configureShortcuts()
  }

  func persistPreferences() {
    preferencesStore.save(model.preferences)
  }

  func refreshLicensingState() {
    licensingService.refresh(licenseKey: model.preferences.licenseKey)
  }

  // The v1 key is taken over only on the first launch of v2. After that the
  // License settings field is left to the user, so a key they deactivate or
  // clear there isn't brought back from v1.
  #if (CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)) || CLIPBOOK_COMMERCIAL_IN_TREE
  private func activateV1LicenseKeyIfNeeded() {
    guard !model.preferences.hasMigratedV1LicenseKey else {
      return
    }

    model.preferences.hasMigratedV1LicenseKey = true
    guard model.preferences.licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let licenseKey = v1LicenseKey()
    else {
      persistPreferences()
      return
    }

    // The key is shown in the License settings even if the activation fails.
    model.preferences.licenseKey = licenseKey
    persistPreferences()
    Task { [weak self] in
      do {
        try await self?.activateLicenseKey(licenseKey)
      } catch {
        self?.model.lastError = error.localizedDescription
      }
    }
  }

  private func v1LicenseKey() -> String? {
    guard let preferences = UserDefaults.standard.persistentDomain(forName: Self.v1PreferencesDomain),
          let licenseKey = preferences[Self.v1LicenseKeyPreferenceKey] as? String else {
      return nil
    }

    let sanitizedLicenseKey = licenseKey
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
    guard !sanitizedLicenseKey.isEmpty else {
      return nil
    }

    return sanitizedLicenseKey
  }
  #endif

  func activateLicenseKey(_ licenseKey: String) async throws {
    let sanitizedLicenseKey = licenseKey.replacingOccurrences(of: " ", with: "")
    try await licensingService.activate(licenseKey: sanitizedLicenseKey)
    model.preferences.licenseKey = sanitizedLicenseKey
    savePreferences()
  }

  // The key stays in preferences, so it's still in the License settings to
  // activate again later. Activation is tracked by the licensing runtime key,
  // which deactivation removes, not by the stored key.
  func deactivateLicenseKey() async throws {
    try await licensingService.deactivate(licenseKey: model.preferences.licenseKey)
  }

  // Keeps what the user left in the License settings field while the license
  // isn't activated, so it's still there the next time the settings open.
  func updateUnactivatedLicenseKey(_ licenseKey: String) {
    guard !licenseState.isActivated,
          model.preferences.licenseKey != licenseKey else {
      return
    }

    model.preferences.licenseKey = licenseKey
    persistPreferences()
  }

  /// While the discount after the trial runs, its code goes along to the
  /// pricing page, which hands it to the checkout.
  func openBuyLicenseURL() {
    guard var components = URLComponents(string: "https://clipbook.app/pricing/") else {
      return
    }

    if case .discount(let endsAt) = trialNotice, Date() < endsAt {
      components.queryItems = [URLQueryItem(name: "discount", value: TrialOffer.discountCode)]
    }
    guard let url = components.url else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  func sendTrialExpiredFeedback(_ feedback: TrialExpiredFeedback) {
    model.preferences.hasProvidedTrialExpiredFeedback = true
    persistPreferences()

    let reasons = feedback.reasons.isEmpty
      ? L10n.string("No reason selected")
      : feedback.reasons.joined(separator: ", ")
    let message = feedback.message.isEmpty
      ? L10n.string("Not provided")
      : feedback.message
    let email = feedback.email.isEmpty
      ? L10n.string("Not provided")
      : feedback.email
    let body = """
    \(L10n.string("Reasons")): \(reasons)

    \(L10n.string("Feedback")):
    \(message)

    \(L10n.string("Email")):
    \(email)
    """

    Task {
      await licensingService.sendFeedback(text: body)
    }
  }
  
  func clearHistory() {
    do {
      let keepingItems = model.preferences.keepFavoritesOnClearHistory
      let deletedItems = model.items.filter { !keepingItems || !shouldKeepWhenClearingHistory($0) }
      try historyStore.clear(keepingFavoritesAndTaggedItems: keepingItems)
      if keepingItems {
        deletedItems.forEach(removeLinkPreviewFiles)
        removeFilePreviewFiles(for: deletedItems, remainingItems: model.items.filter(shouldKeepWhenClearingHistory))
      } else {
        try? fileManager.removeItem(at: linkPreviewsDirectory)
        filePreviewCache.removeAll()
      }
      removeAssetFiles(for: deletedItems, remainingItems: model.items.filter { keepingItems && shouldKeepWhenClearingHistory($0) })
      model.remove(Set(deletedItems.map(\.id)))
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  /// The "Delete All" command acts on what the list currently shows, so
  /// narrowing the history to a single app, tag or search query and running it
  /// removes just those items instead of the whole history.
  func clearHistoryWithWarningIfNeeded() {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard model.isHistoryNarrowed else {
      guard shouldProceedWithClearHistory(isNarrowed: false) else {
        return
      }

      clearHistory()
      return
    }

    let deletedItems = clearableHistoryItems()
    guard !deletedItems.isEmpty, shouldProceedWithClearHistory(isNarrowed: true) else {
      return
    }

    do {
      try removeFromHistory(deletedItems)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func clearableHistoryItems() -> [ClipboardItem] {
    let keepingItems = model.preferences.keepFavoritesOnClearHistory
    return model.filteredItems.filter { !keepingItems || !shouldKeepWhenClearingHistory($0) }
  }
  
  func pasteSelection() {
    guard allowsUsingHistoryItems() else {
      return
    }

    let selectedItems = model.selectedItems
    guard !selectedItems.isEmpty else {
      return
    }

    guard selectedItems.count > 1 else {
      guard let item = selectedItems.first else {
        return
      }
      paste(item, variant: preferredPasteVariant(for: item.kind))
      return
    }

    let variants = Dictionary(uniqueKeysWithValues: selectedItems.map { item in
      (item.id, preferredPasteVariant(for: item.kind))
    })
    paste(selectedItems, variants: variants)
  }

  /// Pastes the selected items and then removes them from the history, which
  /// suits single-use content such as one-time codes.
  func pasteAndDeleteSelection() {
    pasteAndDelete(model.selectedItems)
  }

  /// Without a variant each item is pasted the way the paste shortcut pastes it.
  func pasteAndDelete(_ items: [ClipboardItem], variant: PasteVariant? = nil) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard canPasteAndDelete(items) else {
      return
    }

    let variants = Dictionary(uniqueKeysWithValues: items.map { item in
      (item.id, variant ?? preferredPasteVariant(for: item.kind))
    })
    paste(items, variants: variants, deletesAfterPaste: true)
  }

  /// Items the history always keeps cannot be deleted by pasting them, so the
  /// action is not offered for them at all rather than pasting without
  /// deleting.
  func canPasteAndDelete(_ items: [ClipboardItem]) -> Bool {
    !items.isEmpty && items.allSatisfy { item in
      !(model.preferences.keepFavoritesOnClearHistory && shouldKeepWhenClearingHistory(item))
    }
  }

  // While the history panel is open the highlighted item is what the user
  // expects to paste, so the paste-next hotkeys stay out of the way instead of
  // hiding the panel and pasting a different item.
  private func pasteNextItemFromGlobalShortcut(variant: PasteVariant?, deletesAfterPaste: Bool = false) {
    guard historyWindow?.isVisible != true else {
      return
    }

    pasteNextItem(variant: variant, deletesAfterPaste: deletesAfterPaste)
  }

  private func pasteNextItem(variant: PasteVariant?, deletesAfterPaste: Bool = false) {
    guard allowsUsingHistoryItems() else {
      return
    }

    let items = model.filteredItems
    let pasteNextItems = historyItemsForPasteNext(in: items)
    guard let item = historyItemForPasteNext(in: pasteNextItems) else {
      return
    }

    // An item the history always keeps is pasted without being deleted, so the
    // hotkey still moves on to the next item instead of getting stuck on it.
    let deletesItem = deletesAfterPaste && canPasteAndDelete([item])
    var nextItemID = nextHistoryItemID(after: item.id, in: pasteNextItems)
    if deletesItem, nextItemID == item.id {
      nextItemID = nil
    }
    paste(item, variant: variant ?? preferredPasteVariant(for: item.kind), deletesAfterPaste: deletesItem) { [weak self] in
      self?.clipboardMonitor.markCopySequencePasteBoundary()
      self?.pasteNextItemID = nextItemID
      self?.selectSingleHistoryItem(nextItemID)
    }
  }

  private func preferredPasteVariant(for kind: ClipboardKind) -> PasteVariant {
    switch kind {
    case .text, .richText, .link, .email, .color:
      return model.preferences.preferPastingAsPlainText ? .plainText : .standard
    case .image, .file:
      return .standard
    }
  }
  
  func paste(_ item: ClipboardItem, variant: PasteVariant = .standard) {
    paste(item, variant: variant) {}
  }

  private func paste(
    _ item: ClipboardItem,
    variant: PasteVariant,
    deletesAfterPaste: Bool = false,
    onSuccess: @escaping @MainActor () -> Void
  ) {
    guard allowsUsingHistoryItems() else {
      return
    }

    hideHistoryWindowForPaste()
    // The synthetic Cmd+V is posted directly to the target application's
    // process, so there is no need to wait for the window server to settle key
    // focus after the panel is hidden; pasting runs synchronously right away.
    do {
      try pasteRecordingHistory(item, variant: variant, deletesAfterPaste: deletesAfterPaste)
      onSuccess()
    } catch {
      model.lastError = error.localizedDescription
      showAccessibilityAlertIfNeeded(error)
    }
  }

  private func pasteRecordingHistory(
    _ item: ClipboardItem,
    variant: PasteVariant,
    deletesAfterPaste: Bool = false
  ) throws {
    try pasteService.paste(item, variant: variant)
    playSound(.paste)
    // The pasteboard already holds the item's data at this point, so removing
    // the item (and its asset files) cannot affect what gets pasted.
    if deletesAfterPaste {
      try removeFromHistory([item])
      interruptCopySequenceTracking()
      return
    }

    let updated = try recordHistoryAction(for: item, incrementsCopyCount: true)
    updated.map(model.replace)
    interruptCopySequenceTracking()
  }

  private func historyItemForPasteNext(in items: [ClipboardItem]) -> ClipboardItem? {
    guard !items.isEmpty else {
      return nil
    }

    // A remembered selection is what the history shows when it opens, so it is
    // also what gets pasted next. Pasting the next item moves the selection on.
    if !model.preferences.rememberHistorySelection,
       let pasteNextItemID,
       let pasteNextItem = items.first(where: { $0.id == pasteNextItemID }) {
      return pasteNextItem
    }

    if let selectedItemID = model.selectedItemID,
       let selectedItem = items.first(where: { $0.id == selectedItemID }) {
      return selectedItem
    }

    return items.first
  }

  private func historyItemsForPasteNext(in items: [ClipboardItem]) -> [ClipboardItem] {
    guard model.preferences.pinFavoritesToTop else {
      return items
    }

    return items.filter { !$0.isFavorite }
  }

  private func nextHistoryItemID(after itemID: ClipboardItem.ID, in items: [ClipboardItem]) -> ClipboardItem.ID? {
    guard !items.isEmpty,
          let index = items.firstIndex(where: { $0.id == itemID }) else {
      return nil
    }

    let nextIndex = items.index(after: index)
    if nextIndex < items.endIndex {
      return items[nextIndex].id
    }

    return items.first?.id
  }

  private func selectSingleHistoryItem(_ itemID: ClipboardItem.ID?) {
    model.selectedItemID = itemID
    model.selectedItemIDs = itemID.map { [$0] } ?? []
    model.selectedItemIDsInSelectionOrder = itemID.map { [$0] } ?? []
  }

  private func resetPasteNextPointer() {
    pasteNextItemID = historyItemsForPasteNext(in: model.filteredItems).first?.id
  }

  var defaultMultiPasteKey: PasteInterItemAction {
    PasteInterItemAction(preferenceValue: model.preferences.multiPasteKey)
  }

  func setDefaultMultiPasteKey(_ action: PasteInterItemAction) {
    model.preferences.multiPasteKey = action.rawValue
    preferencesStore.save(model.preferences)
  }

  func paste(
    _ items: [ClipboardItem],
    variants: [ClipboardItem.ID: PasteVariant],
    interItemAction: PasteInterItemAction? = nil,
    deletesAfterPaste: Bool = false
  ) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard let firstItem = items.first else {
      return
    }

    // Without an explicit key the items are pasted with the key from the
    // settings between them, so every way of pasting several items agrees.
    let interItemAction = interItemAction ?? defaultMultiPasteKey

    hideHistoryWindowForPaste()
    // The first item is pasted synchronously so a multi-item paste starts as
    // instantly as a single-item paste. Only the remaining items run on a task,
    // which they need for the inter-item delays.

    do {
      try pasteRecordingHistory(
        firstItem,
        variant: variants[firstItem.id] ?? .standard,
        deletesAfterPaste: deletesAfterPaste
      )
    } catch {
      model.lastError = error.localizedDescription
      showAccessibilityAlertIfNeeded(error)
      return
    }

    let remainingItems = items.dropFirst()
    guard !remainingItems.isEmpty else {
      return
    }

    Task { @MainActor [weak self] in
      guard let self else {
        return
      }

      do {
        for item in remainingItems {
          try await pasteService.perform(interItemAction)
          try await Task.sleep(for: .milliseconds(160))
          try pasteRecordingHistory(
            item,
            variant: variants[item.id] ?? .standard,
            deletesAfterPaste: deletesAfterPaste
          )
        }
      } catch {
        model.lastError = error.localizedDescription
        showAccessibilityAlertIfNeeded(error)
      }
    }
  }
  
  @discardableResult
  func copy(_ item: ClipboardItem) -> Bool {
    copy(item, variant: .standard)
  }

  @discardableResult
  func copy(_ item: ClipboardItem, variant: PasteVariant) -> Bool {
    guard allowsUsingHistoryItems() else {
      return false
    }

    do {
      try pasteService.copy(item, variant: variant)
      // Copying from the history puts the item on the clipboard, so it counts
      // as a copy the same way a paste does.
      if let updated = try recordHistoryAction(for: item, incrementsCopyCount: true) {
        model.replace(updated)
      }
      interruptCopySequenceTracking()
      playSound(.copy)
      return true
    } catch {
      model.lastError = error.localizedDescription
      return false
    }
  }
  
  @discardableResult
  func copyPlainText(_ item: ClipboardItem) -> Bool {
    copy(item, variant: .plainText)
  }

  @discardableResult
  func copyText(_ text: String) -> Bool {
    guard allowsUsingHistoryItems() else {
      return false
    }

    do {
      try pasteService.copyText(text)
      interruptCopySequenceTracking()
      playSound(.copy)
      return true
    } catch {
      model.lastError = error.localizedDescription
      return false
    }
  }

  func mergeSelection() {
    merge(model.selectedItems)
  }

  func merge(_ items: [ClipboardItem]) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard items.count > 1,
          let text = mergedText(from: items) else {
      return
    }

    do {
      let item = ClipboardItem(
        kind: .text,
        text: text,
        byteSize: text.utf8.count,
        searchText: text
      )
      try deleteExistingMatches(for: item)
      try historyStore.upsert(item)
      model.insert(item)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  @discardableResult
  func copyMergedSelection() -> Bool {
    copyMerged(model.selectedItems)
  }

  @discardableResult
  func copyMerged(_ items: [ClipboardItem]) -> Bool {
    guard allowsUsingHistoryItems() else {
      return false
    }

    guard items.count > 1,
          let text = mergedText(from: items) else {
      return false
    }

    do {
      try pasteService.copyText(text, markAsGhost: true)
      interruptCopySequenceTracking()
      playSound(.copy)
      return true
    } catch {
      model.lastError = error.localizedDescription
      return false
    }
  }
  
  func deleteSelection() {
    delete(model.selectedItems)
  }

  func delete(_ items: [ClipboardItem]) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard !items.isEmpty else {
      return
    }
    
    do {
      try removeFromHistory(items)
      playSound(.delete)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  /// Deletes the items from the store, drops their cached previews, and takes
  /// them out of the model.
  private func removeFromHistory(_ items: [ClipboardItem]) throws {
    guard !items.isEmpty else {
      return
    }

    let deletedItemIDs = Set(items.map(\.id))
    try historyStore.delete(ids: items.map(\.id))
    // A menu or a row may hold a copy of an item from before its link preview
    // was saved, so the files are taken from the item as the history has it now.
    let currentItemsByID = Dictionary(
      model.items.filter { deletedItemIDs.contains($0.id) }.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let items = items.map { currentItemsByID[$0.id] ?? $0 }
    let remainingItems = model.items.filter { !deletedItemIDs.contains($0.id) }
    items.forEach(removeLinkPreviewFiles)
    removeFilePreviewFiles(for: items, remainingItems: remainingItems)
    removeAssetFiles(for: items, remainingItems: remainingItems)
    model.remove(deletedItemIDs)
  }

  // MARK: - History retention

  /// Applies a new "Keep history" period for one group of item kinds. When
  /// items already exceed it, the user is asked before they are deleted;
  /// cancelling restores the previous period.
  func setRetentionDays(_ days: Int, for clipType: RetentionClipType) {
    let keyPath = clipType.preferenceKeyPath
    let previousDays = model.preferences[keyPath: keyPath]
    guard days != previousDays else {
      return
    }

    model.preferences[keyPath: keyPath] = days
    let policy = HistoryRetentionPolicy(preferences: model.preferences, kinds: clipType.kinds)
    var expiredItems: [ClipboardItem] = []
    if !policy.isEmpty {
      do {
        expiredItems = try historyStore.fetchItems(expiredBy: policy)
      } catch {
        model.lastError = error.localizedDescription
      }
    }
    guard !expiredItems.isEmpty else {
      savePreferences()
      return
    }

    isRetentionPromptPresented = true
    presentRetentionChangeAlert { [weak self] confirmed in
      guard let self else {
        return
      }
      isRetentionPromptPresented = false
      guard confirmed else {
        model.preferences[keyPath: keyPath] = previousDays
        return
      }
      do {
        try removeFromHistory(expiredItems)
      } catch {
        model.lastError = error.localizedDescription
      }
      savePreferences()
    }
  }

  private func presentRetentionChangeAlert(completion: @escaping (Bool) -> Void) {
    presentDeletionAlert(
      message: L10n.string("You have items older than the new history limit. Do you want to delete these older items and apply the new limit?"),
      completion: completion
    )
  }

  /// The items among `itemIDs` that have outlived their "Keep history" period.
  private func expiredItems(among itemIDs: Set<ClipboardItem.ID>) -> [ClipboardItem] {
    let policy = HistoryRetentionPolicy(preferences: model.preferences)
    guard !policy.isEmpty, !itemIDs.isEmpty else {
      return []
    }

    do {
      return try historyStore.fetchItems(expiredBy: policy).filter { itemIDs.contains($0.id) }
    } catch {
      model.lastError = error.localizedDescription
      return []
    }
  }

  /// An archive can bring in items older than the "Keep history" period of
  /// their type, which the next retention check would delete without a word.
  /// The user either keeps them, which makes those types unlimited, or
  /// deletes them right away. The retention check waits for the answer.
  private func confirmKeepingExpiredImportedItems(_ expiredItems: [ClipboardItem]) {
    let expiredKinds = Set(expiredItems.map(\.kind))
    let clipTypes = RetentionClipType.allCases.filter { !$0.kinds.isDisjoint(with: expiredKinds) }
    let listFormatter = ListFormatter()
    listFormatter.locale = L10n.currentLocale
    let clipTypeTitles = listFormatter.string(from: clipTypes.map(\.title)) ?? ""

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = L10n.string("Some imported items are older than the history limit. Do you want to keep them?")
    alert.informativeText = L10n.string("Keeping them sets the history limit for %@ to Unlimited. Otherwise they will be deleted.", clipTypeTitles)
    alert.addButton(withTitle: L10n.string("Keep Items"))
    let deleteButton = alert.addButton(withTitle: L10n.string("Delete"))
    deleteButton.hasDestructiveAction = true

    present(alert) { [weak self] response in
      guard let self else {
        return
      }
      isRetentionPromptPresented = false
      if response == .alertFirstButtonReturn {
        for clipType in clipTypes {
          model.preferences[keyPath: clipType.preferenceKeyPath] = AppPreferences.unlimitedRetentionDays
        }
        savePreferences()
      } else {
        do {
          try removeFromHistory(expiredItems)
        } catch {
          model.lastError = error.localizedDescription
        }
      }
    }
  }

  // MARK: - Ignored applications

  /// Adds applications to the ignore list. When the history already holds
  /// items copied from them, the user is asked whether to delete those too.
  /// Declining keeps the items but still ignores the applications.
  func addIgnoredApplications(atPaths paths: [String]) {
    let existingEntries = model.preferences.ignoredApplicationEntries
    var addedApplications: [IgnoredApplication] = []
    for path in paths where !existingEntries.contains(path) && !addedApplications.contains(where: { $0.path == path }) {
      addedApplications.append(IgnoredApplication(path: path))
    }
    guard !addedApplications.isEmpty else {
      return
    }

    model.preferences.ignoredAppsText = (existingEntries + addedApplications.map(\.path)).joined(separator: "\n")
    savePreferences()

    let keepsProtectedItems = model.preferences.keepFavoritesOnClearHistory
    var items: [ClipboardItem] = []
    do {
      items = try historyStore.fetchItems { item in
        addedApplications.contains { $0.matches(item) }
          && !(keepsProtectedItems && shouldKeepWhenClearingHistory(item))
      }
    } catch {
      model.lastError = error.localizedDescription
    }
    guard !items.isEmpty else {
      return
    }

    let message = addedApplications.count == 1
      ? L10n.string("You have items copied from %@. Do you want to delete these items?", addedApplications[0].name)
      : L10n.string("You have items copied from the newly ignored applications. Do you want to delete these items?")
    presentDeletionAlert(message: message) { [weak self] confirmed in
      guard let self, confirmed else {
        return
      }
      do {
        try removeFromHistory(items)
      } catch {
        model.lastError = error.localizedDescription
      }
    }
  }

  /// A Delete/Cancel alert on the settings window whose details spell out
  /// whether favorites and tagged items are spared.
  private func presentDeletionAlert(message: String, completion: @escaping (Bool) -> Void) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = message
    if model.preferences.keepFavoritesOnClearHistory {
      alert.informativeText = L10n.string("Favorites and tagged items won't be deleted. This action cannot be undone.")
    } else {
      alert.informativeText = L10n.string("Favorites and tagged items will be deleted too. This action cannot be undone.")
    }
    let deleteButton = alert.addButton(withTitle: L10n.string("Delete"))
    deleteButton.hasDestructiveAction = true
    alert.addButton(withTitle: L10n.string("Cancel"))

    present(alert) { response in
      completion(response == .alertFirstButtonReturn)
    }
  }

  /// Shows the alert on the settings window, or as a modal alert when the
  /// settings aren't open.
  private func present(_ alert: NSAlert, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
    if let settingsWindow {
      settingsWindow.presentAlert(alert, completionHandler: completionHandler)
    } else {
      completionHandler(alert.runModal())
    }
  }

  /// Removes items that outlived their "Keep history" period. Nothing is
  /// deleted while the user is still deciding on a new period, since they
  /// may cancel it, nor while an archive is being imported, since its items
  /// are checked once it is in.
  private func applyRetention() {
    guard !isRetentionPromptPresented, !isHistoryArchiveOperationRunning else {
      return
    }

    let policy = HistoryRetentionPolicy(preferences: model.preferences)
    guard !policy.isEmpty else {
      return
    }

    do {
      try removeFromHistory(try historyStore.fetchItems(expiredBy: policy))
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  /// Items also expire while nothing is being copied, so the check repeats
  /// on a timer in addition to running after each capture.
  private func scheduleRetentionChecks() {
    retentionTimer?.invalidate()
    let timer = Timer(timeInterval: Self.retentionCheckInterval, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.applyRetention()
      }
    }
    timer.tolerance = 60
    RunLoop.main.add(timer, forMode: .common)
    retentionTimer = timer
  }

  func canMerge(_ items: [ClipboardItem]) -> Bool {
    items.count > 1 && items.allSatisfy { mergeText(for: $0) != nil }
  }

  func canSplit(_ item: ClipboardItem) -> Bool {
    splitTextParts(for: item).count > 1
  }

  func split(_ item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    let parts = splitTextParts(for: item)
    guard parts.count > 1 else {
      return
    }

    do {
      // Each part is a millisecond older than the one above it, so the history
      // lists the parts in the order they had in the text. With one shared
      // time the sort would fall back to the random item IDs.
      let splitAt = Date()
      let newItems = parts.enumerated().map { index, text in
        let copiedAt = splitAt.addingTimeInterval(-0.001 * Double(index))
        return ClipboardItem(
          kind: ClipboardKind.classifyText(text, treatDigitNumbersAsColor: model.preferences.treatDigitNumbersAsColor),
          text: text,
          sourceAppName: item.sourceAppName,
          sourceBundleIdentifier: item.sourceBundleIdentifier,
          copiedAt: copiedAt,
          firstCopiedAt: copiedAt,
          byteSize: text.utf8.count
        )
      }

      for newItem in newItems {
        try historyStore.upsert(newItem)
      }
      model.items.insert(contentsOf: newItems, at: 0)
      model.selectedItemID = newItems.first?.id
      model.selectedItemIDs = Set(newItems.map(\.id))
      model.selectedItemIDsInSelectionOrder = newItems.map(\.id)
    } catch {
      model.lastError = error.localizedDescription
    }
  }
  
  func delete(_ item: ClipboardItem) {
    delete([item])
  }
  
  func toggleFavorite(_ item: ClipboardItem) {
    do {
      var updated = item
      updated.isFavorite.toggle()
      if !updated.isFavorite {
        updated.favoriteOrder = nil
      }
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  /// Hides the content of the item in the history, or shows it again. Showing
  /// it is remembered as the user's choice, so content the app would hide on
  /// its own stays visible too.
  func setSensitive(_ isSensitive: Bool, for item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    do {
      var updated = item
      updated.sensitivity = isSensitive ? .sensitive : .notSensitive
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func setFavorite(_ isFavorite: Bool, for items: [ClipboardItem]) {
    guard !items.isEmpty else {
      return
    }

    do {
      for item in items where item.isFavorite != isFavorite {
        var updated = item
        updated.isFavorite = isFavorite
        if !isFavorite {
          updated.favoriteOrder = nil
        }
        try historyStore.upsert(updated)
        model.replace(updated)
      }
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  /// Moves the favorites with the given IDs, keeping their relative order, so
  /// they sit right before the favorite `targetItemID` names among the pinned
  /// favorites, or at the end when it is nil. Every favorite ends up with an
  /// explicit order so the arrangement survives whatever sort and filter the
  /// history is in, not just the rows that were visible for the drag.
  func moveFavorites(_ itemIDs: [UUID], before targetItemID: UUID?) {
    let movingIDs = Set(itemIDs)
    let favorites = model.favoritesInDisplayOrder
    let movingItems = favorites.filter { movingIDs.contains($0.id) }
    var arrangedItems = favorites.filter { !movingIDs.contains($0.id) }
    guard !movingItems.isEmpty else {
      return
    }

    let insertionIndex = targetItemID.flatMap { targetID in
      arrangedItems.firstIndex { $0.id == targetID }
    } ?? arrangedItems.count
    arrangedItems.insert(contentsOf: movingItems, at: insertionIndex)

    var updatedItems: [ClipboardItem] = []
    for (order, item) in arrangedItems.enumerated() where item.favoriteOrder != order {
      var updated = item
      updated.favoriteOrder = order
      updatedItems.append(updated)
    }
    guard !updatedItems.isEmpty else {
      return
    }

    do {
      try historyStore.performInTransaction {
        for item in updatedItems {
          try historyStore.upsert(item)
        }
      }
      model.replace(updatedItems)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func rename(_ item: ClipboardItem, title: String?) {
    guard allowsUsingHistoryItems() else {
      return
    }

    do {
      var updated = item
      updated.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
      updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func editContent(_ item: ClipboardItem, text: String) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard item.kind.canEditTextContent else {
      model.lastError = "\(item.kind.title) cannot be edited."
      return
    }

    do {
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        try historyStore.delete(item.id)
        let currentItem = model.items.first { $0.id == item.id } ?? item
        removeLinkPreviewFiles(for: currentItem)
        removeAssetFiles(for: [currentItem], remainingItems: model.items.filter { $0.id != item.id })
        model.remove(item.id)
        return
      }

      var updated = item
      let previousContentKey = updated.contentKey
      updated.text = text
      updated.byteSize = text.utf8.count
      updated.kind = ClipboardKind.classifyText(text, treatDigitNumbersAsColor: model.preferences.treatDigitNumbersAsColor)
      if item.kind == .richText {
        updated.removeFormatting()
      }
      if updated.kind != .link || updated.contentKey != previousContentKey {
        removeLinkPreviewFiles(for: updated)
        updated.linkPreviewDetails = nil
      }
      updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func transform(_ item: ClipboardItem, using transform: ClipboardTextTransform) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard let text = item.text else {
      model.lastError = "\(item.kind.title) cannot be transformed."
      return
    }

    do {
      var updated = item
      let previousContentKey = updated.contentKey
      let transformedText = transform.apply(to: text)
      updated.text = transformedText
      updated.byteSize = transformedText.utf8.count
      updated.kind = ClipboardKind.classifyText(
        transformedText,
        treatDigitNumbersAsColor: model.preferences.treatDigitNumbersAsColor
      )
      if item.kind == .richText {
        updated.removeFormatting()
      }
      if updated.kind != .link || updated.contentKey != previousContentKey {
        removeLinkPreviewFiles(for: updated)
        updated.linkPreviewDetails = nil
      }
      updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func toggleTag(_ tag: Tag, for item: ClipboardItem) {
    updateTags(for: item) { tags in
      if tags.contains(tag.id) {
        tags.removeAll { $0 == tag.id }
      } else {
        tags.append(tag.id)
      }
    }
  }

  func addTag(_ tag: Tag, to item: ClipboardItem) {
    updateTags(for: item) { tags in
      guard !tags.contains(tag.id) else {
        return
      }
      tags.append(tag.id)
    }
  }

  @discardableResult
  func createTag(name: String, color: NSColor) -> Tag? {
    do {
      let tag = try historyStore.createTag(name: name, color: color.tagHexString)
      if let index = model.tags.firstIndex(where: { $0.id == tag.id }) {
        model.tags[index] = tag
      } else {
        model.tags.append(tag)
      }
      return tag
    } catch {
      model.lastError = error.localizedDescription
      return nil
    }
  }

  func createTag(name: String, color: NSColor, for item: ClipboardItem) {
    if let tag = createTag(name: name, color: color) {
      addTag(tag, to: item)
    }
  }

  func updateTag(_ tag: Tag, name: String, color: NSColor) {
    do {
      let updatedTag = try historyStore.updateTag(id: tag.id, name: name, color: color.tagHexString)
      if let index = model.tags.firstIndex(where: { $0.id == tag.id }) {
        model.tags[index] = updatedTag
      } else {
        model.tags.append(updatedTag)
      }
      try rebuildSearchTextForItemsReferencingTag(tag.id)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  func deleteTag(_ tag: Tag) {
    do {
      try historyStore.deleteTag(id: tag.id)
      model.tags.removeAll { $0.id == tag.id }
      model.selectedHistoryFilterTagIDs.remove(tag.id)

      for item in model.items where item.tags.contains(tag.id) {
        var updated = item
        updated.tags.removeAll { $0 == tag.id }
        updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
        try historyStore.upsert(updated)
        model.replace(updated)
      }
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func updateTags(for item: ClipboardItem, update: (inout [Int]) -> Void) {
    do {
      var updated = item
      update(&updated.tags)
      let tagNamesByID = Dictionary(uniqueKeysWithValues: model.tags.map { ($0.id, $0.name) })
      updated.tags.sort {
        (tagNamesByID[$0] ?? "").localizedCaseInsensitiveCompare(tagNamesByID[$1] ?? "") == .orderedAscending
      }
      updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
      try historyStore.upsert(updated)
      model.replace(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func rebuildSearchTextForItemsReferencingTag(_ tagID: Tag.ID) throws {
    for item in model.items where item.tags.contains(tagID) {
      let updated = item.rebuildingSearchText(tagNames: model.tagNames(for: item.tags))
      try historyStore.upsert(updated)
      model.replace(updated)
    }
  }

  func openInBrowser(_ item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard let url = item.browserURL else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  @discardableResult
  func saveImageAsFile(_ item: ClipboardItem, presenting window: NSWindow, completion: (() -> Void)? = nil) -> Bool {
    guard allowsUsingHistoryItems() else {
      completion?()
      return false
    }

    guard item.kind == .image,
          let assetURL = item.assetURL else {
      model.lastError = ClipboardImageExportError.unsupportedItem.localizedDescription
      completion?()
      return false
    }

    guard fileManager.fileExists(atPath: assetURL.path) else {
      model.lastError = ClipboardImageExportError.missingImageFile.localizedDescription
      completion?()
      return false
    }

    let panel = NSSavePanel()
    panel.title = L10n.string("Save Image")
    panel.nameFieldStringValue = defaultImageExportFileName(for: item)
    panel.allowedContentTypes = [.png]
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false

    panel.beginSheetModal(for: window) { [weak self] response in
      defer {
        completion?()
      }

      guard response == .OK, let destinationURL = panel.url else {
        return
      }

      do {
        let data = try Data(contentsOf: assetURL)
        try data.write(to: destinationURL, options: .atomic)
      } catch {
        self?.model.lastError = error.localizedDescription
      }
    }

    return true
  }

  func loadLinkPreviewIfNeeded(for item: ClipboardItem) {
    guard model.preferences.showPreviewForLinks,
          item.kind == .link,
          item.linkPreviewDetails == nil,
          pendingLinkPreviewModelUpdatesByItemID[item.id] == nil else {
      return
    }

    updateLinkPreview(for: item, force: false)
  }

  func updateLink(_ item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    updateLinkPreview(for: item, force: true)
  }

  func openInAssociatedApplication(_ item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    // A link opens in the browser that handles its address, the same
    // application the preview names on its Open in ... button.
    guard let url = item.quickLookURL ?? item.browserURL,
          let application = AssociatedApplication.forOpening(url, iconSize: NSSize(width: 22, height: 22)) else {
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    weak let weakSelf = self
    NSWorkspace.shared.open([url], withApplicationAt: application.url, configuration: configuration) { _, error in
      if let error {
        let message = error.localizedDescription
        Task { @MainActor in
          weakSelf?.model.lastError = message
        }
      }
    }
  }

  func open(_ item: ClipboardItem, with applicationURL: URL) {
    guard allowsUsingHistoryItems() else {
      return
    }

    guard let url = item.quickLookURL else {
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    weak let weakSelf = self
    NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
      if let error {
        let message = error.localizedDescription
        Task { @MainActor in
          weakSelf?.model.lastError = message
        }
      }
    }
  }

  private func defaultImageExportFileName(for item: ClipboardItem) -> String {
    guard let dimensions = item.imageDimensions else {
      return "image.png"
    }

    return "image_\(dimensions.width)x\(dimensions.height).png"
  }

  private func mergedText(from items: [ClipboardItem]) -> String? {
    let contents = items.compactMap(mergeText(for:))
    guard contents.count == items.count else {
      return nil
    }

    return contents.joined(separator: "\n")
  }

  private func updateLinkPreview(for item: ClipboardItem, force: Bool) {
    guard item.kind == .link,
          let url = item.browserURL,
          force || item.linkPreviewDetails == nil,
          force || pendingLinkPreviewModelUpdatesByItemID[item.id] == nil,
          linkPreviewTasksByItemID[item.id] == nil else {
      return
    }

    linkPreviewTasksByItemID[item.id] = Task { [weak self, linkPreviewFetcher] in
      let preview = await linkPreviewFetcher.fetchPreview(for: url)
      // A cancelled fetch returns no preview, which is not the page having none.
      let isCancelled = Task.isCancelled
      await MainActor.run {
        guard let self else {
          return
        }

        self.linkPreviewTasksByItemID[item.id] = nil
        guard !isCancelled else {
          return
        }

        self.persistLinkPreview(preview, itemID: item.id, url: url)
      }
    }
  }

  private func persistLinkPreview(_ preview: LinkPreview?, itemID: ClipboardItem.ID, url: URL) {
    // The item may have been deleted while its page was fetched. Saving the
    // preview then would leave its files behind and write the deleted item
    // back to the store, where it came back on the next launch.
    guard var updated = model.items.first(where: { $0.id == itemID }) else {
      return
    }

    do {
      removeLinkPreviewFiles(for: updated)
      let imagePath = try writeLinkPreviewImage(preview?.image, itemID: updated.id, suffix: "preview")
      let faviconPath = try writeLinkPreviewImage(preview?.favicon, itemID: updated.id, suffix: "favicon")
      updated.linkPreviewDetails = LinkPreviewDetails(
        url: ClipboardItem.normalizedLinkContentKey(for: url),
        title: preview?.title,
        description: preview?.description,
        imagePath: imagePath,
        faviconPath: faviconPath,
        fetchedAt: Date()
      )
      updated = updated.rebuildingSearchText(tagNames: model.tagNames(for: updated.tags))
      try historyStore.upsert(updated)
      scheduleLinkPreviewModelUpdate(updated)
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func scheduleLinkPreviewModelUpdate(_ item: ClipboardItem) {
    pendingLinkPreviewModelUpdatesByItemID[item.id] = item
    linkPreviewModelUpdateTask?.cancel()

    linkPreviewModelUpdateTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 150_000_000)
      guard !Task.isCancelled else {
        return
      }

      self?.applyPendingLinkPreviewModelUpdates()
    }
  }

  private func applyPendingLinkPreviewModelUpdates() {
    let updates = Array(pendingLinkPreviewModelUpdatesByItemID.values)
    pendingLinkPreviewModelUpdatesByItemID.removeAll()
    linkPreviewModelUpdateTask = nil

    guard !updates.isEmpty else {
      return
    }

    model.replace(updates)
  }

  private var linkPreviewsDirectory: URL {
    supportDirectory.appendingPathComponent("LinkPreviews", isDirectory: true)
  }

  private func writeLinkPreviewImage(_ image: NSImage?, itemID: UUID, suffix: String) throws -> String? {
    guard let image,
          let data = pngData(from: image) else {
      return nil
    }

    try fileManager.createDirectory(at: linkPreviewsDirectory, withIntermediateDirectories: true)
    let url = linkPreviewsDirectory.appendingPathComponent("\(itemID.uuidString)-\(suffix).png")
    try data.write(to: url, options: .atomic)
    return url.path
  }

  private func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff) else {
      return nil
    }

    return representation.representation(using: .png, properties: [:])
  }

  /// The item with the formatting its history copy comes without.
  func loadingFormatting(of item: ClipboardItem) -> ClipboardItem {
    (try? historyStore.loadingFormatting(of: item)) ?? item
  }

  private func removeLinkPreviewFiles(for item: ClipboardItem) {
    guard let details = item.linkPreviewDetails else {
      return
    }

    [details.imagePath, details.faviconPath].forEach { path in
      guard let path else {
        return
      }

      try? fileManager.removeItem(atPath: path)
    }
  }

  private var imagesDirectory: URL {
    supportDirectory.appendingPathComponent("Images", isDirectory: true)
  }

  /// Deletes the image files of deleted items. Each captured or imported image
  /// has a file of its own, but a file another item still names is kept
  /// anyway, and nothing outside the images folder is ever deleted.
  private func removeAssetFiles(for deletedItems: [ClipboardItem], remainingItems: [ClipboardItem]) {
    let deletedPaths = Set(deletedItems.compactMap(\.assetPath))
    guard !deletedPaths.isEmpty else {
      return
    }

    let remainingPaths = Set(remainingItems.compactMap(\.assetPath))
    let imagesDirectoryPath = imagesDirectory.standardizedFileURL.path + "/"
    for path in deletedPaths.subtracting(remainingPaths)
    where URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(imagesDirectoryPath) {
      try? fileManager.removeItem(atPath: path)
    }
  }

  /// Deletes the files in the images and link previews folders that no item
  /// names any more. They were left behind by versions that kept the files of
  /// a deleted item or saved a link preview for an item deleted while it was
  /// fetched, and by an import that replaced an item, which copies its files
  /// again under new names. The store is read in the background, and a file
  /// changed in the last few minutes is kept, since a capture, a link preview
  /// or an import writes the file before it saves the item.
  private func removeOrphanedStoredFiles() {
    nonisolated(unsafe) let fileManager = self.fileManager
    nonisolated(unsafe) let historyStore = self.historyStore
    let directories = [imagesDirectory, linkPreviewsDirectory]
    // The loaded items must all be among the files the store reports, or the
    // store was not read right and nothing is deleted.
    let loadedFileNames = Set(model.items.flatMap(\.storedFilePaths).map { URL(fileURLWithPath: $0).lastPathComponent })
    let minimumAge = Self.orphanedStoredFileMinimumAge

    DispatchQueue.global(qos: .utility).async {
      guard let referencedPaths = try? historyStore.fetchStoredFilePaths() else {
        return
      }

      // Files are matched by name, so a history whose files moved with a
      // renamed home folder keeps them. The names start with the item's ID,
      // so no two items share one.
      let referencedFileNames = Set(referencedPaths.map { URL(fileURLWithPath: $0).lastPathComponent })
      guard loadedFileNames.isSubset(of: referencedFileNames) else {
        return
      }

      let cutoff = Date().addingTimeInterval(-minimumAge)
      for directory in directories {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
          options: [.skipsHiddenFiles]
        ) else {
          continue
        }

        for fileURL in fileURLs where !referencedFileNames.contains(fileURL.lastPathComponent) {
          guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let modifiedAt = values.contentModificationDate,
                modifiedAt < cutoff else {
            continue
          }

          try? fileManager.removeItem(at: fileURL)
        }
      }
    }
  }

  private func removeFilePreviewFiles(for deletedItems: [ClipboardItem], remainingItems: [ClipboardItem]) {
    let deletedFilePaths = Set(deletedItems.flatMap(\.filePaths))
    guard !deletedFilePaths.isEmpty else {
      return
    }

    let remainingFilePaths = Set(remainingItems.flatMap(\.filePaths))
    filePreviewCache.removePreviews(forFilePaths: deletedFilePaths.subtracting(remainingFilePaths))
  }

  private func pruneFilePreviewCache() {
    filePreviewCache.prune(keepingFilePaths: Set(model.items.flatMap(\.filePaths)))
  }

  private func cancelLinkPreviewTasks() {
    linkPreviewTasksByItemID.values.forEach { $0.cancel() }
    linkPreviewTasksByItemID.removeAll()
    linkPreviewModelUpdateTask?.cancel()
    linkPreviewModelUpdateTask = nil
    pendingLinkPreviewModelUpdatesByItemID.removeAll()
  }

  private func mergeText(for item: ClipboardItem) -> String? {
    switch item.kind {
    case .text, .richText, .link, .email, .color:
      return item.text
    case .file:
      return item.filePaths.isEmpty ? nil : item.filePaths.joined(separator: "\n")
    case .image:
      return nil
    }
  }

  private func splitTextParts(for item: ClipboardItem) -> [String] {
    guard item.kind == .text || item.kind == .richText,
          let text = item.text,
          text.contains(where: \.isNewline) else {
      return []
    }

    return text
      .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func deleteExistingMatches(for item: ClipboardItem) throws {
    for existingItem in model.items where existingItem.kind == item.kind && existingItem.searchText == item.searchText {
      try historyStore.delete(existingItem.id)
      let remainingItems = model.items.filter { $0.id != existingItem.id }
      removeFilePreviewFiles(for: [existingItem], remainingItems: remainingItems)
      removeAssetFiles(for: [existingItem], remainingItems: remainingItems)
    }
  }

  private func recordHistoryAction(for item: ClipboardItem, incrementsCopyCount: Bool) throws -> ClipboardItem? {
    let copiedAt = model.preferences.updatesHistoryAfterAction ? Date() : nil
    guard copiedAt != nil || incrementsCopyCount else {
      return nil
    }

    return try historyStore.recordAction(item.id, copiedAt: copiedAt, incrementsCopyCount: incrementsCopyCount)
  }

  private func interruptCopySequenceTracking() {
    clipboardMonitor.markCopySequencePasteBoundary()
  }
  
  func showInFinder(_ item: ClipboardItem) {
    guard allowsUsingHistoryItems() else {
      return
    }

    if let url = item.quickLookURL {
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }
  }
  
  func checkForUpdates() {
    updateService.checkForUpdates(presenting: NSApp.keyWindow)
  }

  func rememberPasteTarget() {
    pasteService.rememberPasteTarget()
  }
  
  private func configurePanel() {
    if historyWindow == nil {
      historyWindow = HistoryWindow(model: model, coordinator: self)
    }
  }

  // The trial runs for the days the history was opened on, so opening it is
  // what counts as using the app.
  private func recordTrialUsage() {
    #if CLIPBOOK_COMMERCIAL
    licensingService.recordTrialUsage(licenseKey: model.preferences.licenseKey)
    #endif
    updateTrialNotice()
  }

  /// `true` when items may be used. Otherwise the attempt is pointed out, and
  /// the caller does nothing.
  private func allowsUsingHistoryItems() -> Bool {
    guard isHistoryReadOnly else {
      return true
    }

    notifyReadOnlyHistoryActionAttempt()
    return false
  }

  func notifyReadOnlyHistoryActionAttempt() {
    NSSound.beep()
    readOnlyHistoryActionAttempts.send()
  }

  func updateTrialNotice(now: Date = Date()) {
    let notice: TrialNotice?
    switch licenseState {
    case .trial(let daysLeft) where daysLeft <= TrialOffer.daysLeftToShowNotice:
      if let dismissedDaysLeft = model.preferences.dismissedTrialNoticeDaysLeft, daysLeft >= dismissedDaysLeft {
        notice = nil
      } else {
        notice = .endingSoon(daysLeft: daysLeft)
      }
    case .trialExpired:
      if let offeredAt = model.preferences.trialDiscountOfferedAt,
         now < offeredAt.addingTimeInterval(TrialOffer.discountDuration) {
        notice = .discount(endsAt: offeredAt.addingTimeInterval(TrialOffer.discountDuration))
      } else {
        notice = .ended
      }
    default:
      notice = nil
    }

    if trialNotice != notice {
      trialNotice = notice
    }
  }

  func dismissTrialNotice() {
    guard case .endingSoon(let daysLeft) = trialNotice else {
      return
    }

    model.preferences.dismissedTrialNoticeDaysLeft = daysLeft
    persistPreferences()
    updateTrialNotice()
  }

  /// Shows the discount again, from the notice above the history.
  func showTrialDiscountOffer() {
    guard case .discount(let endsAt) = trialNotice,
          Date() < endsAt,
          !isTrialSheetPresented,
          historyWindow?.isVisible == true else {
      return
    }

    _ = presentTrialSheet(.discount(endsAt: endsAt))
  }

  func copyTrialDiscountCode() {
    // Marked so the code doesn't end up in the history it is meant to unlock.
    try? pasteService.copyText(TrialOffer.discountCode, markAsGhost: true)
    playSound(.copy)
  }

  /// The history shows the dialog about the end of the trial the first time it
  /// opens after the trial, and the discount a week later if the app is still
  /// in use. From then on the notice above the history takes over.
  private func presentTrialSheetIfNeeded(now: Date = Date()) {
    guard licenseState.isTrialExpired,
          !isTrialSheetPresented,
          historyWindow?.isVisible == true else {
      return
    }

    guard let trialExpiredAt = model.preferences.trialExpiredAt else {
      if presentTrialSheet(.trialExpired) {
        model.preferences.trialExpiredAt = now
        persistPreferences()
      }
      return
    }

    guard model.preferences.trialDiscountOfferedAt == nil,
          now >= trialExpiredAt.addingTimeInterval(TrialOffer.delayBeforeDiscount) else {
      return
    }

    let discountEndsAt = now.addingTimeInterval(TrialOffer.discountDuration)
    if presentTrialSheet(.discount(endsAt: discountEndsAt)) {
      model.preferences.trialDiscountOfferedAt = now
      persistPreferences()
      updateTrialNotice(now: now)
    }
  }

  private func presentTrialSheet(_ sheet: TrialSheet) -> Bool {
    guard let historyWindow else {
      return false
    }

    // The dialog is a sheet of the panel, like the item preview, so it takes
    // text without the app turning into a regular one. Switching back to an
    // accessory app once it closes would take the panel off the screen for a
    // moment.
    let didPresentSheet = historyWindow.showTrialSheet(
      sheet,
      hasProvidedFeedback: model.preferences.hasProvidedTrialExpiredFeedback,
      onSendFeedback: { [weak self] feedback in
        self?.sendTrialExpiredFeedback(feedback)
      },
      onCopyDiscountCode: { [weak self] in
        self?.copyTrialDiscountCode()
      },
      onDismiss: { [weak self] action in
        guard let self else {
          return
        }

        self.isTrialSheetPresented = false
        switch action {
        case .close:
          // The history stays open to be looked through read-only.
          break
        case .activateLicense:
          self.hideHistoryPanel()
          self.openSettings(section: .license)
        case .buyLicense:
          self.hideHistoryPanel()
          self.openBuyLicenseURL()
        }
      }
    )
    isTrialSheetPresented = didPresentSheet
    return didPresentSheet
  }

  #if DEBUG
  // Launching with `-DebugTrialExpiredDaysAgo <days>` (together with
  // `-DebugTrialDaysLeft 0`) previews the dialogs and notices that follow the
  // trial: 0 shows the trial-ended dialog, 7 or more the discount. Adding
  // `-DebugTrialDiscountOfferedHoursAgo <hours>` previews the running offer.
  private func applyDebugTrialDates() {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: "DebugTrialExpiredDaysAgo") != nil else {
      return
    }

    let now = Date()
    let daysAgo = defaults.double(forKey: "DebugTrialExpiredDaysAgo")
    model.preferences.trialExpiredAt = daysAgo > 0 ? now.addingTimeInterval(-daysAgo * 24 * 60 * 60) : nil
    model.preferences.trialDiscountOfferedAt = defaults.object(forKey: "DebugTrialDiscountOfferedHoursAgo") == nil
      ? nil
      : now.addingTimeInterval(-defaults.double(forKey: "DebugTrialDiscountOfferedHoursAgo") * 60 * 60)
    model.preferences.dismissedTrialNoticeDaysLeft = nil
  }
  #endif

  // A visible panel that lost key focus (a pinned one, for instance) is
  // brought back rather than closed, so the shortcut still reaches it.
  private func handleShowHistoryShortcut() {
    if model.preferences.showHistoryShortcutClosesHistory, historyWindow?.isKeyAndVisible == true {
      hideHistoryPanel()
      return
    }

    showHistoryPanel()
  }

  // A registered global shortcut is taken by the system before it reaches any
  // window, so the shortcut recorder in Settings would trigger the action
  // instead of capturing the combination.
  func setGlobalShortcutsSuspended(_ isSuspended: Bool) {
    guard areGlobalShortcutsSuspended != isSuspended else {
      return
    }

    areGlobalShortcutsSuspended = isSuspended
    configureShortcuts()
  }

  private func configureShortcuts() {
    globalShortcuts.unregisterAll()
    guard !areGlobalShortcutsSuspended else {
      return
    }

    globalShortcuts.register(.showHistory, shortcut: model.preferences.showHistoryShortcut) { [weak self] in
      Task { @MainActor in
        self?.handleShowHistoryShortcut()
      }
    }
    globalShortcuts.register(.pauseCapture, shortcut: model.preferences.pauseShortcut) { [weak self] in
      Task { @MainActor in
        self?.togglePaused()
      }
    }
    globalShortcuts.register(.pasteNext, shortcut: model.preferences.pasteNextShortcut) { [weak self] in
      Task { @MainActor in
        self?.pasteNextItemFromGlobalShortcut(variant: nil)
      }
    }
    globalShortcuts.register(.pasteNextRich, shortcut: model.preferences.pasteNextRichShortcut) { [weak self] in
      Task { @MainActor in
        self?.pasteNextItemFromGlobalShortcut(variant: .standard)
      }
    }
    globalShortcuts.register(.pasteNextAndDelete, shortcut: model.preferences.pasteNextAndDeleteShortcut) { [weak self] in
      Task { @MainActor in
        self?.pasteNextItemFromGlobalShortcut(variant: nil, deletesAfterPaste: true)
      }
    }
    globalShortcuts.register(.pasteNextRichAndDelete, shortcut: model.preferences.pasteNextRichAndDeleteShortcut) { [weak self] in
      Task { @MainActor in
        self?.pasteNextItemFromGlobalShortcut(variant: .standard, deletesAfterPaste: true)
      }
    }
  }
  
  private func loadHistory() {
    do {
      model.tags = try historyStore.fetchTags()
      model.items = try historyStore.fetchAll()
      pruneFilePreviewCache()
      removeOrphanedStoredFiles()
      model.selectedItemID = model.items.first?.id
      model.selectedItemIDs = model.selectedItemID.map { [$0] } ?? []
      model.selectedItemIDsInSelectionOrder = model.selectedItemID.map { [$0] } ?? []
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func clearHistoryAfterRebootIfNeeded() {
    let currentBootTime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime).timeIntervalSince1970
    let defaults = UserDefaults.standard
    let previousBootTime = defaults.object(forKey: lastKnownBootTimeKey) as? Double
    defaults.set(currentBootTime, forKey: lastKnownBootTimeKey)

    guard model.preferences.clearHistoryOnReboot,
          let previousBootTime,
          abs(previousBootTime - currentBootTime) > 60 else {
      return
    }

    clearHistory()
  }

  private func shouldKeepWhenClearingHistory(_ item: ClipboardItem) -> Bool {
    item.isFavorite || !item.tags.isEmpty
  }

  private func shouldProceedWithClearHistory(isNarrowed: Bool) -> Bool {
    guard model.preferences.warnOnClearHistory else {
      return true
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    let keepsProtectedItems = model.preferences.keepFavoritesOnClearHistory
    if isNarrowed {
      alert.messageText = L10n.string("Are you sure you want to delete all filtered history items?")
      if keepsProtectedItems {
        alert.informativeText = L10n.string("This will delete the history items currently shown, except favorites and tagged items. This action cannot be undone.")
      } else {
        alert.informativeText = L10n.string("This will delete the history items currently shown, including favorites and tagged items. This action cannot be undone.")
      }
    } else {
      alert.messageText = L10n.string("Are you sure you want to clear entire history?")
      if keepsProtectedItems {
        alert.informativeText = L10n.string("This will delete all history items except favorites and tagged items. This action cannot be undone.")
      } else {
        alert.informativeText = L10n.string("This will delete all history items including favorites and tagged items. This action cannot be undone.")
      }
    }
    let deleteAllButton = alert.addButton(withTitle: L10n.string("Delete All"))
    deleteAllButton.hasDestructiveAction = true
    alert.addButton(withTitle: L10n.string("Cancel"))
    return alert.runModal() == .alertFirstButtonReturn
  }
  
  private func applyAppearance() {
    switch model.preferences.appearance {
    case .system:
      NSApp.appearance = nil
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }

  private func applyLanguage() {
    let previousLanguage = L10n.languageIdentifier
    L10n.setLanguage(model.preferences.language)
    let appliedLanguage = L10n.languageIdentifier
    if model.preferences.language != appliedLanguage {
      model.preferences.language = appliedLanguage
    }
    if previousLanguage != appliedLanguage {
      model.localizationRevision = UUID()
    }
  }
  
  private func showAccessibilityAlertIfNeeded(_ error: Error) {
    guard case PasteServiceError.accessibilityPermissionRequired = error else {
      return
    }
    let alert = NSAlert()
    alert.messageText = L10n.string("Accessibility permission is required")
    alert.informativeText = L10n.string("ClipBook needs Accessibility permission to paste into the previously active app.")
    alert.addButton(withTitle: L10n.string("Open Settings"))
    alert.addButton(withTitle: L10n.string("Cancel"))
    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermission.openSettings()
    }
  }

  func playSound(_ effect: SoundEffect) {
    guard model.preferences.isSoundEffectEnabled(effect) else {
      return
    }

    soundService.play(effect)
  }

  // Previews are played from Settings when a sound effect is switched on, so
  // they ignore the preferences the user is currently editing.
  func previewSound(_ effect: SoundEffect) {
    soundService.play(effect)
  }
}

private extension NSColor {
  var tagHexString: String {
    let color = usingColorSpace(.sRGB) ?? self
    let red = max(0, min(255, Int(round(color.redComponent * 255))))
    let green = max(0, min(255, Int(round(color.greenComponent * 255))))
    let blue = max(0, min(255, Int(round(color.blueComponent * 255))))
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}

extension AppCoordinator: PasteboardMonitorDelegate {
  func pasteboardMonitor(
    _ monitor: PasteboardMonitor,
    didCapture item: ClipboardItem,
    updatedItems: [ClipboardItem]
  ) {
    updatedItems.forEach(model.replace)
    model.insert(item)
    applyRetention()
    resetPasteNextPointer()
    playSound(.copy)
  }

  func pasteboardMonitor(
    _ monitor: PasteboardMonitor,
    didRecognize content: RecognizedImageContent,
    inItemWithID itemID: ClipboardItem.ID
  ) {
    // The item may have been deleted while its image was read.
    guard var item = model.items.first(where: { $0.id == itemID }),
          item.text != content.text || item.qrCodeText != content.qrCodeText else {
      return
    }

    item.text = content.text
    item.qrCodeText = content.qrCodeText
    item = item.rebuildingSearchText(tagNames: model.tagNames(for: item.tags))
    do {
      try historyStore.upsert(item)
      model.replace(item)
    } catch {
      model.lastError = error.localizedDescription
    }
  }
}
