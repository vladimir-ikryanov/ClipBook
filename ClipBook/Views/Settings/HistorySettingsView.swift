import SwiftUI

struct HistorySettingsView: View {
  @ObservedObject var model: AppModel
  
  var body: some View {
    SettingsSectionGroup() {
      SettingsToggle(title: L10n.string("Update history after action"), description: L10n.string("Move an item to the top of the history after a copy or paste action."), isOn: $model.preferences.updateHistoryAfterAction)
        .disabled(model.preferences.copySequenceModeEnabled)
      SettingsToggle(title: L10n.string("Pin favorites to top"), description: L10n.string("Keep favorite items above regular clipboard history."), isOn: $model.preferences.pinFavoritesToTop)
      SettingsToggle(title: L10n.string("Show quick paste shortcuts"), isOn: $model.preferences.showCommandNumberShortcut)
      SettingsToggle(title: L10n.string("Show dividers between items"), isOn: $model.preferences.showHistoryDividers)
      SettingsToggle(title: L10n.string("Show preview for links"), description: L10n.string("Fetch and display link preview details when available."), isOn: $model.preferences.showPreviewForLinks)
      SettingsToggle(title: L10n.string("Treat digit numbers as colors"), description: L10n.string("Detect hex color values copied without a leading number sign."), isOn: $model.preferences.treatDigitNumbersAsColor)
      SettingsToggle(title: L10n.string("Prefer pasting as plain text"), description: L10n.string("Use the default paste shortcut for plain-text paste actions."), isOn: $model.preferences.preferPastingAsPlainText)
    }
    
    SettingsSectionGroup(L10n.string("Actions")) {
      SettingsToggle(title: L10n.string("Paste on single click"), description: L10n.string("Paste an item immediately when it is clicked."), isOn: $model.preferences.pasteOnClick)
      PickerRow(title: L10n.string("Double-click action"), description: L10n.string("Choose what double-clicking a history item does.")) {
        Picker(L10n.string("Double-click action"), selection: $model.preferences.doubleClickAction) {
          ForEach(HistoryItemActionPreference.allCases) { action in
            Text(action.title).tag(action.rawValue)
          }
        }
        .labelsHidden()
      }
      PickerRow(title: L10n.string("Number key action"), description: L10n.string("Choose what quick number shortcuts do.")) {
        Picker(L10n.string("Number key action"), selection: $model.preferences.numberKeyAction) {
          ForEach(HistoryItemActionPreference.allCases) { action in
            Text(action.title).tag(action.rawValue)
          }
        }
        .labelsHidden()
      }
      PickerRow(title: L10n.string("Key between pasted items"), description: L10n.string("Choose the key pressed between items when you paste several items at once.")) {
        Picker(L10n.string("Key between pasted items"), selection: $model.preferences.multiPasteKey) {
          ForEach(PasteInterItemAction.allCases) { key in
            Text(key.title).tag(key.rawValue)
          }
        }
        .labelsHidden()
      }
    }
    
    SettingsSectionGroup(L10n.string("Copy and merge")) {
      SettingsToggle(title: L10n.string("Enable copy and merge"), description: L10n.string("Press CMD+C+C to append the currently selected text to the previously copied text in the clipboard history."), isOn: $model.preferences.copyAndMergeEnabled)
      PickerRow(title: L10n.string("Separator"), description: L10n.string("Choose how merged text fragments are separated.")) {
        Picker(L10n.string("Separator"), selection: $model.preferences.copyAndMergeSeparator) {
          ForEach(CopyAndMergeSeparatorPreference.allCases) { separator in
            Text(separator.title).tag(separator.rawValue)
          }
        }
        .labelsHidden()
      }
      .disabled(!model.preferences.copyAndMergeEnabled)
      SettingsToggle(title: L10n.string("Copy merged item to clipboard"), description: L10n.string("Put the merged value back on the system clipboard."), isOn: $model.preferences.copyToClipboardAfterMerge)
        .disabled(!model.preferences.copyAndMergeEnabled)
    }
  }
}
