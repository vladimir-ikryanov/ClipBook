import AppKit

/// Renders text that holds an SVG document, such as markup copied from a design
/// tool or a code editor, so the history and the preview can show the picture
/// instead of the code. The item itself stays text and is still pasted as the
/// markup; only the way it is shown changes.
///
/// The markup is parsed and drawn on a queue of its own: the first SVG a launch
/// draws takes AppKit 40-60 ms to set up, which the history must not wait for.
@MainActor
final class SVGImageRenderer {
  static let shared = SVGImageRenderer()

  /// How bright the drawn parts of a picture are, so it can be put on a
  /// background it stays visible on: a black icon disappears on a dark row.
  nonisolated enum Tone: Sendable {
    case dark
    case medium
    case light
  }

  // Never changed once made, so it is handed from the drawing queue to the main thread.
  nonisolated final class Rendering: @unchecked Sendable {
    /// The picture itself, drawn from the markup at any size.
    let image: NSImage
    /// A small bitmap of the picture for the history rows, which redraw often.
    let thumbnail: NSImage
    let tone: Tone

    init(image: NSImage, thumbnail: NSImage, tone: Tone) {
      self.image = image
      self.thumbnail = thumbnail
      self.tone = tone
    }

    /// The background the picture is drawn on: `matchingBackground` while the
    /// picture stands out against the appearance, a solid opposite one when it
    /// would blend in.
    func backgroundColor(matching matchingBackground: NSColor) -> NSColor {
      let tone = tone
      return NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch (tone, isDark) {
        case (.dark, true):
          return SVGImageRenderer.lightBackgroundColor
        case (.light, false):
          return SVGImageRenderer.darkBackgroundColor
        default:
          return matchingBackground
        }
      }
    }
  }

  // Larger documents are left as text: they take long to parse on the main
  // thread, and are rarely something to recognise at a glance anyway.
  private nonisolated static let maximumByteCount = 512 * 1024
  // Enough to find the root element after an XML declaration, a doctype and a
  // comment or two, without scanning the whole document.
  private nonisolated static let prologueCharacterLimit = 4096
  // The thumbnail fills the 34 point type box of a row, so this covers
  // displays up to 3x.
  private nonisolated static let thumbnailMaximumPixelSize: CGFloat = 102
  private nonisolated static let thumbnailMaximumPointSize: CGFloat = 34
  private nonisolated static let lightBackgroundColor = NSColor(white: 0.94, alpha: 1)
  private nonisolated static let darkBackgroundColor = NSColor(white: 0.18, alpha: 1)

  // Text that fails to render is remembered too, so a row does not parse it
  // again every time it is shown.
  private final class CacheEntry {
    let rendering: Rendering?

    init(_ rendering: Rendering?) {
      self.rendering = rendering
    }
  }

  private let cache: NSCache<NSString, CacheEntry> = {
    let cache = NSCache<NSString, CacheEntry>()
    cache.countLimit = 200
    return cache
  }()
  // One document at a time: drawing SVG is quick once AppKit is set up, and
  // the rows ask for only the few in view.
  private let renderQueue = DispatchQueue(label: "com.clipbook.svg-rendering", qos: .userInitiated)
  private var pendingCompletions: [String: [(Rendering?) -> Void]] = [:]

  /// The picture the item's text describes, or nil when the text is not an SVG
  /// document or it cannot be drawn. A picture not drawn yet is drawn right
  /// away, so this is for the preview, which the user opens; the history rows
  /// use `rendering(for:completion:)`.
  func rendering(for item: ClipboardItem) -> Rendering? {
    guard let (key, text) = Self.cacheKey(for: item) else {
      return nil
    }

    if let entry = cache.object(forKey: key as NSString) {
      return entry.rendering
    }

    let rendering = Self.render(text)
    cache.setObject(CacheEntry(rendering), forKey: key as NSString)
    return rendering
  }

  /// Returns the picture the item's text describes when it is already drawn.
  /// Otherwise, for text that is an SVG document, it draws the picture in the
  /// background, returns nil, and calls `completion` on the main thread with
  /// the result, nil when the markup cannot be drawn.
  func rendering(for item: ClipboardItem, completion: @escaping (Rendering?) -> Void) -> Rendering? {
    guard let (key, text) = Self.cacheKey(for: item) else {
      return nil
    }

    if let entry = cache.object(forKey: key as NSString) {
      return entry.rendering
    }

    if pendingCompletions[key] != nil {
      pendingCompletions[key]?.append(completion)
      return nil
    }

    pendingCompletions[key] = [completion]
    renderQueue.async {
      let rendering = Self.render(text)
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          self.cache.setObject(CacheEntry(rendering), forKey: key as NSString)
          let completions = self.pendingCompletions.removeValue(forKey: key) ?? []
          completions.forEach { $0(rendering) }
        }
      }
    }
    return nil
  }

  // Text that is an SVG document, keyed by the item and its text, so an edited
  // item is drawn again.
  private static func cacheKey(for item: ClipboardItem) -> (String, String)? {
    guard item.kind == .text || item.kind == .richText,
          let text = item.text,
          isSVGMarkup(text) else {
      return nil
    }

    return ("\(item.id.uuidString)-\(text.hashValue)", text)
  }

  /// Whether the text is a whole SVG document: an `svg` root element, after at
  /// most an XML declaration, a doctype and comments, closed at the very end.
  /// A page or a component that only contains an SVG somewhere is not one.
  nonisolated static func isSVGMarkup(_ text: String) -> Bool {
    guard text.utf8.count <= maximumByteCount,
          let start = text.firstIndex(where: { !$0.isWhitespace }),
          let last = text.lastIndex(where: { !$0.isWhitespace }) else {
      return false
    }

    let content = text[start...last]
    guard content.first == "<", content.suffix(6).lowercased() == "</svg>" else {
      return false
    }

    let prologue = String(content.prefix(prologueCharacterLimit))
    let pattern = #"^(?:\s+|<\?xml[^>]*>|<!--[\s\S]*?-->|<!DOCTYPE[^>]*>)*<svg[\s>]"#
    return prologue.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
  }

  private nonisolated static func render(_ text: String) -> Rendering? {
    guard let image = NSImage(data: Data(text.utf8)),
          image.size.width > 0,
          image.size.height > 0,
          let (thumbnail, tone) = makeThumbnail(of: image) else {
      return nil
    }

    return Rendering(image: image, thumbnail: thumbnail, tone: tone)
  }

  // Draws the picture into a small bitmap, which also tells how bright it is.
  private nonisolated static func makeThumbnail(of image: NSImage) -> (NSImage, Tone)? {
    let scale = min(
      thumbnailMaximumPixelSize / image.size.width,
      thumbnailMaximumPixelSize / image.size.height
    )
    let width = max(1, Int((image.size.width * scale).rounded()))
    let height = max(1, Int((image.size.height * scale).rounded()))
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
      return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = context.makeImage(), let data = context.data else {
      return nil
    }

    let tone = tone(ofPixels: data.assumingMemoryBound(to: UInt8.self), count: width * height)
    let pointScale = thumbnailMaximumPointSize / CGFloat(max(width, height))
    let thumbnail = NSImage(
      cgImage: cgImage,
      size: NSSize(width: CGFloat(width) * pointScale, height: CGFloat(height) * pointScale)
    )
    return (thumbnail, tone)
  }

  // The average brightness of the drawn pixels, each counted by how opaque it
  // is, so the transparent background around a shape does not dilute it.
  private nonisolated static func tone(ofPixels pixels: UnsafePointer<UInt8>, count: Int) -> Tone {
    var luminance: Double = 0
    var coverage: Double = 0
    for index in 0..<count {
      let pixel = pixels + index * 4
      // The components are premultiplied, so they already carry the alpha.
      luminance += 0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])
      coverage += Double(pixel[3])
    }

    guard coverage > 0 else {
      return .medium
    }

    let averageLuminance = luminance / coverage
    if averageLuminance < 0.3 {
      return .dark
    }
    if averageLuminance > 0.7 {
      return .light
    }
    return .medium
  }
}
