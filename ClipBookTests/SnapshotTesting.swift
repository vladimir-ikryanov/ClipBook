import AppKit
import CoreGraphics
import Foundation
import Testing
import _Testing_AppKit

/// Compares rendered views against reference images stored in `ClipBookTests/Snapshots/macOS-<major>`.
///
/// Each macOS major version has its own directory (`macOS-27`, etc.) and filename prefix
/// (`macOS-27-<name>.png`) so multiple major releases can coexist without bundle resource name
/// collisions. When the running macOS major version has no directory yet, `evaluate` verifies
/// that the view rendered to a non-empty bitmap and succeeds without recording a failure, while
/// optionally writing rendered PNGs into `SNAPSHOT_EXPORT_DIR/macOS-<major>/`.
///
/// Within a recorded OS directory, a missing reference image is written and reported as a failure,
/// so the first run after adding a scenario records it and the next run verifies it.
/// `./test.sh --record-snapshots` rewrites every reference image for the current macOS major
/// version and reports each one as a failure; review the resulting diff. When a comparison fails,
/// the rendered image is attached to the test result, and a diff image too when the two images
/// have the same size.
///
/// Point releases within a major macOS version can render text and controls slightly differently,
/// so a pixel only counts as different when one of its channels moves by more than
/// `channelTolerance`, and a snapshot only fails when more than `maximumDifferingFraction` of its
/// pixels differ.
enum SnapshotTesting {
    enum EvaluationOutcome: Equatable {
        case matched
        case recorded(URL)
        case unrecordedOS(majorVersion: Int, exportedURL: URL?)
        case failed(String)
    }

    private static let channelTolerance = 24
    private static let maximumDifferingFraction = 0.01
    /// The diff image shows unchanged pixels as a faded gray, so the changed ones stand out in red.
    private static let unchangedPixelFade: UInt8 = 4
    private static let unchangedPixelLift: UInt8 = 160

    static let rootDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Snapshots", isDirectory: true)

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
    }

    static func exportDirectory(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let rawPath = environment["SNAPSHOT_EXPORT_DIR"], !rawPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: rawPath, isDirectory: true)
    }

    static var exportDirectory: URL? {
        exportDirectory()
    }

    static func referenceDirectory(
        rootDirectory: URL = Self.rootDirectory,
        majorOSVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> URL {
        rootDirectory.appendingPathComponent("macOS-\(majorOSVersion)", isDirectory: true)
    }

    static func referenceFileURL(
        named name: String,
        rootDirectory: URL = Self.rootDirectory,
        majorOSVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> URL {
        referenceDirectory(rootDirectory: rootDirectory, majorOSVersion: majorOSVersion)
            .appendingPathComponent("macOS-\(majorOSVersion)-\(name).png")
    }

    @MainActor
    static func evaluate(
        _ snapshot: RenderedViewSnapshot,
        named name: String,
        rootDirectory: URL = Self.rootDirectory,
        majorOSVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        isRecording: Bool = Self.isRecording,
        exportDirectory: URL? = Self.exportDirectory
    ) -> EvaluationOutcome {
        let fileName = "macOS-\(majorOSVersion)-\(name).png"
        let osDirectory = referenceDirectory(rootDirectory: rootDirectory, majorOSVersion: majorOSVersion)
        let referenceURL = referenceFileURL(named: name, rootDirectory: rootDirectory, majorOSVersion: majorOSVersion)

        func writeExportIfConfigured() throws -> URL? {
            guard let exportDirectory else {
                return nil
            }
            let targetDirectory = exportDirectory.appendingPathComponent("macOS-\(majorOSVersion)", isDirectory: true)
            let targetURL = targetDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            try snapshot.pngData.write(to: targetURL)
            return targetURL
        }

        func fail(_ message: String) -> EvaluationOutcome {
            do {
                _ = try writeExportIfConfigured()
                return .failed(message)
            } catch {
                return .failed("\(message) (could not export snapshot: \(error))")
            }
        }

        if isRecording {
            do {
                try FileManager.default.createDirectory(at: osDirectory, withIntermediateDirectories: true)
                try snapshot.pngData.write(to: referenceURL)
                Attachment.record(snapshot.image, named: fileName)
                _ = try writeExportIfConfigured()
                return .recorded(referenceURL)
            } catch {
                return .failed("Could not record reference image \(fileName): \(error)")
            }
        }

        var isOSDirectory: ObjCBool = false
        let osDirectoryExists = FileManager.default.fileExists(atPath: osDirectory.path, isDirectory: &isOSDirectory)
            && isOSDirectory.boolValue

        if !osDirectoryExists {
            guard let actual = pixels(of: snapshot.bitmap), actual.width > 0, actual.height > 0 else {
                return fail("Could not decode non-empty rendered snapshot for \(fileName)")
            }
            Attachment.record(snapshot.image, named: fileName)
            do {
                let exportedURL = try writeExportIfConfigured()
                return .unrecordedOS(majorVersion: majorOSVersion, exportedURL: exportedURL)
            } catch {
                return .failed("Could not export snapshot \(fileName): \(error)")
            }
        }

        if !FileManager.default.fileExists(atPath: referenceURL.path) {
            do {
                try snapshot.pngData.write(to: referenceURL)
                Attachment.record(snapshot.image, named: fileName)
                _ = try writeExportIfConfigured()
                return .recorded(referenceURL)
            } catch {
                return .failed("Could not record reference image \(fileName): \(error)")
            }
        }

        let actualAttachmentName = "macOS-\(majorOSVersion)-\(name)-actual.png"
        let diffAttachmentName = "macOS-\(majorOSVersion)-\(name)-diff.png"

        guard let reference = pixels(of: NSBitmapImageRep(data: (try? Data(contentsOf: referenceURL)) ?? Data())),
              let actual = pixels(of: snapshot.bitmap) else {
            Attachment.record(snapshot.image, named: actualAttachmentName)
            return fail("Could not decode \(fileName) or the rendered snapshot")
        }
        guard reference.width == actual.width, reference.height == actual.height else {
            Attachment.record(snapshot.image, named: actualAttachmentName)
            return fail(
                "\(fileName): rendered \(actual.width)x\(actual.height) pixels, reference is \(reference.width)x\(reference.height)"
            )
        }

        let difference = compare(reference, actual)
        if !isWithinTolerance(difference) {
            Attachment.record(snapshot.image, named: actualAttachmentName)
            if let diffImage = difference.image {
                Attachment.record(diffImage, named: diffAttachmentName)
            }
            let percent = String(format: "%.2f", difference.fraction * 100)
            let allowedPercent = String(format: "%.2f", maximumDifferingFraction * 100)
            let totalPixels = actual.width * actual.height
            return fail(
                "\(fileName): \(difference.differingPixels) of \(totalPixels) pixels differ (\(percent)%, allowed \(allowedPercent)%)"
            )
        }

        return .matched
    }

    @MainActor
    static func assertMatchesReference(
        _ snapshot: RenderedViewSnapshot,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        switch evaluate(snapshot, named: name) {
        case .matched, .unrecordedOS:
            return
        case .recorded(let url):
            Issue.record(
                Comment(rawValue: "Recorded reference image \(url.lastPathComponent); run the tests again to verify it"),
                sourceLocation: sourceLocation
            )
        case .failed(let message):
            Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
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
