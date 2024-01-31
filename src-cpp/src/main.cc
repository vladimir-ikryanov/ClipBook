#include "molybden.hpp"

using namespace molybden;

void launch() {
  App::init([](std::shared_ptr<App> app) {
    auto browser = Browser::create(app);
    
    // Hide all standard window buttons.
    browser->setWindowButtonVisible(WindowButtonType::kMinimize, false);
    browser->setWindowButtonVisible(WindowButtonType::kZoom, false);
    browser->setWindowButtonVisible(WindowButtonType::kClose, false);
    
    // Hide window title and title bar.
    browser->setWindowTitleVisible(false);
    browser->setWindowTitlebarVisible(false);
    
    // Display the window always on top of other windows.
    browser->setAlwaysOnTop(true);

    browser->loadUrl(app->baseUrl());
    browser->show();
  });
}
