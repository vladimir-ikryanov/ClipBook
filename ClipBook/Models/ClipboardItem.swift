import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import ImageIO
import UniformTypeIdentifiers
import SQLite3
import CryptoKit

struct LinkPreviewDetails: Codable, Hashable {
    var url: String
    var title: String?
    var description: String?
    var imagePath: String?
    var faviconPath: String?
    var fetchedAt: Date

    var hasVisibleDetails: Bool {
        title != nil || description != nil || imagePath != nil || faviconPath != nil
    }
}

/// The SHA-256 of content, in hex. It tells two copies of the same HTML or
/// image apart from different ones without keeping the content at hand.
nonisolated enum ContentDigest {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: ClipboardKind
    var title: String?
    var text: String?
    // The payload of the QR code found in an image, read when the item is
    // captured. It is kept next to `text`, which holds the text the image was
    // read with OCR, because an image can carry both.
    var qrCodeText: String?
    // The formatting of rich text. The store keeps it apart from the rest of
    // the item and leaves it out of the items it reads, since most of a
    // history's memory went to formatting that only pasting, dragging,
    // previewing and export use. `loadingFormatting(of:)` on the store reads
    // it for one item. It is set only through the methods below, which keep
    // `hasFormatting` and `htmlDigest` in step with it.
    private(set) var rtfData: Data?
    private(set) var html: String?
    /// Whether the item has formatting, loaded in this value or only stored.
    private(set) var hasFormatting: Bool
    /// The SHA-256 of the HTML, which tells two copies of the same text with
    /// different formatting apart when the HTML is not loaded.
    private(set) var htmlDigest: String?
    /// The SHA-256 of the image file's bytes. A copy of an image already in
    /// the history matches it and reuses that item instead of becoming a new one.
    var imageDigest: String?
    var assetPath: String?
    var filePaths: [String]
    var sourceAppName: String?
    var sourceBundleIdentifier: String?
    var copiedAt: Date
    var firstCopiedAt: Date
    var byteSize: Int
    var isFavorite: Bool
    var tags: [Int]
    var searchText: String
    var copyCount: Int
    var linkPreviewDetails: LinkPreviewDetails?
    var copySequenceID: Date?
    var copySequenceOrder: Int?
    /// The item's place among the favorites pinned to the top of the history,
    /// given when the user drags favorites into an order. A favorite that was
    /// never arranged has none and follows the history's own sort instead.
    var favoriteOrder: Int?
    /// Whether the user asked to hide the content of the item in the history,
    /// or to show it although it looks like a secret. None leaves it to the
    /// app to tell.
    var sensitivity: ItemSensitivity?

    init(
        id: UUID = UUID(),
        kind: ClipboardKind,
        title: String? = nil,
        text: String? = nil,
        qrCodeText: String? = nil,
        rtfData: Data? = nil,
        html: String? = nil,
        assetPath: String? = nil,
        imageDigest: String? = nil,
        filePaths: [String] = [],
        sourceAppName: String? = NSWorkspace.shared.frontmostApplication?.localizedName,
        sourceBundleIdentifier: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
        copiedAt: Date = Date(),
        firstCopiedAt: Date? = nil,
        byteSize: Int = 0,
        isFavorite: Bool = false,
        tags: [Int] = [],
        searchText: String? = nil,
        copyCount: Int = 0,
        linkPreviewDetails: LinkPreviewDetails? = nil,
        copySequenceID: Date? = nil,
        copySequenceOrder: Int? = nil,
        favoriteOrder: Int? = nil,
        sensitivity: ItemSensitivity? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.text = text
        self.qrCodeText = qrCodeText
        self.rtfData = rtfData
        self.html = html
        hasFormatting = rtfData != nil || html != nil
        htmlDigest = Self.digest(ofHTML: html)
        self.imageDigest = imageDigest
        self.assetPath = assetPath
        self.filePaths = filePaths
        self.sourceAppName = sourceAppName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.copiedAt = copiedAt
        self.firstCopiedAt = firstCopiedAt ?? copiedAt
        self.byteSize = byteSize
        self.isFavorite = isFavorite
        self.tags = tags
        self.searchText = searchText ?? ClipboardItem.makeSearchText(
            title: title,
            text: text,
            filePaths: filePaths,
            tagNames: [],
            sourceAppName: sourceAppName,
            linkPreviewDetails: linkPreviewDetails,
            qrCodeText: qrCodeText
        )
        self.copyCount = copyCount
        self.linkPreviewDetails = linkPreviewDetails
        self.copySequenceID = copySequenceID
        self.copySequenceOrder = copySequenceOrder
        self.favoriteOrder = favoriteOrder
        self.sensitivity = sensitivity
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case text
        case qrCodeText
        case rtfData
        case html
        case hasFormatting
        case htmlDigest
        case imageDigest
        case assetPath
        case filePaths
        case sourceAppName
        case sourceBundleIdentifier
        case copiedAt
        case firstCopiedAt
        case byteSize
        case isFavorite
        case tags
        case searchText
        case copyCount
        case linkPreviewDetails
        case copySequenceID
        case copySequenceOrder
        case favoriteOrder
        case sensitivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardKind.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        qrCodeText = try container.decodeIfPresent(String.self, forKey: .qrCodeText)
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        html = try container.decodeIfPresent(String.self, forKey: .html)
        // Items stored before the formatting moved out of the payload carry it
        // here and have neither of these.
        hasFormatting = try container.decodeIfPresent(Bool.self, forKey: .hasFormatting)
            ?? (rtfData != nil || html != nil)
        htmlDigest = try container.decodeIfPresent(String.self, forKey: .htmlDigest)
            ?? Self.digest(ofHTML: html)
        imageDigest = try container.decodeIfPresent(String.self, forKey: .imageDigest)
        assetPath = try container.decodeIfPresent(String.self, forKey: .assetPath)
        filePaths = try container.decode([String].self, forKey: .filePaths)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceBundleIdentifier)
        copiedAt = try container.decode(Date.self, forKey: .copiedAt)
        firstCopiedAt = try container.decodeIfPresent(Date.self, forKey: .firstCopiedAt) ?? copiedAt
        byteSize = try container.decode(Int.self, forKey: .byteSize)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        tags = (try? container.decode([Int].self, forKey: .tags)) ?? []
        searchText = try container.decode(String.self, forKey: .searchText)
        copyCount = try container.decode(Int.self, forKey: .copyCount)
        linkPreviewDetails = try container.decodeIfPresent(LinkPreviewDetails.self, forKey: .linkPreviewDetails)
        copySequenceID = try container.decodeIfPresent(Date.self, forKey: .copySequenceID)
        copySequenceOrder = try container.decodeIfPresent(Int.self, forKey: .copySequenceOrder)
        favoriteOrder = try container.decodeIfPresent(Int.self, forKey: .favoriteOrder)
        // Read leniently, so a value written by a later version is ignored
        // instead of making the item unreadable.
        sensitivity = (try? container.decodeIfPresent(String.self, forKey: .sensitivity))
            .flatMap { $0 }
            .flatMap(ItemSensitivity.init(rawValue:))
    }

    /// Whether this value holds the formatting, rather than only knowing the
    /// store has some.
    var isFormattingLoaded: Bool {
        rtfData != nil || html != nil
    }

    /// Replaces the formatting, or removes it when both are nil.
    mutating func setFormatting(html: String?, rtfData: Data?) {
        self.html = html
        self.rtfData = rtfData
        hasFormatting = html != nil || rtfData != nil
        htmlDigest = Self.digest(ofHTML: html)
    }

    mutating func removeFormatting() {
        setFormatting(html: nil, rtfData: nil)
    }

    /// The item without its formatting in memory. It still knows it has some,
    /// so saving it leaves the stored formatting as it is.
    func unloadingFormatting() -> ClipboardItem {
        guard isFormattingLoaded else {
            return self
        }

        var item = self
        item.html = nil
        item.rtfData = nil
        return item
    }

    private static func digest(ofHTML html: String?) -> String? {
        guard let html, !html.isEmpty else {
            return nil
        }

        return ContentDigest.sha256(Data(html.utf8))
    }

    var itemTitle: String? {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var hasSourceApp: Bool {
        sourceBundleIdentifier != nil || sourceAppName != nil
    }

    var displayTitle: String {
        if let itemTitle {
            return itemTitle
        }

        return contentTitle
    }

    var contentTitle: String {
        if kind == .image {
            return imageDisplayTitle
        }

        switch kind {
        case .file:
            return filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        case .color:
            return text ?? "Color"
        default:
            return previewText.components(separatedBy: .newlines).first?.nilIfEmpty ?? kind.title
        }
    }

    var subtitle: String {
        switch kind {
        case .file:
            return filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        case .image:
            return assetPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Captured image"
        default:
            return previewText
        }
    }

    var previewText: String {
        if let text, !text.isEmpty {
            return text
        }
        if let html, !html.isEmpty {
            return html
        }
        if !filePaths.isEmpty {
            return filePaths.joined(separator: "\n")
        }
        return title ?? kind.title
    }

    var assetURL: URL? {
        assetPath.map(URL.init(fileURLWithPath:))
    }

    /// The files ClipBook stored for the item: its image and the pictures of
    /// its link preview. The files an item of copied files lists are the
    /// user's own and are not among them.
    var storedFilePaths: [String] {
        [assetPath, linkPreviewDetails?.imagePath, linkPreviewDetails?.faviconPath].compactMap { $0 }
    }

    var quickLookURL: URL? {
        if let assetURL {
            return assetURL
        }
        return filePaths.first.map(URL.init(fileURLWithPath:))
    }

    var isMultipleFileItem: Bool {
        kind == .file && filePaths.count > 1
    }

    var isImageFileItem: Bool {
        kind == .file && !filePaths.isEmpty && filePaths.allSatisfy { Self.isImageFile(at: $0) }
    }

    var firstFileIsImage: Bool {
        guard let filePath = filePaths.first else {
            return false
        }

        return Self.isImageFile(at: filePath)
    }

    var canCopyTextFromImage: Bool {
        guard !isMultipleFileItem,
              kind == .image || (kind == .file && firstFileIsImage),
              let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return !text.isEmpty
    }

    // The QR code is read from the same kinds of items the image text is read
    // from, so an image and an image file both offer it.
    var canCopyTextFromQRCode: Bool {
        guard !isMultipleFileItem,
              kind == .image || (kind == .file && firstFileIsImage),
              let qrCodeText = qrCodeText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return !qrCodeText.isEmpty
    }

    var browserURL: URL? {
        guard kind == .link, let text else {
            return nil
        }

        return Self.linkURL(from: text)
    }

    // The one address a text holds, if that is all it holds. A URL carries no
    // whitespace of its own, and the parser percent-encodes spaces, tabs and
    // newlines rather than rejecting them, so a list of addresses written one
    // per line would otherwise be read as a single link to the first host.
    static func linkURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let disallowedCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: disallowedCharacters) == nil,
              let url = URL(string: trimmed),
              url.scheme != nil,
              url.host != nil else {
            return nil
        }

        return url
    }

    /// What tells two captures of the same content apart. It is built from the
    /// content alone, never from the search text: the search text also carries
    /// the source app, tag names and link preview details, which the store
    /// adds to an item once it is in the history. A key that included them
    /// would change after the first match, and the next copy of the same
    /// content would start a second item instead of counting on the first.
    var contentKey: String {
        if kind == .link, let browserURL {
            return Self.normalizedLinkContentKey(for: browserURL)
        }

        if kind == .file, !filePaths.isEmpty {
            return Self.normalizedFileContentKey(for: filePaths)
        }

        // An image is told apart by the bytes of its file, so copying the same
        // image again counts on the item it already has. An image stored before
        // images had a digest is told apart by its file.
        if kind == .image, let imageKey = imageDigest ?? assetPath {
            return imageKey
        }

        // Formatting is not searchable, but it still tells two copies of the
        // same text apart, so a differently styled copy stays its own item.
        // The digest stands in for the HTML, which is usually not loaded.
        if let htmlDigest {
            return (text ?? "") + "\n" + htmlDigest
        }

        return text ?? ""
    }

    /// Whether the two items hold the same content, as their `contentKey`
    /// tells, without building the key of a text item for the comparison.
    func hasSameContent(as other: ClipboardItem) -> Bool {
        guard kind == other.kind else {
            return false
        }

        switch kind {
        case .link, .file, .image:
            return contentKey == other.contentKey
        default:
            return htmlDigest == other.htmlDigest && (text ?? "") == (other.text ?? "")
        }
    }

    var imageDimensions: (width: Int, height: Int)? {
        guard kind == .image,
              let assetURL,
              let source = CGImageSourceCreateWithURL(assetURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        return (width, height)
    }

    private var imageDisplayTitle: String {
        guard let imageDimensions else {
            return "Image"
        }

        return "Image (\(imageDimensions.width)x\(imageDimensions.height))"
    }

    nonisolated static func isImageFile(at filePath: String) -> Bool {
        let fileURL = URL(fileURLWithPath: filePath)

        // Prefer the extension-based check because it does not touch the disk,
        // which matters when filtering the whole history.
        let pathExtension = fileURL.pathExtension
        if !pathExtension.isEmpty, let type = UTType(filenameExtension: pathExtension) {
            return type.conforms(to: .image)
        }

        guard let type = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }

        return type.conforms(to: .image)
    }

    func rebuildingSearchText(tagNames: [String]) -> ClipboardItem {
        var updated = self
        updated.searchText = Self.makeSearchText(
            title: title,
            text: text,
            filePaths: filePaths,
            tagNames: tagNames,
            sourceAppName: sourceAppName,
            linkPreviewDetails: linkPreviewDetails,
            qrCodeText: qrCodeText
        )
        return updated
    }

    /// Only the plain text of an item is searchable. The HTML of a rich text
    /// item is left out on purpose: its markup would match queries the user
    /// cannot see in the item.
    static func makeSearchText(
        title: String?,
        text: String?,
        filePaths: [String],
        tagNames: [String],
        sourceAppName: String?,
        linkPreviewDetails: LinkPreviewDetails? = nil,
        qrCodeText: String? = nil
    ) -> String {
        [
            title,
            text,
            qrCodeText,
            linkPreviewDetails?.title,
            linkPreviewDetails?.description,
            filePaths.joined(separator: " "),
            tagNames.joined(separator: " "),
            sourceAppName
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    static func normalizedLinkContentKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        components.fragment = nil
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.url?.absoluteString ?? url.absoluteString
    }

    static func normalizedFileContentKey(for filePaths: [String]) -> String {
        filePaths
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .joined(separator: "\n")
    }
}
