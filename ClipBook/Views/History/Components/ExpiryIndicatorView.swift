import AppKit

/// The timer a history row shows for an item that is deleted after a while,
/// such as confidential content. Its tooltip tells how long the item has left,
/// worked out when the tooltip shows rather than when the row was filled.
final class ExpiryIndicatorView: NSImageView, NSViewToolTipOwner {
  var expiresAt: Date? {
    didSet {
      isHidden = expiresAt == nil
    }
  }

  init() {
    super.init(frame: .zero)
    let configuration = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .regular)
      .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))
    image = NSImage(systemSymbolName: "timer", accessibilityDescription: L10n.string("Deleted automatically"))?
      .withSymbolConfiguration(configuration)
    isHidden = true
    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    removeAllToolTips()
    addToolTip(bounds, owner: self, userData: nil)
  }

  func view(
    _ view: NSView,
    stringForToolTip tag: NSView.ToolTipTag,
    point: NSPoint,
    userData data: UnsafeMutableRawPointer?
  ) -> String {
    guard let expiresAt else {
      return ""
    }

    return Self.toolTip(for: expiresAt)
  }

  static func toolTip(for expiresAt: Date, now: Date = Date()) -> String {
    let remaining = max(1, Int(expiresAt.timeIntervalSince(now).rounded(.up)))
    return L10n.string("Deleted in %@. Star or tag the item to keep it.", ContentLifetime.duration(remaining))
  }
}
