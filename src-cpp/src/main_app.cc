#include "main_app.h"

#include "clipboard_manager.h"

MainApp::MainApp(const std::shared_ptr<molybden::App>& app) : app_(app) {
// Hide the dock icon and make the app a background app.
  app_->dock()->hide();

  browser_ = Browser::create(app);

  // Hide all standard window buttons.
  browser_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  browser_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  browser_->setWindowButtonVisible(WindowButtonType::kClose, false);

  // Hide window title and title bar.
  browser_->setWindowTitleVisible(false);
  browser_->setWindowTitlebarVisible(false);

  // Display the window always on top of other windows.
  browser_->setAlwaysOnTop(true);

  browser_->loadUrl(app->baseUrl());
}

void MainApp::show() {
  browser_->show();
}

void MainApp::hide() {
  if (browser_->isActive()) {
    browser_->hide();
  }
}
std::shared_ptr<molybden::Browser> MainApp::browser() const {
  return browser_;
}
