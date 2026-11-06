import AppKit

@MainActor
final class OutsideClickDismissalMonitor {
  private nonisolated(unsafe) var eventMonitor: Any?

  init(window: NSWindow, onOutsideClick: @escaping () -> Void) {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak window] event in
      guard let window,
            Self.isOutsideClick(in: event.window, of: window, at: NSEvent.mouseLocation) else {
        return event
      }

      onOutsideClick()
      return nil
    }
  }

  /// Whether a click in `eventWindow` at `mouseLocation` is outside `window`
  /// and should dismiss it. A window that is hidden or has a sheet open is
  /// never dismissed, and neither is one by a click in another window, except
  /// the window it is a sheet of.
  static func isOutsideClick(in eventWindow: NSWindow?, of window: NSWindow, at mouseLocation: NSPoint) -> Bool {
    guard window.isVisible, window.attachedSheet == nil else {
      return false
    }

    if let eventWindow,
       eventWindow !== window,
       eventWindow !== window.sheetParent {
      return false
    }

    return !window.frame.contains(mouseLocation)
  }

  deinit {
    invalidate()
  }

  nonisolated func invalidate() {
    guard let eventMonitor else {
      return
    }

    NSEvent.removeMonitor(eventMonitor)
    self.eventMonitor = nil
  }
}
