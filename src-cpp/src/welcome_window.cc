#include <thread>
#include <iostream>

#include "welcome_window.h"

using namespace molybden;

WelcomeWindow::WelcomeWindow(const std::shared_ptr<MainApp> &app) : app_(app) {
  browser_ = Browser::create(app_->app());
  browser_->onInjectJs = [this](const InjectJsArgs &args, InjectJsAction action) {
    args.window->putProperty("enableAccessibilityAccess", [this]() {
      app_->paste("");
      browser_->loadUrl(app_->app()->baseUrl() + "/enjoy");
    });
    args.window->putProperty("openHistory", [this]() {
      hide();
      app_->show();
    });
    action.proceed();
  };
  browser_->loadUrl(app_->app()->baseUrl() + "/welcome");
  browser_->setWindowTitleVisible(false);
  browser_->setWindowTitlebarVisible(false);
  browser_->setWindowButtonVisible(WindowButtonType::kMaximize, false);
  browser_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  browser_->setWindowButtonVisible(WindowButtonType::kRestore, false);
  browser_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  browser_->setSize(500, 750);
  browser_->centerWindow();
}

void WelcomeWindow::show() {
  browser_->show();
}

void WelcomeWindow::hide() {
  browser_->hide();
}
