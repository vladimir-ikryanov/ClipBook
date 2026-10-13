import AppKit

struct AssociatedApplication {
  let url: URL
  let name: String
  let icon: NSImage

  static func forOpening(_ url: URL, iconSize: NSSize) -> AssociatedApplication? {
    guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
      return nil
    }

    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    icon.size = iconSize

    return AssociatedApplication(
      url: applicationURL,
      name: displayName(for: applicationURL),
      icon: icon
    )
  }

  static func openTitle(forName name: String) -> String {
    L10n.string("Open in %@", name)
  }

  private static func displayName(for applicationURL: URL) -> String {
    let displayName = FileManager.default.displayName(atPath: applicationURL.path)
    return displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
  }
}
