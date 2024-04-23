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
  options.logging.enabled = true;
  options.logging.log_level = LogLevel::kInfo;
  App::init(options, [](std::shared_ptr<App> app) {
#if OS_MAC
    MainAppMac main_app(app);
    // Hide the dock icon and make the app a background app.
    app->dock()->hide();
#elif OS_WIN
    MainAppWin main_app(app);
#endif
    bool first_run = main_app.init();
    if (first_run) {
      // Show the welcome window if the app is running for the first time.
      WelcomeWindow welcome_window(app);
      welcome_window.show();
    }
    main_app.launch();
    ClipboardManager::create(main_app.browser())->start();
  });
}
