import AppKit

enum FavoriteView {
  static func make(isFavorite: Bool) -> NSImageView {
    let imageView = NSImageView()
    let configuration = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .regular)
      .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
    imageView.image = NSImage(systemSymbolName: "star", accessibilityDescription: "Favorite")?
      .withSymbolConfiguration(configuration)
    imageView.isHidden = !isFavorite
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    return imageView
  }
}
