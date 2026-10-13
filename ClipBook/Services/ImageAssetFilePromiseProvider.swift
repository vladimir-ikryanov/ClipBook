import AppKit
import UniformTypeIdentifiers

/// Drag payload for a captured image. The stored PNG asset is offered three
/// ways at once: as a promised file, so Finder, Mail and file pickers receive
/// a real PNG with a readable name; and as PNG and TIFF data, so image-aware
/// destinations such as editors, chats and browsers can take the pixels
/// directly. The data representations are promised rather than written up
/// front, so a drag starts without reading or re-encoding the asset.
final class ImageAssetFilePromiseProvider: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
  private static let writeQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "com.ikryanov.clipbook.image-drag-promises"
    queue.qualityOfService = .userInitiated
    return queue
  }()

  private let assetURL: URL
  private let fileName: String
  /// Set by the history table so the drag also names the item it came from.
  var historyItemID: UUID?

  init(assetURL: URL, fileName: String) {
    self.assetURL = assetURL
    self.fileName = fileName
    super.init()
    fileType = UTType.png.identifier
    delegate = self
  }

  // MARK: - Extra pasteboard types

  override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    // Image data comes first so destinations that read whichever type the
    // pasteboard lists earliest prefer the pixels over the promised file.
    var types = [.png, .tiff] + super.writableTypes(for: pasteboard)
    if historyItemID != nil {
      types.append(.historyItemID)
    }
    return types
  }

  override func writingOptions(
    forType type: NSPasteboard.PasteboardType,
    pasteboard: NSPasteboard
  ) -> NSPasteboard.WritingOptions {
    switch type {
    case .png, .tiff:
      return .promised
    case .historyItemID:
      return []
    default:
      return super.writingOptions(forType: type, pasteboard: pasteboard)
    }
  }

  override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    switch type {
    case .png:
      return try? Data(contentsOf: assetURL)
    case .tiff:
      guard let pngData = try? Data(contentsOf: assetURL) else {
        return nil
      }
      return NSBitmapImageRep(data: pngData)?.tiffRepresentation
    case .historyItemID:
      return historyItemID?.uuidString
    default:
      return super.pasteboardPropertyList(forType: type)
    }
  }

  // MARK: - NSFilePromiseProviderDelegate

  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
    fileName
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    writePromiseTo url: URL,
    completionHandler: @escaping (Error?) -> Void
  ) {
    do {
      try FileManager.default.copyItem(at: assetURL, to: url)
      completionHandler(nil)
    } catch {
      completionHandler(error)
    }
  }

  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    Self.writeQueue
  }
}
