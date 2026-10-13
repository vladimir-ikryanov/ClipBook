import AppKit

/// One draggable piece of a history row. A row usually yields a single entry;
/// a multi-file item yields one per file so Finder receives them as separate
/// files.
struct HistoryRowDragEntry {
  let writer: NSPasteboardWriting
  /// Shown instead of the row snapshot when a row is dragged as several
  /// entries. Nil means the row snapshot is used.
  let icon: NSImage?
}

struct HistoryRowDragPayload {
  let entries: [HistoryRowDragEntry]
  /// True when the payload carries URLs of the user's own files. Those drags
  /// are copy-only so no destination ever moves the original.
  let containsFileURLs: Bool
}

extension NSPasteboard.PasteboardType {
  /// Carried by every row dragged out of the history table so the table can
  /// tell its own rows apart from anything else and let pinned favorites be
  /// dropped back into a new order. No other app reads it.
  static let historyItemID = NSPasteboard.PasteboardType("com.ikryanov.clipbook.history-item-id")
}

/// Adds the history item's ID to whatever a row already writes to the
/// pasteboard. Wrapping keeps the writer's own types and options as they are,
/// so a file URL still lands in Finder as a file.
final class HistoryItemIDPasteboardWriter: NSObject, NSPasteboardWriting {
  private let writer: NSPasteboardWriting
  private let itemID: UUID

  init(wrapping writer: NSPasteboardWriting, itemID: UUID) {
    self.writer = writer
    self.itemID = itemID
  }

  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    writer.writableTypes(for: pasteboard) + [.historyItemID]
  }

  func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
    guard type != .historyItemID else {
      return []
    }

    return writer.writingOptions?(forType: type, pasteboard: pasteboard) ?? []
  }

  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    guard type != .historyItemID else {
      return itemID.uuidString
    }

    return writer.pasteboardPropertyList(forType: type)
  }
}

enum HistoryItemDragging {
  private static let urlNameType = NSPasteboard.PasteboardType("public.url-name")
  private static let fileIconSize = NSSize(width: 32, height: 32)

  /// The writer for a dragged row, carrying the row's item ID next to the
  /// content. Pasteboard items and the image promise provider take the type
  /// directly; anything else is wrapped.
  static func writer(_ writer: NSPasteboardWriting, carrying itemID: UUID) -> NSPasteboardWriting {
    if let pasteboardItem = writer as? NSPasteboardItem {
      pasteboardItem.setString(itemID.uuidString, forType: .historyItemID)
      return pasteboardItem
    }

    if let promiseProvider = writer as? ImageAssetFilePromiseProvider {
      promiseProvider.historyItemID = itemID
      return promiseProvider
    }

    return HistoryItemIDPasteboardWriter(wrapping: writer, itemID: itemID)
  }

  /// A payload with nothing for other apps, used when a pinned favorite has
  /// no content to hand out (an image whose file is gone, say) but can still
  /// be dragged to a new place in the favorites.
  static func reorderOnlyPayload() -> HistoryRowDragPayload {
    singleEntryPayload(NSPasteboardItem())
  }

  /// `asPlainText` drops the formatting of text-like items, so a rich text,
  /// link or color lands as the plain string; images and files are unaffected.
  static func payload(for item: ClipboardItem, asPlainText: Bool) -> HistoryRowDragPayload? {
    if asPlainText, item.kind.isEditableText {
      return textPayload(for: item)
    }

    switch item.kind {
    case .image:
      return imagePayload(for: item)
    case .file:
      return filePayload(for: item)
    case .link:
      return linkPayload(for: item)
    case .richText:
      return richTextPayload(for: item)
    case .color:
      return colorPayload(for: item)
    case .text, .email:
      return textPayload(for: item)
    }
  }

  private static func imagePayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    guard let assetURL = item.assetURL,
          FileManager.default.fileExists(atPath: assetURL.path) else {
      return nil
    }

    let provider = ImageAssetFilePromiseProvider(
      assetURL: assetURL,
      fileName: promisedImageFileName(for: item)
    )
    return HistoryRowDragPayload(entries: [HistoryRowDragEntry(writer: provider, icon: nil)], containsFileURLs: false)
  }

  private static func filePayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    let existingURLs = item.filePaths
      .map(URL.init(fileURLWithPath:))
      .filter { FileManager.default.fileExists(atPath: $0.path) }

    guard !existingURLs.isEmpty else {
      // The files are gone; at least the paths remain useful as text.
      return textPayload(for: item)
    }

    let showsIcons = existingURLs.count > 1
    let entries = existingURLs.map { url -> HistoryRowDragEntry in
      let icon: NSImage?
      if showsIcons {
        let fileIcon = NSWorkspace.shared.icon(forFile: url.path)
        fileIcon.size = fileIconSize
        icon = fileIcon
      } else {
        icon = nil
      }
      return HistoryRowDragEntry(writer: url as NSURL, icon: icon)
    }
    return HistoryRowDragPayload(entries: entries, containsFileURLs: true)
  }

  private static func linkPayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    guard let url = item.browserURL else {
      return textPayload(for: item)
    }

    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(url.absoluteString, forType: .URL)
    if let title = item.itemTitle ?? item.linkPreviewDetails?.title?.nilIfEmpty {
      pasteboardItem.setString(title, forType: urlNameType)
    }
    pasteboardItem.setString(url.absoluteString, forType: .string)
    return singleEntryPayload(pasteboardItem)
  }

  private static func richTextPayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    let pasteboardItem = NSPasteboardItem()
    var hasContent = false
    if let rtfData = item.rtfData {
      pasteboardItem.setData(rtfData, forType: .rtf)
      hasContent = true
    }
    if let html = item.html?.nilIfEmpty {
      pasteboardItem.setString(html, forType: .html)
      hasContent = true
    }
    if let text = item.text?.nilIfEmpty {
      pasteboardItem.setString(text, forType: .string)
      hasContent = true
    }

    guard hasContent else {
      return textPayload(for: item)
    }

    return singleEntryPayload(pasteboardItem)
  }

  private static func colorPayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(item.previewText, forType: .string)
    // Color wells and palettes read an archived NSColor; everything else gets
    // the color as the user copied it.
    if let color = NSColor(colorItemText: item.previewText),
       let colorData = color.pasteboardPropertyList(forType: .color) as? Data {
      pasteboardItem.setData(colorData, forType: .color)
    }
    return singleEntryPayload(pasteboardItem)
  }

  private static func textPayload(for item: ClipboardItem) -> HistoryRowDragPayload? {
    let text = item.previewText
    guard !text.isEmpty else {
      return nil
    }

    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(text, forType: .string)
    return singleEntryPayload(pasteboardItem)
  }

  private static func singleEntryPayload(_ writer: NSPasteboardWriting) -> HistoryRowDragPayload {
    HistoryRowDragPayload(entries: [HistoryRowDragEntry(writer: writer, icon: nil)], containsFileURLs: false)
  }

  /// The name the promised PNG gets at the destination: the item's own title
  /// when it has one, otherwise a timestamped name in the style of screenshots.
  private static func promisedImageFileName(for item: ClipboardItem) -> String {
    let baseName: String
    if let title = item.itemTitle {
      baseName = title
    } else {
      let formatter = DateFormatter()
      formatter.locale = L10n.currentLocale
      formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
      baseName = "\(ClipboardKind.image.title) \(formatter.string(from: item.copiedAt))"
    }

    let sanitized = baseName
      .components(separatedBy: CharacterSet(charactersIn: "/:\\").union(.newlines))
      .joined(separator: "-")
      .trimmingCharacters(in: .whitespaces)
    let limited = String(sanitized.prefix(120))
    return (limited.isEmpty ? ClipboardKind.image.title : limited) + ".png"
  }
}

/// Source for drags that start in the history table. Drags are copy-only for
/// file URLs, so a destination on the same volume never moves the user's file;
/// other payloads also allow the generic operation for destinations that only
/// answer with it. Inside the app the only destination is the table itself,
/// which moves pinned favorites into a new order.
final class HistoryDragSource: NSObject, NSDraggingSource {
  var containsFileURLs = false
  var allowsMoveWithinApplication = false
  var onEnded: ((NSDragOperation) -> Void)?

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    guard context == .outsideApplication else {
      return allowsMoveWithinApplication ? .move : []
    }

    return containsFileURLs ? .copy : [.copy, .generic]
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    onEnded?(operation)
  }
}
