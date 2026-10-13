import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IgnoredApplicationsList: View {
    @Binding var ignoredAppsText: String
    /// Receives the bundle paths picked in the open panel. The owner adds
    /// them to the list, so it can also deal with their existing items.
    let onAddApplications: ([String]) -> Void
    @State private var selectedEntry: String?

    private static let cornerRadius: CGFloat = 12
    private static let rowHeight: CGFloat = 40
    private static let iconSize: CGFloat = 32
    private static let rowLeadingPadding: CGFloat = 6
    private static let iconSpacing: CGFloat = 6
    private static let rowTrailingPadding: CGFloat = 6
    private static let firstRowHeight: CGFloat = 46
    private static let dividerLeadingInset: CGFloat = rowLeadingPadding + iconSize + iconSpacing
    private static let toolbarBackground = Color(nsColor: adaptiveToolbarBackground)

    private static var adaptiveToolbarBackground: NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(
                    red: 0x2E / 255.0,
                    green: 0x2E / 255.0,
                    blue: 0x2F / 255.0,
                    alpha: 1.0
                )
                : NSColor(white: 0.92, alpha: 1.0)
        }
    }

    private var entries: [String] {
        ignoredAppsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var listHeight: CGFloat {
        if entries.isEmpty {
            return Self.rowHeight
        }
        if entries.count == 1 {
            return Self.firstRowHeight
        }
        return Self.firstRowHeight + CGFloat(entries.count - 2) * Self.rowHeight + Self.firstRowHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if entries.isEmpty {
                    Text(L10n.string("No items"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element) { index, entry in
                            applicationRow(
                                entry,
                                isFirst: index == 0,
                                isLast: index == entries.count - 1
                            )
                            if index < entries.count - 1 {
                                rowDivider
                            }
                        }
                    }
                }
            }
            .frame(height: listHeight)
            .frame(maxWidth: .infinity)
            .background(
                .ultraThinMaterial,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: Self.cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: Self.cornerRadius,
                    style: .continuous
                )
            )

            HStack(spacing: 0) {
                Button {
                    addApplications()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(L10n.string("Add application"))

                Divider()
                    .frame(height: 16)

                Button {
                    removeSelectedApplication()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedEntry == nil)
                .help(L10n.string("Remove selected application"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 0)
            .padding(.vertical, 2)
            .background(
                Self.toolbarBackground,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: Self.cornerRadius,
                    bottomTrailingRadius: Self.cornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
        }
        .frame(maxWidth: .infinity)
        .onChange(of: entries) { updatedEntries in
            if let selectedEntry, !updatedEntries.contains(selectedEntry) {
                self.selectedEntry = nil
            }
        }
    }

    private func applicationRow(_ entry: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        let isSelected = selectedEntry == entry
        let height = (isFirst || isLast) ? Self.firstRowHeight : Self.rowHeight

        return HStack(spacing: Self.iconSpacing) {
            Image(nsImage: appIcon(for: entry))
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)
            Text(displayName(for: entry))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .padding(.leading, Self.rowLeadingPadding)
        .padding(.trailing, Self.rowTrailingPadding)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
        .background(
            isSelected ? Color.accentColor : Color.clear,
            in: Self.selectionShape(isFirst: isFirst)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
        }
    }

    private static func selectionShape(isFirst: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? cornerRadius : 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: isFirst ? cornerRadius : 0,
            style: .continuous
        )
    }

    private var rowDivider: some View {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(white: 0x2F / 255.0, alpha: 1.0)
                : NSColor.separatorColor
        })
        .frame(height: 0.5)
        .padding(.leading, Self.dividerLeadingInset)
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = L10n.string("Choose Applications")
        panel.prompt = L10n.string("Add")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK else {
            return
        }

        let paths = panel.urls.map { $0.standardizedFileURL.path }
        guard !paths.isEmpty else {
            return
        }

        onAddApplications(paths)
        selectedEntry = paths.last
    }

    private func removeSelectedApplication() {
        guard let selectedEntry else {
            return
        }

        let updatedEntries = ignoredAppEntries.filter { $0 != selectedEntry }
        ignoredAppsText = updatedEntries.joined(separator: "\n")
        self.selectedEntry = nil
    }

    private func displayName(for entry: String) -> String {
        if entry.contains("/") {
            return URL(fileURLWithPath: entry).lastPathComponent
        }
        if entry.hasSuffix(".app") {
            return entry
        }
        return entry
    }

    private func appIcon(for entry: String) -> NSImage {
        if FileManager.default.fileExists(atPath: entry) {
            return NSWorkspace.shared.icon(forFile: entry)
        }

        let candidatePaths = [
            "/Applications/\(entry).app",
            "/Applications/\(entry)",
            "/System/Applications/\(entry).app",
            "/System/Applications/\(entry)",
        ]

        for path in candidatePaths where FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }

        return NSWorkspace.shared.icon(for: .application)
    }

    private var ignoredAppEntries: [String] {
        ignoredAppsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

}
