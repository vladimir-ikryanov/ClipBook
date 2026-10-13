import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsSectionGroup() {
            SettingsToggle(title: L10n.string("Launch at login"), description: L10n.string("Start ClipBook automatically when you sign in."), isOn: $model.preferences.launchAtLogin)
            SettingsToggle(title: L10n.string("Show history window at startup"), description: L10n.string("Open the clipboard history window when ClipBook starts."), isOn: $model.preferences.showMainWindowAtStartup)
            SettingsToggle(title: L10n.string("Check for updates automatically"), description: L10n.string("Periodically check for a newer direct-download release."), isOn: $model.preferences.checkForUpdatesAutomatically)
                .onChange(of: model.preferences.checkForUpdatesAutomatically) { _ in
                    coordinator.savePreferences()
                }
        }

        SettingsSectionGroup(L10n.string("Appearance")) {
            AppearancePicker(selection: $model.preferences.appearance)
                .onChange(of: model.preferences.appearance) { _ in
                    coordinator.savePreferences()
                }
            PickerRow(title: L10n.string("Language"), description: L10n.string("Change the language of the user interface.")) {
                Picker("", selection: $model.preferences.language) {
                    Text("English").tag("en")
                    Text("English (UK)").tag("en-GB")
                    Text("Deutsch").tag("de")
                    Text("Italiano").tag("it")
                    Text("Português (Brasil)").tag("pt-BR")
                    Text("Español").tag("es")
                    Text("日本語").tag("ja")
                    Text("简体中文").tag("zh-Hans")
                }
                .labelsHidden()
            }
            .onChange(of: model.preferences.language) { _ in
                coordinator.savePreferences()
            }
            SettingsToggle(title: L10n.string("Show icon in menu bar"), description: L10n.string("Display the ClipBook app icon in the menu bar. You can always open Settings by pressing ⌘ + , inside the clipboard history window."), isOn: $model.preferences.showMenuBarIcon)
        }

        SettingsSectionGroup(L10n.string("Window")) {
            PickerRow(title: L10n.string("Open window position"), description: L10n.string("Choose where the clipboard history window appears.")) {
                Picker("", selection: $model.preferences.openWindowStrategy) {
                    ForEach(HistoryWindowOpenStrategy.allCases, id: \.rawValue) { strategy in
                        Text(strategy.title).tag(strategy.rawValue)
                    }
                }
                .labelsHidden()
            }
        }
    }
}
