import AppKit

final class HistoryItemRowColorView: HistoryItemRowView {
  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    if let color = NSColor(colorItemText: item.previewText) {
      configureTypeIconColorSwatch(color, toolTip: item.displayTitle)
    }

    setLines(primary: makePrimaryLabel(text: item.contentTitle), secondary: nil)
  }
}

extension NSColor {
  // Also used by the item preview dialog to render the color swatch.
  convenience init?(colorItemText text: String) {
    // Items are classified before they get here, so a hex value without a
    // number sign is only seen when the user asked for those to be colors.
    guard let color = ColorText(text, allowsBareHex: true) else {
      return nil
    }

    self.init(
      srgbRed: CGFloat(color.red),
      green: CGFloat(color.green),
      blue: CGFloat(color.blue),
      alpha: CGFloat(color.alpha)
    )
  }
}
