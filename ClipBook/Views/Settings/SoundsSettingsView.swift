import SwiftUI

struct SoundsSettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsSectionGroup() {
            ForEach(SoundEffect.allCases) { effect in
                SettingsToggle(
                    title: effect.title,
                    isOn: binding(for: effect)
                )
            }
        }
        .disabled(!model.preferences.soundEffectsEnabled)
    }

    private func binding(for effect: SoundEffect) -> Binding<Bool> {
        Binding(
            get: { model.preferences[keyPath: effect.preferenceKeyPath] },
            set: { isOn in
                model.preferences[keyPath: effect.preferenceKeyPath] = isOn
                if isOn {
                    coordinator.previewSound(effect)
                }
            }
        )
    }
}
