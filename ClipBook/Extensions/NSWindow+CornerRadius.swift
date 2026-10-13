import AppKit

extension NSWindow {
  /// Corner radius macOS 26 gives titled windows. macOS 27 reduced it to 16pt,
  /// which no longer matches the rounded toolbar controls the history window
  /// and the item preview sheet are built around.
  static let macOS26CornerRadius: CGFloat = 26

  /// Restores the macOS 26 corner radius on macOS 27 and later.
  ///
  /// There is no public API for the corner radius of a titled window. AppKit
  /// exposes it through the private `-[NSWindow _setCornerRadius:]` selector,
  /// which is what the frame uses to build the window mask and shadow. Only
  /// macOS 27 and later need the override, and the call is skipped entirely if
  /// a future AppKit drops the selector. Call it again after anything that
  /// reconfigures the frame, such as presenting the window as a sheet.
  func applyMacOS26CornerRadiusIfNeeded() {
    guard #available(macOS 27.0, *) else {
      return
    }

    let selector = NSSelectorFromString("_setCornerRadius:")
    guard responds(to: selector),
          let implementation = class_getMethodImplementation(type(of: self), selector) else {
      return
    }

    typealias SetCornerRadius = @convention(c) (AnyObject, Selector, CGFloat) -> Void
    let setCornerRadius = unsafeBitCast(implementation, to: SetCornerRadius.self)
    setCornerRadius(self, selector, Self.macOS26CornerRadius)
  }
}
