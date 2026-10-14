import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

protocol HistoryStore {
    /// The items in the history. Items in the Trash are left out of this and
    /// of every other fetch unless it says otherwise.
    func fetchAll() throws -> [ClipboardItem]
    /// The items in the Trash, the most recently deleted first.
    func fetchTrashedItems() throws -> [ClipboardItem]
    /// The items that were moved to the Trash before `date`.
    func fetchItems(trashedBefore date: Date) throws -> [ClipboardItem]
    /// Marks the items as deleted at `date`. They stay in the store, with
    /// their files, until they are deleted for good.
    func moveToTrash(ids: [UUID], at date: Date) throws
    /// Brings items in the Trash back to the history.
    func restoreFromTrash(ids: [UUID]) throws
    func fetchTags() throws -> [Tag]
    /// Saves a captured item, or updates the item that already holds its
    /// content. An item in the Trash that holds it comes back to the history.
    func capture(_ item: ClipboardItem, updatesCopySequence: Bool) throws -> ClipboardItem
    /// Saves the item. An existing item stays in or out of the Trash.
    func upsert(_ item: ClipboardItem) throws
    /// The item with its formatting read from the store. Items read from the
    /// store come without it, and only pasting, dragging, previewing and
    /// export need it. An item without formatting comes back as it is.
    func loadingFormatting(of item: ClipboardItem) throws -> ClipboardItem
    func createTag(name: String, color: String) throws -> Tag
    func updateTag(id: Tag.ID, name: String, color: String) throws -> Tag
    func deleteTag(id: Tag.ID) throws
    /// Deletes items for good, whether they are in the history or the Trash.
    func delete(_ id: UUID) throws
    func delete(ids: [UUID]) throws
    /// Deletes everything, the Trash included.
    func clear() throws
    /// Deletes the history and the whole Trash, sparing the favorites and
    /// tagged items in the history when asked to.
    func clear(keepingFavoritesAndTaggedItems: Bool) throws
    func incrementCopyCount(_ id: UUID) throws
    func recordAction(_ id: UUID, copiedAt: Date?, incrementsCopyCount: Bool) throws -> ClipboardItem?
    func fetchItems(expiredBy policy: HistoryRetentionPolicy) throws -> [ClipboardItem]
    /// The latest item of the kind with the content key, the one a capture of
    /// that content updates. It may be in the Trash, which a capture brings
    /// it back from, but an item in the history comes first.
    func fetchItem(kind: ClipboardKind, contentKey: String) throws -> ClipboardItem?
    /// The files every item in the store refers to, its image and its link
    /// preview pictures, the items in the Trash included.
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
