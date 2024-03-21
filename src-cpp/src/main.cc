#include "molybden.hpp"

#include "main_app_mac.h"
#include "clipboard_manager.h"

using namespace molybden;

void launch() {
  AppOptions options;
  options.logging.enabled = true;
  options.logging.log_level = LogLevel::kInfo;
  App::init(options, [](std::shared_ptr<App> app) {
    MainAppMac main_app(app);
    ClipboardManager::create(main_app.browser())->start();
  });
}
