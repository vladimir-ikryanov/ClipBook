import Foundation

struct ClipBookArchiveImportResult {
    var itemIDs: Set<ClipboardItem.ID>
    var tagCount: Int

    var itemCount: Int {
        itemIDs.count
    }
}

struct ClipBookArchiveExportResult {
    var url: URL
    var itemCount: Int
    var tagCount: Int
}

struct ClipBookArchiveProgress {
    var completedItemCount: Int
    var totalItemCount: Int
}

enum ClipBookArchiveError: LocalizedError {
    case unsupportedVersion(Int)
    case missingFile(String)
    case invalidAssetPath(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return L10n.string("ClipBook archive version %d is not supported.", version)
        case .missingFile(let fileName):
            return L10n.string("The archive is missing %@.", fileName)
        case .invalidAssetPath(let path):
            return L10n.string("The archive contains an invalid asset path: %@.", path)
        }
    }
}

final class ClipBookArchiveService {
    private let supportedFormatVersion = 1
    private let fileManager: FileManager
    private let supportDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager, supportDirectory: URL) {
        self.fileManager = fileManager
        self.supportDirectory = supportDirectory
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    func export(
        items: [ClipboardItem],
        tags: [Tag],
        to archiveURL: URL,
        progress: ((ClipBookArchiveProgress) -> Void)? = nil
    ) throws {
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }

        try fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)

        let assetsDirectory = archiveURL.appendingPathComponent("assets", isDirectory: true)
        let imagesDirectory = assetsDirectory.appendingPathComponent("images", isDirectory: true)
        let linkPreviewsDirectory = assetsDirectory.appendingPathComponent("link-previews", isDirectory: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: linkPreviewsDirectory, withIntermediateDirectories: true)

        let archiveTags = tags.map { tag in
            ClipBookArchiveTag(id: String(tag.id), name: tag.name, color: tag.color)
        }
        progress?(ClipBookArchiveProgress(completedItemCount: 0, totalItemCount: items.count))
        var archiveItems: [ClipBookArchiveItem] = []
        archiveItems.reserveCapacity(items.count)
        for item in items {
            let archiveItem = try archiveItem(
                from: item,
                tags: tags,
                imagesDirectory: imagesDirectory,
                linkPreviewsDirectory: linkPreviewsDirectory
            )
            archiveItems.append(archiveItem)
            progress?(ClipBookArchiveProgress(completedItemCount: archiveItems.count, totalItemCount: items.count))
        }
        let manifest = ClipBookArchiveManifest(
            formatVersion: supportedFormatVersion,
            appName: "ClipBook",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            exportedAt: Date()
        )

        try write(manifest, to: archiveURL.appendingPathComponent("manifest.json"))
        try write(archiveTags, to: archiveURL.appendingPathComponent("tags.json"))
        try write(archiveItems, to: archiveURL.appendingPathComponent("history.json"))
    }

    func `import`(
        from archiveURL: URL,
        into historyStore: HistoryStore,
        progress: ((ClipBookArchiveProgress) -> Void)? = nil
    ) throws -> ClipBookArchiveImportResult {
        let manifestURL = archiveURL.appendingPathComponent("manifest.json")
        let tagsURL = archiveURL.appendingPathComponent("tags.json")
        let historyURL = archiveURL.appendingPathComponent("history.json")
        try requireFile(at: manifestURL, name: "manifest.json")
        try requireFile(at: tagsURL, name: "tags.json")
        try requireFile(at: historyURL, name: "history.json")

        let manifest = try read(ClipBookArchiveManifest.self, from: manifestURL)
        guard manifest.formatVersion <= supportedFormatVersion else {
            throw ClipBookArchiveError.unsupportedVersion(manifest.formatVersion)
        }

        let archiveTags = try read([ClipBookArchiveTag].self, from: tagsURL)
        let archiveItems = try read([ClipBookArchiveItem].self, from: historyURL)
        progress?(ClipBookArchiveProgress(completedItemCount: 0, totalItemCount: archiveItems.count))
        var tagIDsByArchiveID: [String: Tag.ID] = [:]
        var tagNamesByID: [Tag.ID: String] = [:]

        var importedItemIDs: Set<ClipboardItem.ID> = []
        var importedItemCount = 0
        // One transaction for the whole archive: a commit per item is the slow
        // part of a large import, and a failed import leaves nothing behind.
        try historyStore.performInTransaction {
            for archiveTag in archiveTags {
                let tag = try historyStore.createTag(name: archiveTag.name, color: archiveTag.color)
                tagIDsByArchiveID[archiveTag.id] = tag.id
                tagNamesByID[tag.id] = tag.name
            }

            for archiveItem in archiveItems {
                let item = try clipboardItem(
                    from: archiveItem,
                    archiveURL: archiveURL,
                    tagIDsByArchiveID: tagIDsByArchiveID,
                    tagNamesByID: tagNamesByID
                )
                try historyStore.upsert(item)
                importedItemIDs.insert(item.id)
                importedItemCount += 1
                progress?(ClipBookArchiveProgress(completedItemCount: importedItemCount, totalItemCount: archiveItems.count))
            }
            // Importing an export taken before items were deleted brings them
            // back, so an item in the Trash that the archive holds leaves it.
            try historyStore.restoreFromTrash(ids: Array(importedItemIDs))
        }

        return ClipBookArchiveImportResult(itemIDs: importedItemIDs, tagCount: archiveTags.count)
    }

    private func archiveItem(
        from item: ClipboardItem,
        tags: [Tag],
        imagesDirectory: URL,
        linkPreviewsDirectory: URL
    ) throws -> ClipBookArchiveItem {
        let tagIDs = item.tags.map(String.init)
        let archiveAssetPath = try copyAsset(item.assetPath, to: imagesDirectory)
        let archivePreviewDetails: ClipBookArchiveLinkPreviewDetails?
        if let linkPreviewDetails = item.linkPreviewDetails {
            archivePreviewDetails = try archiveLinkPreviewDetails(
                from: linkPreviewDetails,
                linkPreviewsDirectory: linkPreviewsDirectory
            )
        } else {
            archivePreviewDetails = nil
        }

        return ClipBookArchiveItem(
            id: item.id,
            kind: item.kind.rawValue,
            title: item.title,
            text: item.text,
            qrCodeText: item.qrCodeText,
            rtfBase64: item.rtfData?.base64EncodedString(),
            html: item.html,
            assetPath: archiveAssetPath,
            filePaths: item.filePaths,
            sourceAppName: item.sourceAppName,
            sourceBundleIdentifier: item.sourceBundleIdentifier,
            copiedAt: item.copiedAt,
            firstCopiedAt: item.firstCopiedAt,
            byteSize: item.byteSize,
            isFavorite: item.isFavorite,
            tagIDs: tagIDs,
            tagNames: item.tags.compactMap { tagID in tags.first { $0.id == tagID }?.name },
            copyCount: item.copyCount,
            linkPreviewDetails: archivePreviewDetails,
            copySequenceID: item.copySequenceID,
            copySequenceOrder: item.copySequenceOrder,
            favoriteOrder: item.favoriteOrder,
            sensitivity: item.sensitivity?.rawValue
        )
    }

    private func clipboardItem(
        from archiveItem: ClipBookArchiveItem,
        archiveURL: URL,
        tagIDsByArchiveID: [String: Tag.ID],
        tagNamesByID: [Tag.ID: String]
    ) throws -> ClipboardItem {
        let tagIDs = archiveItem.tagIDs.compactMap { tagIDsByArchiveID[$0] }
        let assetPath = try copyImportedAsset(
            archiveRelativePath: archiveItem.assetPath,
            archiveURL: archiveURL,
            destinationDirectory: supportDirectory.appendingPathComponent("Images", isDirectory: true),
            fallbackFileName: archiveItem.id.uuidString
        )
        let linkPreviewDetails: LinkPreviewDetails?
        if let archiveLinkPreviewDetails = archiveItem.linkPreviewDetails {
            linkPreviewDetails = try importedLinkPreviewDetails(
                from: archiveLinkPreviewDetails,
                archiveURL: archiveURL,
                itemID: archiveItem.id
            )
        } else {
            linkPreviewDetails = nil
        }
        let tagNames = tagIDs.compactMap { tagNamesByID[$0] }
        let kind = ClipboardKind(rawValue: archiveItem.kind) ?? .text
        let rtfData = archiveItem.rtfBase64.flatMap { Data(base64Encoded: $0) }
        let searchText = ClipboardItem.makeSearchText(
            title: archiveItem.title,
            text: archiveItem.text,
            filePaths: archiveItem.filePaths,
            tagNames: tagNames,
            sourceAppName: archiveItem.sourceAppName,
            linkPreviewDetails: linkPreviewDetails,
            qrCodeText: archiveItem.qrCodeText
        )

        return ClipboardItem(
            id: archiveItem.id,
            kind: kind,
            title: archiveItem.title,
            text: archiveItem.text,
            qrCodeText: archiveItem.qrCodeText,
            rtfData: rtfData,
            html: archiveItem.html,
            assetPath: assetPath,
            imageDigest: kind == .image ? assetPath.flatMap { fileManager.contents(atPath: $0) }.map(ContentDigest.sha256) : nil,
            filePaths: archiveItem.filePaths,
            sourceAppName: archiveItem.sourceAppName,
            sourceBundleIdentifier: archiveItem.sourceBundleIdentifier,
            copiedAt: archiveItem.copiedAt,
            firstCopiedAt: archiveItem.firstCopiedAt,
            byteSize: archiveItem.byteSize,
            isFavorite: archiveItem.isFavorite,
            tags: tagIDs,
            searchText: searchText,
            copyCount: archiveItem.copyCount,
            linkPreviewDetails: linkPreviewDetails,
            copySequenceID: archiveItem.copySequenceID,
            copySequenceOrder: archiveItem.copySequenceOrder,
            favoriteOrder: archiveItem.favoriteOrder,
            sensitivity: archiveItem.sensitivity.flatMap(ItemSensitivity.init(rawValue:))
        )
    }

    private func archiveLinkPreviewDetails(
        from details: LinkPreviewDetails,
        linkPreviewsDirectory: URL
    ) throws -> ClipBookArchiveLinkPreviewDetails {
        ClipBookArchiveLinkPreviewDetails(
            url: details.url,
            title: details.title,
            description: details.description,
            imagePath: try copyAsset(details.imagePath, to: linkPreviewsDirectory),
            faviconPath: try copyAsset(details.faviconPath, to: linkPreviewsDirectory),
            fetchedAt: details.fetchedAt
        )
    }

    private func importedLinkPreviewDetails(
        from details: ClipBookArchiveLinkPreviewDetails,
        archiveURL: URL,
        itemID: UUID
    ) throws -> LinkPreviewDetails {
        let directory = supportDirectory.appendingPathComponent("LinkPreviews", isDirectory: true)
        return LinkPreviewDetails(
            url: details.url,
            title: details.title,
            description: details.description,
            imagePath: try copyImportedAsset(
                archiveRelativePath: details.imagePath,
                archiveURL: archiveURL,
                destinationDirectory: directory,
                fallbackFileName: "\(itemID.uuidString)-preview"
            ),
            faviconPath: try copyImportedAsset(
                archiveRelativePath: details.faviconPath,
                archiveURL: archiveURL,
                destinationDirectory: directory,
                fallbackFileName: "\(itemID.uuidString)-favicon"
            ),
            fetchedAt: details.fetchedAt
        )
    }

    private func copyAsset(_ path: String?, to directory: URL) throws -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        let sourceURL = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let destinationURL = uniqueURL(
            in: directory,
            preferredFileName: sourceURL.lastPathComponent.nilIfEmpty ?? UUID().uuidString
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return "assets/\(directory.lastPathComponent)/\(destinationURL.lastPathComponent)"
    }

    private func copyImportedAsset(
        archiveRelativePath: String?,
        archiveURL: URL,
        destinationDirectory: URL,
        fallbackFileName: String
    ) throws -> String? {
        guard let archiveRelativePath, !archiveRelativePath.isEmpty else {
            return nil
        }
        guard !archiveRelativePath.contains(".."), !archiveRelativePath.hasPrefix("/") else {
            throw ClipBookArchiveError.invalidAssetPath(archiveRelativePath)
        }

        let sourceURL = archiveURL.appendingPathComponent(archiveRelativePath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension
        let fileName = fileExtension.isEmpty ? fallbackFileName : "\(fallbackFileName).\(fileExtension)"
        let destinationURL = uniqueURL(in: destinationDirectory, preferredFileName: fileName)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    private func uniqueURL(in directory: URL, preferredFileName: String) -> URL {
        var url = directory.appendingPathComponent(preferredFileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        var index = 1
        repeat {
            let candidateName = fileExtension.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(fileExtension)"
            url = directory.appendingPathComponent(candidateName)
            index += 1
        } while fileManager.fileExists(atPath: url.path)
        return url
    }

    private func requireFile(at url: URL, name: String) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ClipBookArchiveError.missingFile(name)
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
}

private struct ClipBookArchiveManifest: Codable {
    var formatVersion: Int
    var appName: String
    var appVersion: String?
    var exportedAt: Date
}

private struct ClipBookArchiveTag: Codable {
    var id: String
    var name: String
    var color: String
}

private struct ClipBookArchiveItem: Codable {
    var id: UUID
    var kind: String
    var title: String?
    var text: String?
    // Absent from archives written before QR codes were read, so the item is
    // imported without one rather than failing to decode.
    var qrCodeText: String?
    var rtfBase64: String?
    var html: String?
    var assetPath: String?
    var filePaths: [String]
    var sourceAppName: String?
    var sourceBundleIdentifier: String?
    var copiedAt: Date
    var firstCopiedAt: Date
    var byteSize: Int
    var isFavorite: Bool
    var tagIDs: [String]
    var tagNames: [String]
    var copyCount: Int
    var linkPreviewDetails: ClipBookArchiveLinkPreviewDetails?
    var copySequenceID: Date?
    var copySequenceOrder: Int?
    // Absent from archives written before favorites could be arranged.
    var favoriteOrder: Int?
    // Absent from archives written before items could be marked as sensitive.
    var sensitivity: String?
}

private struct ClipBookArchiveLinkPreviewDetails: Codable {
    var url: String
    var title: String?
    var description: String?
    var imagePath: String?
    var faviconPath: String?
    var fetchedAt: Date
}
