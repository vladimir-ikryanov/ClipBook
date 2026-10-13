import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

final class FilePreviewCache {
  private struct SourceSignature: Equatable {
    let modificationTime: TimeInterval
    let fileSize: Int64
  }

  private struct Metadata: Codable {
    let sourcePath: String
    let modificationTime: TimeInterval
    let fileSize: Int64
    let targetWidth: Int
    let targetHeight: Int

    func matches(sourcePath: String, signature: SourceSignature, targetSize: CGSize) -> Bool {
      self.sourcePath == sourcePath
        && modificationTime == signature.modificationTime
        && fileSize == signature.fileSize
        && targetWidth == Int(targetSize.width.rounded())
        && targetHeight == Int(targetSize.height.rounded())
    }
  }

  private struct CachedDisplaySize {
    let signature: SourceSignature
    let size: CGSize
  }

  private let directory: URL
  private let fileManager: FileManager
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let generationQueue = DispatchQueue(label: "com.clipbook.file-preview-cache", qos: .utility)
  private let pendingLock = NSLock()
  private let imageCache = NSCache<NSString, NSImage>()
  private var pendingKeys: Set<String> = []
  private var displaySizeCache: [String: CachedDisplaySize] = [:]
  private var imageFileCache: [String: Bool] = [:]

  init(directory: URL, fileManager: FileManager = .default) {
    self.directory = directory
    self.fileManager = fileManager
  }

  func image(
    forFileAt filePath: String,
    targetSize: CGSize,
    completion: @escaping (NSImage) -> Void
  ) -> NSImage {
    // Only picture thumbnails are worth caching. A file icon comes from the system
    // quickly, while encoding it for the disk cache takes hundreds of milliseconds
    // for every icon, since it carries every size the system has for it.
    guard isImageFile(at: filePath) else {
      return fallbackImage(forFileAt: filePath)
    }

    let targetSize = normalizedTargetSize(targetSize)
    let key = cacheKey(filePath: filePath, targetSize: targetSize)

    if let image = cachedImage(filePath: filePath, targetSize: targetSize, key: key) {
      return image
    }

    let fallback = fallbackImage(forFileAt: filePath)
    guard let signature = sourceSignature(forFileAt: filePath) else {
      return fallback
    }

    scheduleImageThumbnailGeneration(
      filePath: filePath,
      targetSize: targetSize,
      signature: signature,
      key: key,
      completion: completion
    )

    return fallback
  }

  // Rows ask this for every height pass and every configure, so the answer is
  // remembered per path. The extension settles it without touching the disk;
  // only a file without one is asked for its content type.
  func isImageFile(at filePath: String) -> Bool {
    if let isImage = imageFileCache[filePath] {
      return isImage
    }

    let fileURL = URL(fileURLWithPath: filePath)
    let isImage: Bool
    let pathExtension = fileURL.pathExtension
    if !pathExtension.isEmpty, let type = UTType(filenameExtension: pathExtension) {
      isImage = type.conforms(to: .image)
    } else if let type = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
      isImage = type.conforms(to: .image)
    } else {
      // A missing file is not remembered as a non-image: it may appear later.
      return false
    }

    imageFileCache[filePath] = isImage
    return isImage
  }

  func displaySizeForImageFile(at filePath: String) -> CGSize? {
    guard isImageFile(at: filePath),
          let signature = sourceSignature(forFileAt: filePath) else {
      return nil
    }

    if let cached = displaySizeCache[filePath], cached.signature == signature {
      return cached.size
    }

    let fileURL = URL(fileURLWithPath: filePath)
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = cgFloatProperty(properties[kCGImagePropertyPixelWidth]),
          let height = cgFloatProperty(properties[kCGImagePropertyPixelHeight]),
          width > 0,
          height > 0 else {
      return nil
    }

    let dpiWidth = cgFloatProperty(properties[kCGImagePropertyDPIWidth])
    let dpiHeight = cgFloatProperty(properties[kCGImagePropertyDPIHeight])
    let size = CGSize(
      width: displayLength(forPixelLength: width, dpi: dpiWidth),
      height: displayLength(forPixelLength: height, dpi: dpiHeight)
    )
    displaySizeCache[filePath] = CachedDisplaySize(signature: signature, size: size)
    return size
  }

  func removePreviews(forFilePaths filePaths: Set<String>) {
    guard !filePaths.isEmpty else {
      return
    }

    removeCacheEntries { metadata in
      filePaths.contains(metadata.sourcePath)
    }
  }

  func prune(keepingFilePaths filePaths: Set<String>) {
    removeCacheEntries { metadata in
      !filePaths.contains(metadata.sourcePath)
    }
  }

  func removeAll() {
    imageCache.removeAllObjects()
    displaySizeCache.removeAll()
    imageFileCache.removeAll()
    pendingLock.withLock {
      pendingKeys.removeAll()
    }
    try? fileManager.removeItem(at: directory)
  }

  private func cachedImage(filePath: String, targetSize: CGSize, key: String) -> NSImage? {
    guard let signature = sourceSignature(forFileAt: filePath),
          let metadata = readMetadata(key: key),
          metadata.matches(sourcePath: filePath, signature: signature, targetSize: targetSize) else {
      return nil
    }

    if let image = imageCache.object(forKey: key as NSString) {
      return image
    }

    guard let image = NSImage(contentsOf: imageURL(forKey: key)) else {
      return nil
    }

    imageCache.setObject(image, forKey: key as NSString)
    return image
  }

  private func scheduleImageThumbnailGeneration(
    filePath: String,
    targetSize: CGSize,
    signature: SourceSignature,
    key: String,
    completion: @escaping (NSImage) -> Void
  ) {
    guard beginGeneration(forKey: key) else {
      return
    }

    let fileURL = URL(fileURLWithPath: filePath)
    let maximumPixelSize = max(Int(max(targetSize.width, targetSize.height).rounded()), 1) * 2
    generationQueue.async { [weak self] in
      guard let self else {
        return
      }

      defer { self.endGeneration(forKey: key) }

      guard let data = Self.thumbnailPNGData(from: fileURL, maximumPixelSize: maximumPixelSize) else {
        return
      }

      do {
        try self.writeCachedImageData(
          data,
          filePath: filePath,
          targetSize: targetSize,
          signature: signature,
          key: key
        )
      } catch {
        return
      }

      guard let image = NSImage(data: data) else {
        return
      }

      self.imageCache.setObject(image, forKey: key as NSString)
      DispatchQueue.main.async {
        completion(image)
      }
    }
  }

  private func fallbackImage(forFileAt filePath: String) -> NSImage {
    NSWorkspace.shared.icon(forFile: filePath)
  }

  private func writeCachedImageData(
    _ data: Data,
    filePath: String,
    targetSize: CGSize,
    signature: SourceSignature,
    key: String
  ) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: imageURL(forKey: key), options: .atomic)
    let metadata = Metadata(
      sourcePath: filePath,
      modificationTime: signature.modificationTime,
      fileSize: signature.fileSize,
      targetWidth: Int(targetSize.width.rounded()),
      targetHeight: Int(targetSize.height.rounded())
    )
    let metadataData = try encoder.encode(metadata)
    try metadataData.write(to: metadataURL(forKey: key), options: .atomic)
  }

  private static func thumbnailPNGData(from fileURL: URL, maximumPixelSize: Int) -> Data? {
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
      return nil
    }

    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCache: false,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
    ] as CFDictionary

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      return nil
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else {
      return nil
    }

    CGImageDestinationAddImage(destination, thumbnail, nil)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    return data as Data
  }

  private func sourceSignature(forFileAt filePath: String) -> SourceSignature? {
    guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
          let modificationDate = attributes[.modificationDate] as? Date else {
      return nil
    }

    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
    return SourceSignature(modificationTime: modificationDate.timeIntervalSince1970, fileSize: fileSize)
  }

  private func normalizedTargetSize(_ targetSize: CGSize) -> CGSize {
    CGSize(
      width: max(1, targetSize.width.rounded()),
      height: max(1, targetSize.height.rounded())
    )
  }

  private func cacheKey(filePath: String, targetSize: CGSize) -> String {
    let rawKey = [
      URL(fileURLWithPath: filePath).standardizedFileURL.path,
      String(Int(targetSize.width.rounded())),
      String(Int(targetSize.height.rounded()))
    ].joined(separator: "\n")
    let digest = SHA256.hash(data: Data(rawKey.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func imageURL(forKey key: String) -> URL {
    directory.appendingPathComponent("\(key).png")
  }

  private func metadataURL(forKey key: String) -> URL {
    directory.appendingPathComponent("\(key).json")
  }

  private func readMetadata(key: String) -> Metadata? {
    guard let data = try? Data(contentsOf: metadataURL(forKey: key)) else {
      return nil
    }

    return try? decoder.decode(Metadata.self, from: data)
  }

  private func removeCacheEntries(where shouldRemove: (Metadata) -> Bool) {
    guard let metadataURLs = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      return
    }

    for metadataURL in metadataURLs where metadataURL.pathExtension == "json" {
      guard let data = try? Data(contentsOf: metadataURL),
            let metadata = try? decoder.decode(Metadata.self, from: data),
            shouldRemove(metadata) else {
        continue
      }

      let key = metadataURL.deletingPathExtension().lastPathComponent
      try? fileManager.removeItem(at: metadataURL)
      try? fileManager.removeItem(at: imageURL(forKey: key))
      imageCache.removeObject(forKey: key as NSString)
      displaySizeCache.removeValue(forKey: metadata.sourcePath)
      imageFileCache.removeValue(forKey: metadata.sourcePath)
    }
  }

  private func beginGeneration(forKey key: String) -> Bool {
    pendingLock.withLock {
      pendingKeys.insert(key).inserted
    }
  }

  private func endGeneration(forKey key: String) {
    pendingLock.withLock {
      _ = pendingKeys.remove(key)
    }
  }

  private func cgFloatProperty(_ value: Any?) -> CGFloat? {
    switch value {
    case let value as CGFloat:
      return value
    case let value as NSNumber:
      return CGFloat(truncating: value)
    case let value as Double:
      return CGFloat(value)
    case let value as Int:
      return CGFloat(value)
    default:
      return nil
    }
  }

  private func displayLength(forPixelLength pixelLength: CGFloat, dpi: CGFloat?) -> CGFloat {
    guard let dpi, dpi > 0 else {
      return pixelLength
    }

    return pixelLength * 72 / dpi
  }
}

private extension NSLock {
  func withLock<Result>(_ action: () -> Result) -> Result {
    lock()
    defer { unlock() }
    return action()
  }
}
