#include "molybden.hpp"

#if OS_MAC
#include "main_app_mac.h"
#elif OS_WIN
#include "main_app_win.h"
#endif

#include "clipboard_reader.h"
#include "welcome_window.h"
#include "url_request_interceptor.h"

using namespace molybden;

std::string getHomeDirectory() {
  const char* homeDir = getenv("HOME");
  if (homeDir != nullptr) {
    return {homeDir};
  } else {
    return ""; // Home directory not found
  }
}

void launch() {
  AppOptions options;
  // Configure logging.
  options.logging.enabled = false;
  options.logging.log_level = LogLevel::kError;
  options.logging.destination = Destination::kFile;
  options.logging.log_file = getHomeDirectory() + "/Library/Application Support/ClipBook/clipbook.log";
  // Register the custom URL scheme.
  options.schemes.emplace_back(kClipBookScheme);

  App::init(options, [](std::shared_ptr<App> app) {
    std::shared_ptr<MainApp> main_app;
#if OS_MAC
    main_app = std::make_shared<MainAppMac>(app, AppSettings::create());
#elif OS_WIN
    main_app = std::make_shared<MainAppWin>(app);
#endif
    bool first_run = main_app->init();
    if (first_run) {
      // Show the welcome window if the app is running for the first time.
      auto* welcome_window = new WelcomeWindow(main_app);
      welcome_window->show();
    }
    main_app->launch();
    ClipboardReader::create(main_app)->start();
  });
}
