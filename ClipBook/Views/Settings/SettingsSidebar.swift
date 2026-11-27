import AppKit
import SwiftUI

/// The settings sidebar in the style of System Settings: the app row at the
/// top, where System Settings shows the Apple Account, followed by groups of
/// panes with icon tiles. While searching, it lists the matching panes and
/// settings instead, each with the path to it.
struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    var searchText: String = ""
    var onSelectSearchResult: (SettingsSearchResult) -> Void = { _ in }

    @State private var selectedResultID: String?
    @FocusState private var isFocused: Bool

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if isSearching {
                resultsList
            } else {
                sectionsList
            }
        }
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onChange(of: searchText) { _ in
            selectedResultID = nil
        }
    }

    // MARK: - Sections

    private var sectionsList: some View {
        List(selection: $selection) {
            if SettingsSection.visibleSections.contains(.about) {
                Section {
                    appRow
                        .tag(SettingsSection.about)
                }
            }

            ForEach(Array(SettingsSection.sidebarGroups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group) { section in
                        sectionRow(section)
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sectionRow(_ section: SettingsSection) -> some View {
        HStack(spacing: 8) {
            SettingsIconTile(section: section)
            Text(section.title)
        }
        .modifier(SidebarSelectionStyle(isSelected: section == selection))
    }

    private var appRow: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "ClipBook")
                    .font(.system(size: 13, weight: .semibold))
                Text(SettingsSection.about.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .modifier(SidebarSelectionStyle(isSelected: selection == .about))
    }

    // MARK: - Search results

    private var resultsList: some View {
        let results = SettingsSearch.results(for: searchText)

        return List(selection: $selectedResultID) {
            ForEach(results) { result in
                resultRow(result)
                    .tag(result.id)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if results.isEmpty {
                Text(L10n.string("No Results"))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedResultID) { id in
            guard let id,
                  let result = SettingsSearch.results(for: searchText).first(where: { $0.id == id }) else {
                return
            }
            onSelectSearchResult(result)
        }
    }

    private func resultRow(_ result: SettingsSearchResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            SettingsIconTile(section: result.section)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                // Long titles wrap instead of being truncated, as in System
                // Settings; the sidebar list limits rows to one line otherwise.
                Text(result.title)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
        .modifier(SidebarSelectionStyle(isSelected: result.id == selectedResultID))
    }
}

// On macOS 27 the sidebar list only draws the selected row with the accent
// color while it is the first responder; once focus moves into the detail
// column the highlight turns gray. System Settings keeps the accent highlight
// regardless of focus, so the row draws its own accent background on top of
// the list's selection highlight and forces white content, which is what the
// list does itself while focused. The icon tile keeps its colors, as in System
// Settings. Earlier systems keep the accent highlight on their own.
private struct SidebarSelectionStyle: ViewModifier {
    let isSelected: Bool

    private static let cornerRadius: CGFloat = 8
    private static let horizontalInset: CGFloat = 10

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 27.0, *) {
            content
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                        .padding(.horizontal, Self.horizontalInset)
                )
        } else {
            content
        }
    }
}
