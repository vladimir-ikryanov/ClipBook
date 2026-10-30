import Foundation
import AppKit
import Carbon
import Combine

final class HistoryContentWindow: NSPanel {
  var onKeyDown: ((NSEvent) -> Bool)?

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }

  override func sendEvent(_ event: NSEvent) {
    // While an input method is composing (e.g. Japanese conversion), Return,
    // Escape, Space and the arrow keys belong to the input method, so the
    // window shortcuts must not see them.
    if event.type == .keyDown, !isComposingText, onKeyDown?(event) == true {
      return
    }

    super.sendEvent(event)
  }

  /// The sharing type the panel is meant to have. Once a window hidden from
  /// screen capture is made capturable again, the window server keeps it
  /// capturable and `sharingType` keeps returning `.none` (seen on macOS 27 in
  /// an app launched through Launch Services). So the panel keeps the value
  /// itself instead of reading it back.
  var screenCaptureSharingType: NSWindow.SharingType = .readOnly {
    didSet {
      if oldValue == .none, screenCaptureSharingType != .none {
        canBeHiddenFromScreenCapture = false
      }
      setSharingTypeIncludingAttachedWindows(screenCaptureSharingType)
    }
  }

  /// False once the panel was made capturable after being hidden from screen
  /// capture; hiding it again then takes a new window.
  private(set) var canBeHiddenFromScreenCapture = true

  // Sheets (dialogs and alerts) and child windows (search suggestions) take
  // the panel's sharing type before they are shown, so none of them shows up
  // in a screen share while the panel is hidden from it.
  override func beginSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
    sheetWindow.setSharingTypeIncludingAttachedWindows(screenCaptureSharingType)
    super.beginSheet(sheetWindow, completionHandler: handler)
  }

  override func beginCriticalSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
    sheetWindow.setSharingTypeIncludingAttachedWindows(screenCaptureSharingType)
    super.beginCriticalSheet(sheetWindow, completionHandler: handler)
  }

  override func addChildWindow(_ childWindow: NSWindow, ordered place: NSWindow.OrderingMode) {
    childWindow.setSharingTypeIncludingAttachedWindows(screenCaptureSharingType)
    super.addChildWindow(childWindow, ordered: place)
  }

  private var isComposingText: Bool {
    (firstResponder as? NSTextInputClient)?.hasMarkedText() ?? false
  }

  @discardableResult
  func position(using strategy: HistoryWindowOpenStrategy, savedOrigin: NSPoint?) -> NSPoint? {
    guard let origin = HistoryWindowPositioner.origin(
      for: strategy,
      windowSize: frame.size,
      savedOrigin: savedOrigin
    ) else {
      center()
      return nil
    }

    setFrameOrigin(origin)
    return origin
  }
}

enum HistoryWindowOpenStrategy: String, CaseIterable {
  case lastLocation
  case activeScreenCenter
  case activeWindowCenter
  case screenWithCursor
  case mouseCursor
  case inputCursor

  var title: String {
    switch self {
    case .lastLocation:
      return L10n.string("Last location")
    case .activeScreenCenter:
      return L10n.string("Active screen center")
    case .activeWindowCenter:
      return L10n.string("Active window center")
    case .screenWithCursor:
      return L10n.string("Screen with cursor")
    case .mouseCursor:
      return L10n.string("Mouse cursor")
    case .inputCursor:
      return L10n.string("Input cursor")
    }
  }

  init(preferenceValue: String) {
    switch preferenceValue {
    case Self.lastLocation.rawValue, "Last location":
      self = .lastLocation
    case Self.activeScreenCenter.rawValue, "Active screen center":
      self = .activeScreenCenter
    case Self.activeWindowCenter.rawValue, "Active window center":
      self = .activeWindowCenter
    case Self.screenWithCursor.rawValue, "Screen with cursor":
      self = .screenWithCursor
    case Self.mouseCursor.rawValue, "Mouse cursor":
      self = .mouseCursor
    case Self.inputCursor.rawValue, "Input cursor":
      self = .inputCursor
    default:
      self = .activeScreenCenter
    }
  }
}

final class HistoryWindow: NSObject, NSWindowDelegate {
  private static let minimumWindowSize = NSSize(width: 400, height: 400)
  private static let searchClearDelayAfterHide: TimeInterval = 15
  private static let keyFocusReturnDelayAfterPaste: TimeInterval = 0.25
  private static let levelAboveModalPanels = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue + 1)
  private static let defaultWindowSize = NSSize(
    width: AppPreferences.defaultHistoryWindowWidth,
    height: AppPreferences.defaultHistoryWindowHeight
  )

  private let model: AppModel
  private let coordinator: AppCoordinator
  private(set) var window: HistoryContentWindow
  private let contentViewController: HistoryContentViewController
  private let historyToolbar = HistoryToolbar()
  private var didRestoreWindowFrame = false
  private var shouldIgnoreNextResignKey = false
  private var clearSearchAfterHideWorkItem: DispatchWorkItem?
  private var appearanceNameWhenHidden: NSAppearance.Name?
  private var cancellables: Set<AnyCancellable> = []
  private var pendingScreenCaptureSharingType: NSWindow.SharingType?

  var isVisible: Bool {
    window.isVisible
  }

  var isKeyAndVisible: Bool {
    window.isVisible && window.isKeyWindow
  }
  
  init(model: AppModel, coordinator: AppCoordinator) {
    self.model = model
    self.coordinator = coordinator
    contentViewController = HistoryContentViewController(model: model, coordinator: coordinator)
    window = Self.makeWindow()
    super.init()
    historyToolbar.delegate = contentViewController
    contentViewController.attachToolbar(historyToolbar)
    configureWindow()
    window.center()

    // $preferences publishes before the new value is stored, so the value it
    // delivers is used rather than the one read back from the model.
    model.$preferences
      .map(\.showDuringScreenSharing)
      .removeDuplicates()
      .sink { [weak self] showDuringScreenSharing in
        self?.setScreenCaptureSharingType(showDuringScreenSharing ? .readOnly : .none)
      }
      .store(in: &cancellables)
  }

  private static func makeWindow() -> HistoryContentWindow {
    HistoryContentWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
      styleMask: [.titled, .fullSizeContentView, .resizable, .unifiedTitleAndToolbar, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
  }

  private func configureWindow() {
    window.contentViewController = contentViewController
    window.onKeyDown = { [weak contentViewController, weak window] event in
      contentViewController?.handleHistoryWindowKeyDown(event, firstResponder: window?.firstResponder) ?? false
    }
    window.delegate = self
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = !Self.usesNativeToolbarMaterial
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    configureToolbar()
    let trialNoticeAccessory = TrialNoticeAccessoryController(coordinator: coordinator)
    trialNoticeAccessory.onVisibilityChange = { [weak contentViewController] in
      contentViewController?.safeAreaDidChange()
    }
    window.addTitlebarAccessoryViewController(trialNoticeAccessory)
    window.applyMacOS26CornerRadiusIfNeeded()
    window.backgroundColor = HistoryAppearance.backgroundColor
    window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    applyPreferences()
    window.isReleasedWhenClosed = false
    window.isMovableByWindowBackground = true
    window.minSize = Self.minimumWindowSize
    // Disable window animation.
    window.animationBehavior = .none
  }

  private func setScreenCaptureSharingType(_ sharingType: NSWindow.SharingType) {
    pendingScreenCaptureSharingType = nil
    guard sharingType == .none, !window.canBeHiddenFromScreenCapture else {
      window.screenCaptureSharingType = sharingType
      return
    }

    // A sheet (an item preview with unsaved edits, for instance) cannot move
    // to another window, so the window is replaced once the sheet is closed.
    if window.attachedSheet == nil {
      replaceWindow(sharingType: sharingType)
    } else {
      pendingScreenCaptureSharingType = sharingType
    }
  }

  /// Moves the content to a new window, which the window server still lets be
  /// hidden from screen capture (see HistoryContentWindow.screenCaptureSharingType).
  private func replaceWindow(sharingType: NSWindow.SharingType) {
    pendingScreenCaptureSharingType = nil
    let oldWindow = window
    let wasVisible = oldWindow.isVisible
    let wasKey = oldWindow.isKeyWindow
    oldWindow.delegate = nil
    oldWindow.orderOut(nil)
    oldWindow.toolbar = nil
    oldWindow.contentViewController = nil
    oldWindow.close()

    window = Self.makeWindow()
    window.screenCaptureSharingType = sharingType
    configureWindow()
    window.setFrame(oldWindow.frame, display: false)
    guard wasVisible else {
      return
    }

    if wasKey {
      window.makeKeyAndOrderFront(nil)
    } else {
      window.orderFrontRegardless()
    }
  }

  private static var usesNativeToolbarMaterial: Bool {
    if #available(macOS 26.0, *) {
      return true
    }

    return false
  }

  private static func clampedWindowSize(_ size: NSSize) -> NSSize {
    var width = max(size.width, minimumWindowSize.width)
    var height = max(size.height, minimumWindowSize.height)

    if let screen = NSScreen.main {
      let visibleFrame = screen.visibleFrame
      width = min(width, visibleFrame.width)
      height = min(height, visibleFrame.height)
    }

    return NSSize(width: width, height: height)
  }

  private func restoreWindowFrame() {
    let savedSize = Self.clampedWindowSize(model.preferences.historyWindowSize)
    var frame = window.frame
    frame.size = savedSize
    if HistoryWindowOpenStrategy(preferenceValue: model.preferences.openWindowStrategy) == .lastLocation,
       let savedOrigin = model.preferences.historyWindowOrigin {
      frame.origin = savedOrigin
    }
    window.setFrame(frame, display: false)
  }

  // The frame is stored in one change of the preferences rather than one per
  // field, since everything that follows the preferences hears each change.
  func saveWindowFrame() {
    let frame = window.frame
    var preferences = model.preferences
    preferences.historyWindowX = frame.origin.x
    preferences.historyWindowY = frame.origin.y
    preferences.historyWindowWidth = frame.width
    preferences.historyWindowHeight = frame.height
    model.preferences = preferences
    coordinator.persistPreferences()
  }

  private func applySavedWindowFrameIfNeeded() {
    guard !didRestoreWindowFrame else {
      return
    }
    restoreWindowFrame()
    didRestoreWindowFrame = true
  }

  private func configureToolbar() {
    window.toolbar = historyToolbar.makeToolbar()
    window.toolbarStyle = .unified
  }
  
  /// With an anchor window the history opens beside it rather than where the
  /// settings say, so it leaves that window in view (onboarding, for one).
  func show(ignoresNextResignKey: Bool = false, beside anchorWindow: NSWindow? = nil) {
    let wasVisible = window.isVisible
    cancelSearchClearAfterHide()
    if ignoresNextResignKey {
      shouldIgnoreNextResignKey = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.shouldIgnoreNextResignKey = false
      }
    }
    applySavedWindowFrameIfNeeded()
    var openingOrigin: NSPoint?
    if !wasVisible {
      rebuildToolbarAfterHiddenAppearanceChangeIfNeeded()
      historyToolbar.applyAppearance(window.effectiveAppearance)
      openingOrigin = anchorWindow.flatMap(positionWindow(beside:)) ?? positionWindow()
    }
    window.applyMacOS26CornerRadiusIfNeeded()
    coordinator.rememberPasteTarget()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    contentViewController.refreshVisibleFilePreviews()
    if ignoresNextResignKey {
      DispatchQueue.main.async { [weak window] in
        window?.makeKey()
      }
    }

    guard !wasVisible else {
      return
    }

    contentViewController.selectHistoryItemOnOpen()

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.restoreWindowFrame()
      if let openingOrigin {
        self.window.setFrameOrigin(openingOrigin)
      } else {
        self.positionWindow()
      }
    }
  }
  
  func hide() {
    saveWindowFrame()
    recordAppearanceBeforeHiding()
    window.orderOut(nil)
    // Outside of a key or mouse event (the global shortcut that closes the
    // panel, the status bar menu) the panel stays on screen until the next
    // Core Animation commit, which can come a noticeable moment later.
    CATransaction.flush()
    scheduleSearchClearAfterHide()
    contentViewController.exitMultipleSelectionMode()
    contentViewController.hideRevealedSensitiveContent()
  }

  // Fast path used right before pasting: order the panel out instantly without
  // persisting the window frame, so there is no extra work on the paste hot path.
  func hideForPaste() {
    recordAppearanceBeforeHiding()
    window.orderOut(nil)
    scheduleSearchClearAfterHide()
    contentViewController.exitMultipleSelectionMode()
    contentViewController.hideRevealedSensitiveContent()
  }

  // Used by a pinned panel after key focus was handed to the paste target.
  // Raising the target window put it above this panel, so the panel is put
  // back in front right away (without key focus, which the target needs for
  // the keystroke) and becomes key again once the keystrokes have been
  // delivered, so it keeps taking keyboard input like any pinned panel.
  func retakeKeyFocusAfterPaste() {
    window.orderFrontRegardless()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyFocusReturnDelayAfterPaste) { [weak window] in
      guard let window, window.isVisible else {
        return
      }
      window.makeKey()
    }
  }

  private func recordAppearanceBeforeHiding() {
    appearanceNameWhenHidden = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
  }

  // The toolbar (item materials, scroll edge effect) caches its rendered
  // appearance and does not process appearance transitions while the panel is
  // ordered out; the stale rendering is then re-applied with an animation
  // shortly after the panel is shown again. Recreating the toolbar's view
  // hierarchy before showing the panel is the only reliable way to drop that
  // cached state.
  private func rebuildToolbarAfterHiddenAppearanceChangeIfNeeded() {
    let currentName = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
    guard let hiddenName = appearanceNameWhenHidden, hiddenName != currentName else {
      return
    }

    appearanceNameWhenHidden = currentName
    window.toolbar = nil
    configureToolbar()
  }

  func applyPreferences() {
    window.hidesOnDeactivate = false
    // Make the window behave as a floating window that doesn't steal focus from the current active app.
    window.isFloatingPanel = true
    updateWindowLevel()
  }

  // Some apps (Adobe Lightroom, for one) show their open and save dialogs at the
  // modal panel level, above floating windows. A panel that closes on focus loss
  // opens above them, as it can't get in the way for long. A pinned panel stays
  // floating so it never covers another app's dialog for as long as it is pinned,
  // and so does any panel while one of ClipBook's own modal dialogs is open.
  private func updateWindowLevel() {
    let level = model.preferences.hideOnFocusLoss && NSApp.modalWindow == nil
      ? Self.levelAboveModalPanels
      : NSWindow.Level.floating
    window.level = level
    window.childWindows?.forEach { $0.level = level }
  }

  func toggle() {
    window.isVisible ? hide() : show()
  }

  private static let anchorWindowGap: CGFloat = 16

  // Beside the anchor window's right edge, or its left one. When neither side
  // has room, the anchor window moves over so the two sit side by side in the
  // middle of the screen. Returns nil when even that does not fit.
  private func positionWindow(beside anchorWindow: NSWindow) -> NSPoint? {
    guard let visibleFrame = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame else {
      return nil
    }

    let size = window.frame.size
    let gap = Self.anchorWindowGap
    var anchorFrame = anchorWindow.frame
    guard size.width + gap + anchorFrame.width <= visibleFrame.width,
          size.height <= visibleFrame.height else {
      return nil
    }

    let y = min(max(anchorFrame.midY - size.height / 2, visibleFrame.minY), visibleFrame.maxY - size.height)
    let origin: NSPoint
    if anchorFrame.maxX + gap + size.width <= visibleFrame.maxX {
      origin = NSPoint(x: anchorFrame.maxX + gap, y: y)
    } else if anchorFrame.minX - gap - size.width >= visibleFrame.minX {
      origin = NSPoint(x: anchorFrame.minX - gap - size.width, y: y)
    } else {
      anchorFrame.origin.x = visibleFrame.midX - (anchorFrame.width + gap + size.width) / 2
      anchorWindow.setFrame(anchorFrame, display: true, animate: true)
      origin = NSPoint(x: anchorFrame.maxX + gap, y: y)
    }
    window.setFrameOrigin(origin)
    return origin
  }

  @discardableResult
  private func positionWindow() -> NSPoint? {
    let strategy = HistoryWindowOpenStrategy(preferenceValue: model.preferences.openWindowStrategy)
    return window.position(using: strategy, savedOrigin: model.preferences.historyWindowOrigin)
  }

  private func scheduleSearchClearAfterHide() {
    clearSearchAfterHideWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, !self.window.isVisible else {
        return
      }

      self.contentViewController.clearSearchAfterHiddenInterval()
      self.clearSearchAfterHideWorkItem = nil
    }
    clearSearchAfterHideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.searchClearDelayAfterHide, execute: workItem)
  }

  private func cancelSearchClearAfterHide() {
    clearSearchAfterHideWorkItem?.cancel()
    clearSearchAfterHideWorkItem = nil
  }
  
  func windowDidBecomeKey(_ notification: Notification) {
    updateWindowLevel()
  }

  func windowDidResignKey(_ notification: Notification) {
    updateWindowLevel()
    // Focus has not moved yet when this fires, and how long the window server
    // takes to settle varies, so look it up a few times over a short window.
    for delay in [0.05, 0.2, 0.5] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [coordinator] in
        coordinator.rememberPasteTarget()
      }
    }
    if shouldIgnoreNextResignKey {
      shouldIgnoreNextResignKey = false
      return
    }

    guard model.preferences.hideOnFocusLoss else {
      return
    }

    guard !contentViewController.isCommandPalettePresented,
          !contentViewController.isTagSheetPresented,
          !contentViewController.isModalPresentationPending,
          window.attachedSheet == nil else {
      return
    }

    hide()
  }

  func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
    (sheet as? CommandPaletteSheetWindow)?.positioningRect(in: window, proposedRect: rect) ?? rect
  }

  func windowDidEndSheet(_ notification: Notification) {
    // The code that ended the sheet may still use the window, so it is
    // replaced once that code has finished.
    DispatchQueue.main.async { [weak self] in
      guard let self,
            let sharingType = self.pendingScreenCaptureSharingType,
            self.window.attachedSheet == nil else {
        return
      }

      self.replaceWindow(sharingType: sharingType)
    }
  }

  func windowDidEndLiveResize(_ notification: Notification) {
    saveWindowFrame()
  }
}
