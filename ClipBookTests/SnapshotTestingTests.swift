import AppKit
import Foundation
import Testing

/// The comparison the snapshot tests rely on has to be able to fail.
@Suite
struct SnapshotComparisonTests {
    private static func pixels(width: Int, height: Int, value: UInt8 = 100) -> SnapshotTesting.Pixels {
        SnapshotTesting.Pixels(width: width, height: height, bytes: [UInt8](repeating: value, count: width * height * 4))
    }

    /// `pixels` with every channel of the pixels in the given block moved by `delta`.
    private static func changing(
        _ pixels: SnapshotTesting.Pixels,
        block: (x: Range<Int>, y: Range<Int>),
        by delta: Int
    ) -> SnapshotTesting.Pixels {
        var bytes = pixels.bytes
        for y in block.y {
            for x in block.x {
                for channel in 0..<4 {
                    let offset = (y * pixels.width + x) * 4 + channel
                    bytes[offset] = UInt8(Int(bytes[offset]) + delta)
                }
            }
        }
        return SnapshotTesting.Pixels(width: pixels.width, height: pixels.height, bytes: bytes)
    }

    @Test
    func identicalImagesDoNotDiffer() {
        let image = Self.pixels(width: 40, height: 30)
        let difference = SnapshotTesting.compare(image, image)
        #expect(difference.differingPixels == 0)
        #expect(difference.image == nil)
        #expect(SnapshotTesting.isWithinTolerance(difference))
    }

    @Test
    func renderingNoiseWithinTheChannelToleranceIsIgnored() {
        let reference = Self.pixels(width: 40, height: 30)
        let noisy = Self.changing(reference, block: (0..<40, 0..<30), by: 20)
        #expect(SnapshotTesting.compare(reference, noisy).differingPixels == 0)
    }

    @Test
    func aChangeBeyondTheChannelToleranceIsCountedAndDrawn() {
        let reference = Self.pixels(width: 40, height: 30)
        let changed = Self.changing(reference, block: (5..<6, 7..<8), by: 40)
        let difference = SnapshotTesting.compare(reference, changed)
        #expect(difference.differingPixels == 1)
        #expect(difference.image != nil)
    }

    @Test
    func aSolidIconSizedBlockChangedInARowFailsTheTolerance() {
        // A row at 2x is 960 by 100 pixels; a 20-point icon is 40 by 40 of them. A glyph changes
        // fewer pixels than a solid block does, so this is the most obvious change that is caught.
        let row = Self.pixels(width: 960, height: 100)
        let iconChanged = Self.changing(row, block: (100..<140, 30..<70), by: 60)
        let difference = SnapshotTesting.compare(row, iconChanged)
        #expect(difference.differingPixels == 1_600)
        #expect(!SnapshotTesting.isWithinTolerance(difference))

        let singlePixelChanged = Self.changing(row, block: (100..<101, 30..<31), by: 60)
        #expect(SnapshotTesting.isWithinTolerance(SnapshotTesting.compare(row, singlePixelChanged)))
    }

    @Test
    func decodingAnImageGivesItsPixelSizeAndColors() throws {
        let rep = try TestSupport.makeBitmap(pixelsWide: 6, pixelsHigh: 4)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 6, height: 4).fill()
        NSGraphicsContext.restoreGraphicsState()

        let decoded = try #require(SnapshotTesting.pixels(of: rep))
        #expect(decoded.width == 6)
        #expect(decoded.height == 4)
        #expect(decoded.bytes.count == 6 * 4 * 4)
        #expect(abs(Int(decoded.bytes[0]) - 255) <= 2)
        #expect(decoded.bytes[1] <= 2)
        #expect(decoded.bytes[2] <= 2)
        #expect(decoded.bytes[3] == 255)
    }

    private static func makeSnapshot(
        width: Int = 8,
        height: Int = 6,
        color: NSColor = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    ) throws -> RenderedViewSnapshot {
        let rep = try TestSupport.makeBitmap(pixelsWide: width, pixelsHigh: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        let pngData = try #require(rep.representation(using: .png, properties: [:]))
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return RenderedViewSnapshot(image: image, bitmap: rep, pngData: pngData)
    }

    @Test
    func referenceFileURLIncludesMajorOSFolderAndPrefixedBasename() {
        let root = URL(fileURLWithPath: "/tmp/snapshots", isDirectory: true)
        let dir = SnapshotTesting.referenceDirectory(rootDirectory: root, majorOSVersion: 27)
        let fileURL = SnapshotTesting.referenceFileURL(named: "EmptyHistory-dark", rootDirectory: root, majorOSVersion: 27)

        #expect(dir.path == "/tmp/snapshots/macOS-27")
        #expect(fileURL.path == "/tmp/snapshots/macOS-27/macOS-27-EmptyHistory-dark.png")
    }

    @Test
    func allTwelveMacOS27ReferenceImagesExistOnDisk() {
        var count = 0
        for scenario in SnapshotScenario.allCases {
            for appearance in SnapshotAppearance.allCases {
                let url = SnapshotTesting.referenceFileURL(
                    named: "\(scenario.rawValue)-\(appearance.rawValue)",
                    majorOSVersion: 27
                )
                #expect(FileManager.default.fileExists(atPath: url.path))
                count += 1
            }
        }
        #expect(count == 12)
    }

    @Test
    func exportDirectoryParsesFilePathsIncludingSpacesAndRejectsEmpty() {
        #expect(SnapshotTesting.exportDirectory(from: [:]) == nil)
        #expect(SnapshotTesting.exportDirectory(from: ["SNAPSHOT_EXPORT_DIR": ""]) == nil)

        let spacedPath = "/tmp/clipbook snapshot export/dir with spaces"
        let exported = SnapshotTesting.exportDirectory(from: ["SNAPSHOT_EXPORT_DIR": spacedPath])
        #expect(exported?.isFileURL == true)
        #expect(exported?.path == spacedPath)
    }

    @Test
    @MainActor
    func isRecordingWritesReferenceImageAndOptionalExport() throws {
        try TestSupport.withTemporaryDirectory { tempDir in
            let root = tempDir.appendingPathComponent("refs", isDirectory: true)
            let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)
            let snapshot = try Self.makeSnapshot()

            let outcomeWithoutExport = SnapshotTesting.evaluate(
                snapshot,
                named: "Sample",
                rootDirectory: root,
                majorOSVersion: 28,
                isRecording: true,
                exportDirectory: nil
            )
            let expectedRef = SnapshotTesting.referenceFileURL(named: "Sample", rootDirectory: root, majorOSVersion: 28)
            #expect(outcomeWithoutExport == .recorded(expectedRef))
            #expect(FileManager.default.fileExists(atPath: expectedRef.path))
            #expect(!FileManager.default.fileExists(atPath: exportDir.path))

            let outcomeWithExport = SnapshotTesting.evaluate(
                snapshot,
                named: "Sample",
                rootDirectory: root,
                majorOSVersion: 28,
                isRecording: true,
                exportDirectory: exportDir
            )
            let expectedExport = exportDir
                .appendingPathComponent("macOS-28", isDirectory: true)
                .appendingPathComponent("macOS-28-Sample.png")
            #expect(outcomeWithExport == .recorded(expectedRef))
            #expect(FileManager.default.fileExists(atPath: expectedExport.path))
        }
    }

    @Test
    @MainActor
    func unrecordedOSExportsWhenConfiguredAndPropagatesInvalidPathErrors() throws {
        try TestSupport.withTemporaryDirectory { tempDir in
            let root = tempDir.appendingPathComponent("refs", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let snapshot = try Self.makeSnapshot()

            let smokeOnly = SnapshotTesting.evaluate(
                snapshot,
                named: "Smoke",
                rootDirectory: root,
                majorOSVersion: 99,
                isRecording: false,
                exportDirectory: nil
            )
            #expect(smokeOnly == .unrecordedOS(majorVersion: 99, exportedURL: nil))

            let exportDir = tempDir.appendingPathComponent("export out", isDirectory: true)
            let exported = SnapshotTesting.evaluate(
                snapshot,
                named: "Smoke",
                rootDirectory: root,
                majorOSVersion: 99,
                isRecording: false,
                exportDirectory: exportDir
            )
            let expectedExportURL = exportDir
                .appendingPathComponent("macOS-99", isDirectory: true)
                .appendingPathComponent("macOS-99-Smoke.png")
            #expect(exported == .unrecordedOS(majorVersion: 99, exportedURL: expectedExportURL))
            #expect(FileManager.default.fileExists(atPath: expectedExportURL.path))

            let blockingFile = tempDir.appendingPathComponent("not-a-directory")
            try Data("occupied".utf8).write(to: blockingFile)
            let failedExport = SnapshotTesting.evaluate(
                snapshot,
                named: "Smoke",
                rootDirectory: root,
                majorOSVersion: 99,
                isRecording: false,
                exportDirectory: blockingFile
            )
            guard case .failed(let message) = failedExport else {
                Issue.record("Expected .failed when export path is a regular file, got \(failedExport)")
                return
            }
            #expect(message.contains("macOS-99-Smoke.png"))
        }
    }

    @Test
    @MainActor
    func recordedOSHandlesMissingMatchedAndFailedBranches() throws {
        try TestSupport.withTemporaryDirectory { tempDir in
            let root = tempDir.appendingPathComponent("refs", isDirectory: true)
            let osDir = SnapshotTesting.referenceDirectory(rootDirectory: root, majorOSVersion: 27)
            try FileManager.default.createDirectory(at: osDir, withIntermediateDirectories: true)
            let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)

            let blueSnapshot = try Self.makeSnapshot(width: 8, height: 6, color: NSColor(srgbRed: 0.1, green: 0.2, blue: 0.9, alpha: 1))
            let expectedRef = SnapshotTesting.referenceFileURL(named: "Card", rootDirectory: root, majorOSVersion: 27)

            let missingOutcome = SnapshotTesting.evaluate(
                blueSnapshot,
                named: "Card",
                rootDirectory: root,
                majorOSVersion: 27,
                isRecording: false,
                exportDirectory: exportDir
            )
            #expect(missingOutcome == .recorded(expectedRef))
            #expect(FileManager.default.fileExists(atPath: expectedRef.path))

            let matchedExportDir = tempDir.appendingPathComponent("matched-exports", isDirectory: true)
            let matchedOutcome = SnapshotTesting.evaluate(
                blueSnapshot,
                named: "Card",
                rootDirectory: root,
                majorOSVersion: 27,
                isRecording: false,
                exportDirectory: matchedExportDir
            )
            #expect(matchedOutcome == .matched)
            #expect(!FileManager.default.fileExists(atPath: matchedExportDir.path))

            let redSnapshot = try Self.makeSnapshot(width: 8, height: 6, color: NSColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1))
            let diffFailureExports = tempDir.appendingPathComponent("diff-exports", isDirectory: true)
            let diffOutcome = SnapshotTesting.evaluate(
                redSnapshot,
                named: "Card",
                rootDirectory: root,
                majorOSVersion: 27,
                isRecording: false,
                exportDirectory: diffFailureExports
            )
            guard case .failed(let diffMessage) = diffOutcome else {
                Issue.record("Expected .failed on pixel mismatch, got \(diffOutcome)")
                return
            }
            #expect(diffMessage.contains("pixels differ"))
            #expect(
                FileManager.default.fileExists(
                    atPath: diffFailureExports.appendingPathComponent("macOS-27/macOS-27-Card.png").path
                )
            )

            let widerSnapshot = try Self.makeSnapshot(width: 12, height: 6)
            let sizeFailureExports = tempDir.appendingPathComponent("size-exports", isDirectory: true)
            let sizeOutcome = SnapshotTesting.evaluate(
                widerSnapshot,
                named: "Card",
                rootDirectory: root,
                majorOSVersion: 27,
                isRecording: false,
                exportDirectory: sizeFailureExports
            )
            guard case .failed(let sizeMessage) = sizeOutcome else {
                Issue.record("Expected .failed on dimension mismatch, got \(sizeOutcome)")
                return
            }
            #expect(sizeMessage.contains("12x6"))
            #expect(
                FileManager.default.fileExists(
                    atPath: sizeFailureExports.appendingPathComponent("macOS-27/macOS-27-Card.png").path
                )
            )

            try Data("corrupt-png".utf8).write(to: expectedRef)
            let corruptExports = tempDir.appendingPathComponent("corrupt-exports", isDirectory: true)
            let decodeOutcome = SnapshotTesting.evaluate(
                blueSnapshot,
                named: "Card",
                rootDirectory: root,
                majorOSVersion: 27,
                isRecording: false,
                exportDirectory: corruptExports
            )
            guard case .failed(let decodeMessage) = decodeOutcome else {
                Issue.record("Expected .failed on corrupt reference PNG, got \(decodeOutcome)")
                return
            }
            #expect(decodeMessage.contains("Could not decode"))
            #expect(
                FileManager.default.fileExists(
                    atPath: corruptExports.appendingPathComponent("macOS-27/macOS-27-Card.png").path
                )
            )
        }
    }
}
