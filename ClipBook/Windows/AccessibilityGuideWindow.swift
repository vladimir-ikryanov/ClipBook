import AppKit
import SwiftUI

/// A small floating hint shown next to System Settings while onboarding waits
/// for the Accessibility switch, so the user knows what to look for there.
@MainActor
final class AccessibilityGuideWindow {
  private static let systemSettingsBundleIdentifier = "com.apple.systempreferences"
  private static let gap: CGFloat = 16
  private static let screenMargin: CGFloat = 12

  private var panel: NSPanel?

  /// Shows the hint beside the frontmost System Settings window and keeps it
  /// there as that window moves. Without a System Settings window on screen
  /// (it is still opening, or the user closed it) there is nothing to point
  /// at, so the hint is hidden.
  func showNextToSystemSettings() {
    guard let settingsFrame = Self.systemSettingsWindowFrame() else {
      hide()
      return
    }

    let panel = self.panel ?? makePanel()
    self.panel = panel
    panel.setFrameOrigin(origin(for: panel.frame.size, besideFrame: settingsFrame))
    if !panel.isVisible {
      panel.orderFrontRegardless()
    }
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func makePanel() -> NSPanel {
    let hostingView = NSHostingView(rootView: AccessibilityGuideView())
    hostingView.frame.size = hostingView.fittingSize
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = hostingView
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.animationBehavior = .none
    return panel
  }

  // Beside the left edge of System Settings first, where its sidebar is, then
  // beside the right edge, and over its lower left corner when neither side
  // has room.
  private func origin(for size: NSSize, besideFrame frame: NSRect) -> NSPoint {
    let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
    let visibleFrame = screen?.visibleFrame ?? frame
    let top = frame.maxY - 56
    var origin = NSPoint(x: frame.minX - Self.gap - size.width, y: top - size.height)
    if origin.x < visibleFrame.minX + Self.screenMargin {
      origin.x = frame.maxX + Self.gap
    }
    if origin.x + size.width > visibleFrame.maxX - Self.screenMargin {
      origin = NSPoint(x: frame.minX + Self.gap, y: frame.minY + Self.gap)
    }
    origin.x = min(max(origin.x, visibleFrame.minX + Self.screenMargin), visibleFrame.maxX - Self.screenMargin - size.width)
    origin.y = min(max(origin.y, visibleFrame.minY + Self.screenMargin), visibleFrame.maxY - Self.screenMargin - size.height)
    return origin
  }

  /// The frame of the frontmost System Settings window in AppKit screen
  /// coordinates. Window bounds can be read without Screen Recording
  /// permission; only window titles need it.
  private static func systemSettingsWindowFrame() -> NSRect? {
    let pids = Set(
      NSRunningApplication.runningApplications(withBundleIdentifier: systemSettingsBundleIdentifier)
        .map(\.processIdentifier)
    )
    guard !pids.isEmpty,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
          let primaryScreenHeight = NSScreen.screens.first?.frame.maxY else {
      return nil
    }

    for window in windows {
      guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
            pids.contains(pid),
            (window[kCGWindowLayer as String] as? Int) == 0,
            let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            bounds.width > 200, bounds.height > 200 else {
        continue
      }

      return NSRect(
        x: bounds.minX,
        y: primaryScreenHeight - bounds.maxY,
        width: bounds.width,
        height: bounds.height
      )
    }
    return nil
  }
}

private struct AccessibilityGuideView: View {
  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        OnboardingAppIcon(size: 26)

        Text(L10n.string("Find ClipBook in the list below and switch it on."))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "arrow.down")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

      VStack(alignment: .leading, spacing: 0) {
        Text(L10n.string("System Settings"))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        Text(L10n.string("Accessibility"))
          .font(.system(size: 17, weight: .bold))
          .padding(.top, 6)

        Text(L10n.string("Allow the applications below to control your computer."))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 6)

        OnboardingAccessibilityList(isClipBookSwitchedOn: false)
          .padding(.top, 12)
      }
      .padding(14)
      .background(OnboardingPalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08))
      )
      .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }
    .frame(width: 320)
    .padding(16)
  }
}
