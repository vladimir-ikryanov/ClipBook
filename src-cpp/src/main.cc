#include "molybden.hpp"

#if OS_MAC
#include "main_app_mac.h"
#elif OS_WIN
#include "main_app_win.h"
#endif

#include "url_request_interceptor.h"
#include "utils.h"

using namespace molybden;

void launch() {
  AppOptions options;
  // Configure logging.
  options.logging.enabled = true;
  options.logging.log_level = LogLevel::kInfo;
  options.logging.destination = Destination::kStandardOutput;
  options.logging.log_file = getAppDataDir() + "/clipbook.log";
  // Register the custom URL scheme.
  options.schemes.emplace_back(kClipBookScheme);

  App::init(options, [](std::shared_ptr<App> app) {
    std::shared_ptr<MainApp> main_app;
#if OS_MAC
    main_app = std::make_shared<MainAppMac>(app, AppSettings::create());
    // Hide the dock icon and make the app a background app.
    app->dock()->hide();
#elif OS_WIN
    main_app = std::make_shared<MainAppWin>(app);
#endif
    bool first_run = main_app->init();
    if (first_run) {
      main_app->showWelcomeWindow();
    }
    main_app->launch();
  });
}
