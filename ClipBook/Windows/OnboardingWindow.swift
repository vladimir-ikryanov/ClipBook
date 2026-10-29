import SwiftUI
import AppKit
import Combine

@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
  static let contentSize = NSSize(width: 500, height: 640)
  private static let toolbarIdentifier = NSToolbar.Identifier("OnboardingToolbar")

  private let coordinator: AppCoordinator
  private let onboardingModel: OnboardingModel
  let window: NSWindow

  var isVisible: Bool {
    window.isVisible
  }

  init(model: AppModel, coordinator: AppCoordinator) {
    self.coordinator = coordinator
    onboardingModel = OnboardingModel(appModel: model, coordinator: coordinator)
    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.contentSize),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    super.init()
    let hostingView = NSHostingView(rootView: OnboardingView(model: onboardingModel))
    // The window keeps the size set below; left to the hosting view, the
    // window would grow by the height of the title bar the content runs under.
    hostingView.sizingOptions = []
    window.contentView = hostingView
    window.delegate = self
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    // A window with a toolbar gets the larger, concentric corner radius on macOS 26.
    window.toolbar = Self.makeToolbar()
    window.toolbarStyle = .unified
    window.setFrame(NSRect(origin: .zero, size: Self.contentSize), display: false)
    window.backgroundColor = OnboardingPalette.windowBackground
    window.collectionBehavior = [.moveToActiveSpace]
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    onboardingModel.onAccessibilityGranted = { [weak self] in
      self?.show()
    }
  }

  func show() {
    if !window.isVisible {
      centerWindowOnActiveScreen()
    }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func close() {
    window.close()
  }

  /// Pastes an item the history just put on the clipboard into onboarding.
  func paste(_ item: ClipboardItem) {
    window.makeKeyAndOrderFront(nil)
    onboardingModel.receivePaste(of: item, in: window)
  }

  func windowWillClose(_ notification: Notification) {
    onboardingModel.stop()
    coordinator.onboardingDidClose()
  }

  private func centerWindowOnActiveScreen() {
    let mouseLocation = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    guard let screen else {
      window.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    let origin = NSPoint(
      x: visibleFrame.midX - window.frame.width / 2,
      y: visibleFrame.midY - window.frame.height / 2
    )
    window.setFrameOrigin(origin)
  }

  private static func makeToolbar() -> NSToolbar {
    let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
    toolbar.allowsUserCustomization = false
    if #available(macOS 15.0, *) {
      toolbar.allowsDisplayModeCustomization = false
    }
    toolbar.autosavesConfiguration = false
    return toolbar
  }
}
