import SwiftUI

struct SettingsDetailView: View {
    let selection: SettingsSection
    @ObservedObject var model: AppModel
    /// Whether the pane starts with its System Settings style header card.
    /// The view snapshot tests leave it off to compare only the settings.
    var showsHeader = false
    /// A setting the search leads to, which the pane scrolls to and highlights.
    var highlight: SettingsSearchHighlight? = nil
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if selection == .about {
                AboutSettingsView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        paneContent
                    }
                    // Waits a moment so a pane the search just opened is laid
                    // out before scrolling to the setting.
                    .task(id: highlight) {
                        guard let highlight else {
                            return
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(SettingsSearchAnchorID(title: highlight.anchor), anchor: .center)
                        }
                    }
                }
            }
        }
        .environment(\.settingsSearchHighlight, highlight?.anchor)
        .background(.background)
    }

    private var paneContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsHeader {
                SettingsPaneHeader(section: selection)
            }

            switch selection {
            case .general:
                GeneralSettingsView(model: model)
            case .history:
                HistorySettingsView(model: model)
            case .sounds:
                SoundsSettingsView(model: model)
            case .tags:
                TagsSettingsView(model: model)
            case .importExport:
                ImportExportSettingsView(model: model)
            case .storage:
                StorageSettingsView(model: model)
            case .shortcuts:
                ShortcutSettingsView(model: model)
            case .privacy:
                PrivacySettingsView(model: model)
            case .license:
                LicenseSettingsView(model: model)
            case .about:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
