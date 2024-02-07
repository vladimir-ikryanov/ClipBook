#include "molybden.hpp"

#include "main_app_mac.h"
#include "clipboard_manager.h"

using namespace molybden;

void launch() {
  App::init([](std::shared_ptr<App> app) {
    MainAppMac main_app(app);
    ClipboardManager::create(main_app.browser())->start();
  });
}
