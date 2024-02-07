#include "main_app_mac.h"

MainAppMac::MainAppMac(const std::shared_ptr<App> &app) : MainApp(app) {}

void MainAppMac::show() {
  MainApp::show();
}

void MainAppMac::hide() {
  MainApp::hide();
}
