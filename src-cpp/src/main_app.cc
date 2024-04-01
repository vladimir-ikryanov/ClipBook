#include <thread>

#include "main_app.h"

using namespace molybden;

MainApp::MainApp(const std::shared_ptr<App> &app) : app_(app) {
  auto tray = Tray::create(app);
  tray->setImage(app->getPath(PathKey::kAppResources) + "/imageTemplate.png");
  tray->setMenu(CustomMenu::create(
      {
          menu::Item("Open " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
            show();
          }),
          menu::Separator(),
          menu::Menu("Appearance", {
              menu::Item("Dark", [this](const CustomMenuItemActionArgs &args) {
                app_->setTheme(AppTheme::kDark);
              }),
              menu::Item("Light", [this](const CustomMenuItemActionArgs &args) {
                app_->setTheme(AppTheme::kLight);
              }),
              menu::Item("System", [this](const CustomMenuItemActionArgs &args) {
                app_->setTheme(AppTheme::kSystem);
              }),
          }),
          menu::Item("Clear all", [this](const CustomMenuItemActionArgs &args) {
            activate();

            MessageDialogOptions options;
            options.message = "Are you sure you want to clear entire history?";
            options.informative_text = "This action cannot be undone.";
            options.buttons = {
                MessageDialogButton("Clear", MessageDialogButtonType::kDefault),
                MessageDialogButton("Cancel", MessageDialogButtonType::kCancel),
            };
            MessageDialog::show(app_, options, [this](const MessageDialogResult &result) {
              if (result.button.type == MessageDialogButtonType::kDefault) {
                std::thread([this]() {
                  clearHistory();
                }).detach();
              }
            });
          }),
          menu::Separator(),
          menu::Item("About " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
            activate();

            MessageDialogOptions options;
            options.message = app_->name();
            options.informative_text =
                "Version " + app_->version() + "\n\n© 2024 ClipBook. All rights reserved.";
            options.buttons = {
                MessageDialogButton("Visit Website", MessageDialogButtonType::kNone),
                MessageDialogButton("Close", MessageDialogButtonType::kDefault)
            };
            MessageDialog::show(app_, options, [this](const MessageDialogResult &result) {
              if (result.button.type == MessageDialogButtonType::kNone) {
                app_->desktop()->openUrl("https://clipbook.app");
              }
            });
          }),
          menu::Item("Quit", [app](const CustomMenuItemActionArgs &args) {
            app->quit();
          })
      }));

  // Hide the dock icon and make the app a background app.
  app_->dock()->hide();

  browser_ = Browser::create(app);
  browser_->settings()->disableOverscrollHistoryNavigation();
  browser_->onInjectJs = [this](const InjectJsArgs &args, InjectJsAction action) {
    args.window->putProperty("pasteInFrontApp", [this](std::string text) {
      paste(text);
    });
    args.window->putProperty("hideAppWindow", [this]() {
      hide();
    });
    action.proceed();
  };

  browser_->onCanExecuteCommand =
      [this](const CanExecuteCommandArgs &args, CanExecuteCommandAction action) {
        if (app_->isProduction()) {
          action.cannot();
        } else {
          action.can();
        }
      };

  // Hide the window when the focus is lost.
  if (app_->isProduction()) {
    browser_->onFocusLost += [](const FocusLost &event) {
      event.browser->hide();
    };
  }

  // Hide all standard window buttons.
  browser_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  browser_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  browser_->setWindowButtonVisible(WindowButtonType::kClose, false);

  // Hide window title and title bar.
  browser_->setWindowTitleVisible(false);
  browser_->setWindowTitlebarVisible(false);

  // Move the window to the active desktop when the app is activated.
  browser_->setWindowDisplayPolicy(WindowDisplayPolicy::kMoveToActiveDesktop);

  // Display the window always on top of other windows.
  browser_->setAlwaysOnTop(true);

  browser_->loadUrl(app->baseUrl());
}

void MainApp::show() {
  browser_->show();
  browser_->mainFrame()->executeJavaScript("activateApp()");
}

void MainApp::hide() {
  if (browser_->isActive()) {
    browser_->hide();
  }
}

std::shared_ptr<molybden::Browser> MainApp::browser() const {
  return browser_;
}

void MainApp::setActiveAppName(const std::string &app_name) {
  browser_->mainFrame()->executeJavaScript("setActiveAppName(\"" + app_name + "\")");
}

void MainApp::clearHistory() {
  browser_->mainFrame()->executeJavaScript("clearHistory()");
}
