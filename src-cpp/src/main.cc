#include "molybden.hpp"

#include "main_app_mac.h"

using namespace molybden;

void launch() {
  App::init([](std::shared_ptr<App> app) {
    new MainAppMac(app);
  });
}
