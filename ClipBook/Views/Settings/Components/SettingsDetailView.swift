import SwiftUI

struct SettingsDetailView: View {
    let selection: SettingsSection
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if selection == .about {
                AboutSettingsView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
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
        }
        .background(.background)
    }
}
