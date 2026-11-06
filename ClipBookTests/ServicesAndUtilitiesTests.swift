@testable import ClipBook
import AppKit
import Carbon
import Foundation
import Testing

@Suite
enum ServicesAndUtilitiesTests {
    @Suite
    struct ShortcutsTests {
        @Test
        func parserValidAndInvalidShortcuts() {
            let cmdShiftV = KeyboardShortcutParser.parse("cmd+shift+v")
            let shiftCmdV = KeyboardShortcutParser.parse("SHIFT+COMMAND+V")
            #expect(cmdShiftV != nil)
            #expect(cmdShiftV == shiftCmdV)
            #expect(KeyboardShortcutParser.hasModifiers("cmd+shift+v"))
            #expect(!KeyboardShortcutParser.hasModifiers("return"))

            let ctrlOptDelete = KeyboardShortcutParser.parse("ctrl+alt+delete")
            #expect(ctrlOptDelete != nil)
            #expect(ctrlOptDelete?.modifiers == UInt32(controlKey | optionKey))

            #expect(KeyboardShortcutParser.parse("") == nil)
            #expect(KeyboardShortcutParser.parse("cmd+unknownkey") == nil)
        }

        @Test
        func menuItemKeyEquivalents() throws {
            // The Delete key reports U+007F, which is what a menu item's key equivalent has to be to match it.
            let deleteEquiv = try #require(KeyboardShortcutParser.menuItemKeyEquivalent(for: "cmd+delete"))
            #expect(deleteEquiv.keyEquivalent == "\u{7f}")
            #expect(deleteEquiv.modifierFlags == [.command])

            let forwardDeleteEquiv = try #require(KeyboardShortcutParser.menuItemKeyEquivalent(for: "cmd+forwarddelete"))
            #expect(forwardDeleteEquiv.keyEquivalent == String(Character(UnicodeScalar(NSDeleteFunctionKey)!)))
            #expect(forwardDeleteEquiv.modifierFlags == [.command])

            let keypadPlusEquiv = try #require(KeyboardShortcutParser.menuItemKeyEquivalent(for: "cmd+keypadplus"))
            #expect(keypadPlusEquiv.keyEquivalent == "+")
            #expect(keypadPlusEquiv.modifierFlags.contains(.command))
            #expect(keypadPlusEquiv.modifierFlags.contains(.numericPad))
        }

        @Test
        func shortcutConflictDetection() {
            #expect(ShortcutConflicts.isSameShortcut("cmd+shift+c", "shift+command+c"))
            #expect(!ShortcutConflicts.isSameShortcut("cmd+c", "option+c"))
            #expect(!ShortcutConflicts.isSameShortcut("", "cmd+c"))

            let customAssignments = [
                ShortcutConflicts.Assignment(title: "Copy Item", shortcut: "cmd+c"),
                ShortcutConflicts.Assignment(title: "Delete Item", shortcut: "cmd+delete")
            ]
            #expect(ShortcutConflicts.conflictingActionTitle(for: "command+c", in: customAssignments) == "Copy Item")
            #expect(ShortcutConflicts.conflictingActionTitle(for: "cmd+e", in: customAssignments) == nil)
        }

        @Test
        func disabledGlobalShortcutService() {
            let service = GlobalShortcutService(isEnabled: false)
            #expect(!service.hasHandler(for: .showHistory))

            service.register(.showHistory, shortcut: "shift+cmd+v") {}
            service.register(.pasteNext, shortcut: "control+v") {}
            #expect(service.hasHandler(for: .showHistory))
            #expect(service.hasHandler(for: .pasteNext))
            #expect(!service.hasHandler(for: .pauseCapture))

            // A bare key, or one that does not parse, is never registered.
            service.register(.pauseCapture, shortcut: "return") {}
            service.register(.pasteNextRich, shortcut: "cmd+unknownkey") {}
            #expect(!service.hasHandler(for: .pauseCapture))
            #expect(!service.hasHandler(for: .pasteNextRich))

            service.unregisterAll()
            #expect(!service.hasHandler(for: .showHistory))
            #expect(!service.hasHandler(for: .pasteNext))
        }
    }

    @Suite
    struct PreviewCachesSVGRendererAndLicensingTests {
        @Test(.timeLimit(.minutes(1)))
        func previewCacheReportsTheDisplaySizeOfAnImageFileAndRemovesItsDirectory() async throws {
            try await TestSupport.withTemporaryDirectory { tempDir in
                let cacheDir = tempDir.appendingPathComponent("PreviewCache", isDirectory: true)
                let previewCache = FilePreviewCache(directory: cacheDir)
                let imageURL = tempDir.appendingPathComponent("photo.png")
                try TestSupport.makePNGData(pixelWidth: 288, pixelHeight: 144, dpi: 144.0, color: .systemGreen)
                    .write(to: imageURL)

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    _ = previewCache.image(forFileAt: imageURL.path, targetSize: CGSize(width: 64, height: 64)) { _ in
                        continuation.resume()
                    }
                }

                let displaySize = try #require(previewCache.displaySizeForImageFile(at: imageURL.path))
                #expect(abs(displaySize.width - 144) < 0.5)
                #expect(abs(displaySize.height - 72) < 0.5)

                previewCache.removeAll()
                #expect(!FileManager.default.fileExists(atPath: cacheDir.path))
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func thumbnailLoaderDecodesInTheBackgroundAndForgetsEverythingOnRemoveAll() async throws {
            try await TestSupport.withTemporaryDirectory { tempDir in
                let thumbnailLoader = ImageAssetThumbnailLoader()
                let imageURL = tempDir.appendingPathComponent("photo.png")
                try TestSupport.makePNGData(pixelWidth: 288, pixelHeight: 144, dpi: 144.0, color: .systemGreen)
                    .write(to: imageURL)

                let decodedImage = await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
                    if let cached = thumbnailLoader.thumbnail(for: imageURL, maximumPixelSize: 128, completion: { image in
                        continuation.resume(returning: image)
                    }) {
                        continuation.resume(returning: cached)
                    }
                }
                let thumbnail = try #require(decodedImage)
                #expect(thumbnail.size.width > 0)
                #expect(thumbnail.size.height > 0)

                thumbnailLoader.removeAll()
                #expect(thumbnailLoader.thumbnail(for: imageURL, maximumPixelSize: 128) { _ in } == nil)
            }
        }

        @Test
        @MainActor
        func svgImageRendererValidationAndRendering() {
            TestSupport.ensureAppKitInitialized()
            let validSVG = """
            <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
              <circle cx="24" cy="24" r="20" fill="#000000"/>
            </svg>
            """
            #expect(SVGImageRenderer.isSVGMarkup(validSVG))

            let htmlWrappedSVG = "<div><svg xmlns=\"http://www.w3.org/2000/svg\"></svg></div>"
            let unclosedSVG = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"10\" height=\"10\"/>"
            #expect(!SVGImageRenderer.isSVGMarkup(htmlWrappedSVG))
            #expect(!SVGImageRenderer.isSVGMarkup(unclosedSVG))

            let renderer = SVGImageRenderer()
            let item = ClipboardItem.fixture(kind: .text, text: validSVG)
            let rendering = renderer.rendering(for: item)
            #expect(rendering != nil)
            #expect(rendering?.tone == .dark)
        }

        @MainActor
        private final class MockLicensingBackend: LicensingService.Backend {
            var currentState: LicensingService.State = .trial(daysLeft: 7)
            var recordedTrialUsageKeys: [String] = []
            var feedbackMessages: [String] = []

            func refresh(licenseKey: String) -> LicensingService.State {
                currentState
            }

            func recordTrialUsage(licenseKey: String) {
                recordedTrialUsageKeys.append(licenseKey)
            }

            func activate(licenseKey: String) async throws {
                currentState = .activated
            }

            func deactivate(licenseKey: String) async throws {
                currentState = .trial(daysLeft: 5)
            }

            func sendFeedback(text: String) async {
                feedbackMessages.append(text)
            }
        }

        @Test
        @MainActor
        func licensingServiceTransitions() async throws {
            let backend = MockLicensingBackend()
            let service = LicensingService(backend: backend)

            service.refresh(licenseKey: "")
            #expect(service.state == .trial(daysLeft: 7))

            backend.currentState = .trialExpired
            service.refresh(licenseKey: "")
            #expect(service.state == .trialExpired)
            #expect(service.state.isTrialExpired)

            try await service.activate(licenseKey: "VALID-KEY-123")
            #expect(service.state == .activated)
            #expect(service.state.isActivated)

            try await service.deactivate(licenseKey: "VALID-KEY-123")
            #expect(service.state == .trial(daysLeft: 5))

            service.recordTrialUsage(licenseKey: "")
            #expect(backend.recordedTrialUsageKeys == [""])

            await service.sendFeedback(text: "Great app!")
            #expect(backend.feedbackMessages == ["Great app!"])
        }

        @MainActor
        private static func makeOutsideClickTestWindow() -> NSWindow {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            return window
        }

        @Test
        @MainActor
        func outsideClickDecision() throws {
            TestSupport.ensureAppKitInitialized()
            let window = Self.makeOutsideClickTestWindow()
            defer { window.close() }
            let inside = NSPoint(x: window.frame.midX, y: window.frame.midY)
            let outside = NSPoint(x: window.frame.maxX + 50, y: window.frame.maxY + 50)

            // A window that is not visible is never dismissed.
            #expect(!OutsideClickDismissalMonitor.isOutsideClick(in: nil, of: window, at: outside))

            window.orderFront(nil)
            try #require(window.isVisible)
            #expect(OutsideClickDismissalMonitor.isOutsideClick(in: nil, of: window, at: outside))
            #expect(OutsideClickDismissalMonitor.isOutsideClick(in: window, of: window, at: outside))
            #expect(!OutsideClickDismissalMonitor.isOutsideClick(in: nil, of: window, at: inside))

            // A click in some other window is not this window's business.
            let other = Self.makeOutsideClickTestWindow()
            defer { other.close() }
            #expect(!OutsideClickDismissalMonitor.isOutsideClick(in: other, of: window, at: outside))
        }

        @Test
        @MainActor
        func outsideClickDecisionWithSheets() throws {
            TestSupport.ensureAppKitInitialized()
            let parent = Self.makeOutsideClickTestWindow()
            let sheet = Self.makeOutsideClickTestWindow()
            let other = Self.makeOutsideClickTestWindow()
            defer {
                parent.endSheet(sheet)
                sheet.close()
                parent.close()
                other.close()
            }
            parent.orderFront(nil)
            try #require(parent.isVisible)
            parent.beginSheet(sheet)
            try #require(sheet.sheetParent === parent)
            try #require(parent.attachedSheet === sheet)
            let outside = NSPoint(x: sheet.frame.maxX + 50, y: sheet.frame.maxY + 50)

            // The sheet is dismissed by clicks in its own parent window, but not in unrelated ones.
            #expect(OutsideClickDismissalMonitor.isOutsideClick(in: parent, of: sheet, at: outside))
            #expect(!OutsideClickDismissalMonitor.isOutsideClick(in: other, of: sheet, at: outside))
            // A window with a sheet attached is never dismissed.
            #expect(!OutsideClickDismissalMonitor.isOutsideClick(in: parent, of: parent, at: outside))
        }

        @Test
        @MainActor
        func outsideClickDismissalMonitorStopsAfterInvalidateAndDeinit() throws {
            TestSupport.ensureAppKitInitialized()
            let window = Self.makeOutsideClickTestWindow()
            defer { window.close() }
            window.orderFront(nil)
            try #require(window.isVisible)
            // Park the window away from the real cursor, which decides what is "outside".
            let cursor = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(x: cursor.x + 2000, y: cursor.y + 2000))
            try #require(!window.frame.contains(cursor))

            func click() throws {
                let event = try #require(NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: .zero,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: 0,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                ))
                NSApp.sendEvent(event)
            }

            var dismissalCount = 0
            var monitor: OutsideClickDismissalMonitor? = OutsideClickDismissalMonitor(window: window) {
                dismissalCount += 1
            }
            try click()
            #expect(dismissalCount == 1)

            monitor?.invalidate()
            monitor?.invalidate()
            try click()
            #expect(dismissalCount == 1)

            // Releasing a monitor that was not invalidated removes it as well.
            monitor = OutsideClickDismissalMonitor(window: window) {
                dismissalCount += 1
            }
            monitor = nil
            try click()
            #expect(dismissalCount == 1)
        }
    }
}
