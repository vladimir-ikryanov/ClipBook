import SwiftUI

struct StorageSettingsView: View {
  @ObservedObject var model: AppModel
  @EnvironmentObject private var coordinator: AppCoordinator
  
  var body: some View {
    SettingsSectionGroup() {
      SettingsToggle(title: L10n.string("Always keep favorites and tagged items"), description: L10n.string("Preserve favorite and tagged items when clearing history and when older items are removed automatically."), isOn: $model.preferences.keepFavoritesOnClearHistory)
    }
    
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.string("Keep history"))
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)

      Text(L10n.string("Select how long to keep individual history items. Items older than this period will be automatically removed from the history. Choose Never to stop capturing a type of content."))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)

      VStack(spacing: 16) {
        RetentionRow(clipType: .text, value: retentionDays(for: .text))
        RetentionRow(clipType: .richText, value: retentionDays(for: .richText))
        RetentionRow(clipType: .image, value: retentionDays(for: .image))
        RetentionRow(clipType: .file, value: retentionDays(for: .file))
        RetentionRow(clipType: .link, value: retentionDays(for: .link))
        RetentionRow(clipType: .email, value: retentionDays(for: .email))
        RetentionRow(clipType: .color, value: retentionDays(for: .color))
      }
    }
    
    SettingsSectionGroup() {
      SettingsToggle(title: L10n.string("Warn before manually clearing history"), description: L10n.string("Display a confirmation dialog when clearing history manually using the 'Delete All' command."), isOn: $model.preferences.warnOnClearHistory)
    }
    
    SettingsSectionGroup() {
      SettingsToggle(title: L10n.string("Clear history on quit"), description: L10n.string("Delete unprotected items when ClipBook quits."), isOn: $model.preferences.clearHistoryOnQuit)
      SettingsToggle(title: L10n.string("Clear history after Mac reboot"), description: L10n.string("Delete unprotected items after a system restart."), isOn: $model.preferences.clearHistoryOnReboot)
    }
  }

  // Changes go through the coordinator, which asks before deleting items
  // that are already older than the new period.
  private func retentionDays(for clipType: RetentionClipType) -> Binding<Int> {
    Binding(
      get: { model.preferences[keyPath: clipType.preferenceKeyPath] },
      set: { coordinator.setRetentionDays($0, for: clipType) }
    )
  }
}
