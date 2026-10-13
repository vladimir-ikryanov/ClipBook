import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class PasteService {
  private static let interKeyDelay: TimeInterval = 0.06

  private let pasteboard = NSPasteboard.general
  // History items come without their formatting; this reads it for the one
  // item being pasted or copied.
  private let loadFormatting: (ClipboardItem) -> ClipboardItem

  init(loadFormatting: @escaping (ClipboardItem) -> ClipboardItem) {
    self.loadFormatting = loadFormatting
  }

  // The process that owned keyboard focus the last time the history panel took
  // it. It is the paste target when the panel is still key at paste time (a
  // pinned panel stays up), because the focus owner is then ClipBook itself.
  private var targetPidBeforePanelTookFocus: pid_t?
  private var targetWindowBeforePanelTookFocus: AXUIElement?

  // The target of the paste in flight, resolved before the history panel is
  // hidden: once it is ordered out, keyboard focus is briefly nowhere and the
  // focus query answers nothing.
  private var pasteTargetPid: pid_t?
  private var pasteTargetWindow: AXUIElement?

  // Called right before the history panel takes key focus, and again once it
  // gives it up, so a later paste from a pinned panel knows where to go.
  func rememberPasteTarget() {
    let focusedPid = Self.keyboardFocusedProcessIdentifier()
    guard focusedPid != getpid() else {
      return
    }
    // Some apps (Electron ones such as Claude Desktop) report no focused
    // application at all; the frontmost app is the target then, and it must
    // replace whatever was remembered before so the target cannot go stale.
    guard let pid = focusedPid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier else {
      return
    }
    targetPidBeforePanelTookFocus = pid
    targetWindowBeforePanelTookFocus = focusedPid == nil ? nil : Self.focusedWindow(ofProcess: pid)
  }

  private static func focusedWindow(ofProcess pid: pid_t) -> AXUIElement? {
    var window: CFTypeRef?
    let app = AXUIElementCreateApplication(pid)
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
          let window, CFGetTypeID(window) == AXUIElementGetTypeID() else {
      return nil
    }
    return (window as! AXUIElement)
  }

  // Resolves where the paste goes. Called while the history panel still holds
  // focus, if it is showing at all; the process with keyboard focus is the
  // target, unless that is ClipBook's own panel, in which case it is the
  // process that had focus before the panel took it.
  func resolvePasteTarget() {
    let focusedPid = Self.keyboardFocusedProcessIdentifier()
    if let focusedPid, focusedPid != getpid() {
      pasteTargetPid = focusedPid
      pasteTargetWindow = Self.focusedWindow(ofProcess: focusedPid)
    } else if focusedPid == getpid(),
              let pid = targetPidBeforePanelTookFocus, NSRunningApplication(processIdentifier: pid) != nil {
      pasteTargetPid = pid
      pasteTargetWindow = targetWindowBeforePanelTookFocus
    } else {
      pasteTargetPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
      pasteTargetWindow = nil
    }
  }

  // False when the paste goes to a non-activating panel of an app that is not
  // frontmost. Such a panel only receives the keystroke while it holds key
  // focus, so the history panel has to hand focus to it before pasting.
  func pasteTargetIsFrontmostApplication() -> Bool {
    guard let pasteTargetPid else {
      return true
    }
    return pasteTargetPid == NSWorkspace.shared.frontmostApplication?.processIdentifier
  }

  // Raises the target window through Accessibility, which AppKit implements
  // with makeKeyAndOrderFront: the window takes keyboard focus without
  // activating its app, so a keystroke posted to that process right afterwards
  // is delivered to it. Returns false when there is no such window.
  func giveKeyFocusToTargetWindow() -> Bool {
    guard let window = pasteTargetWindow else {
      return false
    }
    return AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
  }

  // Synchronous on purpose: the synthetic Cmd+V must be posted with as few
  // scheduling hops as possible after the history window is hidden, otherwise
  // the paste feels laggy. Follow-up keys (Return/Tab) are scheduled instead
  // of awaited so they never delay the paste itself.
  func paste(_ item: ClipboardItem, variant: PasteVariant) throws {
    guard AccessibilityPermission.isTrusted else {
      throw PasteServiceError.accessibilityPermissionRequired
    }

    try copy(item, variant: variant)
    sendKey(keyCode: 9, flags: .maskCommand)

    switch variant {
    case .pasteAndReturn:
      scheduleKey(keyCode: 36, flags: [], after: Self.interKeyDelay)
    case .pasteAndTab:
      scheduleKey(keyCode: 48, flags: [], after: Self.interKeyDelay)
    default:
      break
    }
  }

  private func scheduleKey(keyCode: CGKeyCode, flags: CGEventFlags, after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.sendKey(keyCode: keyCode, flags: flags)
    }
  }

  func perform(_ action: PasteInterItemAction) async throws {
    if let text = action.text {
      try await Task.sleep(for: .milliseconds(80))
      sendText(text)
      return
    }

    guard let keyCode = action.keyCode else {
      return
    }

    try await Task.sleep(for: .milliseconds(80))
    sendKey(keyCode: keyCode, flags: action.flags)
  }
  
  func copy(_ item: ClipboardItem, variant: PasteVariant) throws {
    pasteboard.clearContents()
    pasteboard.setString("1", forType: PasteboardMonitor.ghostType)
    
    switch variant {
    case .plainText:
      guard pasteboard.setString(item.previewText, forType: .string) else {
        throw PasteServiceError.unsupportedItem
      }
    case .filePath:
      guard !item.filePaths.isEmpty else {
        throw PasteServiceError.unsupportedItem
      }
      pasteboard.setString(item.filePaths.joined(separator: "\n"), forType: .string)
    default:
      try writeItem(item)
    }
  }

  func copyText(_ text: String, markAsGhost: Bool = false) throws {
    pasteboard.clearContents()
    if markAsGhost {
      pasteboard.setString("1", forType: PasteboardMonitor.ghostType)
    }
    guard pasteboard.setString(text, forType: .string) else {
      throw PasteServiceError.unsupportedItem
    }
  }
  
  private func writeItem(_ item: ClipboardItem) throws {
    switch item.kind {
    case .image:
      guard let url = item.assetURL, let pngData = try? Data(contentsOf: url) else {
        throw PasteServiceError.unsupportedItem
      }
      // Image assets are stored as PNG. Write the raw bytes directly and promise
      // TIFF lazily: decoding and re-encoding the image up front is expensive for
      // large images and would delay the synthetic Cmd+V, while most target apps
      // never request the TIFF representation.
      let pasteboardItem = NSPasteboardItem()
      pasteboardItem.setData(pngData, forType: .png)
      pasteboardItem.setDataProvider(LazyTiffDataProvider(pngData: pngData), forTypes: [.tiff])
      pasteboard.writeObjects([pasteboardItem])
    case .file:
      let urls = item.filePaths.map(URL.init(fileURLWithPath:))
      guard !urls.isEmpty else {
        throw PasteServiceError.unsupportedItem
      }
      pasteboard.writeObjects(urls as [NSURL])
    case .richText:
      let item = loadFormatting(item)
      if let rtfData = item.rtfData {
        pasteboard.setData(rtfData, forType: .rtf)
      }
      if let html = item.html {
        pasteboard.setString(html, forType: .html)
      }
      if let text = item.text {
        pasteboard.setString(text, forType: .string)
      }
    default:
      guard pasteboard.setString(item.previewText, forType: .string) else {
        throw PasteServiceError.unsupportedItem
      }
    }
  }
  
  // Types the text as a single keystroke carrying the characters, so it goes
  // through neither the pasteboard nor the keyboard layout.
  private func sendText(_ text: String) {
    let source = CGEventSource(stateID: .combinedSessionState)
    source?.setLocalEventsFilterDuringSuppressionState(
      [.permitLocalMouseEvents, .permitSystemDefinedEvents],
      state: .eventSuppressionStateSuppressionInterval
    )
    let characters = Array(text.utf16)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    keyDown?.flags = []
    keyUp?.flags = []
    keyDown?.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
    keyUp?.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
    post(keyDown: keyDown, keyUp: keyUp)
  }

  private func sendKey(keyCode: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .combinedSessionState)
    // Suppress the user's currently pressed physical keys (e.g. the Control+V global
    // shortcut modifiers) so they don't merge into the synthetic keystroke. Without this,
    // a still-held modifier turns Cmd+V into Ctrl+Cmd+V and the paste is ignored until the
    // user releases the keys.
    source?.setLocalEventsFilterDuringSuppressionState(
      [.permitLocalMouseEvents, .permitSystemDefinedEvents],
      state: .eventSuppressionStateSuppressionInterval
    )
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    keyDown?.flags = flags
    keyUp?.flags = flags
    post(keyDown: keyDown, keyUp: keyUp)
  }

  private func post(keyDown: CGEvent?, keyUp: CGEvent?) {
    // The history panel is non-activating, so the paste target keeps keyboard
    // focus while the panel is up. Posting straight to its process bypasses the
    // window server's key focus routing, which would otherwise delay the
    // keystroke while focus settles after the panel is ordered out, and keeps a
    // pinned panel from swallowing the keystroke itself.
    //
    // The target is the process that owns keyboard focus, which is not always
    // the frontmost application: a non-activating panel of another app (for
    // example Easydict's pinned window) can hold focus while a regular app
    // stays frontmost, and the paste has to land in that panel.
    if let targetPid = pasteTargetPid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier {
      keyDown?.postToPid(targetPid)
      keyUp?.postToPid(targetPid)
    } else {
      keyDown?.post(tap: .cgAnnotatedSessionEventTap)
      keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
  }

  // The process whose window has keyboard focus according to the window server,
  // which includes non-activating panels of apps that are not frontmost.
  private static func keyboardFocusedProcessIdentifier() -> pid_t? {
    var focused: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      AXUIElementCreateSystemWide(),
      kAXFocusedApplicationAttribute as CFString,
      &focused
    )
    guard result == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
      return nil
    }
    var pid: pid_t = 0
    guard AXUIElementGetPid(focused as! AXUIElement, &pid) == .success, pid > 0 else {
      return nil
    }
    return pid
  }
}

// Converts the stored PNG bytes to TIFF only when a target app actually asks
// for the TIFF representation, keeping the conversion cost off the paste hot path.
private final class LazyTiffDataProvider: NSObject, NSPasteboardItemDataProvider {
  private let pngData: Data

  init(pngData: Data) {
    self.pngData = pngData
  }

  func pasteboard(
    _ pasteboard: NSPasteboard?,
    item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    guard type == .tiff,
          let representation = NSBitmapImageRep(data: pngData),
          let tiffData = representation.tiffRepresentation else {
      return
    }

    item.setData(tiffData, forType: .tiff)
  }
}
