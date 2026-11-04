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
            SettingsRow(title: L10n.string("Keep confidential content"), description: L10n.string("Passwords and other data that password managers mark as confidential.")) {
                lifetimePicker(L10n.string("Keep confidential content"), selection: confidentialContentLifetime)
            }
            SettingsRow(title: L10n.string("Keep sensitive content"), description: L10n.string("Passwords, API keys, access tokens and card numbers found in copied text.")) {
                lifetimePicker(L10n.string("Keep sensitive content"), selection: sensitiveContentLifetime)
            }
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

    // The pop-up is as wide as its longest period, so it stays small next
    // to the description. Never and Unlimited are set apart from the periods.
    private func lifetimePicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            Text(ContentLifetime.title(for: ContentLifetime.dontSave)).tag(ContentLifetime.dontSave)
            Divider()
            ForEach(ContentLifetime.periods, id: \.self) { lifetime in
                Text(ContentLifetime.title(for: lifetime)).tag(lifetime)
            }
            Divider()
            Text(ContentLifetime.title(for: ContentLifetime.keep)).tag(ContentLifetime.keep)
        }
        .labelsHidden()
        .fixedSize()
    }

    // Changes go through the coordinator, which asks before deleting the
    // secrets already in the history when they are no longer to be saved.
    private var confidentialContentLifetime: Binding<Int> {
        Binding(
            get: { model.preferences.confidentialContentLifetime },
            set: { coordinator.setConfidentialContentLifetime($0) }
        )
    }

    private var sensitiveContentLifetime: Binding<Int> {
        Binding(
            get: { model.preferences.sensitiveContentLifetime },
            set: { coordinator.setSensitiveContentLifetime($0) }
        )
    }
}
