#include "molybden.hpp"

#if OS_MAC
#include "main_app_mac.h"
#elif OS_WIN
#include "main_app_win.h"
#endif

#include "clipboard_manager.h"

using namespace molybden;

void launch() {
  AppOptions options;
  options.logging.enabled = true;
  options.logging.log_level = LogLevel::kInfo;
  App::init(options, [](std::shared_ptr<App> app) {
#if OS_MAC
      MainAppMac main_app(app);
#elif OS_WIN
      MainAppWin main_app(app);
#endif
      ClipboardManager::create(main_app.browser())->start();
  });
}
