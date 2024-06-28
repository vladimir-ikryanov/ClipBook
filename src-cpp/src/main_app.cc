#include <thread>
#include <iostream>
#include <fstream>
#include <filesystem>

#include "main_app.h"

using namespace molybden;

namespace fs = std::filesystem;

std::string kKeyboardShortcutsUrl =
    "https://clipbook.app/blog/keyboard-shortcuts/?utm_source=app&utm_medium=help";
std::string kProductUpdatesUrl =
    "https://clipbook.app/tags/updates/?utm_source=app&utm_medium=help";
std::string kContactSupportUrl =
    "mailto:vladimir.ikryanov@gmail.com?subject=ClipBook%20Support&body=Please%20describe%20your%20issue%20here.%";

MainApp::MainApp(const std::shared_ptr<App> &app, const std::shared_ptr<AppSettings> &settings)
    : app_(app), first_run_(false), settings_(settings) {
  request_interceptor_ = std::make_shared<UrlRequestInterceptor>();
}

bool MainApp::init() {
  app_->profile()->network()->onInterceptUrlRequest = [this](const InterceptUrlRequestArgs &args,
                                                             InterceptUrlRequestAction action) {
    request_interceptor_->intercept(args, std::move(action));
  };

  std::string filePath = getUserDataDir() + "/version.txt";
  if (!fs::exists(filePath)) {
    std::ofstream outputFile(filePath);
    if (outputFile.is_open()) {
      outputFile << app_->version() << std::endl;
      outputFile.close();
    }
    first_run_ = true;
  } else {
    first_run_ = false;
  }
  return first_run_;
}

void MainApp::launch() {
  auto tray = Tray::create(app_);
  tray->setImage(app_->getPath(PathKey::kAppResources) + "/imageTemplate.png");
  tray->setMenu(CustomMenu::create(
      {
          menu::Item("Open " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
            show();
          }, Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT)),
          menu::Separator(),
          menu::Item("Settings...", [this](const CustomMenuItemActionArgs &args) {
            showSettingsWindow();
          }),
          menu::Separator(),
          menu::Item("Clear all", [this](const CustomMenuItemActionArgs &args) {
            clearHistory();
          }),
          menu::Separator(),
          menu::Menu("Help", {
              menu::Item("Keyboard Shortcuts", [this](const CustomMenuItemActionArgs &args) {
                app_->desktop()->openUrl(kKeyboardShortcutsUrl);
              }),
              menu::Item("Product Updates", [this](const CustomMenuItemActionArgs &args) {
                app_->desktop()->openUrl(kProductUpdatesUrl);
              }),
              menu::Item("Contact Support", [this](const CustomMenuItemActionArgs &args) {
                app_->desktop()->openUrl(kContactSupportUrl);
              }),
          }),
          menu::Separator(),
          menu::Item("About " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
            showAboutDialog();
          }),
          menu::Item("Check for Updates...", [this](const CustomMenuItemActionArgs &args) {
              args.menu_item->setEnabled(false);
              checkForUpdates([args]() {
                  args.menu_item->setEnabled(true);
              });
          }),
          menu::Item("Quit", [this](const CustomMenuItemActionArgs &) {
            std::thread([this]() {
              app_->quit();
            }).detach();
          })
      }));

  browser_ = Browser::create(app_);
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

  // Set the initial window size and position if it's the first run.
  if (first_run_ || !app_->isProduction()) {
    browser_->setSize(1080, 640);
    browser_->centerWindow();
  }

  browser_->loadUrl(app_->baseUrl());

  app_->setTheme(settings_->getTheme());
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

std::shared_ptr<molybden::App> MainApp::app() const {
  return app_;
}

std::shared_ptr<molybden::Browser> MainApp::browser() const {
  return browser_;
}

std::shared_ptr<AppSettings> MainApp::settings() const {
  return settings_;
}

void MainApp::setActiveAppName(const std::string &app_name) {
  browser_->mainFrame()->executeJavaScript("setActiveAppName(\"" + app_name + "\")");
}

void MainApp::clearHistory() {
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
        browser_->mainFrame()->executeJavaScript("clearHistory()");
      }).detach();
    }
  });
}

void MainApp::checkForUpdates(const std::function<void()>& complete) {
  app_->checkForUpdate(getUpdateServerUrl(), [this, complete](const CheckForUpdateResult &result) {
    std::string error_msg = result.error_message;
    if (!error_msg.empty()) {
      activate();
      MessageDialogOptions options;
      options.title = "Update Check Failed";
      options.type = MessageDialogType::kError;
      options.message = "Oops! An error occurred while checking for updates :(";
      options.informative_text = error_msg;
      options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
      MessageDialog::show(app_, options);
      complete();
    } else {
      auto app_update = result.app_update;
      if (app_update) {
        activate();
        MessageDialogOptions options;
        options.title = "Update Available";
        options.message = "A new version of " + app_->name() + " is available.";
        options.informative_text = "Would you like to update?";
        options.buttons = {
            MessageDialogButton("Update", MessageDialogButtonType::kDefault),
            MessageDialogButton("Later", MessageDialogButtonType::kCancel),
        };
        MessageDialog::show(app_, options, [this, complete, app_update](const MessageDialogResult &result) {
          if (result.button.type == MessageDialogButtonType::kDefault) {
            app_update->onAppUpdateInstalled += [this, complete](const AppUpdateInstalled &event) {
              activate();
              auto app_version = event.app_update->version();
              MessageDialogOptions options;
              options.title = "Restart Required";
              options.message = app_->name() + " has been updated to version " + app_version + ".";
              options.informative_text = "Please restart the application to apply the update.";
              options.buttons = {
                  MessageDialogButton("Restart", MessageDialogButtonType::kDefault),
                  MessageDialogButton("Later", MessageDialogButtonType::kCancel),
              };
              MessageDialog::show(app_, options, [this, complete](const MessageDialogResult &result) {
                complete();
                if (result.button.type == MessageDialogButtonType::kDefault) {
                  std::thread([this]() {
                      app_->restart();
                  }).detach();
                }
              });
            };

            app_update->onAppUpdateFailed += [this, complete](const AppUpdateFailed &event) {
              activate();
              MessageDialogOptions options;
              options.title = "Update Failed";
              options.type = MessageDialogType::kError;
              options.message = "An error occurred while installing the update :(";
              options.informative_text = event.message;
              options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
              MessageDialog::show(app_, options);
              complete();
            };

            app_update->install();
          } else {
            app_update->dismiss();
            complete();
          }
        });
      } else {
        activate();
        MessageDialogOptions options;
        options.title = "Up to Date";
        options.message = app_->name() + " is up to date!";
        options.informative_text = "You are using the latest version of " + app_->name() + ".";
        options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
        MessageDialog::show(app_, options);
        complete();
      }
    }
  });
}

void MainApp::showAboutDialog() {
  activate();
  MessageDialogOptions options;
  options.title = "About " + app_->name();
  options.message = app_->name();
  options.informative_text =
      "Version " + app_->version() + "\n\n(c) 2024 ClipBook. All rights reserved.";
  options.buttons = {
      MessageDialogButton("Visit Website", MessageDialogButtonType::kNone),
      MessageDialogButton("Close", MessageDialogButtonType::kDefault)
  };
  MessageDialog::show(app_, options, [this](const MessageDialogResult &result) {
    if (result.button.type == MessageDialogButtonType::kNone) {
      app_->desktop()->openUrl("https://clipbook.app?utm_source=app&utm_medium=about");
    }
  });
}

void MainApp::showSettingsWindow() {
  if (settings_window_ && !settings_window_->isClosed()) {
    settings_window_->show();
    return;
  }

  settings_window_ = Browser::create(app_);
  settings_window_->onInjectJs = [](const InjectJsArgs &args, InjectJsAction action) {
    action.proceed();
  };
  settings_window_->loadUrl(app_->baseUrl() + "/settings");
  settings_window_->setWindowTitleVisible(false);
  settings_window_->setWindowTitlebarVisible(false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kMaximize, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kRestore, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  settings_window_->setSize(700, 500);
  settings_window_->centerWindow();
  settings_window_->show();
}
