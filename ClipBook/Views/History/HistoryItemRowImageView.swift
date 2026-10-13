import AppKit

final class HistoryItemRowImageView: HistoryItemRowView {
  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    configureImagePreview(for: item)
    setLines(
      primary: makePrimaryLabel(text: item.contentTitle),
      secondary: makeSecondaryLabel(text: ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
    )
  }

  // The thumbnail takes the place of the type symbol. A cached one shows at once; otherwise
  // the symbol stays until the picture is decoded.
  private func configureImagePreview(for item: ClipboardItem) {
    guard let url = item.assetURL else {
      return
    }

    let boxSize = CGSize(width: HistoryRow.typeIconBoxSize, height: HistoryRow.typeIconBoxSize)
    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    let maximumPixelSize = ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: boxSize, scale: scale)
    let toolTip = item.contentTitle

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
