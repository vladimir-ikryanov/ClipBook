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
}
