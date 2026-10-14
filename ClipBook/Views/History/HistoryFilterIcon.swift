import AppKit

/// Icons shared by every place a history filter is presented: the toolbar
/// filter menus, the search field chips and the suggestion list.
enum HistoryFilterIcon {
  static func symbolImage(symbolName: String, label: String) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    return NSImage(systemSymbolName: symbolName, accessibilityDescription: label)?
      .withSymbolConfiguration(configuration)
  }

  static func tagIcon(for tag: Tag) -> NSImage? {
    let color = NSColor(tagHexString: tag.color) ?? .labelColor
    let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
      .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
    return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: tag.name)?
      .withSymbolConfiguration(configuration)
  }

  static func applicationIcon(for sourceApplication: HistorySourceApplication) -> NSImage? {
    guard let appURL = sourceApplication.resolvedApplicationURL else {
      return symbolImage(symbolName: "app.dashed", label: sourceApplication.name)?
        .sized(to: NSSize(width: 16, height: 16))
    }

    return NSWorkspace.shared.icon(forFile: appURL.path).sized(to: NSSize(width: 16, height: 16))
  }
}

extension HistoryFilterContentType {
  var systemImage: String {
    switch self {
    case .all:
      return "list.bullet"
    case .favorites:
      return "star.fill"
    case .text:
      return ClipboardKind.text.systemImage
    case .images:
      return ClipboardKind.image.systemImage
    case .files:
      return ClipboardKind.file.systemImage
    case .links:
      return ClipboardKind.link.systemImage
    case .emails:
      return ClipboardKind.email.systemImage
    case .colors:
      return ClipboardKind.color.systemImage
    case .trash:
      return "trash"
    }
  }
}

private extension NSColor {
  convenience init?(tagHexString: String) {
    let hex = tagHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let value = Int(hex, radix: 16) else {
      return nil
    }

    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}

private extension NSImage {
  func sized(to size: NSSize) -> NSImage {
    self.size = size
    return self
  }
}
