import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

final class SettingsWindow: NSObject, NSWindowDelegate {
  private static let defaultWindowSize = NSSize(
    width: AppPreferences.defaultSettingsWindowWidth,
    height: AppPreferences.defaultSettingsWindowHeight
  )

  private let model: AppModel
  private let coordinator: AppCoordinator
  let window: NSWindow
  private var didRestoreWindowFrame = false

  init(model: AppModel, coordinator: AppCoordinator) {
    self.model = model
    self.coordinator = coordinator
    let content = SettingsView(model: model)
      .environmentObject(coordinator)
    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    super.init()
    window.contentView = NSHostingView(rootView: content)
    window.delegate = self
    if #available(macOS 27.0, *) {
      // The title is provided by the detail column's navigation title and is
      // shown in the toolbar at the leading edge of that column.
      window.titleVisibility = .visible
    } else {
      // Earlier systems draw the title as a custom toolbar item.
      window.title = ""
      window.titleVisibility = .hidden
    }
    window.titlebarAppearsTransparent = false
    window.toolbarStyle = .unified
    window.backgroundColor = .windowBackgroundColor
    window.collectionBehavior = [.moveToActiveSpace]
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
  }

  func show() {
    applySavedWindowFrameIfNeeded()
    centerWindowOnActiveScreen()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  /// Shows the alert as a sheet, or as a standalone dialog when the window
  /// is not on screen to attach it to.
  func presentAlert(_ alert: NSAlert, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
    guard window.isVisible else {
      completionHandler(alert.runModal())
      return
    }

    alert.beginSheetModal(for: window, completionHandler: completionHandler)
  }

  func windowDidMove(_ notification: Notification) {
    saveWindowFrame()
  }

  func windowDidEndLiveResize(_ notification: Notification) {
    saveWindowFrame()
  }

  func windowWillClose(_ notification: Notification) {
    saveWindowFrame()
    coordinator.savePreferences()
    coordinator.settingsDidClose()
  }

  private func applySavedWindowFrameIfNeeded() {
    guard !didRestoreWindowFrame else {
      return
    }
    didRestoreWindowFrame = true

    guard let savedFrame = model.preferences.settingsWindowFrame else {
      return
    }

    var frame = window.frame
    frame.size = savedFrame.size
    window.setFrame(frame, display: false)
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

  private func saveWindowFrame() {
    let frame = window.frame
    model.preferences.settingsWindowX = frame.origin.x
    model.preferences.settingsWindowY = frame.origin.y
    model.preferences.settingsWindowWidth = frame.width
    model.preferences.settingsWindowHeight = frame.height
    coordinator.persistPreferences()
  }
}
