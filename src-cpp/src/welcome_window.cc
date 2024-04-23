#include <thread>
#include <iostream>

#include "welcome_window.h"

using namespace molybden;

WelcomeWindow::WelcomeWindow(const std::shared_ptr<App> &app) : app_(app) {
  browser_ = Browser::create(app_);
}

void WelcomeWindow::show() {
  browser_->show();
}

void WelcomeWindow::hide() {
  browser_->hide();
}

std::shared_ptr<molybden::Browser> WelcomeWindow::browser() const {
  return browser_;
}
