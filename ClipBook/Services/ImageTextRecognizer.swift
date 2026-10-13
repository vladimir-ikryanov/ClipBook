import Foundation
import ImageIO
import Vision

/// Reads the text and the QR codes of a stored image. It takes from a fraction
/// of a second to several seconds, the first time after launch much longer,
/// so it runs on a queue of its own after the image is in the history, never
/// while the pasteboard is read: copies made meanwhile would be missed.
nonisolated enum ImageTextRecognizer {
  /// The longest side Vision is given. Accurate text recognition finds nothing
  /// in images of about 8 megapixels or more, such as a full-screen screenshot
  /// of a 2560x1440 display at 2x, and a bigger image only takes more memory.
  static let maximumPixelSize = 3_200

  static func recognizeContent(ofImageAt url: URL) -> RecognizedImageContent {
    defer { malloc_zone_pressure_relief(nil, 0) }
    return autoreleasepool {
      guard let handler = makeRequestHandler(forImageAt: url) else {
        return .empty
      }

      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.usesLanguageCorrection = true

      let barcodeRequest = VNDetectBarcodesRequest()
      barcodeRequest.symbologies = [.qr]

      do {
        try handler.perform([textRequest, barcodeRequest])
      } catch {
        NSLog("ClipBook image content recognition failed: \(error.localizedDescription)")
        return .empty
      }

      let recognizedLines = textRequest.results?
        .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty } ?? []
      // Several QR codes in one image are kept in the order they were found,
      // one per line, so nothing the image carries is lost.
      let qrCodePayloads = barcodeRequest.results?
        .compactMap { $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty } ?? []

      return RecognizedImageContent(
        text: recognizedLines.isEmpty ? nil : recognizedLines.joined(separator: "\n"),
        qrCodeText: qrCodePayloads.isEmpty ? nil : qrCodePayloads.joined(separator: "\n")
      )
    }
  }

  /// Vision reads an image that fits from its file. A bigger one is scaled
  /// down first, upright, so its longest side is `maximumPixelSize`.
  private static func makeRequestHandler(forImageAt url: URL) -> VNImageRequestHandler? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) > 0 else {
      return nil
    }

    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
    let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
    guard max(width, height) > maximumPixelSize else {
      return VNImageRequestHandler(url: url, options: [:])
    }

    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      return nil
    }

    return VNImageRequestHandler(cgImage: image, options: [:])
  }
}
