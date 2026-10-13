import AppKit

final class HistoryItemRowFilesView: HistoryItemRowView {
  private static let previewCornerRadius: CGFloat = 4
  private lazy var previewStrip = makePreviewStrip()
  private var previewImageViews: [NSImageView] = []

  override func typeIconSystemImageName(for item: ClipboardItem) -> String {
    "document.on.document"
  }

  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    setLines(
      primary: makePrimaryLabel(text: "\(item.filePaths.count) items"),
      secondary: makeSecondaryLabel(text: makeFileSetDetailsText(for: item))
    )

    if configureFilePreviewStrip(for: item) {
      setTrailingView(previewStrip)
    }
  }

  override func makeTitledSummaryLine(for item: ClipboardItem) -> NSView {
    makeSecondaryLabel(text: "\(item.filePaths.count) items" + " · " + makeFileSetDetailsText(for: item))
  }

  // The first files of the set, as many as fit next to the text, up to a fixed number.
  // The strip keeps its image views and hides the ones it does not need.
  private func configureFilePreviewStrip(for item: ClipboardItem) -> Bool {
    let visibleCount = visiblePreviewImageCount(for: item)
    guard visibleCount > 0 else {
      return false
    }

    while previewImageViews.count < visibleCount {
      let imageView = makePreviewImageView()
      previewImageViews.append(imageView)
      previewStrip.addArrangedSubview(imageView)
    }
    for (index, imageView) in previewImageViews.enumerated() {
      guard index < visibleCount else {
        imageView.isHidden = true
        continue
      }

      configurePreviewImageView(imageView, forFileAt: item.filePaths[index], item: item)
      imageView.isHidden = false
    }
    return true
  }

  private func makePreviewStrip() -> NSStackView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.distribution = .fill
    stack.spacing = HistoryRow.multipleFilesPreviewImageSpacing
    stack.alignment = .centerY
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }

  private func visiblePreviewImageCount(for item: ClipboardItem) -> Int {
    let availableWidth = availableTrailingWidth(minimumTextWidth: HistoryRow.multipleFilesPreviewMinimumTextWidth)
    let itemWidthWithSpacing = HistoryRow.multipleFilesPreviewImageSize + HistoryRow.multipleFilesPreviewImageSpacing
    let fittingCount = Int(floor((availableWidth + HistoryRow.multipleFilesPreviewImageSpacing) / itemWidthWithSpacing))
    return min(item.filePaths.count, HistoryRow.multipleFilesPreviewMaximumCount, max(0, fittingCount))
  }

  private func configurePreviewImageView(_ imageView: NSImageView, forFileAt filePath: String, item: ClipboardItem) {
    let targetSize = CGSize(
      width: HistoryRow.multipleFilesPreviewImageSize,
      height: HistoryRow.multipleFilesPreviewImageSize
    )
    imageView.image = filePreviewImage(filePath: filePath, targetSize: targetSize) { [weak self, weak imageView] image in
      guard self?.isConfigured(for: item) == true else {
        return
      }

      imageView?.image = image
    }
    imageView.toolTip = URL(fileURLWithPath: filePath).lastPathComponent
  }

  private func makePreviewImageView() -> NSImageView {
    let imageView = NSImageView()
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.imageAlignment = .alignCenter
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = Self.previewCornerRadius
    imageView.layer?.masksToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: HistoryRow.multipleFilesPreviewImageSize),
      imageView.heightAnchor.constraint(equalToConstant: HistoryRow.multipleFilesPreviewImageSize)
    ])

    return imageView
  }

  private func makeFileSetDetailsText(for item: ClipboardItem) -> String {
    var fileCount = 0
    var folderCount = 0

    for filePath in item.filePaths {
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
        folderCount += 1
      } else {
        fileCount += 1
      }
    }

    return [
      makeCountText(count: folderCount, singular: "folder", plural: "folders"),
      makeCountText(count: fileCount, singular: "file", plural: "files")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: " · ")
  }

  private func makeCountText(count: Int, singular: String, plural: String) -> String {
    guard count > 0 else {
      return ""
    }

    return "\(count) \(count == 1 ? singular : plural)"
  }
}
