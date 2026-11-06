@testable import ClipBook
import AppKit
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// Container suite for tests that mutate process-global state such as the `L10n` language.
/// Suites nested in `SharedProcessStateTests` run one after the other, but other suites still
/// run beside them, so a test that reads localized text compares it with text produced in the
/// same language instead of with fixed English strings.
@Suite(.serialized)
enum SharedProcessStateTests {}

final class TestNoOpUpdateService: UpdateService {
    var isRelaunchingToInstallUpdate: Bool = false
    private(set) var automaticChecksEnabledValues: [Bool] = []

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticChecksEnabledValues.append(enabled)
    }

    func checkForUpdates(presenting window: NSWindow?) {}
}

struct RenderedViewSnapshot {
    let image: NSImage
    let bitmap: NSBitmapImageRep
    let pngData: Data

    var pixelWidth: Int { bitmap.pixelsWide }
    var pixelHeight: Int { bitmap.pixelsHigh }
}

@MainActor
final class TestCoordinatorHarness {
    let coordinator: AppCoordinator
    let model: AppModel
    let historyStore: SQLiteHistoryStore
    let preferencesStore: PreferencesStore
    let clipboardMonitor: PasteboardMonitor
    let globalShortcuts: GlobalShortcutService
    let updateService: TestNoOpUpdateService
    let pasteboard: NSPasteboard
    let userDefaultsSuiteName: String
    let supportDirectory: URL

    private var isCleanedUp = false

    init(
        coordinator: AppCoordinator,
        model: AppModel,
        historyStore: SQLiteHistoryStore,
        preferencesStore: PreferencesStore,
        clipboardMonitor: PasteboardMonitor,
        globalShortcuts: GlobalShortcutService,
        updateService: TestNoOpUpdateService,
        pasteboard: NSPasteboard,
        userDefaultsSuiteName: String,
        supportDirectory: URL
    ) {
        self.coordinator = coordinator
        self.model = model
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.clipboardMonitor = clipboardMonitor
        self.globalShortcuts = globalShortcuts
        self.updateService = updateService
        self.pasteboard = pasteboard
        self.userDefaultsSuiteName = userDefaultsSuiteName
        self.supportDirectory = supportDirectory
    }

    /// Stores `items` and loads them into the model, as if they had been captured earlier.
    func seedHistory(_ items: [ClipboardItem]) throws {
        for item in items {
            try historyStore.upsert(item)
        }
        coordinator.loadHistory()
    }

    /// The item with `id` as the model currently shows it.
    func currentItem(_ id: ClipboardItem.ID) -> ClipboardItem? {
        model.items.first { $0.id == id }
    }

    func trashedIDs() throws -> [ClipboardItem.ID] {
        try historyStore.fetchTrashedItems().map(\.id)
    }

    func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        clipboardMonitor.stop()
        globalShortcuts.unregisterAll()
        pasteboard.releaseGlobally()
        TestSupport.removeDefaultsSuite(named: userDefaultsSuiteName)
        try? FileManager.default.removeItem(at: supportDirectory)
    }

    deinit {
        let suiteName = userDefaultsSuiteName
        let supportDir = supportDirectory
        if !isCleanedUp {
            TestSupport.removeDefaultsSuite(named: suiteName)
            try? FileManager.default.removeItem(at: supportDir)
        }
    }
}

enum TestSupport {
    static let snapshotScale = 2

    @MainActor
    static func ensureAppKitInitialized() {
        _ = NSApplication.shared
    }

    /// Waits, letting the main actor run, until `condition` holds. Returns whether it did within `timeout`.
    @MainActor
    static func waitUntil(timeout: Duration = .seconds(45), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                return false
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    static func keyDownEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        windowNumber: Int = 0
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: keyCode
            )
        )
    }

    /// An empty 8-bit RGBA bitmap of the given pixel size.
    static func makeBitmap(pixelsWide: Int, pixelsHigh: Int) throws -> NSBitmapImageRep {
        try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
    }

    static func makePNGData(
        pixelWidth: Int = 32,
        pixelHeight: Int = 24,
        dpi: Double = 72.0,
        color: NSColor = .systemBlue
    ) throws -> Data {
        let rep = try makeBitmap(pixelsWide: pixelWidth, pixelsHigh: pixelHeight)
        rep.size = NSSize(
            width: Double(pixelWidth) * 72.0 / dpi,
            height: Double(pixelHeight) * 72.0 / dpi
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(origin: .zero, size: rep.size).fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else {
            throw CocoaError(.coderInvalidValue)
        }
        let output = NSMutableData()
        let dest = try #require(
            CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        )
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi
        ]
        CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        return output as Data
    }

    static func makePDFData(width: CGFloat = 64, height: CGFloat = 48) -> Data {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
        if let consumer = CGDataConsumer(data: pdfData as CFMutableData),
           let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.systemRed.cgColor)
            context.fill(mediaBox)
            context.endPDFPage()
            context.closePDF()
        }
        return pdfData as Data
    }

    static func makeRTFData(text: String) throws -> Data {
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        return try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // The helpers that tests with `await` in them use have a synchronous and an `async` form,
    // because a closure cannot be both. The setup and the cleanup are shared.

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipBookTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }

    static func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    static func withTemporaryHistoryStore<T>(_ body: (SQLiteHistoryStore, URL) throws -> T) throws -> T {
        try withTemporaryDirectory { directory in
            try body(SQLiteHistoryStore(directory: directory), directory)
        }
    }

    static func withUniquePasteboard<T>(_ body: (NSPasteboard) throws -> T) rethrows -> T {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        return try body(pasteboard)
    }

    static func withUniquePasteboard<T>(_ body: (NSPasteboard) async throws -> T) async rethrows -> T {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        return try await body(pasteboard)
    }

    /// Removes the preferences of a test suite, and the empty property list that removing the domain leaves behind.
    static func removeDefaultsSuite(named suiteName: String) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let propertyList = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: propertyList)
    }

    static func withIsolatedUserDefaults<T>(_ body: (UserDefaults) throws -> T) throws -> T {
        let suiteName = "com.ikryanov.clipbook.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { removeDefaultsSuite(named: suiteName) }
        return try body(defaults)
    }

    @MainActor
    static func makeTestCoordinator() throws -> TestCoordinatorHarness {
        ensureAppKitInitialized()
        let fileManager = FileManager.default
        let supportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("ClipBookCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        let suiteName = "com.ikryanov.clipbook.coordinator.tests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let pasteboard = NSPasteboard.withUniqueName()
        let historyStore = SQLiteHistoryStore(directory: supportDirectory)
        let preferencesStore = PreferencesStore(userDefaults: userDefaults)

        var initialPreferences = AppPreferences()
        initialPreferences.warnOnClearHistory = false
        // The coordinator's sound service is not injectable, so tests that
        // delete, paste or merge would otherwise play real audio.
        initialPreferences.soundEffectsEnabled = false
        // Saving applies launch at login for real. Turned off, a save can only
        // unregister the Debug build, which is never registered, rather than add
        // it as a login item.
        initialPreferences.launchAtLogin = false
        preferencesStore.save(initialPreferences)

        let model = AppModel()
        model.preferences = initialPreferences

        let globalShortcuts = GlobalShortcutService(isEnabled: false)
        let updateService = TestNoOpUpdateService()
        let licensingService = LicensingService()
        let clipboardMonitor = PasteboardMonitor(
            historyStore: historyStore,
            fileManager: fileManager,
            supportDirectory: supportDirectory,
            pasteboard: pasteboard
        )

        let pasteService = PasteService(
            pasteboard: pasteboard,
            loadFormatting: { [historyStore] item in
                (try? historyStore.loadingFormatting(of: item)) ?? item
            }
        )
        let coordinator = AppCoordinator(
            model: model,
            preferencesStore: preferencesStore,
            historyStore: historyStore,
            clipboardMonitor: clipboardMonitor,
            pasteService: pasteService,
            globalShortcuts: globalShortcuts,
            updateService: updateService,
            licensingService: licensingService,
            fileManager: fileManager,
            supportDirectory: supportDirectory
        )

        return TestCoordinatorHarness(
            coordinator: coordinator,
            model: model,
            historyStore: historyStore,
            preferencesStore: preferencesStore,
            clipboardMonitor: clipboardMonitor,
            globalShortcuts: globalShortcuts,
            updateService: updateService,
            pasteboard: pasteboard,
            userDefaultsSuiteName: suiteName,
            supportDirectory: supportDirectory
        )
    }

    @MainActor
    @discardableResult
    static func renderOffscreenView(
        _ view: NSView,
        size: NSSize = NSSize(width: 480, height: 120),
        appearance: NSAppearance.Name = .aqua
    ) throws -> RenderedViewSnapshot {
        ensureAppKitInitialized()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.appearance = NSAppearance(named: appearance)
        view.frame = container.bounds
        view.appearance = NSAppearance(named: appearance)
        container.addSubview(view)
        window.contentView = container

        container.layoutSubtreeIfNeeded()
        view.layoutSubtreeIfNeeded()
        container.displayIfNeeded()

        // Render at a fixed 2x so that snapshots do not depend on the display this runs on.
        let bounds = container.bounds
        let bitmap = try makeBitmap(
            pixelsWide: Int(bounds.width) * snapshotScale,
            pixelsHigh: Int(bounds.height) * snapshotScale
        )
        bitmap.size = bounds.size
        container.cacheDisplay(in: bounds, to: bitmap)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        let pngData = try #require(bitmap.representation(using: .png, properties: [:]))

        window.orderOut(nil)
        return RenderedViewSnapshot(image: image, bitmap: bitmap, pngData: pngData)
    }

    @MainActor
    @discardableResult
    static func renderOffscreenSwiftUIView<Content: View>(
        _ rootView: Content,
        size: NSSize = NSSize(width: 640, height: 480),
        appearance: NSAppearance.Name = .aqua
    ) throws -> RenderedViewSnapshot {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        return try renderOffscreenView(
            hostingView,
            size: size,
            appearance: appearance
        )
    }
}

extension HistoryItemRowView {
    /// Configures the row the way a 480-point-wide history table does when sensitive
    /// content is detected and kept hidden.
    func configureForTest(
        item: ClipboardItem,
        quickPasteIndex: Int = 1,
        searchQuery: String = "",
        itemTags: [ClipBook.Tag] = [],
        linkPreview: LinkPreview? = nil,
        showsLinkPreview: Bool = false
    ) {
        configure(
            item: item,
            quickPasteIndex: quickPasteIndex,
            tableWidth: 480,
            searchQuery: searchQuery,
            itemTags: itemTags,
            linkPreview: linkPreview,
            showsLinkPreview: showsLinkPreview,
            detectsSensitiveContent: true,
            revealsSensitiveContent: false
        )
    }
}

extension ClipboardItem {
    static func fixture(
        id: UUID = UUID(),
        kind: ClipboardKind = .text,
        title: String? = nil,
        text: String? = "Sample clipboard text",
        qrCodeText: String? = nil,
        rtfData: Data? = nil,
        html: String? = nil,
        assetPath: String? = nil,
        imageDigest: String? = nil,
        filePaths: [String] = [],
        sourceAppName: String? = "TestApp",
        sourceBundleIdentifier: String? = "com.example.test",
        copiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        firstCopiedAt: Date? = nil,
        byteSize: Int? = nil,
        isFavorite: Bool = false,
        tags: [Int] = [],
        searchText: String? = nil,
        copyCount: Int = 1,
        linkPreviewDetails: LinkPreviewDetails? = nil,
        copySequenceID: Date? = nil,
        copySequenceOrder: Int? = nil,
        favoriteOrder: Int? = nil,
        sensitivity: ItemSensitivity? = nil,
        deletedAt: Date? = nil
    ) -> ClipboardItem {
        let computedByteSize = byteSize ?? (text?.utf8.count ?? 0)
        var item = ClipboardItem(
            id: id,
            kind: kind,
            title: title,
            text: text,
            qrCodeText: qrCodeText,
            rtfData: rtfData,
            html: html,
            assetPath: assetPath,
            imageDigest: imageDigest,
            filePaths: filePaths,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier: sourceBundleIdentifier,
            copiedAt: copiedAt,
            firstCopiedAt: firstCopiedAt,
            byteSize: computedByteSize,
            isFavorite: isFavorite,
            tags: tags,
            searchText: searchText,
            copyCount: copyCount,
            linkPreviewDetails: linkPreviewDetails,
            copySequenceID: copySequenceID,
            copySequenceOrder: copySequenceOrder,
            favoriteOrder: favoriteOrder,
            sensitivity: sensitivity
        )
        item.deletedAt = deletedAt
        return item
    }
}

/// The helpers every other suite builds on.
@Suite
struct TestSupportTests {
    @Test
    func temporaryHistoryStoreIsIsolatedAndRemoved() throws {
        var removedDirectory: URL?
        try TestSupport.withTemporaryHistoryStore { store, directory in
            removedDirectory = directory
            let fixture = ClipboardItem.fixture(
                kind: .text,
                text: "Hello",
                sourceAppName: "TestApp",
                sourceBundleIdentifier: "com.example.test"
            )
            let captured = try store.capture(fixture, updatesCopySequence: false)
            #expect(captured.text == "Hello")
            #expect(captured.sourceAppName == "TestApp")
            #expect(captured.sourceBundleIdentifier == "com.example.test")
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("History.sqlite").path))
            #expect(try store.fetchAll().map(\.id) == [captured.id])
        }
        #expect(!FileManager.default.fileExists(atPath: try #require(removedDirectory).path))
    }

    @Test
    func uniquePasteboardIsNotTheGeneralPasteboard() {
        TestSupport.withUniquePasteboard { pasteboard in
            pasteboard.clearContents()
            #expect(pasteboard.setString("Hello", forType: .string))
            #expect(pasteboard.string(forType: .string) == "Hello")
            #expect(pasteboard.name != NSPasteboard.general.name)
        }
    }

    @Test
    func isolatedUserDefaultsKeepPreferencesApart() throws {
        try TestSupport.withIsolatedUserDefaults { defaults in
            let store = PreferencesStore(userDefaults: defaults)
            var preferences = store.load()
            preferences.historySortOption = HistorySortOption.size.rawValue
            store.save(preferences)
            #expect(store.load().historySortOption == HistorySortOption.size.rawValue)
        }
        try TestSupport.withIsolatedUserDefaults { defaults in
            #expect(PreferencesStore(userDefaults: defaults).load().historySortOption != HistorySortOption.size.rawValue)
        }
    }

    @Test
    @MainActor
    func coordinatorHarnessStartsQuietAndCleansUp() throws {
        let harness = try TestSupport.makeTestCoordinator()
        defer { harness.cleanup() }
        #expect(!harness.model.preferences.warnOnClearHistory)
        #expect(!harness.model.preferences.soundEffectsEnabled)

        harness.cleanup()
        #expect(!FileManager.default.fileExists(atPath: harness.supportDirectory.path))
    }

    @Test
    @MainActor
    func offscreenRenderingUsesAFixedScale() throws {
        let snapshot = try TestSupport.renderOffscreenView(
            NSTextField(labelWithString: "Hello"),
            size: NSSize(width: 240, height: 48),
            appearance: .aqua
        )
        #expect(snapshot.pixelWidth == 240 * TestSupport.snapshotScale)
        #expect(snapshot.pixelHeight == 48 * TestSupport.snapshotScale)
        #expect(!snapshot.pngData.isEmpty)
    }
}

