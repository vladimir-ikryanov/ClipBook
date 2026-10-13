import AppKit

final class HistoryItemRowFileView: HistoryItemRowView {
  private static let missingFileTextColor = NSColor.lightGray
  private static let missingFilePreviewAlpha: CGFloat = 0.5
  private static let detailsSeparator = " · "
  private lazy var detailsLine = makeDetailsLine()

  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    let isMissing = isFirstFileMissing(for: item)
    configureFilePreview(for: item, isMissing: isMissing)

    let nameField = isMissing
      ? makePrimaryLabel(text: item.contentTitle, textColor: Self.missingFileTextColor, keepsTextColor: true)
      : makePrimaryLabel(text: item.contentTitle)
    // A long name is cut in its middle, so the extension at its end stays readable.
    nameField.lineBreakMode = .byTruncatingMiddle
    setLines(primary: nameField, secondary: makeFileDetailsLine(for: item, isMissing: isMissing))
  }

  // The file preview takes the place of the type symbol: a picture is fit into the box, any
  // other file shows its icon at the box size.
  private func configureFilePreview(for item: ClipboardItem, isMissing: Bool) {
    guard let filePath = item.filePaths.first else {
      return
    }

    let style: HistoryTypeIconImageStyle = isFirstFileImage(item) ? .picture : .icon
    let alpha = isMissing ? Self.missingFilePreviewAlpha : 1
    let toolTip = item.contentTitle
    let targetSize = CGSize(width: HistoryRow.typeIconBoxSize, height: HistoryRow.typeIconBoxSize)
    let image = filePreviewImage(filePath: filePath, targetSize: targetSize) { [weak self] image in
      guard let self, self.isConfigured(for: item) else {
        return
      }

      self.configureTypeIconImage(image, style: style, toolTip: toolTip, alpha: alpha)
    }
    configureTypeIconImage(image, style: style, toolTip: toolTip, alpha: alpha)
  }

  // "1024x1024 · 356KB · ~/Pictures": the fixed details keep their width and the folder
  // path gives way, truncated in its middle so the start and the end of it stay readable.
  private func makeFileDetailsLine(for item: ClipboardItem, isMissing: Bool) -> NSView {
    let textColor: NSColor = isMissing ? Self.missingFileTextColor : .secondaryLabelColor
    var details: [String] = []
    if let filePath = item.filePaths.first, let dimensions = imageDimensions(forFileAt: filePath) {
      details.append("\(dimensions.width)x\(dimensions.height)")
    }
    details.append(ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))

    let detailsField = makeSecondaryLabel(
      text: details.joined(separator: Self.detailsSeparator) + " ·",
      textColor: textColor
    )
    detailsField.setContentHuggingPriority(.required, for: .horizontal)
    detailsField.setContentCompressionResistancePriority(.required, for: .horizontal)

    let pathField = makeSecondaryLabel(
      text: folderPath(for: item),
      textColor: textColor,
      lineBreakMode: .byTruncatingMiddle
    )

    // The row hands out the same labels for every file, so the line usually has them already.
    let fields = [detailsField, pathField]
    if !detailsLine.arrangedSubviews.elementsEqual(fields, by: ===) {
      detailsLine.arrangedSubviews.forEach { view in
        detailsLine.removeArrangedSubview(view)
        view.removeFromSuperview()
      }
      fields.forEach { detailsLine.addArrangedSubview($0) }
    }
    return detailsLine
  }

  private func makeDetailsLine() -> NSStackView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.distribution = .fill
    stack.spacing = 4
    stack.alignment = .centerY
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
    stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return stack
  }

  private func folderPath(for item: ClipboardItem) -> String {
    guard let filePath = item.filePaths.first else {
      return item.previewText
    }

    let folder = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
    return (folder as NSString).abbreviatingWithTildeInPath
  }

  private func isFirstFileMissing(for item: ClipboardItem) -> Bool {
    guard let filePath = item.filePaths.first else {
      return false
    }

    return !FileManager.default.fileExists(atPath: filePath)
  }
}
