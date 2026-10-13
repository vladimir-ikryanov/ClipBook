import AppKit

final class HistoryItemRowTextView: HistoryItemRowView {
  override func configureContent(item: ClipboardItem, quickPasteIndex: Int?) {
    configureTypeIconSVGPreview(for: item)
    setLines(primary: makeTextPreviewField(text: item.previewText), secondary: nil)
  }

  override func makeTitledSummaryLine(for item: ClipboardItem) -> NSView {
    makeTextPreviewField(
      text: item.previewText,
      maximumNumberOfLines: 1,
      font: HistoryRow.makeSecondaryFont(),
      textColor: .secondaryLabelColor
    )
  }
}
