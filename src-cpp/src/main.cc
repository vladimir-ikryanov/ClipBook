#include "molybden.hpp"

#if OS_MAC
#include "main_app_mac.h"
#elif OS_WIN
#include "main_app_win.h"
#endif

#include "clipboard_manager.h"
#include "welcome_window.h"

using namespace molybden;

void launch() {
  AppOptions options;
  App::init(options, [](std::shared_ptr<App> app) {
    std::shared_ptr<MainApp> main_app;
#if OS_MAC
    main_app = std::make_shared<MainAppMac>(app);
    // Hide the dock icon and make the app a background app.
    app->dock()->hide();
#elif OS_WIN
    main_app = std::make_shared<MainAppWin>(app);
#endif
    bool first_run = main_app->init();
    if (first_run || !app->isProduction()) {
      // Show the welcome window if the app is running for the first time.
      auto* welcome_window = new WelcomeWindow(main_app);
      welcome_window->show();
    }
    main_app->launch();
    ClipboardManager::create(main_app->browser())->start();
  });
}
