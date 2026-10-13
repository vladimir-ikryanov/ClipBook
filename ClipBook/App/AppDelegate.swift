import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
  let model: AppModel
  let coordinator: AppCoordinator
  
  private let preferencesStore: PreferencesStore
  private let historyStore: HistoryStore
  private let clipboardMonitor: PasteboardMonitor
  private let pasteService: PasteService
  private let globalShortcuts: GlobalShortcutService
  private let updateService: UpdateService
  private let licensingService: LicensingService
  private var statusItem: NSStatusItem?
  private var historyMenuItem: NSMenuItem?
  private var isQuitConfirmed = false
  private var isQuitConfirmationPresented = false
  private var statusCancellables: Set<AnyCancellable> = []
  
  override init() {
    let fileManager = FileManager.default
    let supportDirectory = AppDirectories.applicationSupport(fileManager: fileManager)
    preferencesStore = PreferencesStore()
    historyStore = SQLiteHistoryStore(directory: supportDirectory)
    model = AppModel()
    pasteService = PasteService { [historyStore] item in
      (try? historyStore.loadingFormatting(of: item)) ?? item
    }
    globalShortcuts = GlobalShortcutService()
    updateService = SparkleUpdateService()
    licensingService = LicensingService()
    clipboardMonitor = PasteboardMonitor(historyStore: historyStore, fileManager: fileManager, supportDirectory: supportDirectory)
    coordinator = AppCoordinator(
      model: model,
      preferencesStore: preferencesStore,
      historyStore: historyStore,
      clipboardMonitor: clipboardMonitor,
      pasteService: pasteService,
      globalShortcuts: globalShortcuts,
      updateService: updateService,
      licensingService: licensingService,
      fileManager: fileManager,
      supportDirectory: supportDirectory
    )
    super.init()
  }
  
  // Window tabbing has no use in an app with a single panel, and leaving it on
  // makes AppKit add "Show Tab Bar" and "Show All Tabs" to the View menu.
  func applicationWillFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false
    // ClipBook has no fields for passwords, contacts or card numbers. With the
    // AutoFill heuristics on, the first focused text field makes macOS launch
    // a separate "AutoFill (ClipBook)" helper process that stays alive for as
    // long as the app runs.
    UserDefaults.standard.register(defaults: ["NSAutoFillHeuristicsEnabled": false])
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    coordinator.start()
    configureStatusItem()
    configureHistoryMenu()
    observeStatusItemState()
  }
  
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    // Quitting again while the question is on screen would stack a second one.
    guard !isQuitConfirmationPresented else {
      return .terminateCancel
    }

    guard shouldConfirmQuit else {
      return .terminateNow
    }

    confirmQuit { confirmed in
      sender.reply(toApplicationShouldTerminate: confirmed)
    }
    return .terminateLater
  }

  /// Cmd+Q and the ClipBook menu ask first only while the history window or
  /// Settings is open. A quit requested by the system (logout, shutdown),
  /// another app or the updater is never held up by a dialog.
  private var shouldConfirmQuit: Bool {
    !isQuitConfirmed
      && NSAppleEventManager.shared().currentAppleEvent == nil
      && !updateService.isRelaunchingToInstallUpdate
      && coordinator.quitConfirmationWindow != nil
  }

  /// Asks on the window the user is in, as a sheet: a standalone alert would
  /// take key focus from the history window, which then hides itself, so it
  /// would be gone after Cancel.
  private func confirmQuit(completion: @escaping (Bool) -> Void) {
    isQuitConfirmationPresented = true
    let completion: (Bool) -> Void = { [weak self] confirmed in
      self?.isQuitConfirmationPresented = false
      completion(confirmed)
    }
    let alert = NSAlert()
    alert.messageText = L10n.string("Are you sure you want to quit ClipBook?")
    alert.informativeText = L10n.string("ClipBook won't save what you copy until you open it again.")
    alert.addButton(withTitle: L10n.string("Quit"))
    alert.addButton(withTitle: L10n.string("Cancel"))
    // The status bar menu can be used while another app is active, and the
    // alert would open behind that app's windows.
    NSApp.activate(ignoringOtherApps: true)

    guard let window = coordinator.quitConfirmationWindow else {
      completion(alert.runModal() == .alertFirstButtonReturn)
      return
    }

    // A sheet over another sheet does not go through the history window's
    // beginSheet, so it takes the hidden-from-screen-capture setting here.
    alert.window.sharingType = window.sharingType
    alert.beginSheetModal(for: window) { response in
      completion(response == .alertFirstButtonReturn)
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    coordinator.stop()
  }
  
  private func configureStatusItem() {
    guard model.preferences.showMenuBarIcon else {
      if let item = statusItem {
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
      }
      return
    }

    let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = Self.statusBarImage(isPaused: model.isPaused)
    item.button?.imagePosition = .imageOnly
    item.button?.toolTip = "ClipBook"
    item.menu = makeStatusMenu()
    statusItem = item
  }
  
  private func observeStatusItemState() {
    model.$items
      .combineLatest(model.$isPaused, model.$selectedItemID, model.$preferences)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.configureStatusItem()
        self?.configureHistoryMenu()
      }
      .store(in: &statusCancellables)

    model.$localizationRevision
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.configureStatusItem()
        self?.configureHistoryMenu()
      }
      .store(in: &statusCancellables)

    coordinator.$licenseState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.configureStatusItem()
      }
      .store(in: &statusCancellables)
  }
  
  /// Builds the History menu in the main menu bar.
  ///
  /// The menu is built with AppKit instead of a SwiftUI `CommandMenu` because
  /// SwiftUI keeps the titles and key equivalents its command items were
  /// created with: after a shortcut is reassigned the menu item still holds the
  /// previous key equivalent, so the old shortcut keeps triggering the action
  /// whenever ClipBook is the active app.
  private func configureHistoryMenu() {
    guard let mainMenu = NSApp.mainMenu else {
      return
    }

    let title = L10n.string("History")
    let item = historyMenuItem ?? NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.title = title
    item.submenu = makeHistoryMenu()
    historyMenuItem = item

    if !mainMenu.items.contains(item) {
      mainMenu.insertItem(item, at: historyMenuInsertionIndex(in: mainMenu))
    }
  }

  /// Keeps the History menu in its usual place, right before the Window menu.
  private func historyMenuInsertionIndex(in mainMenu: NSMenu) -> Int {
    if let windowsMenu = NSApp.windowsMenu,
       let index = mainMenu.items.firstIndex(where: { $0.submenu === windowsMenu }) {
      return index
    }

    return mainMenu.items.count
  }

  private func makeHistoryMenu() -> NSMenu {
    let menu = NSMenu(title: L10n.string("History"))
    menu.autoenablesItems = false

    let showHistoryItem = menuItem(L10n.string("Show Clipboard History"), action: #selector(toggleHistory))
    if let shortcut = KeyboardShortcutParser.menuItemKeyEquivalent(for: model.preferences.showHistoryShortcut) {
      showHistoryItem.keyEquivalent = shortcut.keyEquivalent
      showHistoryItem.keyEquivalentModifierMask = shortcut.modifierFlags
    }
    menu.addItem(showHistoryItem)

    let pauseItem = menuItem(
      model.isPaused ? L10n.string("Resume Clipboard Capture") : L10n.string("Pause Clipboard Capture"),
      action: #selector(togglePaused)
    )
    if let shortcut = KeyboardShortcutParser.menuItemKeyEquivalent(for: model.preferences.pauseShortcut) {
      pauseItem.keyEquivalent = shortcut.keyEquivalent
      pauseItem.keyEquivalentModifierMask = shortcut.modifierFlags
    }
    menu.addItem(pauseItem)
    return menu
  }

  private func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()
    let openClipBookItem = menuItem(L10n.string("Open ClipBook"), action: #selector(showHistory))
    if let shortcut = KeyboardShortcutParser.menuItemKeyEquivalent(for: model.preferences.showHistoryShortcut) {
      openClipBookItem.keyEquivalent = shortcut.keyEquivalent
      openClipBookItem.keyEquivalentModifierMask = shortcut.modifierFlags
    }
    menu.addItem(openClipBookItem)
    menu.addItem(.separator())
    menu.addItem(menuItem(L10n.string("About ClipBook"), action: #selector(aboutClipBook), systemImage: "info.circle"))
    menu.addItem(menuItem(L10n.string("Check for Updates..."), action: #selector(checkForUpdates), systemImage: "arrow.clockwise"))
    menu.addItem(menuItem(L10n.string("Settings..."), action: #selector(openSettings), keyEquivalent: ","))
    let trialTitle: String?
    switch coordinator.licenseState {
    case .trial(let daysLeft):
      trialTitle = L10n.string("Trial: %@ days left", String(daysLeft))
    case .trialExpired:
      trialTitle = L10n.string("Trial has ended")
    case .activated, .unavailable:
      trialTitle = nil
    }
    if let trialTitle {
      menu.addItem(.separator())
      let trialItem = NSMenuItem(title: trialTitle, action: nil, keyEquivalent: "")
      trialItem.isEnabled = false
      menu.addItem(trialItem)
      menu.addItem(menuItem(L10n.string("Buy License..."), action: #selector(buyLicense), systemImage: "checkmark.seal"))
    }
    menu.addItem(.separator())
    let pauseItem = menuItem(
      model.isPaused ? L10n.string("Resume") : L10n.string("Pause"),
      action: #selector(togglePaused),
      systemImage: model.isPaused ? "play.fill" : "pause.fill"
    )
    if let shortcut = KeyboardShortcutParser.menuItemKeyEquivalent(for: model.preferences.pauseShortcut) {
      pauseItem.keyEquivalent = shortcut.keyEquivalent
      pauseItem.keyEquivalentModifierMask = shortcut.modifierFlags
    }
    menu.addItem(pauseItem)
    menu.addItem(menuItem(L10n.string("Quit"), action: #selector(quit), systemImage: "power"))
    menu.showsItemImagesRegardlessOfSystemSetting()
    return menu
  }
  
  private func menuItem(_ title: String, action: Selector, keyEquivalent: String = "", systemImage: String? = nil, enabled: Bool = true) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.target = self
    item.isEnabled = enabled
    if let systemImage {
      item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
    }
    return item
  }
  
  private static func statusBarImage(isPaused: Bool) -> NSImage? {
    let imageName = isPaused ? "PausedStatusBarIcon" : "StatusBarIcon"
    let image = NSImage(named: imageName)
    image?.isTemplate = true
    return image
  }
  
  @objc private func showHistory() {
    DispatchQueue.main.async { [coordinator] in
      coordinator.showHistoryPanel()
    }
  }

  @objc private func toggleHistory() {
    DispatchQueue.main.async { [coordinator] in
      coordinator.toggleHistoryPanel()
    }
  }

  @objc private func togglePaused() {
    coordinator.togglePaused()
    configureStatusItem()
    configureHistoryMenu()
  }
  
  @objc private func aboutClipBook() {
    DispatchQueue.main.async { [coordinator] in
      coordinator.openSettings(section: .about)
    }
  }

  @objc private func openSettings() {
    coordinator.openSettings()
  }
  
  @objc private func checkForUpdates() {
    coordinator.checkForUpdates()
  }

  @objc private func buyLicense() {
    coordinator.openBuyLicenseURL()
  }
  
  @objc private func quit() {
    guard !isQuitConfirmationPresented else {
      return
    }

    confirmQuit { [weak self] confirmed in
      guard confirmed else {
        return
      }

      self?.isQuitConfirmed = true
      NSApp.terminate(nil)
    }
  }
}
