import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the monitor asks the reader to look at on one poll.
nonisolated struct PasteboardReadRequest: Sendable {
    /// The change count the monitor has already dealt with.
    var lastChangeCount: Int
    /// Read the pasteboard although its change count is the same, because the
    /// last read found nothing and its writer may still be filling it.
    var retriesUnchangedPasteboard: Bool
    var ignoresTransientContent: Bool
    var ignoresConcealedContent: Bool
    var ignoredApplicationEntries: [String]
    /// Where a copied image is stored.
    var imagesDirectory: URL
    /// The image already in the history with the given digest, if any. It is
    /// asked from the read queue.
    var findStoredImage: @Sendable (_ digest: String) -> StoredImage?
    /// The application in front at the moment of the read.
    var frontmostApplication: @Sendable () -> FrontmostApplication? = { FrontmostApplication.current }
}

/// The application in front when something was copied: what the history records
/// as the source of the copy, and what the ignored applications are matched against.
nonisolated struct FrontmostApplication: Sendable {
    var bundlePath: String?
    var localizedName: String?
    var bundleIdentifier: String?

    static var current: FrontmostApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return FrontmostApplication(
            bundlePath: application.bundleURL?.standardizedFileURL.path,
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
    }
}

/// An image already in the history: its file and the content read from it.
nonisolated struct StoredImage: Sendable {
    var assetPath: String
    var recognizedContent: RecognizedImageContent
}

nonisolated struct PasteboardReadResult: Sendable {
    nonisolated enum Outcome: Sendable {
        /// Nothing was copied since the last read, so nothing was read.
        case unchanged
        /// The content is not to be captured: it is ClipBook's own, it is
        /// marked transient or concealed, or it comes from an ignored app.
        case skipped
        /// Nothing readable is on the pasteboard, at least not yet.
        case empty
        case content(PasteboardContent)
    }

    var changeCount: Int
    var outcome: Outcome
}

/// What was copied, as it was read from the pasteboard, together with the
/// application that was in front at that moment.
nonisolated struct PasteboardContent: Sendable {
    nonisolated enum Payload: Sendable {
        case files(paths: [String], byteSize: Int, recognizedContent: RecognizedImageContent)
        /// `reusesStoredFile` is set when the image is already in the history:
        /// `assetPath` is then that item's file, which is not the reader's to delete.
        case image(
            id: UUID,
            assetPath: String,
            byteSize: Int,
            recognizedContent: RecognizedImageContent,
            digest: String,
            reusesStoredFile: Bool
        )
        case richText(plainText: String?, rtf: Data?, html: String?)
        case text(String)
    }

    var payload: Payload
    var sourceAppName: String?
    var sourceBundleIdentifier: String?
    /// The writer marked the content as confidential, as password managers do.
    var isConcealed = false
}

// What an image is read for when it is captured: the text it shows, and the
// payload of the QR code it carries. Both are read from the same image in
// one pass, because an image can hold either, both or neither.
nonisolated struct RecognizedImageContent: Sendable {
    static let empty = RecognizedImageContent(text: nil, qrCodeText: nil)

    var text: String?
    var qrCodeText: String?
}

/// Reads the general pasteboard. It is called off the main thread: an
/// application may put a promise on the pasteboard and hand the data over only
/// when it is asked for, and the read waits for that application as long as it
/// takes. The text of a copied image is not read here: that is
/// `ImageTextRecognizer`'s job once the image is in the history.
nonisolated enum PasteboardReader {
    static let ghostType = NSPasteboard.PasteboardType("com.ikryanov.clipbook.v2.ghost")

    static func read(_ request: PasteboardReadRequest, from pasteboard: NSPasteboard = .general) -> PasteboardReadResult {
        let changeCount = pasteboard.changeCount
        guard changeCount != request.lastChangeCount || request.retriesUnchangedPasteboard else {
            return PasteboardReadResult(changeCount: changeCount, outcome: .unchanged)
        }

        let frontmostApplication = request.frontmostApplication()
        guard shouldCapture(pasteboard, from: frontmostApplication, request: request) else {
            return PasteboardReadResult(changeCount: changeCount, outcome: .skipped)
        }
        guard let payload = readPayload(from: pasteboard, request: request) else {
            return PasteboardReadResult(changeCount: changeCount, outcome: .empty)
        }

        let content = PasteboardContent(
            payload: payload,
            sourceAppName: frontmostApplication?.localizedName,
            sourceBundleIdentifier: frontmostApplication?.bundleIdentifier,
            isConcealed: isConcealed(pasteboard)
        )
        return PasteboardReadResult(changeCount: changeCount, outcome: .content(content))
    }

    private static func shouldCapture(
        _ pasteboard: NSPasteboard,
        from frontmostApplication: FrontmostApplication?,
        request: PasteboardReadRequest
    ) -> Bool {
        guard pasteboard.string(forType: ghostType) == nil else {
            return false
        }

        let types = pasteboard.types ?? []
        if request.ignoresTransientContent,
           types.contains(.init("org.nspasteboard.TransientType")) || types.contains(.init("org.nspasteboard.AutoGeneratedType")) {
            return false
        }

        if request.ignoresConcealedContent, isConcealed(pasteboard) {
            return false
        }

        if let frontmostApplication,
           AppPreferences.isApplicationIgnored(
               bundlePath: frontmostApplication.bundlePath,
               localizedName: frontmostApplication.localizedName,
               entries: request.ignoredApplicationEntries
           ) {
            return false
        }

        return true
    }

    private static func isConcealed(_ pasteboard: NSPasteboard) -> Bool {
        (pasteboard.types ?? []).contains(.init("org.nspasteboard.ConcealedType"))
    }

    private static func readPayload(from pasteboard: NSPasteboard, request: PasteboardReadRequest) -> PasteboardContent.Payload? {
        if let files = readFiles(from: pasteboard) {
            return files
        }
        if !isImageRenderingOfText(pasteboard), let image = readImage(from: pasteboard, request: request) {
            return image
        }
        if let richText = readRichText(from: pasteboard) {
            return richText
        }
        if let text = readText(from: pasteboard) {
            return text
        }
        return nil
    }

    private static func readFiles(from pasteboard: NSPasteboard) -> PasteboardContent.Payload? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else {
            return nil
        }

        let paths = urls.map(\.path)
        // The text of a copied image file is read once the item is in the
        // history, by `ImageTextRecognizer`.
        return .files(
            paths: paths,
            byteSize: paths.reduce(0) { $0 + fileSize(atPath: $1) },
            recognizedContent: .empty
        )
    }

    // Office and text apps (Microsoft Word, Pages, etc.) put a picture of the
    // copied selection next to its text: a PDF or PICT rendering, or a bitmap
    // alongside RTF. That picture is only a rendering of the text, so the text
    // is what gets captured. A copied image has no meaningful text beside it,
    // at most the object replacement character that stands in for the image.
    private static func isImageRenderingOfText(_ pasteboard: NSPasteboard) -> Bool {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines.union(["\u{FFFC}"])).isEmpty else {
            return false
        }

        let types = pasteboard.types ?? []
        if types.contains(.rtf) {
            return true
        }
        let vectorTypes: [NSPasteboard.PasteboardType] = [.pdf, .init("com.apple.pict")]
        return !types.contains { type in
            !vectorTypes.contains(type) && NSImage.imageTypes.contains(type.rawValue)
        }
    }

    // A copied image is stored as PNG. A 5K screenshot is 59 MB once decoded,
    // and it used to be decoded three times and kept as an uncompressed TIFF
    // on the way. Now a PNG is stored as it is and any other bitmap is
    // converted in one pass. The text of a new image is read later, once it is
    // in the history, by `ImageTextRecognizer`.
    private static func readImage(from pasteboard: NSPasteboard, request: PasteboardReadRequest) -> PasteboardContent.Payload? {
        defer { returnFreedMemory() }
        return autoreleasepool {
            guard let png = pngData(from: pasteboard) else {
                return nil
            }

            // An image already in the history keeps its file and the text read
            // from it, so it is neither stored nor read again. Reading the text
            // is what takes the time and the memory.
            let digest = ContentDigest.sha256(png)
            if let storedImage = request.findStoredImage(digest),
               FileManager.default.fileExists(atPath: storedImage.assetPath) {
                return .image(
                    id: UUID(),
                    assetPath: storedImage.assetPath,
                    byteSize: png.count,
                    recognizedContent: storedImage.recognizedContent,
                    digest: digest,
                    reusesStoredFile: true
                )
            }

            let imagesDirectory = request.imagesDirectory
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let id = UUID()
            let url = imagesDirectory.appendingPathComponent("\(id.uuidString).png")
            do {
                try png.write(to: url, options: .atomic)
            } catch {
                return nil
            }

            return .image(
                id: id,
                assetPath: url.path,
                byteSize: png.count,
                recognizedContent: .empty,
                digest: digest,
                reusesStoredFile: false
            )
        }
    }

    /// The PNG to store for the image on the pasteboard.
    private static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png), isImageData(png, of: .png) {
            return png
        }
        if let tiff = pasteboard.data(forType: .tiff), let png = pngData(converting: tiff) {
            return png
        }

        // What ImageIO does not read, such as a PDF or PICT picture, is drawn
        // by AppKit. The point size is kept, and with it the image's DPI.
        guard let image = NSImage(pasteboard: pasteboard) else {
            return nil
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        representation.size = image.size
        return representation.representation(using: .png, properties: [:])
    }

    private static func isImageData(_ data: Data, of type: UTType) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }

        return CGImageSourceGetCount(source) > 0 && CGImageSourceGetType(source) == type.identifier as CFString
    }

    /// The first image in `data` as PNG, with its color profile and DPI.
    /// ImageIO copies it from the source to the PNG in one pass.
    private static func pngData(converting data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return output as Data
    }

    /// Converting an image goes through buffers of tens of megabytes. Once
    /// they are freed the allocator keeps them for reuse, and they count as
    /// the app's memory until the system runs short and asks for them, so they
    /// are handed back right away.
    private static func returnFreedMemory() {
        malloc_zone_pressure_relief(nil, 0)
    }

    private static func readRichText(from pasteboard: NSPasteboard) -> PasteboardContent.Payload? {
        let rtf = pasteboard.data(forType: .rtf)
        let html = pasteboard.string(forType: .html)
        guard rtf != nil || html != nil else {
            return nil
        }
        // Some apps put only HTML on the pasteboard, so its text is the last fallback.
        let plainText = pasteboard.string(forType: .string)
            ?? rtf.flatMap { NSAttributedString(rtf: $0, documentAttributes: nil)?.string }
            ?? html.map { textContent(ofHTML: $0) }
        guard let plainText,
              !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return .richText(plainText: plainText, rtf: rtf, html: html)
    }

    /// The text of HTML markup as a browser shows it: scripts, styles and the
    /// head dropped, a line break where a paragraph, a list item, a row or a
    /// `<br>` ends, tags stripped, entities decoded.
    private static func textContent(ofHTML html: String) -> String {
        let withoutHiddenElements = ["script", "style", "head"].reduce(removingComments(from: html)) {
            replacingElements(named: $1, in: $0) { _ in "" }
        }
        // A preformatted block keeps its line breaks, which the next step would turn into spaces.
        let withPreformattedBreaks = replacingElements(named: "pre", in: withoutHiddenElements) {
            $0.replacingOccurrences(of: "\n", with: "<br>")
        }
        // The line breaks and the indentation of the markup itself are one space.
        let collapsed = withPreformattedBreaks.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let withLineBreaks = collapsed.replacingOccurrences(
            of: #"<br\b[^<>]*>|</(?:p|div|li|tr|h[1-6]|ul|ol|table|section|article|blockquote|pre)\s*>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        let withCellBreaks = withLineBreaks.replacingOccurrences(
            of: #"</t[dh]\s*>"#,
            with: "\t",
            options: [.regularExpression, .caseInsensitive]
        )
        // A tag ends at the next ">", and no tag contains a "<", so a stray "<"
        // costs nothing beyond itself.
        let withoutTags = withCellBreaks.replacingOccurrences(of: "<[^<>]+>", with: "", options: .regularExpression)
        return ClipboardTextTransform.decodeHTMLEntities(withoutTags)
            .replacingOccurrences(of: "\t\n", with: "\n")
            .replacingOccurrences(of: " ?\n ?", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `html` without its comments. A comment that is never closed stays as it is.
    private static func removingComments(from html: String) -> String {
        var result = ""
        var copiedUpTo = html.startIndex
        while let open = html.range(of: "<!--", range: copiedUpTo..<html.endIndex),
              let close = html.range(of: "-->", range: open.upperBound..<html.endIndex) {
            result += html[copiedUpTo..<open.lowerBound]
            copiedUpTo = close.upperBound
        }
        return result + html[copiedUpTo...]
    }

    /// `html` with each element called `name`, tags included, replaced by what
    /// `replacement` makes of it. An element that is never closed stays as it is.
    /// The page is copied by whoever wrote it, so each search starts where the
    /// last one ended: a regular expression would search to the end again from
    /// every unclosed tag.
    private static func replacingElements(
        named name: String,
        in html: String,
        with replacement: (String) -> String
    ) -> String {
        var result = ""
        var copiedUpTo = html.startIndex
        var searchFrom = html.startIndex
        while let open = html.range(of: "<\(name)", options: .caseInsensitive, range: searchFrom..<html.endIndex) {
            // "<scripture>" is not a script: the name has to end there.
            if open.upperBound < html.endIndex,
               html[open.upperBound].isLetter || html[open.upperBound].isNumber || html[open.upperBound] == "_" {
                searchFrom = open.upperBound
                continue
            }
            guard let close = html.range(of: "</\(name)", options: .caseInsensitive, range: open.upperBound..<html.endIndex) else {
                break
            }
            let end = html.range(of: ">", range: close.upperBound..<html.endIndex)?.upperBound ?? html.endIndex
            result += html[copiedUpTo..<open.lowerBound]
            result += replacement(String(html[open.lowerBound..<end]))
            copiedUpTo = end
            searchFrom = end
        }
        return result + html[copiedUpTo...]
    }

    private static func readText(from pasteboard: NSPasteboard) -> PasteboardContent.Payload? {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return .text(text)
    }

    private static func fileSize(atPath path: String) -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.intValue
    }
}
