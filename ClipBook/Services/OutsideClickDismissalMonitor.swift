import AppKit

@MainActor
final class OutsideClickDismissalMonitor {
  private var eventMonitor: Any?

  init(window: NSWindow, onOutsideClick: @escaping () -> Void) {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak window] event in
      guard let window, window.isVisible else {
        return event
      }

      guard !window.frame.contains(NSEvent.mouseLocation) else {
        return event
      }

      onOutsideClick()
      return nil
    }
  }

  func invalidate() {
    guard let eventMonitor else {
      return
    }

    NSEvent.removeMonitor(eventMonitor)
    self.eventMonitor = nil
  }
}
