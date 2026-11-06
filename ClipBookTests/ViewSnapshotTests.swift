@testable import ClipBook
import AppKit
import Foundation
import SwiftUI
import Testing

/// Appearances every snapshot is rendered in.
enum SnapshotAppearance: String, CaseIterable, Sendable {
    case light
    case dark

    var name: NSAppearance.Name {
        switch self {
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}

/// Views with a reference image in `ClipBookTests/Snapshots`.
enum SnapshotScenario: String, CaseIterable, Sendable {
    case textRow = "HistoryItemRowTextView"
    case linkRow = "HistoryItemRowLinkView-normal"
    case maskedLinkRow = "HistoryItemRowLinkView-masked"
    case colorRow = "HistoryItemRowColorView"
    case emptyHistory = "EmptyHistory"
    case settingsShortcuts = "SettingsPane-shortcuts"

    private static let rowSize = NSSize(width: 480, height: HistoryRow.height)

    @MainActor
    func render(in appearance: SnapshotAppearance) throws -> RenderedViewSnapshot {
        let rowSize = Self.rowSize
        let tag = ClipBook.Tag(id: 1, name: "Work", color: "#3B84ED")
        switch self {
        case .textRow:
            let item = ClipboardItem.fixture(
                kind: .text,
                text: "Snapshot test clip with\nline break and\ttab character",
                isFavorite: true,
                tags: [tag.id]
            )
            return try Self.renderRow({ HistoryItemRowTextView(frame: $0) }, appearance: appearance) { row in
                row.configureForTest(item: item, searchQuery: "Snapshot", itemTags: [tag])
            }
        case .linkRow:
            let url = try #require(URL(string: "https://clipbook.app/docs/getting-started"))
            let item = ClipboardItem.fixture(kind: .link, text: url.absoluteString)
            let preview = LinkPreview(
                url: url,
                title: "Getting Started with ClipBook",
                description: "Learn how to search and organize your clipboard history.",
                image: nil,
                favicon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
            )
            return try Self.renderRow({ HistoryItemRowLinkView(frame: $0) }, appearance: appearance) { row in
                row.configureForTest(item: item, quickPasteIndex: 2, linkPreview: preview, showsLinkPreview: true)
            }
        case .maskedLinkRow:
            let secretParameter = ["sk", "-", String(repeating: "zY9xW8vU", count: 4)].joined()
            let item = ClipboardItem.fixture(
                kind: .link,
                title: "Staging Token URL",
                text: "https://staging.example.com/callback?key=\(secretParameter)",
                sensitivity: .sensitive
            )
            return try Self.renderRow({ HistoryItemRowLinkView(frame: $0) }, appearance: appearance) { row in
                row.configureForTest(item: item, quickPasteIndex: 3, showsLinkPreview: true)
            }
        case .colorRow:
            let item = ClipboardItem.fixture(kind: .color, text: "#3B84ED")
            return try Self.renderRow({ HistoryItemRowColorView(frame: $0) }, appearance: appearance) { row in
                row.configure(item: item, quickPasteIndex: 4, tableWidth: rowSize.width)
            }
        case .emptyHistory:
            let view = EmptyHistory(
                title: "No clipboard items",
                message: "Copy text, images, files, links, emails, or colors to build your history.",
                symbolName: "clipboard"
            )
            return try TestSupport.renderOffscreenView(
                view,
                size: NSSize(width: 420, height: 220),
                appearance: appearance.name
            )
        case .settingsShortcuts:
            // This pane draws nothing with the system accent color, which is a setting of the Mac the
            // test runs on. The sidebar, the theme picker and the switches of the other panes do.
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            return try TestSupport.renderOffscreenSwiftUIView(
                SettingsDetailView(selection: .shortcuts, model: harness.model).environmentObject(harness.coordinator),
                size: NSSize(width: 520, height: 640),
                appearance: appearance.name
            )
        }
    }

    @MainActor
    private static func renderRow<RowView: HistoryItemRowView>(
        _ makeRow: (NSRect) -> RowView,
        appearance: SnapshotAppearance,
        configure: (RowView) -> Void
    ) throws -> RenderedViewSnapshot {
        let targetAppearance = try #require(NSAppearance(named: appearance.name))
        let row = makeRow(NSRect(origin: .zero, size: rowSize))
        row.appearance = targetAppearance
        targetAppearance.performAsCurrentDrawingAppearance {
            configure(row)
        }
        return try TestSupport.renderOffscreenView(row, size: rowSize, appearance: appearance.name)
    }
}

extension SharedProcessStateTests {
    @Suite
    struct ViewSnapshotTests {
        @Test(arguments: SnapshotScenario.allCases, SnapshotAppearance.allCases)
        @MainActor
        func viewMatchesReferenceImage(scenario: SnapshotScenario, appearance: SnapshotAppearance) throws {
            let snapshot = try scenario.render(in: appearance)
            SnapshotTesting.assertMatchesReference(snapshot, named: "\(scenario.rawValue)-\(appearance.rawValue)")
        }
    }
}
