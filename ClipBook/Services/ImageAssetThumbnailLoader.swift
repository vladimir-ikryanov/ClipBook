import AppKit
import ImageIO

/// Decodes history image assets off the main thread, downsampled to the box a
/// row shows them in, and keeps the results in memory so a row scrolled back
/// into view gets its picture at once. Decoding a full-size screenshot on the
/// main thread for every row that scrolls in is what made image rows stutter.
final class ImageAssetThumbnailLoader {
  static let shared = ImageAssetThumbnailLoader()

  private let cache = NSCache<NSString, NSImage>()
  private let decodeQueue = DispatchQueue(
    label: "com.clipbook.image-asset-thumbnails",
    qos: .userInitiated,
    attributes: .concurrent
  )
  private let lock = NSLock()
  private var pendingCompletions: [String: [(NSImage?) -> Void]] = [:]

  init(memoryLimit: Int = 128 * 1024 * 1024) {
    cache.totalCostLimit = memoryLimit
  }

  /// Thumbnail sizes are rounded up to a step so a small change of the table
  /// width reuses the decoded picture instead of decoding it again.
  static func maximumPixelSize(forDisplaySize displaySize: CGSize, scale: CGFloat) -> Int {
    let step: CGFloat = 128
    let pixels = max(displaySize.width, displaySize.height) * max(scale, 1)
    return Int(max(step, (pixels / step).rounded(.up) * step))
  }

  /// Returns the cached thumbnail when there is one. Otherwise it starts
  /// decoding in the background, returns nil, and calls `completion` on the
  /// main thread with the result (nil when the file cannot be read).
  func thumbnail(
    for url: URL,
    maximumPixelSize: Int,
    completion: @escaping (NSImage?) -> Void
  ) -> NSImage? {
    let key = "\(url.path)\n\(maximumPixelSize)"
    if let image = cache.object(forKey: key as NSString) {
      return image
    }

    let startsDecoding: Bool = lock.withLock {
      if pendingCompletions[key] != nil {
        pendingCompletions[key]?.append(completion)
        return false
      }

      pendingCompletions[key] = [completion]
      return true
    }
    guard startsDecoding else {
      return nil
    }

    decodeQueue.async { [weak self] in
      let image = Self.decodeThumbnail(at: url, maximumPixelSize: maximumPixelSize)
      guard let self else {
        return
      }

      if let image {
        self.cache.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
      }
      let completions = self.lock.withLock {
        self.pendingCompletions.removeValue(forKey: key) ?? []
      }
      DispatchQueue.main.async {
        completions.forEach { $0(image) }
      }
    }
    return nil
  }

  func removeAll() {
    cache.removeAllObjects()
  }

  private static func decodeThumbnail(at url: URL, maximumPixelSize: Int) -> NSImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return nil
    }

    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
    ] as CFDictionary
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      return nil
    }

    // The point size follows the file's DPI, the same way `NSImage(contentsOf:)`
    // sizes a picture, so a retina screenshot keeps the size it had before.
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let dpiWidth = (properties?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0
    let dpiHeight = (properties?[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue ?? 0
    let pointSize = CGSize(
      width: CGFloat(thumbnail.width) * (dpiWidth > 0 ? 72 / dpiWidth : 1),
      height: CGFloat(thumbnail.height) * (dpiHeight > 0 ? 72 / dpiHeight : 1)
    )
    return NSImage(cgImage: thumbnail, size: pointSize)
  }

  private static func cost(of image: NSImage) -> Int {
    guard let representation = image.representations.first else {
      return 0
    }

    return representation.pixelsWide * representation.pixelsHigh * 4
  }
}

private extension NSLock {
  func withLock<Result>(_ action: () -> Result) -> Result {
    lock()
    defer { unlock() }
    return action()
  }
}
