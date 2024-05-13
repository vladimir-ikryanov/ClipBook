#include <thread>
#include <iostream>
#include <fstream>
#include <filesystem>

#include "main_app.h"

using namespace molybden;

namespace fs = std::filesystem;

std::string kKeyboardShortcutsUrl =
    "https://clipbook.app/blog/keyboard-shortcuts/?utm_source=app&utm_medium=help";
std::string kContactSupportUrl =
    "mailto:vladimir.ikryanov@gmail.com?subject=ClipBook%20Support&body=Please%20describe%20your%20issue%20here.%";

MainApp::MainApp(const std::shared_ptr<App> &app) : app_(app), first_run_(false) {
  dark_menu_item_ =
      menu::CheckboxItem("Dark", [this](const CustomCheckboxMenuItemActionArgs &args) {
        app_->setTheme(AppTheme::kDark);
        dark_menu_item_->setChecked(true);
        light_menu_item_->setChecked(false);
        system_menu_item_->setChecked(false);
      });
  light_menu_item_ =
      menu::CheckboxItem("Light", [this](const CustomCheckboxMenuItemActionArgs &args) {
        app_->setTheme(AppTheme::kLight);
        dark_menu_item_->setChecked(false);
        light_menu_item_->setChecked(true);
        system_menu_item_->setChecked(false);
      });
  system_menu_item_ =
      menu::CheckboxItem("System", [this](const CustomCheckboxMenuItemActionArgs &args) {
        app_->setTheme(AppTheme::kSystem);
        dark_menu_item_->setChecked(false);
        light_menu_item_->setChecked(false);
        system_menu_item_->setChecked(true);
      });
  system_menu_item_->setChecked(true);
}

bool MainApp::init() {
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
          menu::Menu("Appearance", {
              dark_menu_item_,
              light_menu_item_,
              system_menu_item_
          }),
          menu::Item("Clear all", [this](const CustomMenuItemActionArgs &args) {
              clearHistory();
          }),
          menu::Separator(),
          menu::Menu("Help", {
              menu::Item("Keyboard Shortcuts", [this](const CustomMenuItemActionArgs &args) {
                  app_->desktop()->openUrl(kKeyboardShortcutsUrl);
              }),
              menu::Item("Contact Support", [this](const CustomMenuItemActionArgs &args) {
                  app_->desktop()->openUrl(kContactSupportUrl);
              }),
          }),
          menu::Separator(),
          menu::Item("About " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
              showAboutDialog();
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
