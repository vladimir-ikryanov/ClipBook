@testable import ClipBook
import Foundation
import SQLite3
import Testing

@Suite
enum SQLiteHistoryStoreAndArchiveTests {
    @Suite
    struct SQLiteHistoryStoreTests {
        @Test
        func capturePreservesMetadataAndRevivesTrash() throws {
            try TestSupport.withTemporaryHistoryStore { store, _ in
                let tag = try store.createTag(name: "Reference", color: "#3B85ED")
                let initialTime = Date(timeIntervalSince1970: 1_700_000_100.125)
                let sequenceID = Date(timeIntervalSince1970: 1_700_000_100.000)

                let original = ClipboardItem.fixture(
                    kind: .image,
                    title: "Custom Diagram Title",
                    text: "Recognized OCR Text From Vision",
                    qrCodeText: "https://example.com/qr",
                    assetPath: "/tmp/diagram.png",
                    imageDigest: "sha256-diagram-digest-001",
                    sourceAppName: "Preview",
                    sourceBundleIdentifier: "com.apple.Preview",
                    copiedAt: initialTime,
                    firstCopiedAt: initialTime,
                    byteSize: 4096,
                    isFavorite: true,
                    tags: [tag.id],
                    copyCount: 1,
                    copySequenceID: sequenceID,
                    copySequenceOrder: 2
                )
                let firstCaptured = try store.capture(original, updatesCopySequence: true)
                #expect(firstCaptured.id == original.id)
                #expect(firstCaptured.copySequenceID == sequenceID)
                #expect(firstCaptured.copySequenceOrder == 2)

                let trashedAt = Date(timeIntervalSince1970: 1_700_000_200.500)
                try store.moveToTrash(ids: [original.id], at: trashedAt)
                #expect(try store.fetchAll().isEmpty)
                #expect(try store.fetchTrashedItems().map(\.id) == [original.id])

                let recopyTime = Date(timeIntervalSince1970: 1_700_000_300.875)
                let recopyWithoutOCR = ClipboardItem.fixture(
                    kind: .image,
                    title: nil,
                    text: nil,
                    qrCodeText: nil,
                    assetPath: "/tmp/diagram-recopy.png",
                    imageDigest: "sha256-diagram-digest-001",
                    sourceAppName: "Safari",
                    sourceBundleIdentifier: "com.apple.Safari",
                    copiedAt: recopyTime,
                    byteSize: 4096,
                    copyCount: 1
                )

                let revived = try store.capture(recopyWithoutOCR, updatesCopySequence: false)
                #expect(revived.id == original.id)
                #expect(revived.title == "Custom Diagram Title")
                #expect(revived.text == "Recognized OCR Text From Vision")
                #expect(revived.qrCodeText == "https://example.com/qr")
                #expect(revived.copyCount == 2)
                #expect(revived.deletedAt == nil)
                #expect(revived.searchText.localizedCaseInsensitiveContains("Custom Diagram Title"))
                #expect(revived.searchText.localizedCaseInsensitiveContains("Recognized OCR Text From Vision"))
                #expect(revived.searchText.localizedCaseInsensitiveContains("Reference"))

                #expect(try store.fetchTrashedItems().isEmpty)
                let activeItems = try store.fetchAll()
                #expect(activeItems.count == 1)
                let fetched = try #require(activeItems.first)
                #expect(fetched.id == original.id)
                #expect(fetched.title == "Custom Diagram Title")
                #expect(fetched.text == "Recognized OCR Text From Vision")
                #expect(fetched.qrCodeText == "https://example.com/qr")
            }
        }

        @Test
        func subSecondCopiedAtPrecisionRoundTrip() throws {
            try TestSupport.withTemporaryHistoryStore { store, _ in
                let baseEpoch = 1_700_000_000.000
                var expectedIDsInDescOrder: [UUID] = []

                for offsetMs in 0..<10 {
                    let copied = Date(timeIntervalSince1970: baseEpoch + 10.0 + Double(offsetMs) * 0.001)
                    let item = ClipboardItem.fixture(
                        kind: .text,
                        text: "Millisecond clip #\(offsetMs)",
                        copiedAt: copied
                    )
                    try store.upsert(item)
                    expectedIDsInDescOrder.insert(item.id, at: 0)
                }

                let fetched = try store.fetchAll()
                #expect(fetched.map(\.id) == expectedIDsInDescOrder)

                for (reverseIndex, item) in fetched.enumerated() {
                    let offsetMs = 9 - reverseIndex
                    let expectedCopied = baseEpoch + 10.0 + Double(offsetMs) * 0.001
                    #expect(abs(item.copiedAt.timeIntervalSince1970 - expectedCopied) < 0.000_5)
                }
            }
        }

        @Test
        func lazyFormattingAndUpsertPreservation() throws {
            try TestSupport.withTemporaryHistoryStore { store, _ in
                let html = "<strong>Rich HTML Body</strong>"
                let rtfData = Data(#"{\rtf1\ansi\b Rich HTML Body\b0}"#.utf8)
                let richItem = ClipboardItem.fixture(
                    kind: .richText,
                    text: "Rich HTML Body",
                    rtfData: rtfData,
                    html: html
                )
                #expect(richItem.hasFormatting)
                #expect(richItem.isFormattingLoaded)

                try store.upsert(richItem)

                let fetchedUnloaded = try Self.fetchItem(richItem.id, from: store)
                #expect(fetchedUnloaded.hasFormatting)
                #expect(!fetchedUnloaded.isFormattingLoaded)
                #expect(fetchedUnloaded.html == nil)
                #expect(fetchedUnloaded.rtfData == nil)
                #expect(fetchedUnloaded.htmlDigest == richItem.htmlDigest)

                var mutatedUnloaded = fetchedUnloaded
                mutatedUnloaded.isFavorite = true
                mutatedUnloaded.title = "Pinned Rich Clip"
                try store.upsert(mutatedUnloaded)

                let reloadedUnloaded = try Self.fetchItem(richItem.id, from: store)
                #expect(reloadedUnloaded.isFavorite)
                #expect(reloadedUnloaded.title == "Pinned Rich Clip")
                #expect(!reloadedUnloaded.isFormattingLoaded)

                let withFormatting = try store.loadingFormatting(of: reloadedUnloaded)
                #expect(withFormatting.isFormattingLoaded)
                #expect(withFormatting.html == html)
                #expect(withFormatting.rtfData == rtfData)

                var stripped = withFormatting
                stripped.removeFormatting()
                #expect(!stripped.hasFormatting)
                try store.upsert(stripped)

                let afterStrip = try Self.fetchItem(richItem.id, from: store)
                #expect(!afterStrip.hasFormatting)
                let loadedAfterStrip = try store.loadingFormatting(of: afterStrip)
                #expect(loadedAfterStrip.html == nil)
                #expect(loadedAfterStrip.rtfData == nil)
            }
        }

        @Test
        func schemaMigrationFromV0ToV4() throws {
            try TestSupport.withTemporaryDirectory { directory in
                let dbURL = directory.appendingPathComponent("History.sqlite")
                let imageURL = directory.appendingPathComponent("legacy-image.png")
                let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02, 0x03, 0x04])
                try imageBytes.write(to: imageURL)
                let expectedImageDigest = ContentDigest.sha256(imageBytes)

                let legacyTaggedRichID = UUID()
                let legacyUntaggedRichID = UUID()
                let legacyImageID = UUID()

                let subSecondCopiedAt = 1_700_000_123.789
                let rtfOneData = Data(#"{\rtf1\ansi\b Styled Variant One\b0}"#.utf8)

                try Self.createSynthesizedV0Database(
                    at: dbURL,
                    imagePath: imageURL.path,
                    legacyTaggedRichID: legacyTaggedRichID,
                    legacyUntaggedRichID: legacyUntaggedRichID,
                    legacyImageID: legacyImageID,
                    subSecondCopiedAt: subSecondCopiedAt,
                    rtfOneData: rtfOneData
                )

                let store = SQLiteHistoryStore(directory: directory)
                let migratedItems = try store.fetchAll()
                let itemsByID = Dictionary(uniqueKeysWithValues: migratedItems.map { ($0.id, $0) })

                let (schemaVersion, hasFTSTable) = try Self.inspectDatabaseState(at: dbURL)
                #expect(schemaVersion == 4)
                #expect(!hasFTSTable)

                let migratedTags = try store.fetchTags()
                #expect(migratedTags.map(\.name) == ["LegacyTag"])

                let taggedRich = try #require(itemsByID[legacyTaggedRichID])
                #expect(taggedRich.tags.count == 1)
                #expect(!taggedRich.searchText.contains("<span"))
                #expect(taggedRich.searchText.localizedCaseInsensitiveContains("Tagged Rich Heading"))
                #expect(taggedRich.searchText.localizedCaseInsensitiveContains("LegacyTag"))
                #expect(taggedRich.hasFormatting)
                #expect(!taggedRich.isFormattingLoaded)
                let loadedTaggedRich = try store.loadingFormatting(of: taggedRich)
                #expect(loadedTaggedRich.html == #"<span class="secret-markup">Tagged Rich Heading</span>"#)
                #expect(loadedTaggedRich.rtfData == rtfOneData)

                let untaggedRich = try #require(itemsByID[legacyUntaggedRichID])
                #expect(!untaggedRich.searchText.contains("hidden-class"))
                #expect(untaggedRich.hasFormatting)
                #expect(!untaggedRich.isFormattingLoaded)
                let loadedUntaggedRich = try store.loadingFormatting(of: untaggedRich)
                #expect(loadedUntaggedRich.html == #"<div class="hidden-class">Untagged Rich Body</div>"#)

                let imageItem = try #require(itemsByID[legacyImageID])
                #expect(imageItem.imageDigest == expectedImageDigest)
                #expect(imageItem.contentKey == expectedImageDigest)
            }
        }

        private static func createSynthesizedV0Database(
            at dbURL: URL,
            imagePath: String,
            legacyTaggedRichID: UUID,
            legacyUntaggedRichID: UUID,
            legacyImageID: UUID,
            subSecondCopiedAt: Double,
            rtfOneData: Data
        ) throws {
            try executeSQL(at: dbURL, """
                CREATE TABLE clips (
                    id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    copiedAt REAL NOT NULL,
                    favorite INTEGER NOT NULL,
                    sourceApp TEXT,
                    searchText TEXT NOT NULL,
                    payload BLOB NOT NULL
                );
                CREATE TABLE clips_fts (content TEXT);
                PRAGMA user_version = 0;
                """)

            /// Inserts a row the way the first release stored it: a JSON payload with string tag names.
            func insertV0Row(
                id: UUID,
                kind: ClipboardKind,
                copiedAt: Double,
                favorite: Bool,
                sourceApp: String,
                searchText: String,
                payload: [String: Any]
            ) throws {
                var fullPayload: [String: Any] = [
                    "id": id.uuidString,
                    "kind": kind.rawValue,
                    "filePaths": [String](),
                    "sourceAppName": sourceApp,
                    "isFavorite": favorite,
                    "searchText": searchText
                ]
                fullPayload.merge(payload) { _, new in new }
                let data = try JSONSerialization.data(withJSONObject: fullPayload, options: [.sortedKeys])
                try executeSQL(at: dbURL, """
                    INSERT INTO clips (id, kind, copiedAt, favorite, sourceApp, searchText, payload)
                    VALUES ('\(id.uuidString)', '\(kind.rawValue)', \(copiedAt), \(favorite ? 1 : 0), '\(sourceApp)', '\(searchText)', \(sqlHex(data)));
                    """)
            }

            let taggedSearchText = #"Tagged Rich Heading <span class="secret-markup">Tagged Rich Heading</span>"#
            try insertV0Row(
                id: legacyTaggedRichID,
                kind: .richText,
                copiedAt: subSecondCopiedAt,
                favorite: true,
                sourceApp: "Notes",
                searchText: taggedSearchText,
                payload: [
                    "text": "Tagged Rich Heading",
                    "html": #"<span class="secret-markup">Tagged Rich Heading</span>"#,
                    "rtfData": rtfOneData.base64EncodedString(),
                    "copiedAt": "2023-11-14T22:15:23Z",
                    "byteSize": 64,
                    "tags": ["LegacyTag"],
                    "copyCount": 2
                ]
            )

            let untaggedSearchText = #"Untagged Rich Body <div class="hidden-class">Untagged Rich Body</div>"#
            try insertV0Row(
                id: legacyUntaggedRichID,
                kind: .richText,
                copiedAt: 1_700_000_200.250,
                favorite: false,
                sourceApp: "Pages",
                searchText: untaggedSearchText,
                payload: [
                    "text": "Untagged Rich Body",
                    "html": #"<div class="hidden-class">Untagged Rich Body</div>"#,
                    "copiedAt": "2023-11-14T22:16:40Z",
                    "byteSize": 48,
                    "tags": [Int](),
                    "copyCount": 1
                ]
            )

            try insertV0Row(
                id: legacyImageID,
                kind: .image,
                copiedAt: 1_700_000_300.500,
                favorite: false,
                sourceApp: "Preview",
                searchText: "legacy-image.png Preview",
                payload: [
                    "assetPath": imagePath,
                    "copiedAt": "2023-11-14T22:18:20Z",
                    "byteSize": 12,
                    "tags": [Int](),
                    "copyCount": 1
                ]
            )
        }

        @Test(arguments: [2, 3, 4])
        func legacyMigrationStepsDoNotRerunOnDatabaseAtOrAboveV2(version: Int) throws {
            try TestSupport.withTemporaryDirectory { directory in
                let dbURL = directory.appendingPathComponent("History.sqlite")
                do { _ = SQLiteHistoryStore(directory: directory) }

                // A row with string tags is what migrateLegacyTagNames rewrites.
                let legacyID = UUID()
                let legacyPayload = try JSONSerialization.data(withJSONObject: [
                    "id": legacyID.uuidString,
                    "kind": ClipboardKind.text.rawValue,
                    "text": "Legacy tagged text",
                    "filePaths": [String](),
                    "copiedAt": "2023-11-14T22:15:23Z",
                    "byteSize": 18,
                    "isFavorite": false,
                    "tags": ["LegacyTag"],
                    "searchText": "Legacy tagged text",
                    "copyCount": 1
                ] as [String: Any], options: [.sortedKeys])

                // A row with an empty key is what migrateContentKeys fills in.
                let keylessID = UUID()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let keylessPayload = try encoder.encode(
                    ClipboardItem.fixture(id: keylessID, kind: .text, text: "Keyless text")
                )

                try Self.executeSQL(at: dbURL, """
                    INSERT INTO clips (id, kind, copiedAt, favorite, sourceApp, searchText, contentKey, payload)
                    VALUES ('\(legacyID.uuidString)', 'text', 1700000000, 0, NULL, 'Legacy tagged text', 'Legacy tagged text', \(Self.sqlHex(legacyPayload)));
                    INSERT INTO clips (id, kind, copiedAt, favorite, sourceApp, searchText, contentKey, payload)
                    VALUES ('\(keylessID.uuidString)', 'text', 1700000100, 0, NULL, 'Keyless text', '', \(Self.sqlHex(keylessPayload)));
                    PRAGMA user_version = \(version);
                    """)

                let store = SQLiteHistoryStore(directory: directory)

                #expect(try store.fetchTags().isEmpty)
                #expect(try Self.queryText(at: dbURL, "SELECT hex(payload) FROM clips WHERE id = '\(legacyID.uuidString)';") == Self.hexString(legacyPayload))
                #expect(try Self.queryText(at: dbURL, "SELECT contentKey FROM clips WHERE id = '\(keylessID.uuidString)';") == "")
                #expect(try Self.queryText(at: dbURL, "SELECT hex(payload) FROM clips WHERE id = '\(keylessID.uuidString)';") == Self.hexString(keylessPayload))
                let (schemaVersion, _) = try Self.inspectDatabaseState(at: dbURL)
                #expect(schemaVersion >= 4)
            }
        }

        private static func hexString(_ data: Data) -> String {
            data.map { String(format: "%02X", $0) }.joined()
        }

        private static func sqlHex(_ data: Data) -> String {
            "X'\(hexString(data))'"
        }

        private static func withDatabase<T>(at dbURL: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
            var db: OpaquePointer?
            guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else {
                if let db { sqlite3_close(db) }
                throw HistoryStoreError.openFailed
            }
            defer { sqlite3_close(db) }
            return try body(db)
        }

        private static func executeSQL(at dbURL: URL, _ sql: String) throws {
            try withDatabase(at: dbURL) { db in
                guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                    throw HistoryStoreError.stepFailed(String(cString: sqlite3_errmsg(db)))
                }
            }
        }

        /// The first column of the first row `sql` returns, as text.
        private static func queryText(at dbURL: URL, _ sql: String) throws -> String? {
            try withDatabase(at: dbURL) { db in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                    throw HistoryStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(statement) }
                guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
                    return nil
                }
                return String(cString: text)
            }
        }

        private static func inspectDatabaseState(at dbURL: URL) throws -> (schemaVersion: Int32, hasFTSTable: Bool) {
            let version = try queryText(at: dbURL, "PRAGMA user_version;").flatMap { Int32($0) } ?? -1
            let ftsTableCount = try queryText(
                at: dbURL,
                "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'clips_fts';"
            ).flatMap { Int($0) } ?? 0
            return (version, ftsTableCount > 0)
        }

        private static func fetchItem(_ id: ClipboardItem.ID, from store: SQLiteHistoryStore) throws -> ClipboardItem {
            try #require(try store.fetchAll().first { $0.id == id })
        }
    }

    @Suite
    struct ClipBookArchiveServiceTests {
        @Test
        func fullExportAndImportRoundTrip() throws {
            try TestSupport.withTemporaryDirectory { rootDir in
                let fileManager = FileManager.default
                let sourceSupportDir = rootDir.appendingPathComponent("SourceSupport", isDirectory: true)
                let targetSupportDir = rootDir.appendingPathComponent("TargetSupport", isDirectory: true)
                let archiveURL = rootDir.appendingPathComponent("Backup.clipbookarchive", isDirectory: true)
                try fileManager.createDirectory(at: sourceSupportDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: targetSupportDir, withIntermediateDirectories: true)

                let sourceStore = SQLiteHistoryStore(directory: sourceSupportDir)
                let designTag = try sourceStore.createTag(name: "Design", color: "#E91E63")
                let docsTag = try sourceStore.createTag(name: "Docs", color: "#2196F3")

                let sourceImageURL = sourceSupportDir.appendingPathComponent("diagram.png")
                let sourcePreviewImageURL = sourceSupportDir.appendingPathComponent("og-image.png")
                let sourceFaviconURL = sourceSupportDir.appendingPathComponent("favicon.ico")
                let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x10, 0x20, 0x30])
                let previewImageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x40, 0x50, 0x60])
                let faviconBytes = Data([0x00, 0x00, 0x01, 0x00, 0x01, 0x00])
                try imageBytes.write(to: sourceImageURL)
                try previewImageBytes.write(to: sourcePreviewImageURL)
                try faviconBytes.write(to: sourceFaviconURL)

                let richItem = ClipboardItem.fixture(
                    kind: .richText,
                    title: "Formatted Spec",
                    text: "Bold & Italic Spec",
                    rtfData: Data(#"{\rtf1\ansi\b Bold & Italic Spec\b0}"#.utf8),
                    html: "<b>Bold &amp; Italic Spec</b>",
                    copiedAt: Date(timeIntervalSince1970: 1_700_001_000),
                    firstCopiedAt: Date(timeIntervalSince1970: 1_700_000_500),
                    isFavorite: true,
                    tags: [designTag.id, docsTag.id],
                    copyCount: 4,
                    favoriteOrder: 1,
                    sensitivity: .notSensitive
                )

                let imageItem = ClipboardItem.fixture(
                    kind: .image,
                    title: "Architecture Mockup",
                    text: "OCR Diagram Text",
                    qrCodeText: "https://example.com/mockup",
                    assetPath: sourceImageURL.path,
                    imageDigest: ContentDigest.sha256(imageBytes),
                    copiedAt: Date(timeIntervalSince1970: 1_700_001_010),
                    firstCopiedAt: Date(timeIntervalSince1970: 1_700_000_510),
                    tags: [designTag.id]
                )

                let linkItem = ClipboardItem.fixture(
                    kind: .link,
                    text: "https://example.com/docs#section-2",
                    copiedAt: Date(timeIntervalSince1970: 1_700_001_020),
                    firstCopiedAt: Date(timeIntervalSince1970: 1_700_000_520),
                    tags: [docsTag.id],
                    linkPreviewDetails: LinkPreviewDetails(
                        url: "https://example.com/docs#section-2",
                        title: "Section 2 — API Reference",
                        description: "Detailed documentation",
                        imagePath: sourcePreviewImageURL.path,
                        faviconPath: sourceFaviconURL.path,
                        fetchedAt: Date(timeIntervalSince1970: 1_700_001_000)
                    )
                )

                try sourceStore.upsert(richItem)
                try sourceStore.upsert(imageItem)
                try sourceStore.upsert(linkItem)

                let itemsForExport = try sourceStore.fetchAll().map { try sourceStore.loadingFormatting(of: $0) }
                let tagsForExport = try sourceStore.fetchTags()
                let sourceArchiveService = ClipBookArchiveService(
                    fileManager: fileManager,
                    supportDirectory: sourceSupportDir
                )

                var exportProgressSteps: [ClipBookArchiveProgress] = []
                try sourceArchiveService.export(
                    items: itemsForExport,
                    tags: tagsForExport,
                    to: archiveURL,
                    progress: { exportProgressSteps.append($0) }
                )
                #expect(exportProgressSteps.first?.completedItemCount == 0)
                #expect(exportProgressSteps.last?.completedItemCount == 3)
                #expect(exportProgressSteps.last?.totalItemCount == 3)

                let targetStore = SQLiteHistoryStore(directory: targetSupportDir)
                let targetArchiveService = ClipBookArchiveService(
                    fileManager: fileManager,
                    supportDirectory: targetSupportDir
                )

                var importProgressSteps: [ClipBookArchiveProgress] = []
                let importResult = try targetArchiveService.import(
                    from: archiveURL,
                    into: targetStore,
                    progress: { importProgressSteps.append($0) }
                )
                #expect(importResult.itemCount == 3)
                #expect(importResult.tagCount == 2)
                #expect(importProgressSteps.last?.completedItemCount == 3)

                let importedTags = try targetStore.fetchTags()
                #expect(Set(importedTags.map(\.name)) == Set(["Design", "Docs"]))

                let importedItems = try targetStore.fetchAll()
                #expect(importedItems.map(\.id) == [linkItem.id, imageItem.id, richItem.id])

                let importedByID = Dictionary(uniqueKeysWithValues: importedItems.map { ($0.id, $0) })

                let importedRich = try #require(importedByID[richItem.id])
                #expect(importedRich.isFavorite)
                #expect(importedRich.favoriteOrder == 1)
                #expect(importedRich.sensitivity == .notSensitive)
                let loadedRich = try targetStore.loadingFormatting(of: importedRich)
                #expect(loadedRich.html == "<b>Bold &amp; Italic Spec</b>")
                #expect(loadedRich.rtfData == Data(#"{\rtf1\ansi\b Bold & Italic Spec\b0}"#.utf8))

                let importedImage = try #require(importedByID[imageItem.id])
                #expect(importedImage.title == "Architecture Mockup")
                #expect(importedImage.text == "OCR Diagram Text")
                #expect(importedImage.qrCodeText == "https://example.com/mockup")
                #expect(importedImage.imageDigest == ContentDigest.sha256(imageBytes))
                let importedImagePath = try #require(importedImage.assetPath)
                #expect(try Data(contentsOf: URL(fileURLWithPath: importedImagePath)) == imageBytes)

                let importedLink = try #require(importedByID[linkItem.id])
                let preview = try #require(importedLink.linkPreviewDetails)
                #expect(preview.title == "Section 2 — API Reference")
                let previewImagePath = try #require(preview.imagePath)
                let faviconPath = try #require(preview.faviconPath)
                #expect(try Data(contentsOf: URL(fileURLWithPath: previewImagePath)) == previewImageBytes)
                #expect(try Data(contentsOf: URL(fileURLWithPath: faviconPath)) == faviconBytes)
            }
        }

        @Test
        func archivePathSecurityChecks() throws {
            try TestSupport.withTemporaryDirectory { rootDir in
                let fileManager = FileManager.default
                let (_, store, service) = try Self.makeImportTarget(in: rootDir)

                let secretOutsideFile = rootDir.appendingPathComponent("outside-secret.png")
                try Data("secret".utf8).write(to: secretOutsideFile)

                let invalidCases: [(name: String, assetPath: String, setup: (URL) throws -> Void)] = [
                    (
                        name: "dot-dot path traversal",
                        assetPath: "assets/images/../../../outside-secret.png",
                        setup: { _ in }
                    ),
                    (
                        name: "absolute path",
                        assetPath: secretOutsideFile.path,
                        setup: { _ in }
                    ),
                    (
                        name: "symlinked asset file",
                        assetPath: "assets/images/symlinked.png",
                        setup: { archiveDir in
                            let linkURL = archiveDir.appendingPathComponent("assets/images/symlinked.png")
                            try fileManager.createSymbolicLink(at: linkURL, withDestinationURL: secretOutsideFile)
                        }
                    ),
                    (
                        name: "symlinked parent directory",
                        assetPath: "assets/linked-dir/outside-secret.png",
                        setup: { archiveDir in
                            let linkedDirURL = archiveDir.appendingPathComponent("assets/linked-dir")
                            try fileManager.createSymbolicLink(at: linkedDirURL, withDestinationURL: rootDir)
                        }
                    ),
                    (
                        name: "directory instead of file",
                        assetPath: "assets/images/folder.png",
                        setup: { archiveDir in
                            let folderURL = archiveDir.appendingPathComponent("assets/images/folder.png")
                            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                            try Data("inner".utf8).write(to: folderURL.appendingPathComponent("inner.txt"))
                        }
                    ),
                    (
                        name: "dot-dot component inside the archive",
                        assetPath: "assets/images/../images/inner.png",
                        setup: { archiveDir in
                            try Data("inner".utf8).write(to: archiveDir.appendingPathComponent("assets/images/inner.png"))
                        }
                    )
                ]

                for (index, testCase) in invalidCases.enumerated() {
                    let badArchiveURL = rootDir.appendingPathComponent("Bad-\(index).clipbookarchive", isDirectory: true)
                    try Self.writeCustomArchive(
                        at: badArchiveURL,
                        items: [
                            (id: UUID(), kind: "image", text: nil, assetPath: testCase.assetPath)
                        ],
                        setupFiles: testCase.setup
                    )

                    let thrownError = #expect(throws: ClipBookArchiveError.self, Comment(rawValue: testCase.name)) {
                        _ = try service.import(from: badArchiveURL, into: store)
                    }
                    var isInvalidAssetPath = false
                    if case .invalidAssetPath? = thrownError {
                        isInvalidAssetPath = true
                    }
                    #expect(isInvalidAssetPath, Comment(rawValue: testCase.name))
                }
            }
        }

        @Test
        func archiveImportAcceptsDoubleDotInsideFileName() throws {
            try TestSupport.withTemporaryDirectory { rootDir in
                let (_, store, service) = try Self.makeImportTarget(in: rootDir)

                let itemID = UUID()
                let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])
                let archiveURL = rootDir.appendingPathComponent("Dots.clipbookarchive", isDirectory: true)
                try Self.writeCustomArchive(
                    at: archiveURL,
                    items: [(id: itemID, kind: "image", text: nil, assetPath: "assets/images/photo..png")],
                    setupFiles: { archiveDir in
                        try imageBytes.write(to: archiveDir.appendingPathComponent("assets/images/photo..png"))
                    }
                )

                let result = try service.import(from: archiveURL, into: store)
                #expect(result.itemIDs == [itemID])
                let imported = try #require(try store.fetchAll().first)
                let importedPath = try #require(imported.assetPath)
                #expect(try Data(contentsOf: URL(fileURLWithPath: importedPath)) == imageBytes)
            }
        }

        @Test
        func failedImportRemovesAssetFilesAlreadyCopied() throws {
            try TestSupport.withTemporaryDirectory { rootDir in
                let fileManager = FileManager.default
                let (supportDir, store, service) = try Self.makeImportTarget(in: rootDir)

                // The first item copies its image, the second one is invalid
                // (its asset is a directory), so the whole import rolls back.
                let archiveURL = rootDir.appendingPathComponent("Rollback.clipbookarchive", isDirectory: true)
                try Self.writeCustomArchive(
                    at: archiveURL,
                    items: [
                        (id: UUID(), kind: "image", text: nil, assetPath: "assets/images/first.png"),
                        (id: UUID(), kind: "image", text: nil, assetPath: "assets/images/folder.png")
                    ],
                    setupFiles: { archiveDir in
                        try Data([0x01, 0x02, 0x03]).write(to: archiveDir.appendingPathComponent("assets/images/first.png"))
                        try fileManager.createDirectory(
                            at: archiveDir.appendingPathComponent("assets/images/folder.png"),
                            withIntermediateDirectories: true
                        )
                    }
                )

                #expect(throws: ClipBookArchiveError.self) {
                    _ = try service.import(from: archiveURL, into: store)
                }

                #expect(try store.fetchAll().isEmpty)
                let imagesDirectory = supportDir.appendingPathComponent("Images", isDirectory: true)
                let leftovers = (try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
                #expect(leftovers.isEmpty)
            }
        }

        @Test(arguments: [
            (imagePath: "assets/link-previews/good.png", faviconPath: "assets/link-previews/../../../outside.png"),
            (imagePath: "assets/link-previews/../../../outside.png", faviconPath: "assets/link-previews/good.png"),
            (imagePath: "assets/link-previews/good.png", faviconPath: "assets/link-previews/folder.png")
        ])
        func linkPreviewPicturesAreCheckedLikeAssetsAndRolledBack(imagePath: String, faviconPath: String) throws {
            try TestSupport.withTemporaryDirectory { rootDir in
                let fileManager = FileManager.default
                let (supportDir, store, service) = try Self.makeImportTarget(in: rootDir)
                let itemID = UUID()
                let archiveURL = rootDir.appendingPathComponent("Previews.clipbookarchive", isDirectory: true)
                try Self.writeCustomArchive(
                    at: archiveURL,
                    items: [(id: itemID, kind: "link", text: "https://example.com/page", assetPath: nil)],
                    linkPreviews: [itemID: (imagePath: imagePath, faviconPath: faviconPath)],
                    setupFiles: { archiveDir in
                        try Data([0x01, 0x02, 0x03]).write(to: archiveDir.appendingPathComponent("assets/link-previews/good.png"))
                        try Data("secret".utf8).write(to: rootDir.appendingPathComponent("outside.png"))
                        try fileManager.createDirectory(
                            at: archiveDir.appendingPathComponent("assets/link-previews/folder.png"),
                            withIntermediateDirectories: true
                        )
                    }
                )

                let thrownError = #expect(throws: ClipBookArchiveError.self) {
                    _ = try service.import(from: archiveURL, into: store)
                }
                var isInvalidAssetPath = false
                if case .invalidAssetPath? = thrownError {
                    isInvalidAssetPath = true
                }
                #expect(isInvalidAssetPath)

                #expect(try store.fetchAll().isEmpty)
                let previewsDirectory = supportDir.appendingPathComponent("LinkPreviews", isDirectory: true)
                #expect(((try? fileManager.contentsOfDirectory(atPath: previewsDirectory.path)) ?? []).isEmpty)
            }
        }

        /// An empty support directory under `rootDir` with a store and an archive service on it.
        private static func makeImportTarget(
            in rootDir: URL
        ) throws -> (supportDir: URL, store: SQLiteHistoryStore, service: ClipBookArchiveService) {
            let supportDir = rootDir.appendingPathComponent("Support", isDirectory: true)
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            return (
                supportDir,
                SQLiteHistoryStore(directory: supportDir),
                ClipBookArchiveService(fileManager: .default, supportDirectory: supportDir)
            )
        }

        private static func writeCustomArchive(
            at archiveURL: URL,
            items: [(id: UUID, kind: String, text: String?, assetPath: String?)],
            linkPreviews: [UUID: (imagePath: String?, faviconPath: String?)] = [:],
            setupFiles: (URL) throws -> Void
        ) throws {
            let fileManager = FileManager.default
            let imagesDir = archiveURL.appendingPathComponent("assets/images", isDirectory: true)
            let linkPreviewsDir = archiveURL.appendingPathComponent("assets/link-previews", isDirectory: true)
            try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: linkPreviewsDir, withIntermediateDirectories: true)

            let manifest: [String: Any] = [
                "formatVersion": 1,
                "appName": "ClipBook",
                "exportedAt": "2026-10-30T12:00:00Z"
            ]
            let history: [[String: Any]] = items.map { entry in
                var dict: [String: Any] = [
                    "id": entry.id.uuidString,
                    "kind": entry.kind,
                    "filePaths": [String](),
                    "copiedAt": "2026-10-30T12:00:00Z",
                    "firstCopiedAt": "2026-10-30T12:00:00Z",
                    "byteSize": 16,
                    "isFavorite": false,
                    "tagIDs": [String](),
                    "tagNames": [String](),
                    "copyCount": 1
                ]
                if let text = entry.text {
                    dict["text"] = text
                }
                if let assetPath = entry.assetPath {
                    dict["assetPath"] = assetPath
                }
                if let preview = linkPreviews[entry.id] {
                    var details: [String: Any] = ["url": "https://example.com/page", "fetchedAt": "2026-10-30T12:00:00Z"]
                    details["imagePath"] = preview.imagePath
                    details["faviconPath"] = preview.faviconPath
                    dict["linkPreviewDetails"] = details
                }
                return dict
            }

            try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
                .write(to: archiveURL.appendingPathComponent("manifest.json"))
            try Data("[]".utf8)
                .write(to: archiveURL.appendingPathComponent("tags.json"))
            try JSONSerialization.data(withJSONObject: history, options: [.prettyPrinted])
                .write(to: archiveURL.appendingPathComponent("history.json"))

            try setupFiles(archiveURL)
        }
    }
}
