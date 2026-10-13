import Foundation
import AppKit
import UniformTypeIdentifiers

protocol PasteboardMonitorDelegate: AnyObject {
    @MainActor func pasteboardMonitor(
        _ monitor: PasteboardMonitor,
        didCapture item: ClipboardItem,
        updatedItems: [ClipboardItem]
    )

    /// The text and QR codes read from the image of a captured item, which
    /// arrive after the item is in the history.
    @MainActor func pasteboardMonitor(
        _ monitor: PasteboardMonitor,
        didRecognize content: RecognizedImageContent,
        inItemWithID itemID: ClipboardItem.ID
    )
}
