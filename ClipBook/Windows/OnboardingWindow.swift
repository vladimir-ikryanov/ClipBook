import SwiftUI
import AppKit
import Combine

@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
  static let contentSize = NSSize(width: 500, height: 640)
  private static let toolbarIdentifier = NSToolbar.Identifier("OnboardingToolbar")
  private static let flightDuration: CFTimeInterval = 0.2
  private static let flightEndWidth: CGFloat = 28
  private static let flightShadowRadius: CGFloat = 40

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

  /// Closes the window with its content shrinking into the menu bar icon.
  ///
  /// Resizing the window itself would lay its content out again at every step
  /// and keeps it below the menu bar, so the content moves to a transparent
  /// panel covering the way there, and only its layer is animated.
  func closeFlying(toMenuBarIconAt iconFrame: NSRect, completion: @escaping () -> Void) {
    guard let content = window.contentView else {
      close()
      completion()
      return
    }

    let windowFrame = window.frame
    let panelFrame = windowFrame.union(iconFrame).insetBy(dx: -Self.flightShadowRadius, dy: -Self.flightShadowRadius)
    let panel = NSPanel(contentRect: panelFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .statusBar
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.setFrame(panelFrame, display: false)

    let cornerRadius: CGFloat
    if #available(macOS 27.0, *) {
      cornerRadius = 16
    } else if #available(macOS 26.0, *) {
      cornerRadius = NSWindow.macOS26CornerRadius
    } else {
      cornerRadius = 10
    }

    let origin = NSPoint(x: windowFrame.minX - panelFrame.minX, y: windowFrame.minY - panelFrame.minY)
    let card = NSView(frame: NSRect(origin: origin, size: windowFrame.size))
    card.wantsLayer = true
    panel.contentView?.addSubview(card)

    window.contentView = NSView()
    content.frame = card.bounds
    content.autoresizingMask = [.width, .height]
    content.wantsLayer = true
    content.layer?.cornerRadius = cornerRadius
    content.layer?.cornerCurve = .continuous
    content.layer?.masksToBounds = true
    card.addSubview(content)

    panel.orderFrontRegardless()
    window.close()

    guard let layer = card.layer else {
      panel.orderOut(nil)
      completion()
      return
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.anchorPoint = .zero
    layer.position = origin
    layer.shadowColor = NSColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowRadius = Self.flightShadowRadius / 2
    layer.shadowOffset = CGSize(width: 0, height: -8)
    layer.shadowPath = CGPath(roundedRect: card.bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    CATransaction.commit()

    // With the anchor at the bottom left, the scale happens around that corner,
    // and the move then brings the center of the window to the center of the icon.
    let scale = Self.flightEndWidth / windowFrame.width
    let scaled = CATransform3DMakeScale(scale, scale, 1)
    let transform = CATransform3DConcat(scaled, CATransform3DMakeTranslation(
      iconFrame.midX - windowFrame.minX - scale * windowFrame.width / 2,
      iconFrame.midY - windowFrame.minY - scale * windowFrame.height / 2,
      0
    ))

    let flight = CABasicAnimation(keyPath: "transform")
    flight.fromValue = CATransform3DIdentity
    flight.toValue = transform
    flight.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.75, 0.6)

    // It stays solid for most of the way, so the eye can follow it.
    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [1, 1, 0]
    fade.keyTimes = [0, 0.7, 1]

    let group = CAAnimationGroup()
    group.animations = [flight, fade]
    group.duration = Self.flightDuration
    group.fillMode = .forwards
    group.isRemovedOnCompletion = false

    CATransaction.begin()
    CATransaction.setCompletionBlock {
      panel.orderOut(nil)
      completion()
    }
    layer.add(group, forKey: "flight")
    CATransaction.commit()
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
