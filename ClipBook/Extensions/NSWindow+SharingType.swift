import AppKit

extension NSWindow {
  /// Screen sharing and recording capture sheets and child windows on their
  /// own, so a window hidden from capture has to hide them as well.
  func setSharingTypeIncludingAttachedWindows(_ sharingType: NSWindow.SharingType) {
    self.sharingType = sharingType
    for window in sheets + (childWindows ?? []) {
      window.setSharingTypeIncludingAttachedWindows(sharingType)
    }
  }
}
