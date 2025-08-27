#include "molybden.hpp"

#if OS_MAC
#include "main_app_mac.h"
#endif

#include "url_request_interceptor.h"
#include "utils.h"

using namespace molybden;

void launch() {
  AppOptions options;
  // Configure logging.
  auto args = CommandLineArgs::get().list();
  for (const auto& arg : args) {
    if (arg == "--debug") {
      options.logging.enabled = true;
      options.logging.log_level = LogLevel::kInfo;
      options.logging.destination = Destination::kFile;
      options.logging.log_file = getAppDataDir() + "/clipbook.log";
    }
    if (arg == "--dev") {
      options.logging.enabled = true;
      options.logging.log_level = LogLevel::kWarning;
      options.logging.destination = Destination::kStandardOutput;
    }
  }
  // Register the custom URL scheme.
  options.schemes.emplace_back(kClipBookScheme);
  // Disable internal Chromium traffic.
  options.switches.emplace("--disable-background-networking");
  options.switches.emplace("--disable-component-update");
  options.switches.emplace("--disable-features=OptimizationHintsFetching,NativeNotifications,GatherProcessRequirementMetrics");
  options.switches.emplace("--disable-sync");

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
    main_app->launch();
    if (first_run) {
      main_app->showWelcomeWindow();
    }
  });
}
