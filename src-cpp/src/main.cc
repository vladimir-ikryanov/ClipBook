#include "molybden.hpp"

using namespace molybden;

void launch() {
  App::init([](std::shared_ptr<App> app) {
    // Hide the dock icon and make the app a background app.
    app->dock()->hide();

    auto browser = Browser::create(app);

    // Hide all standard window buttons.
    browser->setWindowButtonVisible(WindowButtonType::kMinimize, false);
    browser->setWindowButtonVisible(WindowButtonType::kZoom, false);
    browser->setWindowButtonVisible(WindowButtonType::kClose, false);

    // Hide window title and title bar.
    browser->setWindowTitleVisible(false);
    browser->setWindowTitlebarVisible(false);

    // Display the window always on top of other windows.
    browser->setAlwaysOnTop(true);

    browser->loadUrl(app->baseUrl());

    auto global_shortcuts = app->globalShortcuts();
    // Register a global shortcut to show the browser window.
    auto shortcut_show = Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT);
    global_shortcuts->registerShortcut(shortcut_show, [browser](const Shortcut &) {
      browser->show();
    });

    // Register a global shortcut to hide the browser window.
    auto shortcut_hide = Shortcut(KeyCode::ESC);
    global_shortcuts->registerShortcut(shortcut_hide, [browser](const Shortcut &) {
      if (browser->isActive()) {
        browser->hide();
      }
    });
  });
}
