import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

final class SQLiteHistoryStore: HistoryStore {
    private let databaseURL: URL
    private let lock = NSRecursiveLock()
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL) {
        databaseURL = directory.appendingPathComponent("History.sqlite")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? open()
        try? migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func fetchAll() throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let sql = "SELECT payload, copiedAt FROM clips ORDER BY copiedAt DESC;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []
        var seenItemIDs: Set<ClipboardItem.ID> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = try? decodeItem(from: statement),
               seenItemIDs.insert(item.id).inserted {
                items.append(item)
            }
        }
        return items
    }

    func fetchTags() throws -> [Tag] {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let sql = "SELECT id, name, color FROM tags ORDER BY name COLLATE NOCASE ASC;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var tags: [Tag] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameText = sqlite3_column_text(statement, 1),
                  let colorText = sqlite3_column_text(statement, 2) else {
                continue
            }
            tags.append(Tag(
                id: Int(sqlite3_column_int64(statement, 0)),
                name: String(cString: nameText),
                color: String(cString: colorText)
            ))
        }
        return tags
    }

    func capture(_ item: ClipboardItem, updatesCopySequence: Bool) throws -> ClipboardItem {
        lock.lock()
        defer { lock.unlock() }

        if var existingItem = try fetchMatchingItem(kind: item.kind, contentKey: item.contentKey) {
            existingItem.title = item.title
            existingItem.text = item.text
            // An item captured before QR codes were read keeps whatever it has
            // until a capture brings a payload with it.
            existingItem.qrCodeText = item.qrCodeText ?? existingItem.qrCodeText
            existingItem.setFormatting(html: item.html, rtfData: item.rtfData)
            existingItem.assetPath = item.assetPath
            existingItem.filePaths = item.filePaths
            existingItem.sourceAppName = item.sourceAppName
            existingItem.sourceBundleIdentifier = item.sourceBundleIdentifier
            existingItem.copiedAt = item.copiedAt
            existingItem.byteSize = item.byteSize
            existingItem.linkPreviewDetails = item.linkPreviewDetails ?? existingItem.linkPreviewDetails
            if updatesCopySequence {
                existingItem.copySequenceID = item.copySequenceID
                existingItem.copySequenceOrder = item.copySequenceOrder
            }
            let tagNamesByID = Dictionary(uniqueKeysWithValues: try fetchTags().map { ($0.id, $0.name) })
            existingItem.searchText = ClipboardItem.makeSearchText(
                title: existingItem.title,
                text: existingItem.text,
                filePaths: existingItem.filePaths,
                tagNames: existingItem.tags.compactMap { tagNamesByID[$0] },
                sourceAppName: existingItem.sourceAppName,
                linkPreviewDetails: existingItem.linkPreviewDetails,
                qrCodeText: existingItem.qrCodeText
            )
            existingItem.copyCount += 1
            try upsert(existingItem)
            return existingItem
        }

        try upsert(item)
        return item
    }

    func upsert(_ item: ClipboardItem) throws {
        lock.lock()
        defer { lock.unlock() }

        try open()
        // The formatting has its own columns. An item that has formatting but
        // does not hold it, such as one from the history marked as a favorite,
        // leaves the stored formatting as it is.
        let writesFormatting = item.isFormattingLoaded || !item.hasFormatting
        let payload = try encoder.encode(item.unloadingFormatting())
        let sql = """
        INSERT INTO clips (id, kind, copiedAt, favorite, sourceApp, searchText, contentKey, payload, html, rtf)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            kind = excluded.kind,
            copiedAt = excluded.copiedAt,
            favorite = excluded.favorite,
            sourceApp = excluded.sourceApp,
            searchText = excluded.searchText,
            contentKey = excluded.contentKey,
            payload = excluded.payload\(writesFormatting ? ", html = excluded.html, rtf = excluded.rtf" : "");
        """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(item.id.uuidString, at: 1, statement: statement)
        try bind(item.kind.rawValue, at: 2, statement: statement)
        sqlite3_bind_double(statement, 3, item.copiedAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 4, item.isFavorite ? 1 : 0)
        try bind(item.sourceAppName, at: 5, statement: statement)
        try bind(item.searchText, at: 6, statement: statement)
        try bind(item.contentKey, at: 7, statement: statement)
        bind(payload, at: 8, statement: statement)
        try bind(item.html, at: 9, statement: statement)
        bind(item.rtfData, at: 10, statement: statement)
        try step(statement)
    }

    func loadingFormatting(of item: ClipboardItem) throws -> ClipboardItem {
        guard item.hasFormatting, !item.isFormattingLoaded else {
            return item
        }

        lock.lock()
        defer { lock.unlock() }

        try open()
        let statement = try prepare("SELECT html, rtf FROM clips WHERE id = ? LIMIT 1;")
        defer { sqlite3_finalize(statement) }
        try bind(item.id.uuidString, at: 1, statement: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return item
        }

        var loadedItem = item
        loadedItem.setFormatting(html: columnText(statement, 0), rtfData: columnData(statement, 1))
        return loadedItem
    }

    func createTag(name: String, color: String) throws -> Tag {
        lock.lock()
        defer { lock.unlock() }

        try open()
        if let existingTag = try fetchTag(named: name) {
            return existingTag
        }

        let sql = "INSERT INTO tags (name, color) VALUES (?, ?);"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(name, at: 1, statement: statement)
        try bind(color, at: 2, statement: statement)
        try step(statement)

        return Tag(id: Int(sqlite3_last_insert_rowid(db)), name: name, color: color)
    }

    func updateTag(id: Tag.ID, name: String, color: String) throws -> Tag {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let sql = "UPDATE tags SET name = ?, color = ? WHERE id = ?;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(name, at: 1, statement: statement)
        try bind(color, at: 2, statement: statement)
        sqlite3_bind_int64(statement, 3, sqlite3_int64(id))
        try step(statement)
        return Tag(id: id, name: name, color: color)
    }

    func deleteTag(id: Tag.ID) throws {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let sql = "DELETE FROM tags WHERE id = ?;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(id))
        try step(statement)
    }

    func delete(_ id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        try execute("DELETE FROM clips WHERE id = ?;", binding: id.uuidString)
    }

    func delete(ids: [UUID]) throws {
        lock.lock()
        defer { lock.unlock() }

        try deleteClips(ids: ids)
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        try open()
        try exec("DELETE FROM clips;")
    }

    func clear(keepingFavoritesAndTaggedItems: Bool) throws {
        lock.lock()
        defer { lock.unlock() }

        guard keepingFavoritesAndTaggedItems else {
            try clear()
            return
        }

        let ids = try fetchDeletableClipIDs()
        try deleteClips(ids: ids)
    }

    func incrementCopyCount(_ id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        guard var item = try fetchItem(id) else {
            return
        }
        item.copyCount += 1
        try upsert(item)
    }

    func recordAction(_ id: UUID, copiedAt: Date?, incrementsCopyCount: Bool) throws -> ClipboardItem? {
        lock.lock()
        defer { lock.unlock() }

        guard var item = try fetchItem(id) else {
            return nil
        }

        if let copiedAt {
            item.copiedAt = copiedAt
        }
        if incrementsCopyCount {
            item.copyCount += 1
        }

        try upsert(item)
        return item
    }

    func fetchItems(where isIncluded: (ClipboardItem) -> Bool) throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let statement = try prepare("SELECT payload, copiedAt FROM clips ORDER BY copiedAt DESC;")
        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = try? decodeItem(from: statement), isIncluded(item) {
                items.append(item)
            }
        }
        return items
    }

    func fetchMostRecentItem(where isIncluded: (ClipboardItem) -> Bool) throws -> ClipboardItem? {
        lock.lock()
        defer { lock.unlock() }

        try open()
        let statement = try prepare("SELECT payload, copiedAt FROM clips ORDER BY copiedAt DESC;")
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = try? decodeItem(from: statement), isIncluded(item) {
                return item
            }
        }
        return nil
    }

    func fetchStoredFilePaths() throws -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        try open()
        // Only a payload that names an asset or a link preview can refer to a
        // file, which leaves out the text items that make up most of a history.
        let statement = try prepare("""
            SELECT payload FROM clips
            WHERE instr(payload, CAST('assetPath' AS BLOB)) > 0
               OR instr(payload, CAST('linkPreviewDetails' AS BLOB)) > 0;
            """)
        defer { sqlite3_finalize(statement) }

        var paths: Set<String> = []
        while true {
            let result = sqlite3_step(statement)
            guard result == SQLITE_ROW else {
                guard result == SQLITE_DONE else {
                    throw HistoryStoreError.stepFailed(lastErrorMessage)
                }
                break
            }
            guard let bytes = sqlite3_column_blob(statement, 0) else {
                continue
            }

            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            // A payload that cannot be read fails the whole fetch instead of
            // being skipped: the files left out of the result get deleted.
            let item = try decoder.decode(ClipboardItem.self, from: data)
            paths.formUnion(item.storedFilePaths)
        }
        return paths
    }

    func fetchItem(kind: ClipboardKind, contentKey: String) throws -> ClipboardItem? {
        lock.lock()
        defer { lock.unlock() }

        return try fetchMatchingItem(kind: kind, contentKey: contentKey)
    }

    func fetchItems(expiredBy policy: HistoryRetentionPolicy) throws -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }

        let cutoffs = policy.cutoffsByKind.sorted { $0.key.rawValue < $1.key.rawValue }
        guard !cutoffs.isEmpty else {
            return []
        }

        try open()
        let conditions = cutoffs.map { _ in "(kind = ? AND copiedAt < ?)" }.joined(separator: " OR ")
        let statement = try prepare("SELECT payload, copiedAt FROM clips WHERE \(conditions) ORDER BY copiedAt DESC;")
        defer { sqlite3_finalize(statement) }
        for (offset, (kind, cutoff)) in cutoffs.enumerated() {
            try bind(kind.rawValue, at: Int32(offset * 2 + 1), statement: statement)
            sqlite3_bind_double(statement, Int32(offset * 2 + 2), cutoff.timeIntervalSince1970)
        }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            // Favorites and tags only live in the payload, so the policy gets
            // the final say on each row.
            if let item = try? decodeItem(from: statement), policy.isExpired(item) {
                items.append(item)
            }
        }
        return items
    }

    private func open() throws {
        guard db == nil else {
            return
        }
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw HistoryStoreError.openFailed
        }
        configureConnection()
    }

    /// Every capture is its own small commit, so the database runs in WAL mode:
    /// a commit appends to `History.sqlite-wal` instead of creating, syncing and
    /// deleting a rollback journal. The mode is stored in the file, so existing
    /// databases convert in place on first open. WAL is unavailable on some
    /// filesystems (network volumes); the store keeps working in whichever mode
    /// SQLite reports.
    private func configureConnection() {
        sqlite3_busy_timeout(db, 5_000)
        let journalMode = queryPragma("PRAGMA journal_mode = WAL;") ?? "unknown"
        if journalMode.caseInsensitiveCompare("wal") != .orderedSame {
            NSLog("ClipBook history database could not enable WAL, running in \(journalMode) mode")
        }
        // Durable at checkpoint rather than at every commit; in WAL mode this
        // cannot corrupt the database, only lose the last commits on power loss.
        try? exec("PRAGMA synchronous = NORMAL;")
    }

    private func queryPragma(_ sql: String) -> String? {
        guard let statement = try? prepare(sql) else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: text)
    }

    private func migrate() throws {
        try open()
        try exec("""
        CREATE TABLE IF NOT EXISTS clips (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            copiedAt REAL NOT NULL,
            favorite INTEGER NOT NULL,
            sourceApp TEXT,
            searchText TEXT NOT NULL,
            contentKey TEXT NOT NULL,
            payload BLOB NOT NULL,
            html TEXT,
            rtf BLOB
        );
        """)
        if try !columnExists("contentKey", in: "clips") {
            try exec("ALTER TABLE clips ADD COLUMN contentKey TEXT;")
        }
        if try !columnExists("html", in: "clips") {
            try exec("ALTER TABLE clips ADD COLUMN html TEXT;")
        }
        if try !columnExists("rtf", in: "clips") {
            try exec("ALTER TABLE clips ADD COLUMN rtf BLOB;")
        }
        try exec("CREATE INDEX IF NOT EXISTS idx_clips_copiedAt ON clips(copiedAt DESC);")
        try exec("CREATE INDEX IF NOT EXISTS idx_clips_kind ON clips(kind);")
        try exec("CREATE INDEX IF NOT EXISTS idx_clips_contentKey ON clips(kind, contentKey);")
        // Earlier versions created a full-text index that was never filled or queried.
        try exec("DROP TABLE IF EXISTS clips_fts;")
        try exec("""
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE COLLATE NOCASE,
            color TEXT NOT NULL
        );
        """)
        // Each step rewrites rows one by one; one transaction commits them once.
        try performInTransaction {
            try migrateLegacyTagNames()
            try migrateContentKeys()
            try migrateRichTextSearchText()
            try migrateStableContentKeys()
            try migrateFormattingColumns()
            try migrateImageDigests()
        }
    }

    /// `PRAGMA user_version`, bumped whenever stored rows have to be rewritten.
    /// Each step guards on the version it introduces, so a database is only
    /// rewritten once per step.
    private func schemaVersion() throws -> Int32 {
        let statement = try prepare("PRAGMA user_version;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return sqlite3_column_int(statement, 0)
    }

    private func setSchemaVersion(_ version: Int32) throws {
        try exec("PRAGMA user_version = \(version);")
    }

    /// Rich text items used to carry their HTML in the search text, so markup
    /// nobody could see matched searches. Their search text and content key
    /// are rebuilt from the plain text once.
    private func migrateRichTextSearchText() throws {
        guard try schemaVersion() < 1 else {
            return
        }

        let tagNamesByID = Dictionary(uniqueKeysWithValues: try fetchTags().map { ($0.id, $0.name) })
        let statement = try prepare("SELECT payload FROM clips;")
        defer { sqlite3_finalize(statement) }

        var rebuiltItems: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else {
                continue
            }

            let count = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: count)
            guard let item = try? decoder.decode(ClipboardItem.self, from: data),
                  let html = item.html, !html.isEmpty else {
                continue
            }

            rebuiltItems.append(item.rebuildingSearchText(tagNames: item.tags.compactMap { tagNamesByID[$0] }))
        }

        for item in rebuiltItems {
            try upsert(item)
        }

        try setSchemaVersion(1)
    }

    /// Content keys used to be derived from the search text, which the store
    /// extends with the source app, tag names and link preview details once an
    /// item is matched. A matched item's key therefore drifted away from what
    /// a fresh capture of the same content produced, and the third copy of a
    /// text started a second item. The key is now built from the content
    /// alone, so every stored key is recomputed once.
    private func migrateStableContentKeys() throws {
        guard try schemaVersion() < 2 else {
            return
        }

        let statement = try prepare("SELECT id, payload FROM clips;")
        defer { sqlite3_finalize(statement) }

        var contentKeysByID: [(id: String, contentKey: String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let bytes = sqlite3_column_blob(statement, 1) else {
                continue
            }

            let count = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: bytes, count: count)
            guard let item = try? decoder.decode(ClipboardItem.self, from: data) else {
                continue
            }

            contentKeysByID.append((id: String(cString: idText), contentKey: item.contentKey))
        }

        for entry in contentKeysByID {
            let update = try prepare("UPDATE clips SET contentKey = ? WHERE id = ?;")
            defer { sqlite3_finalize(update) }
            try bind(entry.contentKey, at: 1, statement: update)
            try bind(entry.id, at: 2, statement: update)
            try step(update)
        }

        try setSchemaVersion(2)
    }

    /// The formatting of rich text moved from the payload to its own columns,
    /// so reading the history no longer reads it, and the content key holds a
    /// digest of the HTML instead of the HTML itself. Every item that has
    /// formatting is rewritten once.
    private func migrateFormattingColumns() throws {
        guard try schemaVersion() < 3 else {
            return
        }

        let statement = try prepare("""
            SELECT payload FROM clips
            WHERE instr(payload, CAST('"html"' AS BLOB)) > 0
               OR instr(payload, CAST('"rtfData"' AS BLOB)) > 0;
            """)
        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else {
                continue
            }

            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            if let item = try? decoder.decode(ClipboardItem.self, from: data), item.isFormattingLoaded {
                items.append(item)
            }
        }

        for item in items {
            let payload = try encoder.encode(item.unloadingFormatting())
            let update = try prepare("UPDATE clips SET payload = ?, contentKey = ?, html = ?, rtf = ? WHERE id = ?;")
            defer { sqlite3_finalize(update) }
            bind(payload, at: 1, statement: update)
            try bind(item.contentKey, at: 2, statement: update)
            try bind(item.html, at: 3, statement: update)
            bind(item.rtfData, at: 4, statement: update)
            try bind(item.id.uuidString, at: 5, statement: update)
            try step(update)
        }

        try setSchemaVersion(3)
    }

    /// Images are told apart by the digest of their file instead of the file
    /// itself, so copying an image already in the history updates its item.
    /// The images stored before get their digest from their file once. One
    /// whose file is gone keeps the file path as its key.
    private func migrateImageDigests() throws {
        guard try schemaVersion() < 4 else {
            return
        }

        let statement = try prepare("SELECT payload, copiedAt FROM clips WHERE kind = ?;")
        defer { sqlite3_finalize(statement) }
        try bind(ClipboardKind.image.rawValue, at: 1, statement: statement)

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard var item = try? decodeItem(from: statement),
                  item.imageDigest == nil,
                  let assetPath = item.assetPath,
                  let data = FileManager.default.contents(atPath: assetPath) else {
                continue
            }

            item.imageDigest = ContentDigest.sha256(data)
            items.append(item)
        }

        for item in items {
            try upsert(item)
        }

        try setSchemaVersion(4)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.prepareFailed(lastErrorMessage)
        }
        return statement
    }

    private func execute(_ sql: String, binding value: String) throws {
        try open()
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(value, at: 1, statement: statement)
        try step(statement)
    }

    private func fetchDeletableClipIDs() throws -> [UUID] {
        try open()
        let statement = try prepare("SELECT id, payload FROM clips;")
        defer { sqlite3_finalize(statement) }

        var ids: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idText)),
                  let bytes = sqlite3_column_blob(statement, 1) else {
                continue
            }

            let count = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: bytes, count: count)
            guard let item = try? decoder.decode(ClipboardItem.self, from: data),
                  !item.isFavorite,
                  item.tags.isEmpty else {
                continue
            }

            ids.append(id)
        }
        return ids
    }

    func performInTransaction(_ body: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }

        try open()
        guard sqlite3_get_autocommit(db) != 0 else {
            // Already inside a transaction: join it.
            try body()
            return
        }

        try exec("BEGIN TRANSACTION;")
        do {
            try body()
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    private func deleteClips(ids: [UUID]) throws {
        guard !ids.isEmpty else {
            return
        }

        try performInTransaction {
            for id in ids {
                try execute("DELETE FROM clips WHERE id = ?;", binding: id.uuidString)
            }
        }
    }

    private func fetchItem(_ id: UUID) throws -> ClipboardItem? {
        try open()
        let sql = "SELECT payload, copiedAt FROM clips WHERE id = ? LIMIT 1;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(id.uuidString, at: 1, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try decodeItem(from: statement)
    }

    private func fetchMatchingItem(kind: ClipboardKind, contentKey: String) throws -> ClipboardItem? {
        try open()
        let sql = "SELECT payload, copiedAt FROM clips WHERE kind = ? AND contentKey = ? ORDER BY copiedAt DESC LIMIT 1;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(kind.rawValue, at: 1, statement: statement)
        try bind(contentKey, at: 2, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try decodeItem(from: statement)
    }

    /// Decodes the row of a statement that selects `payload, copiedAt`. The
    /// payload keeps dates to the whole second, so the copy time comes from
    /// its own column, which keeps the fraction and with it the order of
    /// items copied within the same second.
    private func decodeItem(from statement: OpaquePointer?) throws -> ClipboardItem? {
        guard let bytes = sqlite3_column_blob(statement, 0) else {
            return nil
        }

        let count = Int(sqlite3_column_bytes(statement, 0))
        var item = try decoder.decode(ClipboardItem.self, from: Data(bytes: bytes, count: count))
        if sqlite3_column_type(statement, 1) != SQLITE_NULL {
            item.copiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        }
        return item
    }

    private func fetchTag(named name: String) throws -> Tag? {
        try open()
        let sql = "SELECT id, name, color FROM tags WHERE name = ? COLLATE NOCASE LIMIT 1;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(name, at: 1, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let nameText = sqlite3_column_text(statement, 1),
              let colorText = sqlite3_column_text(statement, 2) else {
            return nil
        }

        return Tag(
            id: Int(sqlite3_column_int64(statement, 0)),
            name: String(cString: nameText),
            color: String(cString: colorText)
        )
    }

    private func migrateLegacyTagNames() throws {
        let sql = "SELECT id, payload FROM clips;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var migratedItems: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 1) else {
                continue
            }

            let count = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: bytes, count: count)
            guard let legacyItem = try? decoder.decode(LegacyClipboardItem.self, from: data),
                  !legacyItem.tags.isEmpty else {
                continue
            }

            let tags = try legacyItem.tags.map { try createTag(name: $0, color: "#3B85ED") }
            migratedItems.append(legacyItem.clipboardItem(tagIDs: tags.map(\.id), tagNames: tags.map(\.name)))
        }

        for item in migratedItems {
            try upsert(item)
        }
    }

    private func migrateContentKeys() throws {
        let sql = "SELECT id, payload FROM clips WHERE contentKey IS NULL OR contentKey = '';"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var contentKeysByID: [(id: String, contentKey: String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let bytes = sqlite3_column_blob(statement, 1) else {
                continue
            }

            let count = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: bytes, count: count)
            guard let item = try? decoder.decode(ClipboardItem.self, from: data) else {
                continue
            }

            contentKeysByID.append((id: String(cString: idText), contentKey: item.contentKey))
        }

        for entry in contentKeysByID {
            let update = try prepare("UPDATE clips SET contentKey = ? WHERE id = ?;")
            defer { sqlite3_finalize(update) }
            try bind(entry.contentKey, at: 1, statement: update)
            try bind(entry.id, at: 2, statement: update)
            try step(update)
        }
    }

    private func columnExists(_ columnName: String, in tableName: String) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(tableName));")
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameText = sqlite3_column_text(statement, 1) else {
                continue
            }

            if String(cString: nameText) == columnName {
                return true
            }
        }

        return false
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw HistoryStoreError.stepFailed(lastErrorMessage)
        }
    }

    private func bind(_ value: String?, at index: Int32, statement: OpaquePointer?) throws {
        if let value {
            guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                throw HistoryStoreError.bindFailed
            }
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ value: Data?, at index: Int32, statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        _ = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), SQLITE_TRANSIENT)
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    private func columnData(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else {
            return nil
        }

        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private func step(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.stepFailed(lastErrorMessage)
        }
    }

    private var lastErrorMessage: String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private struct LegacyClipboardItem: Decodable {
    var id: UUID
    var kind: ClipboardKind
    var title: String?
    var text: String?
    var rtfData: Data?
    var html: String?
    var assetPath: String?
    var filePaths: [String]
    var sourceAppName: String?
    var sourceBundleIdentifier: String?
    var copiedAt: Date
    var byteSize: Int
    var isFavorite: Bool
    var tags: [String]
    var copyCount: Int

    func clipboardItem(tagIDs: [Int], tagNames: [String]) -> ClipboardItem {
        ClipboardItem(
            id: id,
            kind: kind,
            title: title,
            text: text,
            rtfData: rtfData,
            html: html,
            assetPath: assetPath,
            filePaths: filePaths,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier: sourceBundleIdentifier,
            copiedAt: copiedAt,
            byteSize: byteSize,
            isFavorite: isFavorite,
            tags: tagIDs,
            searchText: ClipboardItem.makeSearchText(
                title: title,
                text: text,
                filePaths: filePaths,
                tagNames: tagNames,
                sourceAppName: sourceAppName
            ),
            copyCount: copyCount
        )
    }
}
