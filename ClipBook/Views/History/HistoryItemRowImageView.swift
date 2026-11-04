import AppKit

final class HistoryItemRowImageView: HistoryItemRowView {
  // An image's title holds its pixel size, which is read from the image file. Asset files
  // are never rewritten under the same name, so each title is read once.
  private static var titlesByAssetPath: [String: String] = [:]

  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    let title = Self.title(for: item)
    configureImagePreview(for: item, title: title)
    setLines(
      primary: makePrimaryLabel(text: title),
      secondary: makeSecondaryLabel(text: ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
    )
  }

  private static func title(for item: ClipboardItem) -> String {
    guard let assetPath = item.assetPath else {
      return item.contentTitle
    }
    if let cached = titlesByAssetPath[assetPath] {
      return cached
    }
    let title = item.contentTitle
    if titlesByAssetPath.count > 1_024 {
      titlesByAssetPath.removeAll(keepingCapacity: true)
    }
    titlesByAssetPath[assetPath] = title
    return title
  }

  // The thumbnail takes the place of the type symbol. A cached one shows at once; otherwise
  // the symbol stays until the picture is decoded.
  private func configureImagePreview(for item: ClipboardItem, title: String) {
    guard let url = item.assetURL else {
      return
    }

    let boxSize = CGSize(width: HistoryRow.typeIconBoxSize, height: HistoryRow.typeIconBoxSize)
    // A row is set up before it joins the window. The main screen is the key window's
    // screen, and asking the key window for its scale avoids a round trip to the window
    // server for every row that `NSScreen.main` makes.
    let scale = window?.backingScaleFactor
      ?? NSApp.keyWindow?.backingScaleFactor
      ?? NSScreen.main?.backingScaleFactor
      ?? 2
    let maximumPixelSize = ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: boxSize, scale: scale)
    let toolTip = title

    let cachedImage = ImageAssetThumbnailLoader.shared.thumbnail(
      for: url,
      maximumPixelSize: maximumPixelSize
    ) { [weak self] image in
      guard let self, self.isConfigured(for: item), let image else {
        return
      }

      self.configureTypeIconImage(image, style: .picture, toolTip: toolTip)
    }
    if let cachedImage {
      configureTypeIconImage(cachedImage, style: .picture, toolTip: toolTip)
    }
  }
}
