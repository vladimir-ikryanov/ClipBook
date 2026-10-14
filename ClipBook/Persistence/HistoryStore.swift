import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

protocol HistoryStore {
    func fetchAll() throws -> [ClipboardItem]
    func fetchTags() throws -> [Tag]
    func capture(_ item: ClipboardItem, updatesCopySequence: Bool) throws -> ClipboardItem
    func upsert(_ item: ClipboardItem) throws
    /// The item with its formatting read from the store. Items read from the
    /// store come without it, and only pasting, dragging, previewing and
    /// export need it. An item without formatting comes back as it is.
    func loadingFormatting(of item: ClipboardItem) throws -> ClipboardItem
    func createTag(name: String, color: String) throws -> Tag
    func updateTag(id: Tag.ID, name: String, color: String) throws -> Tag
    func deleteTag(id: Tag.ID) throws
    func delete(_ id: UUID) throws
    func delete(ids: [UUID]) throws
    func clear() throws
    func clear(keepingFavoritesAndTaggedItems: Bool) throws
    func incrementCopyCount(_ id: UUID) throws
    func recordAction(_ id: UUID, copiedAt: Date?, incrementsCopyCount: Bool) throws -> ClipboardItem?
    func fetchItems(expiredBy policy: HistoryRetentionPolicy) throws -> [ClipboardItem]
    /// The latest item of the kind with the content key, the one a capture of
    /// that content updates.
    func fetchItem(kind: ClipboardKind, contentKey: String) throws -> ClipboardItem?
    /// The files every item in the store refers to, its image and its link
    /// preview pictures.
    func fetchStoredFilePaths() throws -> Set<String>
    func fetchItems(where isIncluded: (ClipboardItem) -> Bool) throws -> [ClipboardItem]
    /// The item copied last among those `isIncluded` accepts. Items are read
    /// from the latest one back and only until one is accepted, so asking
    /// about the top of the history does not read the rest of it.
    func fetchMostRecentItem(where isIncluded: (ClipboardItem) -> Bool) throws -> ClipboardItem?
    /// Runs `body` as a single transaction, so a loop of writes commits once.
    /// Rolls back and rethrows if `body` throws. Nested calls join the
    /// enclosing transaction.
    func performInTransaction(_ body: () throws -> Void) throws
}
