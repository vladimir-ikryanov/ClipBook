#include "main_app.h"

#include "clipboard_manager.h"

MainApp::MainApp(const std::shared_ptr<App>& app) : app_(app) {
// Hide the dock icon and make the app a background app.
  app_->dock()->hide();

  browser_ = Browser::create(app);

  // Hide all standard window buttons.
  browser_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  browser_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  browser_->setWindowButtonVisible(WindowButtonType::kClose, false);

  // Hide window title and title bar.
  browser_->setWindowTitleVisible(false);
  browser_->setWindowTitlebarVisible(false);

  // Display the window always on top of other windows.
  browser_->setAlwaysOnTop(true);

  browser_->loadUrl(app->baseUrl());

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

  ClipboardManager::create(browser_)->start();
}

void MainApp::show() {
  browser_->show();
}

void MainApp::hide() {
  if (browser_->isActive()) {
    browser_->hide();
  }
}
