#include "main_app_win.h"

using namespace molybden;

MainAppWin::MainAppWin(const std::shared_ptr<App> &app) : MainApp(app) {
  // Register a global shortcut to show the browser window.
  auto global_shortcuts = app->globalShortcuts();
  auto shortcut_show = Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT);
  global_shortcuts->registerShortcut(shortcut_show, [this](const Shortcut &) {
    show();
  });
}

void MainAppWin::activate() {
}

void MainAppWin::show() {
  MainApp::show();
}

void MainAppWin::hide() {
  MainApp::hide();
}

void MainAppWin::paste(const std::string &text) {
  // Hide the browser window and activate the previously active app.
  hide();
}
