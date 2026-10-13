import SwiftUI
import AppKit

@main
struct ClipBookApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(model: appDelegate.model)
        .environmentObject(appDelegate.coordinator)
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(replacing: .appSettings) {
        Button(L10n.string("Settings...")) {
          appDelegate.coordinator.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }
      CommandGroup(after: .appInfo) {
        Button(L10n.string("Check for Updates...")) {
          appDelegate.coordinator.checkForUpdates()
        }
      }
      // The ClipBook menu is built in AppDelegate with AppKit: SwiftUI freezes
      // the titles and key equivalents of command menu items after the menu is
      // created, so a menu declared here keeps the shortcuts assigned at launch
      // and the previous shortcut keeps triggering the action.
    }
  }
}
