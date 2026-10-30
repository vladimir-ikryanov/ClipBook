import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class PasteboardMonitor {
    static let ghostType = PasteboardReader.ghostType

    weak var delegate: PasteboardMonitorDelegate?
    var isPaused = false

    private let pasteboard = NSPasteboard.general
    private let historyStore: HistoryStore
    private let findStoredImage: @Sendable (String) -> StoredImage?
    private let fileManager: FileManager
    private let supportDirectory: URL
    private var timer: Timer?
    private var lastChangeCount: Int
    private var preferences = AppPreferences() {
        didSet {
            if preferences.ignoredAppsText != oldValue.ignoredAppsText {
                ignoredApplicationEntries = preferences.ignoredApplicationEntries
            }
        }
    }
    // Parsed from the setting when it changes rather than on every poll, ten
    // times a second.
    private var ignoredApplicationEntries = AppPreferences().ignoredApplicationEntries
    private var lastCopySequencePasteTime = Date.distantPast
    private var pendingCopyAndMergeItem: ClipboardItem?
    private var pendingCopyAndMergeDeadline = Date.distantPast
    private let checkPasteboardInterval: TimeInterval = 0.1
    private let copySequenceThreshold: TimeInterval = 30
    private let copyAndMergeHoldInterval: TimeInterval = 0.5
    // Chromium-based apps (Slack, Chrome, etc.) clear the pasteboard first, which bumps
    // changeCount, and write the actual data slightly later without bumping it again.
    // When a pasteboard change yields no readable content, keep re-reading it for a
    // short period instead of skipping the change permanently.
    private let maxDeferredReadAttempts = 30
    private var deferredReadAttemptsRemaining = 0
    // The pasteboard is read on a queue of its own: a read waits for the
    // application that owns the pasteboard for as long as it takes to hand its
    // data over, and the main thread must stay free in the meantime. Reads run
    // one at a time, so a poll that finds one still running starts no other.
    private let readQueue = DispatchQueue(label: "com.ikryanov.clipbook.v2.pasteboard-reader", qos: .userInitiated)
    // Reading the text of an image can take seconds, and much longer the first
    // time after launch. It has a queue of its own so the pasteboard is read
    // meanwhile; a read that waited for it missed the copies made in between.
    private let textRecognitionQueue = DispatchQueue(label: "com.ikryanov.clipbook.v2.image-text", qos: .utility)
    /// The image to read the text of, by the ID of the item made for it, until
    /// that item is in the history.
    private var textRecognitionImagesByItemID: [ClipboardItem.ID: URL] = [:]
    private var isReadInFlight = false
    // A read that was started before the monitor was stopped belongs to no
    // one when it finishes, and its result is dropped.
    private var readGeneration = 0

    init(historyStore: HistoryStore, fileManager: FileManager, supportDirectory: URL) {
        self.historyStore = historyStore
        self.fileManager = fileManager
        self.supportDirectory = supportDirectory
        // The store guards itself with a lock, so the read queue may ask it.
        nonisolated(unsafe) let store = historyStore
        findStoredImage = { digest in
            guard let item = try? store.fetchItem(kind: .image, contentKey: digest),
                  let assetPath = item.assetPath else {
                return nil
            }

            return StoredImage(
                assetPath: assetPath,
                recognizedContent: RecognizedImageContent(text: item.text, qrCodeText: item.qrCodeText)
            )
        }
        lastChangeCount = pasteboard.changeCount
    }

    func start(preferences: AppPreferences) {
        self.preferences = preferences
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkPasteboardInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        readGeneration += 1
        clearPendingCopyAndMergeItem()
    }

    func updatePreferences(_ preferences: AppPreferences) {
        if !preferences.copyAndMergeEnabled {
            clearPendingCopyAndMergeItem()
        }
        self.preferences = preferences
    }

    func markCopySequencePasteBoundary() {
        lastCopySequencePasteTime = Date()
    }

    private func poll() {
        guard !isPaused else {
            return
        }

        guard !isReadInFlight else {
            // The read is waiting for the application that owns the pasteboard.
            // An item held for Copy & Merge still goes to the history on time.
            flushPendingCopyAndMergeItemIfExpiredLoggingFailure()
            return
        }

        isReadInFlight = true
        let request = PasteboardReadRequest(
            lastChangeCount: lastChangeCount,
            retriesUnchangedPasteboard: deferredReadAttemptsRemaining > 0,
            ignoresTransientContent: preferences.ignoreTransientContent,
            ignoresConcealedContent: preferences.ignoreConcealedContent,
            ignoredApplicationEntries: ignoredApplicationEntries,
            imagesDirectory: supportDirectory.appendingPathComponent("Images", isDirectory: true),
            findStoredImage: findStoredImage
        )
        let generation = readGeneration
        let readQueue = readQueue
        Task { [weak self] in
            let result = await withCheckedContinuation { continuation in
                readQueue.async {
                    continuation.resume(returning: PasteboardReader.read(request))
                }
            }
            self?.finishRead(result, generation: generation)
        }
    }

    private func finishRead(_ result: PasteboardReadResult, generation: Int) {
        isReadInFlight = false
        guard generation == readGeneration else {
            discard(result)
            return
        }

        let item = capturedItem(from: result)
        if preferences.copyAndMergeEnabled {
            do {
                try handleCopyAndMerge(item)
            } catch {
                clearPendingCopyAndMergeItem()
                NSLog("ClipBook history write failed: \(error.localizedDescription)")
            }
        } else if let item {
            do {
                try capture(item)
            } catch {
                NSLog("ClipBook history write failed: \(error.localizedDescription)")
            }
        }
    }

    /// The file the reader stored for an image goes with a result nobody takes.
    /// The file of an image already in the history stays with its item.
    private func discard(_ result: PasteboardReadResult) {
        if case .content(let content) = result.outcome,
           case .image(_, let assetPath, _, _, _, false) = content.payload {
            try? fileManager.removeItem(atPath: assetPath)
        }
    }

    private func capturedItem(from result: PasteboardReadResult) -> ClipboardItem? {
        if case .unchanged = result.outcome {
            return nil
        }

        let isNewChange = result.changeCount != lastChangeCount
        if isNewChange {
            lastChangeCount = result.changeCount
            deferredReadAttemptsRemaining = 0
        }

        switch result.outcome {
        case .unchanged:
            return nil
        case .skipped:
            deferredReadAttemptsRemaining = 0
            return nil
        case .empty:
            if isNewChange {
                // The writer may still be filling the pasteboard. Retry on subsequent polls.
                deferredReadAttemptsRemaining = maxDeferredReadAttempts
            } else if deferredReadAttemptsRemaining > 0 {
                deferredReadAttemptsRemaining -= 1
            }
            return nil
        case .content(let content):
            deferredReadAttemptsRemaining = 0
            var ownsAssetFile = true
            var textRecognitionImage: URL?
            switch content.payload {
            case .image(_, let assetPath, _, _, _, let reusesStoredFile):
                // An image already in the history comes with the text read from it.
                ownsAssetFile = !reusesStoredFile
                textRecognitionImage = reusesStoredFile ? nil : URL(fileURLWithPath: assetPath)
            case .files(let paths, _, _):
                if let path = paths.first, ClipboardItem.isImageFile(at: path) {
                    textRecognitionImage = URL(fileURLWithPath: path)
                }
            case .richText, .text:
                break
            }
            guard let item = capturableItem(makeItem(from: content), ownsAssetFile: ownsAssetFile) else {
                return nil
            }

            textRecognitionImagesByItemID[item.id] = textRecognitionImage
            return item
        }
    }

    private func makeItem(from content: PasteboardContent) -> ClipboardItem {
        switch content.payload {
        case .files(let paths, let byteSize, let recognizedContent):
            return ClipboardItem(
                kind: .file,
                text: recognizedContent.text,
                qrCodeText: recognizedContent.qrCodeText,
                filePaths: paths,
                sourceAppName: content.sourceAppName,
                sourceBundleIdentifier: content.sourceBundleIdentifier,
                byteSize: byteSize
            )
        case .image(let id, let assetPath, let byteSize, let recognizedContent, let digest, _):
            let searchText = ClipboardItem.makeSearchText(
                title: nil,
                text: recognizedContent.text,
                filePaths: [URL(fileURLWithPath: assetPath).lastPathComponent],
                tagNames: [],
                sourceAppName: content.sourceAppName,
                qrCodeText: recognizedContent.qrCodeText
            )
            return ClipboardItem(
                id: id,
                kind: .image,
                title: nil,
                text: recognizedContent.text,
                qrCodeText: recognizedContent.qrCodeText,
                assetPath: assetPath,
                imageDigest: digest,
                sourceAppName: content.sourceAppName,
                sourceBundleIdentifier: content.sourceBundleIdentifier,
                byteSize: byteSize,
                searchText: searchText
            )
        case .richText(let plainText, let rtf, let html):
            let classifiedKind = plainText.map {
                ClipboardKind.classifyText($0, treatDigitNumbersAsColor: preferences.treatDigitNumbersAsColor)
            }
            let kind: ClipboardKind
            switch classifiedKind {
            case .some(.text), .none:
                kind = .richText
            case .some(let semanticKind):
                kind = semanticKind
            }
            return ClipboardItem(
                kind: kind,
                text: plainText,
                rtfData: rtf,
                html: html,
                sourceAppName: content.sourceAppName,
                sourceBundleIdentifier: content.sourceBundleIdentifier,
                byteSize: (rtf?.count ?? 0) + (html?.utf8.count ?? 0) + (plainText?.utf8.count ?? 0)
            )
        case .text(let text):
            return ClipboardItem(
                kind: ClipboardKind.classifyText(text, treatDigitNumbersAsColor: preferences.treatDigitNumbersAsColor),
                text: text,
                sourceAppName: content.sourceAppName,
                sourceBundleIdentifier: content.sourceBundleIdentifier,
                byteSize: text.utf8.count
            )
        }
    }

    /// An item of a kind whose "Keep history" period is Never is dropped,
    /// together with any file the reader has already stored for it. So is a
    /// secret when sensitive content is ignored.
    private func capturableItem(_ item: ClipboardItem, ownsAssetFile: Bool) -> ClipboardItem? {
        guard !preferences.capturesHistory(for: item.kind) || isIgnoredSensitiveContent(item) else {
            return item
        }

        if ownsAssetFile, let assetPath = item.assetPath {
            try? fileManager.removeItem(atPath: assetPath)
        }
        return nil
    }

    /// A copy of an item the user said is not sensitive still goes to the
    /// history, whatever its content looks like.
    private func isIgnoredSensitiveContent(_ item: ClipboardItem) -> Bool {
        guard preferences.ignoreSensitiveContent, SensitiveContent.containsSensitiveContent(item) else {
            return false
        }

        let storedItem = try? historyStore.fetchItem(kind: item.kind, contentKey: item.contentKey)
        return storedItem?.sensitivity != .notSensitive
    }

    private func handleCopyAndMerge(_ item: ClipboardItem?) throws {
        guard let item else {
            try flushPendingCopyAndMergeItemIfExpired()
            return
        }

        if let pendingItem = pendingCopyAndMergeItem {
            clearPendingCopyAndMergeItem()
            if isDuplicateCopyAndMergeItem(item, of: pendingItem) {
                try mergeCopiedItem(item)
            } else {
                try capture(pendingItem)
                holdPendingCopyAndMergeItem(item)
            }
        } else {
            holdPendingCopyAndMergeItem(item)
        }
    }

    private func flushPendingCopyAndMergeItemIfExpired() throws {
        guard let pendingItem = pendingCopyAndMergeItem,
              Date() >= pendingCopyAndMergeDeadline else {
            return
        }

        clearPendingCopyAndMergeItem()
        try capture(pendingItem)
    }

    private func flushPendingCopyAndMergeItemIfExpiredLoggingFailure() {
        do {
            try flushPendingCopyAndMergeItemIfExpired()
        } catch {
            clearPendingCopyAndMergeItem()
            NSLog("ClipBook history write failed: \(error.localizedDescription)")
        }
    }

    private func holdPendingCopyAndMergeItem(_ item: ClipboardItem) {
        pendingCopyAndMergeItem = item
        pendingCopyAndMergeDeadline = Date().addingTimeInterval(copyAndMergeHoldInterval)
    }

    private func clearPendingCopyAndMergeItem() {
        pendingCopyAndMergeItem = nil
        pendingCopyAndMergeDeadline = .distantPast
    }

    private func mergeCopiedItem(_ item: ClipboardItem) throws {
        guard let targetItem = try copyAndMergeTargetItem(),
              let mergedItem = try copyAndMergedItem(sourceItem: item, targetItem: targetItem) else {
            try capture(item)
            return
        }

        try saveMergedItem(mergedItem)
    }

    private func isDuplicateCopyAndMergeItem(_ item: ClipboardItem, of pendingItem: ClipboardItem) -> Bool {
        item.hasSameContent(as: pendingItem)
    }

    @discardableResult
    private func capture(_ item: ClipboardItem) throws -> ClipboardItem {
        var item = item
        let updatesCopySequence = preferences.copySequenceModeEnabled
        var updatedItems: [ClipboardItem] = []
        if updatesCopySequence {
            let sequenceTrackingResult = try itemWithTrackedCopySequence(item)
            item = sequenceTrackingResult.item
            updatedItems = sequenceTrackingResult.updatedItems
        }

        let textRecognitionImage = textRecognitionImagesByItemID.removeValue(forKey: item.id)
        if textRecognitionImage != nil, item.kind == .file,
           let storedItem = try historyStore.fetchItem(kind: .file, contentKey: item.contentKey) {
            // Copying a file again keeps the text read from it before until the
            // file is read again.
            item.text = storedItem.text
            item.qrCodeText = storedItem.qrCodeText
        }

        let capturedItem = try historyStore.capture(item, updatesCopySequence: updatesCopySequence)
        notifyCapture(capturedItem, updatedItems: updatedItems)
        if let textRecognitionImage {
            recognizeText(ofImageAt: textRecognitionImage, inItemWithID: capturedItem.id)
        }
        return capturedItem
    }

    private func recognizeText(ofImageAt url: URL, inItemWithID itemID: ClipboardItem.ID) {
        textRecognitionQueue.async { [weak self] in
            let content = ImageTextRecognizer.recognizeContent(ofImageAt: url)
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                delegate?.pasteboardMonitor(self, didRecognize: content, inItemWithID: itemID)
            }
        }
    }

    private func saveMergedItem(_ mergedItem: ClipboardItem) throws {
        try historyStore.upsert(mergedItem)
        if preferences.copyToClipboardAfterMerge,
           let text = mergedItem.text {
            copyMergedTextToClipboard(text)
            lastChangeCount = pasteboard.changeCount
        }
        notifyCapture(mergedItem, updatedItems: [])
    }

    private func notifyCapture(_ item: ClipboardItem, updatedItems: [ClipboardItem]) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            delegate?.pasteboardMonitor(self, didCapture: item, updatedItems: updatedItems)
        }
    }

    private func copyAndMergeTargetItem() throws -> ClipboardItem? {
        try historyStore.fetchMostRecentItem { !$0.isFavorite }
    }

    private func copyAndMergedItem(sourceItem: ClipboardItem, targetItem: ClipboardItem) throws -> ClipboardItem? {
        var targetItem = targetItem
        guard let targetText = copyAndMergeText(for: targetItem),
              let copiedText = copyAndMergeText(for: sourceItem) else {
            return nil
        }

        let mergedText = targetText + copyAndMergeSeparator() + copiedText
        let tagNamesByID = Dictionary(uniqueKeysWithValues: try historyStore.fetchTags().map { ($0.id, $0.name) })
        targetItem.text = mergedText
        targetItem.removeFormatting()
        targetItem.assetPath = nil
        targetItem.filePaths = []
        targetItem.kind = ClipboardKind.classifyText(
            mergedText,
            treatDigitNumbersAsColor: preferences.treatDigitNumbersAsColor
        )
        targetItem.copiedAt = sourceItem.copiedAt
        targetItem.byteSize = mergedText.utf8.count
        targetItem.copyCount += 1
        targetItem.linkPreviewDetails = nil
        targetItem = targetItem.rebuildingSearchText(tagNames: targetItem.tags.compactMap { tagNamesByID[$0] })
        return targetItem
    }

    private func copyAndMergeText(for item: ClipboardItem) -> String? {
        switch item.kind {
        case .text, .richText, .link, .email, .color:
            return item.text
        case .image, .file:
            return nil
        }
    }

    private func copyAndMergeSeparator() -> String {
        switch CopyAndMergeSeparatorPreference(preferenceValue: preferences.copyAndMergeSeparator) {
        case .newLine:
            return "\n"
        case .space:
            return " "
        case .comma:
            return ", "
        case .empty:
            return ""
        }
    }

    private func copyMergedTextToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString("1", forType: Self.ghostType)
        pasteboard.setString(text, forType: .string)
    }

    private func itemWithTrackedCopySequence(_ item: ClipboardItem) throws -> (item: ClipboardItem, updatedItems: [ClipboardItem]) {
        var trackedItem = item
        guard let mostRecentClip = try mostRecentClipForSequenceTracking(item: item) else {
            return (trackedItem, [])
        }
        var updatedItems: [ClipboardItem] = []

        let timeDiff = item.copiedAt.timeIntervalSince(mostRecentClip.copiedAt)
        let pasteHappenedAfterLastCopy = lastCopySequencePasteTime > mostRecentClip.copiedAt

        if pasteHappenedAfterLastCopy {
            trackedItem.copySequenceID = nil
            trackedItem.copySequenceOrder = nil
        } else if timeDiff < copySequenceThreshold, let sequenceID = mostRecentClip.copySequenceID {
            trackedItem.copySequenceID = sequenceID
            trackedItem.copySequenceOrder = (mostRecentClip.copySequenceOrder ?? 0) + 1
        } else if timeDiff < copySequenceThreshold {
            // The store keeps the ID to the whole second. An ID with a fraction
            // would no longer equal itself once an item is read back, and the
            // items still in memory would fall out of the sequence of those
            // that were, which changes the order they are pasted in.
            let sequenceID = Date(timeIntervalSince1970: mostRecentClip.copiedAt.timeIntervalSince1970.rounded(.down))
            var updatedMostRecentClip = mostRecentClip
            updatedMostRecentClip.copySequenceID = sequenceID
            updatedMostRecentClip.copySequenceOrder = 0
            try historyStore.upsert(updatedMostRecentClip)
            updatedItems.append(updatedMostRecentClip)

            trackedItem.copySequenceID = sequenceID
            trackedItem.copySequenceOrder = 1
        } else {
            trackedItem.copySequenceID = nil
            trackedItem.copySequenceOrder = nil
        }

        return (trackedItem, updatedItems)
    }

    /// The clip copied right before `item`. A copy of content that is already
    /// in the history updates the item it has there, so that item is not the
    /// one before it.
    private func mostRecentClipForSequenceTracking(item: ClipboardItem) throws -> ClipboardItem? {
        try historyStore.fetchMostRecentItem { clip in
            !clip.hasSameContent(as: item)
        }
    }
}
