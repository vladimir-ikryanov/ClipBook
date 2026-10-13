import SwiftUI

struct PrivacySettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsSectionGroup() {
            SettingsToggle(title: L10n.string("Show during screen sharing and recordings"), description: L10n.string("When off, the history window stays visible to you but is hidden from screen sharing, screen recordings and screenshots."), isOn: $model.preferences.showDuringScreenSharing)
        }

        SettingsSectionGroup() {
            SettingsToggle(title: L10n.string("Mask sensitive content"), description: L10n.string("Mask passwords, API keys, access tokens and card numbers in copied text. Pasting and copying still use the original text."), isOn: $model.preferences.detectSensitiveContent)
        }

        SettingsSectionGroup() {
            SettingsToggle(title: L10n.string("Ignore confidential content"), description: L10n.string("Skip password-manager and other concealed pasteboard data."), isOn: $model.preferences.ignoreConcealedContent)
            SettingsToggle(title: L10n.string("Ignore transient content"), description: L10n.string("Skip temporary pasteboard values that apps do not intend to store."), isOn: $model.preferences.ignoreTransientContent)
        }

        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Ignored applications"))
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)

            Text(L10n.string("Do not capture clipboard changes while these apps are active. Adding an app offers to delete the items already copied from it."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            IgnoredApplicationsList(ignoredAppsText: $model.preferences.ignoredAppsText) { paths in
                coordinator.addIgnoredApplications(atPaths: paths)
            }
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
