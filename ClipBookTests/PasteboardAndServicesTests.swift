@testable import ClipBook
import AppKit
import Foundation
import Testing

@Suite
enum PasteboardAndServicesTests {
    /// Reads `pasteboard` the way the monitor does on a poll.
    private static func readOutcome(
        from pasteboard: NSPasteboard,
        imagesDirectory: URL,
        lastChangeCount: Int = -1,
        retriesUnchangedPasteboard: Bool = false,
        ignoresTransientContent: Bool = true,
        ignoresConcealedContent: Bool = true,
        ignoredApplicationEntries: [String] = [],
        frontmostApplication: FrontmostApplication? = nil,
        findStoredImage: @escaping @Sendable (String) -> StoredImage? = { _ in nil }
    ) -> PasteboardReadResult.Outcome {
        let request = PasteboardReadRequest(
            lastChangeCount: lastChangeCount,
            retriesUnchangedPasteboard: retriesUnchangedPasteboard,
            ignoresTransientContent: ignoresTransientContent,
            ignoresConcealedContent: ignoresConcealedContent,
            ignoredApplicationEntries: ignoredApplicationEntries,
            imagesDirectory: imagesDirectory,
            findStoredImage: findStoredImage,
            frontmostApplication: { frontmostApplication }
        )
        return PasteboardReader.read(request, from: pasteboard).outcome
    }

    /// Reads a fresh pasteboard that `fill` has written to.
    private static func readOutcome(
        ignoresTransientContent: Bool = true,
        ignoresConcealedContent: Bool = true,
        filling fill: (NSPasteboard) throws -> Void
    ) throws -> PasteboardReadResult.Outcome {
        try TestSupport.withTemporaryDirectory { directory in
            try TestSupport.withUniquePasteboard { pasteboard in
                pasteboard.clearContents()
                try fill(pasteboard)
                return readOutcome(
                    from: pasteboard,
                    imagesDirectory: directory,
                    ignoresTransientContent: ignoresTransientContent,
                    ignoresConcealedContent: ignoresConcealedContent
                )
            }
        }
    }

    @Suite
    struct PasteboardReaderTests {
        @Test
        func readsPlainText() throws {
            let outcome = try PasteboardAndServicesTests.readOutcome { pasteboard in
                pasteboard.setString("Hello plain world", forType: .string)
            }
            #expect(outcome.payload?.text == "Hello plain world")
        }

        @Test
        func readsRichTextWithItsAlternateFormats() throws {
            let rtfData = try TestSupport.makeRTFData(text: "Formatted Greeting")
            let outcome = try PasteboardAndServicesTests.readOutcome { pasteboard in
                pasteboard.setData(rtfData, forType: .rtf)
                pasteboard.setString("<b>Formatted Greeting</b>", forType: .html)
                pasteboard.setString("Formatted Greeting", forType: .string)
            }
            let richText = try #require(outcome.payload?.richText)
            #expect(richText.plainText == "Formatted Greeting")
            #expect(richText.rtf == rtfData)
            #expect(richText.html == "<b>Formatted Greeting</b>")
        }

        @Test
        func anUnchangedPasteboardIsReadOnlyWhenARetryIsAsked() throws {
            try TestSupport.withTemporaryDirectory { directory in
                try TestSupport.withUniquePasteboard { pasteboard in
                    pasteboard.clearContents()
                    pasteboard.setString("Copied text", forType: .string)
                    let changeCount = pasteboard.changeCount

                    let unchanged = PasteboardAndServicesTests.readOutcome(
                        from: pasteboard,
                        imagesDirectory: directory,
                        lastChangeCount: changeCount
                    )
                    #expect(unchanged.isUnchanged, "\(unchanged)")

                    let retried = PasteboardAndServicesTests.readOutcome(
                        from: pasteboard,
                        imagesDirectory: directory,
                        lastChangeCount: changeCount,
                        retriesUnchangedPasteboard: true
                    )
                    #expect(retried.payload?.text == "Copied text")
                }
            }
        }

        @Test
        func richTextThatAccompaniesABitmapIsNotReadAsAnImage() throws {
            let pngData = try TestSupport.makePNGData(pixelWidth: 20, pixelHeight: 16)
            let rtfSample = Data("{\\rtf1\\ansi\\deff0 Keynote Selection}".utf8)
            let outcome = try PasteboardAndServicesTests.readOutcome { pasteboard in
                pasteboard.setData(pngData, forType: .png)
                pasteboard.setData(rtfSample, forType: .rtf)
                pasteboard.setString("Keynote Selection", forType: .string)
            }
            let richText = try #require(outcome.payload?.richText)
            #expect(richText.plainText == "Keynote Selection")
            #expect(richText.rtf == rtfSample)
        }

        @Test
        func aStandaloneImageIsStoredAndThenReusedByDigest() throws {
            let pngData = try TestSupport.makePNGData(pixelWidth: 20, pixelHeight: 16)
            try TestSupport.withTemporaryDirectory { directory in
                try TestSupport.withUniquePasteboard { pasteboard in
                    pasteboard.clearContents()
                    pasteboard.setData(pngData, forType: .png)

                    let first = PasteboardAndServicesTests.readOutcome(from: pasteboard, imagesDirectory: directory)
                    let firstImage = try #require(first.payload?.image)
                    #expect(!firstImage.reusesStoredFile)

                    let second = PasteboardAndServicesTests.readOutcome(
                        from: pasteboard,
                        imagesDirectory: directory,
                        findStoredImage: { digest in
                            guard digest == firstImage.digest else { return nil }
                            return StoredImage(
                                assetPath: firstImage.assetPath,
                                recognizedContent: RecognizedImageContent(text: "OCR Text", qrCodeText: "https://qr.example")
                            )
                        }
                    )
                    let reused = try #require(second.payload?.image)
                    #expect(reused.reusesStoredFile)
                    #expect(reused.assetPath == firstImage.assetPath)
                    #expect(reused.recognizedContent.text == "OCR Text")
                    #expect(reused.recognizedContent.qrCodeText == "https://qr.example")
                }
            }
        }

        @Test
        func readsCopiedFiles() throws {
            try TestSupport.withTemporaryDirectory { directory in
                let fileURL = directory.appendingPathComponent("note.txt")
                let fileData = Data("File payload content".utf8)
                try fileData.write(to: fileURL)

                let outcome = try PasteboardAndServicesTests.readOutcome { pasteboard in
                    #expect(pasteboard.writeObjects([fileURL as NSURL]))
                }
                let files = try #require(outcome.payload?.files)
                #expect(files.paths == [fileURL.path])
                #expect(files.byteSize == fileData.count)
            }
        }

        @Test
        func skipsContentClipBookWroteItself() throws {
            let outcome = try PasteboardAndServicesTests.readOutcome { pasteboard in
                pasteboard.setString("Internal ClipBook write", forType: .string)
                pasteboard.setString("1", forType: PasteboardReader.ghostType)
            }
            #expect(outcome.isSkipped, "\(outcome)")
        }

        private static let safari = FrontmostApplication(
            bundlePath: "/Applications/Safari.app",
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari"
        )

        private static func readText(
            from application: FrontmostApplication?,
            ignoring entries: [String] = []
        ) throws -> PasteboardReadResult.Outcome {
            try TestSupport.withTemporaryDirectory { directory in
                try TestSupport.withUniquePasteboard { pasteboard in
                    pasteboard.clearContents()
                    pasteboard.setString("Copied text", forType: .string)
                    return PasteboardAndServicesTests.readOutcome(
                        from: pasteboard,
                        imagesDirectory: directory,
                        ignoredApplicationEntries: entries,
                        frontmostApplication: application
                    )
                }
            }
        }

        @Test
        func recordsTheFrontmostApplicationAsTheSourceOfTheCopy() throws {
            let content = try #require(try Self.readText(from: Self.safari).content)
            #expect(content.sourceAppName == "Safari")
            #expect(content.sourceBundleIdentifier == "com.apple.Safari")

            let anonymous = try #require(try Self.readText(from: nil).content)
            #expect(anonymous.sourceAppName == nil)
            #expect(anonymous.sourceBundleIdentifier == nil)
        }

        @Test(arguments: [
            (entries: ["/Applications/Safari.app"], isIgnored: true),
            (entries: ["Safari"], isIgnored: true),
            (entries: ["1Password", "/Applications/Safari.app"], isIgnored: true),
            (entries: ["/Applications/Notes.app", "Keychain Access"], isIgnored: false),
            (entries: [String](), isIgnored: false)
        ])
        func copiesMadeInAnIgnoredApplicationAreSkipped(entries: [String], isIgnored: Bool) throws {
            let outcome = try Self.readText(from: Self.safari, ignoring: entries)
            if isIgnored {
                #expect(outcome.isSkipped, "\(outcome)")
            } else {
                #expect(outcome.payload?.text == "Copied text")
            }
        }

        private static let transientMarker = "org.nspasteboard.TransientType"
        private static let concealedMarker = "org.nspasteboard.ConcealedType"

        @Test(arguments: [
            (marker: transientMarker, ignoresTransient: true, ignoresConcealed: true, isCaptured: false),
            (marker: transientMarker, ignoresTransient: false, ignoresConcealed: true, isCaptured: true),
            // Allowing one kind of marked content does not allow the other.
            (marker: transientMarker, ignoresTransient: true, ignoresConcealed: false, isCaptured: false),
            (marker: concealedMarker, ignoresTransient: true, ignoresConcealed: true, isCaptured: false),
            (marker: concealedMarker, ignoresTransient: true, ignoresConcealed: false, isCaptured: true),
            (marker: concealedMarker, ignoresTransient: false, ignoresConcealed: true, isCaptured: false)
        ])
        func contentWithAMarkerIsCapturedOnlyWhenItsKindIsAllowed(
            marker: String,
            ignoresTransient: Bool,
            ignoresConcealed: Bool,
            isCaptured: Bool
        ) throws {
            let outcome = try PasteboardAndServicesTests.readOutcome(
                ignoresTransientContent: ignoresTransient,
                ignoresConcealedContent: ignoresConcealed
            ) { pasteboard in
                pasteboard.setString("Marked snippet", forType: .string)
                pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
            }
            if isCaptured {
                #expect(outcome.payload?.text == "Marked snippet")
            } else {
                #expect(outcome.isSkipped, "\(outcome)")
            }
        }
    }

    @Suite
    struct PasteServiceTests {
        @Test
        func copyingFilesWritesTheirURLs() throws {
            try TestSupport.withTemporaryDirectory { directory in
                let fileURL = directory.appendingPathComponent("report.pdf")
                try TestSupport.makePDFData().write(to: fileURL)

                try TestSupport.withUniquePasteboard { pasteboard in
                    let service = PasteService(pasteboard: pasteboard, loadFormatting: { $0 })
                    try service.copy(ClipboardItem.fixture(kind: .file, text: nil, filePaths: [fileURL.path]), variant: .standard)

                    let urls = pasteboard.readObjects(
                        forClasses: [NSURL.self],
                        options: [.urlReadingFileURLsOnly: true]
                    ) as? [URL]
                    #expect(urls?.map(\.standardizedFileURL.path) == [fileURL.standardizedFileURL.path])
                }
            }
        }
    }

    /// Applies a capture to a real `AppModel` the way `AppCoordinator` does.
    @MainActor
    private final class MockMonitorDelegate: PasteboardMonitorDelegate {
        let model = AppModel()
        var capturedHistory: [(item: ClipboardItem, updatedItems: [ClipboardItem])] = []
        var recognizedEvents: [(id: ClipboardItem.ID, content: RecognizedImageContent)] = []

        var items: [ClipboardItem] { model.items }

        func pasteboardMonitor(
            _ monitor: PasteboardMonitor,
            didCapture item: ClipboardItem,
            updatedItems: [ClipboardItem]
        ) {
            capturedHistory.append((item: item, updatedItems: updatedItems))
            updatedItems.forEach(model.replace)
            model.insert(item)
        }

        func pasteboardMonitor(
            _ monitor: PasteboardMonitor,
            didRecognize content: RecognizedImageContent,
            inItemWithID itemID: ClipboardItem.ID
        ) {
            recognizedEvents.append((id: itemID, content: content))
        }
    }

    private final class MutableClock: @unchecked Sendable {
        var current: Date
        init(_ initial: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
            self.current = initial
        }
        func advance(by seconds: TimeInterval) {
            current = current.addingTimeInterval(seconds)
        }
    }

    /// A monitor on its own store and pasteboard, a clock the test moves, and a delegate that records captures.
    @MainActor
    private final class MonitorFixture {
        let monitor: PasteboardMonitor
        let delegate = MockMonitorDelegate()
        let clock: MutableClock
        let store: SQLiteHistoryStore
        let pasteboard: NSPasteboard

        init(monitor: PasteboardMonitor, clock: MutableClock, store: SQLiteHistoryStore, pasteboard: NSPasteboard) {
            self.monitor = monitor
            self.clock = clock
            self.store = store
            self.pasteboard = pasteboard
            monitor.delegate = delegate
        }

        /// Hands the monitor what a poll would have read after `changeCount` changed, and waits
        /// until the delegate has heard about any capture it makes.
        func deliver(_ payload: PasteboardContent.Payload, changeCount: Int) async {
            monitor.processReadResultForTesting(
                PasteboardReadResult(
                    changeCount: changeCount,
                    outcome: .content(
                        PasteboardContent(
                            payload: payload,
                            sourceAppName: "Notes",
                            sourceBundleIdentifier: "com.apple.Notes"
                        )
                    )
                )
            )
            await PasteboardMonitor.deliveryOfCaptures()
        }

        func deliverUnchanged(changeCount: Int) async {
            monitor.processReadResultForTesting(PasteboardReadResult(changeCount: changeCount, outcome: .unchanged))
            await PasteboardMonitor.deliveryOfCaptures()
        }
    }

    @MainActor
    private static func withMonitor<T>(
        clockStart: TimeInterval = 1_700_000_000,
        preferences configurePreferences: ((inout AppPreferences) -> Void)? = nil,
        _ body: (MonitorFixture) async throws -> T
    ) async throws -> T {
        try await TestSupport.withTemporaryDirectory { supportDirectory in
            let store = SQLiteHistoryStore(directory: supportDirectory)
            return try await TestSupport.withUniquePasteboard { pasteboard in
                let clock = MutableClock(Date(timeIntervalSince1970: clockStart))
                let monitor = PasteboardMonitor(
                    historyStore: store,
                    fileManager: .default,
                    supportDirectory: supportDirectory,
                    pasteboard: pasteboard,
                    now: { clock.current }
                )
                if let configurePreferences {
                    var preferences = AppPreferences()
                    configurePreferences(&preferences)
                    monitor.updatePreferences(preferences)
                }
                return try await body(MonitorFixture(monitor: monitor, clock: clock, store: store, pasteboard: pasteboard))
            }
        }
    }

    @Suite
    struct PasteboardMonitorTests {
        @Test
        @MainActor
        func contentCopiedWhilePausedIsNotCaptured() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                let (monitor, pasteboard, delegate) = (fixture.monitor, fixture.pasteboard, fixture.delegate)

                pasteboard.clearContents()
                pasteboard.setString("Before pause", forType: .string)
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.map(\.text) == ["Before pause"])

                monitor.isPaused = true
                pasteboard.clearContents()
                pasteboard.setString("Copied while paused", forType: .string)
                #expect(monitor.poll() == nil)

                monitor.isPaused = false
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.map(\.text) == ["Before pause"])

                pasteboard.clearContents()
                pasteboard.setString("After resume", forType: .string)
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.map(\.text) == ["After resume", "Before pause"])
            }
        }

        @Test
        @MainActor
        func pausingDropsDeferredRetryOfEarlierChange() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                let (monitor, pasteboard, delegate) = (fixture.monitor, fixture.pasteboard, fixture.delegate)

                // A change that yields nothing readable arms the deferred retry.
                pasteboard.clearContents()
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.isEmpty)

                monitor.isPaused = true
                pasteboard.setString("Copied while paused", forType: .string)
                monitor.isPaused = false

                // Without the reset the armed retry re-reads the pasteboard here.
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.isEmpty)
            }
        }

        @Test
        @MainActor
        func contentThatArrivesLateIsCapturedByTheDeferredRetry() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                let (monitor, pasteboard, delegate) = (fixture.monitor, fixture.pasteboard, fixture.delegate)

                // A change that yields nothing readable arms the deferred retry.
                pasteboard.clearContents()
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.isEmpty)

                pasteboard.setString("Arrived late", forType: .string)
                await monitor.pollAndWaitForDelivery()
                #expect(delegate.items.map(\.text) == ["Arrived late"])
            }
        }

        @Test
        @MainActor
        func aReadIsCapturedWhenNothingPausesTheMonitorMeanwhile() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                fixture.pasteboard.clearContents()
                fixture.pasteboard.setString("Copied", forType: .string)

                await fixture.monitor.pollAndWaitForDelivery()

                #expect(fixture.delegate.items.map(\.text) == ["Copied"])
            }
        }

        @Test
        @MainActor
        func pausingAbandonsAReadThatIsInFlight() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                fixture.pasteboard.clearContents()
                fixture.pasteboard.setString("Copied just before pausing", forType: .string)

                let read = fixture.monitor.poll()
                fixture.monitor.isPaused = true
                fixture.monitor.isPaused = false
                await read?.value
                await PasteboardMonitor.deliveryOfCaptures()

                #expect(fixture.delegate.items.isEmpty)
            }
        }

        @Test
        @MainActor
        func copyAndMergeStateMachine() async throws {
            try await PasteboardAndServicesTests.withMonitor(preferences: { preferences in
                preferences.copyAndMergeEnabled = true
                preferences.copyAndMergeSeparator = CopyAndMergeSeparatorPreference.space.rawValue
                preferences.copyToClipboardAfterMerge = true
            }) { fixture in
                fixture.clock.advance(by: 1)
                await fixture.deliver(.text("First"), changeCount: 1)
                #expect(fixture.delegate.capturedHistory.isEmpty)

                fixture.clock.advance(by: 0.6)
                await fixture.deliverUnchanged(changeCount: 1)
                #expect(fixture.delegate.capturedHistory.count == 1)
                #expect(fixture.delegate.items.first?.text == "First")

                // Double-copy within 0.5s merges into the previous item.
                fixture.clock.advance(by: 1)
                await fixture.deliver(.text("Second"), changeCount: 2)
                #expect(fixture.delegate.capturedHistory.count == 1)

                fixture.clock.advance(by: 0.1)
                await fixture.deliver(.text("Second"), changeCount: 3)
                #expect(fixture.delegate.capturedHistory.count == 2)
                #expect(fixture.delegate.items.first?.text == "First Second")
                #expect(fixture.pasteboard.string(forType: .string) == "First Second")
                #expect(fixture.pasteboard.string(forType: PasteboardMonitor.ghostType) == "1")
            }
        }

        @Test
        @MainActor
        func copySequenceTracking() async throws {
            try await PasteboardAndServicesTests.withMonitor(
                clockStart: 1_700_000_000.75,
                preferences: { $0.copySequenceModeEnabled = true }
            ) { fixture in
                let delegate = fixture.delegate
                await fixture.deliver(.text("Seq A"), changeCount: 1)
                #expect(delegate.items.count == 1)
                #expect(delegate.items[0].copySequenceID == nil)
                #expect(delegate.items[0].copySequenceOrder == nil)

                fixture.clock.advance(by: 5)
                await fixture.deliver(.text("Seq B"), changeCount: 2)
                let expectedSequenceID = Date(timeIntervalSince1970: 1_700_000_000)
                #expect(delegate.items.count == 2)
                let itemB = try #require(delegate.items.first { $0.text == "Seq B" })
                let itemA = try #require(delegate.items.first { $0.text == "Seq A" })
                #expect(itemA.copySequenceID == expectedSequenceID)
                #expect(itemA.copySequenceOrder == 0)
                #expect(itemB.copySequenceID == expectedSequenceID)
                #expect(itemB.copySequenceOrder == 1)

                fixture.clock.advance(by: 1)
                fixture.monitor.markCopySequencePasteBoundary()
                fixture.clock.advance(by: 1)
                await fixture.deliver(.text("Seq C after paste"), changeCount: 3)
                let itemC = try #require(delegate.items.first { $0.text == "Seq C after paste" })
                #expect(itemC.copySequenceID == nil)
                #expect(itemC.copySequenceOrder == nil)

                fixture.clock.advance(by: 35)
                await fixture.deliver(.text("Seq D after 35s"), changeCount: 4)
                let itemD = try #require(delegate.items.first { $0.text == "Seq D after 35s" })
                #expect(itemD.copySequenceID == nil)
                #expect(itemD.copySequenceOrder == nil)
            }
        }

        @Test
        @MainActor
        func capturedItemsAreStampedWithTheMonitorsClock() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                fixture.clock.advance(by: 5)
                await fixture.deliver(.text("First"), changeCount: 1)
                #expect(fixture.delegate.items.first?.copiedAt == fixture.clock.current)

                let firstStamp = fixture.clock.current
                fixture.clock.advance(by: 90)
                await fixture.deliver(.text("Second"), changeCount: 2)
                let second = try #require(fixture.delegate.items.first)
                #expect(second.copiedAt == fixture.clock.current)
                #expect(second.copiedAt.timeIntervalSince(firstStamp) == 90)
            }
        }

        private static func fileContent(_ paths: [String]) -> PasteboardContent.Payload {
            .files(paths: paths, byteSize: 1, recognizedContent: .empty)
        }

        @Test
        @MainActor
        func copyingAnImageFileAgainKeepsTheTextReadFromItBefore() async throws {
            try await TestSupport.withTemporaryDirectory { directory in
                let imageURL = directory.appendingPathComponent("scan.png")
                try TestSupport.makePNGData().write(to: imageURL)

                try await PasteboardAndServicesTests.withMonitor { fixture in
                    await fixture.deliver(Self.fileContent([imageURL.path]), changeCount: 1)
                    var stored = try #require(fixture.delegate.items.first)
                    _ = await TestSupport.waitUntil { !fixture.delegate.recognizedEvents.isEmpty }

                    // What the coordinator does with the recognized text.
                    stored.text = "Text read from the scan"
                    try fixture.store.upsert(stored)

                    fixture.clock.advance(by: 60)
                    await fixture.deliver(Self.fileContent([imageURL.path]), changeCount: 2)
                    let recopied = try #require(fixture.delegate.items.first)
                    #expect(recopied.id == stored.id)
                    #expect(recopied.text == "Text read from the scan")
                    #expect(recopied.copyCount == stored.copyCount + 1)
                }
            }
        }

        @Test
        @MainActor
        func captureNotifiesDelegateInOrder() async throws {
            try await PasteboardAndServicesTests.withMonitor { fixture in
                for (index, text) in ["First", "Second", "Third"].enumerated() {
                    fixture.clock.advance(by: 1)
                    await fixture.deliver(.text(text), changeCount: index + 1)
                    // The delegate has the item, and the store holds it, once the delivery has run.
                    #expect(fixture.delegate.capturedHistory.count == index + 1)
                    let stored = (try? fixture.store.fetchAll()) ?? []
                    #expect(stored.contains { $0.text == text })
                }
                #expect(fixture.delegate.capturedHistory.map(\.item.text) == ["First", "Second", "Third"])
            }
        }
    }
}

extension PasteboardMonitor {
    /// Returns once the main-actor tasks the monitor has queued so far, which hand captures to
    /// its delegate, have run. The main actor runs its tasks in the order they were queued.
    @MainActor
    static func deliveryOfCaptures() async {
        await Task.yield()
    }

    /// Polls once and waits until the delegate has heard about what the read captured.
    @MainActor
    func pollAndWaitForDelivery() async {
        await poll()?.value
        await Self.deliveryOfCaptures()
    }
}

// Accessors that let a test state what it read in one `#expect` instead of a `guard case` per payload kind.
private extension PasteboardReadResult.Outcome {
    var content: PasteboardContent? {
        guard case .content(let content) = self else { return nil }
        return content
    }

    var payload: PasteboardContent.Payload? { content?.payload }

    var isUnchanged: Bool {
        if case .unchanged = self { true } else { false }
    }

    var isSkipped: Bool {
        if case .skipped = self { true } else { false }
    }

    var isEmpty: Bool {
        if case .empty = self { true } else { false }
    }
}

private extension PasteboardContent.Payload {
    var text: String? {
        if case .text(let text) = self { text } else { nil }
    }

    var richText: (plainText: String?, rtf: Data?, html: String?)? {
        if case .richText(let plainText, let rtf, let html) = self { (plainText, rtf, html) } else { nil }
    }

    var files: (paths: [String], byteSize: Int)? {
        if case .files(let paths, let byteSize, _) = self { (paths, byteSize) } else { nil }
    }

    var image: (assetPath: String, digest: String, reusesStoredFile: Bool, recognizedContent: RecognizedImageContent)? {
        if case .image(_, let assetPath, _, let recognizedContent, let digest, let reusesStoredFile) = self {
            (assetPath, digest, reusesStoredFile, recognizedContent)
        } else {
            nil
        }
    }
}
