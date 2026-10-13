import AppKit
import ApplicationServices
import Foundation

enum HistoryWindowPositioner {
  private static let anchorPadding: CGFloat = 12

  static func origin(
    for strategy: HistoryWindowOpenStrategy,
    windowSize: NSSize,
    savedOrigin: NSPoint?
  ) -> NSPoint? {
    switch strategy {
    case .lastLocation:
      return originForLastLocation(windowSize: windowSize, savedOrigin: savedOrigin)
    case .activeScreenCenter:
      return originForActiveScreenCenter(windowSize: windowSize)
    case .activeWindowCenter:
      return originForActiveWindowCenter(windowSize: windowSize)
    case .screenWithCursor:
      return originForScreenWithCursor(windowSize: windowSize)
    case .mouseCursor:
      return originNearAnchor(NSEvent.mouseLocation, windowSize: windowSize)
    case .inputCursor:
      return originForInputCursor(windowSize: windowSize)
    }
  }

  private static func originForLastLocation(windowSize: NSSize, savedOrigin: NSPoint?) -> NSPoint? {
    guard let savedOrigin else {
      return originForActiveScreenCenter(windowSize: windowSize)
    }

    let savedFrame = NSRect(origin: savedOrigin, size: windowSize)
    let screen = screen(for: savedFrame) ?? screen(containing: center(of: savedFrame)) ?? screenWithCursor()
    guard let visibleFrame = screen?.visibleFrame else {
      return savedOrigin
    }

    return constrainedOrigin(savedOrigin, windowSize: windowSize, visibleFrame: visibleFrame)
  }

  private static func originForActiveScreenCenter(windowSize: NSSize) -> NSPoint? {
    let targetScreen = activeWindowFrame()
      .flatMap { Self.screen(containing: center(of: $0)) }
      ?? screenWithCursor()
      ?? NSScreen.main

    return targetScreen.map { centerOrigin(windowSize: windowSize, in: $0.visibleFrame) }
  }

  private static func originForActiveWindowCenter(windowSize: NSSize) -> NSPoint? {
    guard let activeFrame = activeWindowFrame() else {
      return originForActiveScreenCenter(windowSize: windowSize)
    }

    let windowCenterOrigin = centerOrigin(windowSize: windowSize, in: activeFrame)
    let screen = screen(containing: center(of: activeFrame)) ?? screen(for: activeFrame) ?? screenWithCursor()
    guard let visibleFrame = screen?.visibleFrame else {
      return windowCenterOrigin
    }

    return constrainedOrigin(windowCenterOrigin, windowSize: windowSize, visibleFrame: visibleFrame)
  }

  private static func originForScreenWithCursor(windowSize: NSSize) -> NSPoint? {
    guard let screen = screenWithCursor() ?? NSScreen.main else {
      return nil
    }

    return centerOrigin(windowSize: windowSize, in: screen.visibleFrame)
  }

  private static func originForInputCursor(windowSize: NSSize) -> NSPoint? {
    guard let origin = inputCursorOrigin(windowSize: windowSize) else {
      return originForActiveWindowCenter(windowSize: windowSize)
    }

    return origin
  }

  private static func originNearAnchor(_ anchor: NSPoint, windowSize: NSSize) -> NSPoint? {
    let screen = screen(containing: anchor) ?? screenWithCursor() ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else {
      return nil
    }

    let preferredX = anchor.x + anchorPadding
    let preferredY: CGFloat
    if anchor.y - windowSize.height - anchorPadding >= visibleFrame.minY {
      preferredY = anchor.y - windowSize.height - anchorPadding
    } else {
      preferredY = anchor.y + anchorPadding
    }

    return constrainedOrigin(
      NSPoint(x: preferredX, y: preferredY),
      windowSize: windowSize,
      visibleFrame: visibleFrame
    )
  }

  private static func activeWindowFrame() -> NSRect? {
    guard let application = targetApplication() else {
      return nil
    }

    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    if let focusedWindow = accessibilityElementAttribute(applicationElement, kAXFocusedWindowAttribute) {
      // After a click on the desktop, Finder reports the desktop itself as its
      // focused window: a scroll area spanning every display. Its center says
      // nothing about the screen the user is on, and neither do Finder's other
      // windows, so the caller falls back to the screen with the cursor.
      guard isWindow(focusedWindow) else {
        return nil
      }

      if let frame = accessibilityFrame(for: focusedWindow) {
        return frame
      }
    }

    if let windows = accessibilityElementArrayAttribute(applicationElement, kAXWindowsAttribute),
       let frame = windows.filter(isWindow).compactMap({ accessibilityFrame(for: $0) }).first {
      return frame
    }

    return cgWindowFrame(for: application)
  }

  private static func inputCursorOrigin(windowSize: NSSize) -> NSPoint? {
    guard AccessibilityPermission.isTrusted else {
      return nil
    }

    guard let caretBounds = inputCursorBounds() else {
      return nil
    }

    let caretFrame = screenRect(fromAccessibilityRect: caretBounds)
    let screen = screen(containing: center(of: caretFrame)) ?? screen(for: caretFrame) ?? screenWithCursor()
    guard let visibleFrame = screen?.visibleFrame else {
      return nil
    }

    let origin = NSPoint(
      x: caretFrame.minX + 4,
      y: caretFrame.minY - windowSize.height - 6
    )
    return constrainedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)
  }

  private static func inputCursorBounds() -> CGRect? {
    let systemWideElement = AXUIElementCreateSystemWide()
    if let focusedElement = accessibilityElementAttribute(systemWideElement, kAXFocusedUIElementAttribute),
       let bounds = boundsForSelectedTextRange(in: focusedElement) {
      return bounds
    }

    guard let application = targetApplication() else {
      return nil
    }

    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    guard let focusedElement = accessibilityElementAttribute(applicationElement, kAXFocusedUIElementAttribute) else {
      return nil
    }

    return boundsForSelectedTextRange(in: focusedElement)
  }

  private static func targetApplication() -> NSRunningApplication? {
    let clipBookBundleIdentifier = Bundle.main.bundleIdentifier
    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
       frontmostApplication.bundleIdentifier != clipBookBundleIdentifier {
      return frontmostApplication
    }

    return NSWorkspace.shared.runningApplications.first { application in
      application.bundleIdentifier != clipBookBundleIdentifier
        && application.activationPolicy == .regular
        && !application.isHidden
    }
  }

  private static func cgWindowFrame(for application: NSRunningApplication) -> NSRect? {
    guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
      return nil
    }

    for windowInfo in windowInfoList {
      guard (windowInfo[kCGWindowOwnerPID as String] as? pid_t) == application.processIdentifier,
            (windowInfo[kCGWindowLayer as String] as? Int) == 0,
            (windowInfo[kCGWindowIsOnscreen as String] as? Bool) == true,
            let boundsDictionary = windowInfo[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
            bounds.width > 0,
            bounds.height > 0 else {
        continue
      }

      return screenRect(fromAccessibilityRect: bounds)
    }

    return nil
  }

  private static func isWindow(_ element: AXUIElement) -> Bool {
    (accessibilityValueAttribute(element, kAXRoleAttribute) as? String) == kAXWindowRole
  }

  private static func accessibilityElementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    guard let value = accessibilityValueAttribute(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }

    return unsafeBitCast(value, to: AXUIElement.self)
  }

  private static func accessibilityElementArrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
    accessibilityValueAttribute(element, attribute) as? [AXUIElement]
  }

  private static func accessibilityAXValueAttribute(_ element: AXUIElement, _ attribute: String) -> AXValue? {
    guard let value = accessibilityValueAttribute(element, attribute),
          CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }

    return unsafeBitCast(value, to: AXValue.self)
  }

  private static func accessibilityValueAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }

    return value
  }

  private static func accessibilityFrame(for element: AXUIElement) -> NSRect? {
    guard let frame = rawAccessibilityFrame(for: element) else {
      return nil
    }

    return screenRect(fromAccessibilityRect: frame)
  }

  private static func boundsForSelectedTextRange(in element: AXUIElement) -> CGRect? {
    var selectedRangeRawValue: CFTypeRef?
    let selectedRangeError = AXUIElementCopyAttributeValue(
      element,
      kAXSelectedTextRangeAttribute as CFString,
      &selectedRangeRawValue
    )
    guard selectedRangeError == .success,
          let selectedRangeValue = selectedRangeRawValue else {
      return nil
    }

    if let bounds = boundsForTextRangeValue(selectedRangeValue, in: element) {
      return adjustedCaretBounds(bounds, for: element)
    }

    guard CFGetTypeID(selectedRangeValue) == AXValueGetTypeID() else {
      return nil
    }

    let selectedRangeAXValue = unsafeBitCast(selectedRangeValue, to: AXValue.self)
    var selectedRange = CFRange()
    guard AXValueGetValue(selectedRangeAXValue, .cfRange, &selectedRange) else {
      return nil
    }

    if selectedRange.length == 0,
       let bounds = boundsForTextRange(CFRange(location: selectedRange.location, length: 1), in: element) {
      return adjustedCaretBounds(bounds, for: element)
    }

    if selectedRange.location > 0,
       let bounds = boundsForTextRange(CFRange(location: selectedRange.location - 1, length: 1), in: element) {
      let adjustedBounds = adjustedCaretBounds(bounds, for: element)
      return CGRect(x: adjustedBounds.maxX, y: adjustedBounds.minY, width: 0, height: adjustedBounds.height)
    }

    return nil
  }

  private static func boundsForTextRange(_ range: CFRange, in element: AXUIElement) -> CGRect? {
    var mutableRange = range
    guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
      return nil
    }

    return boundsForTextRangeValue(rangeValue, in: element)
  }

  private static func boundsForTextRangeValue(_ rangeValue: CFTypeRef, in element: AXUIElement) -> CGRect? {
    var boundsValue: CFTypeRef?
    let boundsError = AXUIElementCopyParameterizedAttributeValue(
      element,
      kAXBoundsForRangeParameterizedAttribute as CFString,
      rangeValue,
      &boundsValue
    )
    guard boundsError == .success,
      let boundsValue,
      CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
      return nil
    }

    let boundsAXValue = unsafeBitCast(boundsValue, to: AXValue.self)
    var bounds = CGRect.zero
    guard AXValueGetValue(boundsAXValue, .cgRect, &bounds) else {
      return nil
    }

    return bounds
  }

  private static func adjustedCaretBounds(_ bounds: CGRect, for element: AXUIElement) -> CGRect {
    guard bounds.minX == 0,
          let elementFrame = rawAccessibilityFrame(for: element),
          elementFrame.minX > 0 else {
      return bounds
    }

    return CGRect(
      x: elementFrame.minX + bounds.minX,
      y: bounds.minY,
      width: bounds.width,
      height: bounds.height
    )
  }

  private static func rawAccessibilityFrame(for element: AXUIElement) -> CGRect? {
    guard let positionValue = accessibilityAXValueAttribute(element, kAXPositionAttribute),
          let sizeValue = accessibilityAXValueAttribute(element, kAXSizeAttribute) else {
      return nil
    }

    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue, .cgPoint, &position),
          AXValueGetValue(sizeValue, .cgSize, &size) else {
      return nil
    }

    return CGRect(origin: position, size: size)
  }

  private static func screenRect(fromAccessibilityRect rect: CGRect) -> NSRect {
    let original = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    guard let primaryScreenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
      ?? NSScreen.main?.frame.height else {
      return original
    }

    let flipped = NSRect(
      x: rect.minX,
      y: primaryScreenHeight - rect.maxY,
      width: rect.width,
      height: rect.height
    )

    return [flipped, original].max { intersectionArea(for: $0) < intersectionArea(for: $1) } ?? flipped
  }

  private static func screenWithCursor() -> NSScreen? {
    screen(containing: NSEvent.mouseLocation)
  }

  private static func screen(containing point: NSPoint) -> NSScreen? {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
  }

  private static func screen(for frame: NSRect) -> NSScreen? {
    NSScreen.screens.max { first, second in
      first.frame.intersection(frame).area < second.frame.intersection(frame).area
    }
  }

  private static func centerOrigin(windowSize: NSSize, in rect: NSRect) -> NSPoint {
    constrainedOrigin(
      NSPoint(x: rect.midX - windowSize.width / 2, y: rect.midY - windowSize.height / 2),
      windowSize: windowSize,
      visibleFrame: rect
    )
  }

  private static func constrainedOrigin(
    _ origin: NSPoint,
    windowSize: NSSize,
    visibleFrame: NSRect
  ) -> NSPoint {
    NSPoint(
      x: constrainedCoordinate(
        origin.x,
        minimum: visibleFrame.minX,
        maximum: visibleFrame.maxX - windowSize.width,
        fallback: visibleFrame.midX - windowSize.width / 2
      ),
      y: constrainedCoordinate(
        origin.y,
        minimum: visibleFrame.minY,
        maximum: visibleFrame.maxY - windowSize.height,
        fallback: visibleFrame.midY - windowSize.height / 2
      )
    )
  }

  private static func constrainedCoordinate(
    _ value: CGFloat,
    minimum: CGFloat,
    maximum: CGFloat,
    fallback: CGFloat
  ) -> CGFloat {
    guard minimum <= maximum else {
      return fallback
    }

    return min(max(value, minimum), maximum)
  }

  private static func center(of rect: NSRect) -> NSPoint {
    NSPoint(x: rect.midX, y: rect.midY)
  }

  private static func intersectionArea(for rect: NSRect) -> CGFloat {
    NSScreen.screens.reduce(CGFloat.zero) { partialResult, screen in
      partialResult + screen.frame.intersection(rect).area
    }
  }
}

private extension NSRect {
  var area: CGFloat {
    guard !isNull && !isEmpty else {
      return 0
    }

    return width * height
  }
}
