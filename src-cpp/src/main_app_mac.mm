#include "main_app_mac.h"

MainAppMac::MainAppMac(const std::shared_ptr<App> &app) : MainApp(app) {
  // Register a global shortcut to show the browser window.
  auto global_shortcuts = app->globalShortcuts();
  auto shortcut_show = Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT);
  global_shortcuts->registerShortcut(shortcut_show, [this](const Shortcut &) {
    show();
  });

  // Register a global shortcut to hide the browser window.
  auto shortcut_hide = Shortcut(KeyCode::ESC);
  global_shortcuts->registerShortcut(shortcut_hide, [this](const Shortcut &) {
    hide();
  });
}

void MainAppMac::show() {
  active_app_ = [[NSWorkspace sharedWorkspace] frontmostApplication];
  MainApp::show();
}

void MainAppMac::hide() {
  MainApp::hide();
  if (active_app_) {
    [active_app_ activateWithOptions:NSApplicationActivateIgnoringOtherApps];
  }
}
