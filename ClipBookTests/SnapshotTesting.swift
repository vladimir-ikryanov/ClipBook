import AppKit
import CoreGraphics
import Foundation
import Testing
import _Testing_AppKit

/// Compares rendered views against reference images stored in `ClipBookTests/Snapshots`.
///
/// A missing reference image is written and reported as a failure, so the first run after
/// adding a scenario records it and the next run verifies it. `./test.sh --record-snapshots`
/// rewrites every reference image and reports each one as a failure; review the resulting diff.
/// When a comparison fails, the rendered image is attached to the test result, and a diff image
/// too when the two images have the same size.
///
/// The reference images were recorded on macOS 27.2. Text and control rendering differs
/// slightly between macOS releases, so a pixel only counts as different when one of its
/// channels moves by more than `channelTolerance`, and a snapshot only fails when more than
/// `maximumDifferingFraction` of its pixels differ. A snapshot that fails only on another
/// release shows the difference in the attached diff image.
enum SnapshotTesting {
    private static let channelTolerance = 24
    private static let maximumDifferingFraction = 0.01
    /// The diff image shows unchanged pixels as a faded gray, so the changed ones stand out in red.
    private static let unchangedPixelFade: UInt8 = 4
    private static let unchangedPixelLift: UInt8 = 160

    private static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Snapshots", isDirectory: true)

    private static var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
    }

    @MainActor
    static func assertMatchesReference(
        _ snapshot: RenderedViewSnapshot,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let referenceURL = directory.appendingPathComponent("\(name).png")
        if isRecording || !FileManager.default.fileExists(atPath: referenceURL.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try snapshot.pngData.write(to: referenceURL)
                Issue.record("Recorded reference image \(name).png; run the tests again to verify it", sourceLocation: sourceLocation)
            } catch {
                Issue.record("Could not record reference image \(name).png: \(error)", sourceLocation: sourceLocation)
            }
            return
        }

        guard let reference = pixels(of: NSBitmapImageRep(data: (try? Data(contentsOf: referenceURL)) ?? Data())),
              let actual = pixels(of: snapshot.bitmap) else {
            Issue.record("Could not decode \(name).png or the rendered snapshot", sourceLocation: sourceLocation)
            return
        }
        guard reference.width == actual.width, reference.height == actual.height else {
            Attachment.record(snapshot.image, named: "\(name)-actual.png")
            Issue.record(
                "\(name): rendered \(actual.width)x\(actual.height) pixels, reference is \(reference.width)x\(reference.height)",
                sourceLocation: sourceLocation
            )
            return
        }

        let difference = compare(reference, actual)
        if !isWithinTolerance(difference) {
            Attachment.record(snapshot.image, named: "\(name)-actual.png")
            if let diffImage = difference.image {
                Attachment.record(diffImage, named: "\(name)-diff.png")
            }
            let percent = String(format: "%.2f", difference.fraction * 100)
            let allowedPercent = String(format: "%.2f", maximumDifferingFraction * 100)
            let totalPixels = actual.width * actual.height
            Issue.record(
                "\(name): \(difference.differingPixels) of \(totalPixels) pixels differ (\(percent)%, allowed \(allowedPercent)%)",
                sourceLocation: sourceLocation
            )
        }
    }

    // MARK: - Pixel comparison

    static func isWithinTolerance(_ difference: Difference) -> Bool {
        difference.fraction <= maximumDifferingFraction
    }

    struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    struct Difference {
        let differingPixels: Int
        let fraction: Double
        let image: NSImage?
    }

    /// Decodes `rep` into 8-bit premultiplied sRGB so that images stored in different
    /// color spaces compare by what they look like.
    static func pixels(of rep: NSBitmapImageRep?) -> Pixels? {
        guard let cgImage = rep?.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Pixels(width: width, height: height, bytes: bytes) : nil
    }

    /// Both images must have the same dimensions.
    static func compare(_ reference: Pixels, _ actual: Pixels) -> Difference {
        let pixelCount = actual.width * actual.height
        var differing = 0
        var diffBytes = [UInt8](repeating: 0, count: pixelCount * 4)
        for pixel in 0..<pixelCount {
            let offset = pixel * 4
            var exceedsTolerance = false
            for channel in 0..<4 where abs(Int(reference.bytes[offset + channel]) - Int(actual.bytes[offset + channel])) > channelTolerance {
                exceedsTolerance = true
            }
            if exceedsTolerance {
                differing += 1
                diffBytes[offset] = 255
                diffBytes[offset + 3] = 255
            } else {
                let gray = actual.bytes[offset] / unchangedPixelFade + unchangedPixelLift
                diffBytes[offset] = gray
                diffBytes[offset + 1] = gray
                diffBytes[offset + 2] = gray
                diffBytes[offset + 3] = 255
            }
        }
        let fraction = pixelCount == 0 ? 0 : Double(differing) / Double(pixelCount)
        return Difference(
            differingPixels: differing,
            fraction: fraction,
            image: differing == 0 ? nil : image(fromRGBA: diffBytes, width: actual.width, height: actual.height)
        )
    }

    private static func image(fromRGBA bytes: [UInt8], width: Int, height: Int) -> NSImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
