#include "main_app.h"

using namespace molybden;

std::string kUpdatesServerUrl = "https://vladimir-ikryanov.github.io/Molybden-AppUpdate/appcast.xml";

MainApp::MainApp(const std::shared_ptr<App> &app) : app_(app) {
  app_->onUpdateInstalled += [app](const UpdateInstalled &event) {
    LOG(INFO) << "Update installed: " << event.version;
//    MessageDialogOptions options;
//    options.message = "Update installed";
//    options.informative_text = event.app->name() + " has been updated to version " + event.version
//        + ". Restart the app to apply the update.";
//    options.buttons = {
//        MessageDialogButton("Restart", MessageDialogButtonType::kDefault),
//        MessageDialogButton("Cancel", MessageDialogButtonType::kCancel),
//    };
//    MessageDialog::show(app, options, [app](const MessageDialogResult &result) {
//      if (result.button.type == MessageDialogButtonType::kDefault) {
//        app->restart();
//      }
//    });
  };

  app_->onCheckForUpdate = [](const CheckForUpdateArgs &args, CheckForUpdateAction action) {
    LOG(INFO) << "Checking for updates...";
    if (args.update_package.has_value()) {
      LOG(INFO) << "Update available: " << args.update_package.value().version;
      action.install(args.update_package.value());
    } else {
//      MessageDialogOptions options;
//      options.message = "You're up to date!";
//      options.informative_text = args.app->name() + " " + args.app->version()
//          + " is currently the newest version available.";
//      MessageDialog::show(args.app, options);
//      // Dismiss what? I don't have an update package. Dismiss the package I don't have?
      action.dismiss();
    }
  };

  app_->onCheckForUpdateFailed += [app](const CheckForUpdateFailed &event) {
    LOG(ERROR) << "Update check failed: " << event.message;
//    MessageDialogOptions options;
//    options.message = "Update check failed";
//    options.informative_text = event.message;
//    MessageDialog::show(app, options);
  };

  app_->onUpdateProgressChanged += [](const UpdateProgressChanged &event) {
    LOG(INFO) << "Update progress: " << event.progress;
  };

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
            clearHistory();
          }),
          menu::Separator(),
          menu::About(app_),
          menu::Item("Check for Updates...", [this](const CustomMenuItemActionArgs &args) {
            app_->updateChecker()->checkNow(kUpdatesServerUrl);
          }),
          menu::Separator(),
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
//  browser_->setWindowDisplayPolicy(WindowDisplayPolicy::kMoveToActiveDesktop);

  // Display the window always on top of other windows.
  browser_->setAlwaysOnTop(true);

  browser_->loadUrl(app->baseUrl());
}

void MainApp::show() {
  browser_->show();
  browser_->mainFrame()->executeJavaScript("forceRerender()");
  browser_->mainFrame()->executeJavaScript("focusHistory()");
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
