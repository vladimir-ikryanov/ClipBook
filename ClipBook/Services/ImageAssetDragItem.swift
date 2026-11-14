import AppKit

/// Drag payload for a captured image. The stored PNG asset is offered three
/// ways at once: as PNG and TIFF data, so image-aware destinations such as
/// editors and chats can take the pixels directly; and as the URL of a copy of
/// the PNG with a readable name, so Finder, Mail and file pickers receive a
/// real file, and Chromium and Electron apps such as Figma, which import
/// images dropped as files, take it too.
///
/// The image data is provided on demand, so a drag starts without reading or
/// re-encoding the asset. The copy is made up front, but within a volume it is
/// a clone that costs next to nothing. A file promise would put off the copy
/// too, but other apps get neither the image data a promise provider offers
/// next to its file nor anything at all in Chromium, which takes no promises.
enum ImageAssetDragItem {
  static func make(assetURL: URL, fileName: String) -> NSPasteboardItem {
    let item = NSPasteboardItem()
    // Image data comes first so destinations that read whichever type the
    // pasteboard lists earliest prefer the pixels over the file.
    item.setDataProvider(ImageAssetDataProvider(assetURL: assetURL), forTypes: [.png, .tiff])
    if let fileURL = ImageDragFiles.makeCopy(of: assetURL, named: fileName) {
      item.setString(fileURL.absoluteString, forType: .fileURL)
    }
    return item
  }
}

/// Reads the asset only when a destination asks for its data, and converts it
/// to TIFF only for destinations that want TIFF.
private final class ImageAssetDataProvider: NSObject, NSPasteboardItemDataProvider {
  private let assetURL: URL

  init(assetURL: URL) {
    self.assetURL = assetURL
  }

  func pasteboard(
    _ pasteboard: NSPasteboard?,
    item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    guard let pngData = try? Data(contentsOf: assetURL) else {
      return
    }

    switch type {
    case .png:
      item.setData(pngData, forType: .png)
    case .tiff:
      if let tiffData = NSBitmapImageRep(data: pngData)?.tiffRepresentation {
        item.setData(tiffData, forType: .tiff)
      }
    default:
      break
    }
  }
}

/// Named copies of image assets handed out as files when images are dragged.
/// Each copy gets a folder of its own, so two images with the same name
/// never collide. A destination may read the file well after the drop ends, so
/// a copy stays until a later drag clears out the ones older than an hour.
enum ImageDragFiles {
  private static let maximumAge: TimeInterval = 60 * 60

  private static var directory: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("Dragged Images", isDirectory: true)
  }

  static func makeCopy(of assetURL: URL, named fileName: String) -> URL? {
    let fileManager = FileManager.default
    removeExpiredCopies()

    let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = folder.appendingPathComponent(fileName, isDirectory: false)
    do {
      try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
      // Copies within a volume are APFS clones, so this does not duplicate
      // the image data on disk or take time for large images.
      try fileManager.copyItem(at: assetURL, to: url)
      return url
    } catch {
      try? fileManager.removeItem(at: folder)
      return nil
    }
  }

  private static func removeExpiredCopies() {
    let fileManager = FileManager.default
    guard let folders = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.creationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    let cutoff = Date().addingTimeInterval(-maximumAge)
    for folder in folders {
      let created = (try? folder.resourceValues(forKeys: [.creationDateKey]))?.creationDate
      if let created, created < cutoff {
        try? fileManager.removeItem(at: folder)
      }
    }
  }
}
