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

  // Restore the application theme.
  setTheme(settings_->getTheme());

  // Register a global shortcut to show the app.
  enableOpenAppShortcut();

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
    initJavaScriptApi(args.window);
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

  browser_->navigation()->loadUrlAndWait(app_->baseUrl());
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
  if (settings_->shouldWarnOnClearHistory()) {
    activate();
    MessageDialogOptions options;
    options.message = "Are you sure you want to clear entire history?";
    options.informative_text = "This action cannot be undone.";
    options.buttons = {
        MessageDialogButton("Clear", MessageDialogButtonType::kDefault),
        MessageDialogButton("Cancel", MessageDialogButtonType::kCancel),
    };
    MessageDialog::show(browser_, options, [this](const MessageDialogResult &result) {
      if (result.button.type == MessageDialogButtonType::kDefault) {
        std::thread([this]() {
          browser_->mainFrame()->executeJavaScript("clearHistory()");
        }).detach();
      }
    });
  } else {
    browser_->mainFrame()->executeJavaScript("clearHistory()");
  }
}

void MainApp::checkForUpdates(const std::function<void()> &complete) {
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
        MessageDialog::show(app_,
                            options,
                            [this, complete, app_update](const MessageDialogResult &result) {
                              if (result.button.type == MessageDialogButtonType::kDefault) {
                                app_update->onAppUpdateInstalled += [this, complete](const AppUpdateInstalled &event) {
                                  activate();
                                  auto app_version = event.app_update->version();
                                  MessageDialogOptions options;
                                  options.title = "Restart Required";
                                  options.message =
                                      app_->name() + " has been updated to version " + app_version +
                                      ".";
                                  options.informative_text = "Please restart the application to apply the update.";
                                  options.buttons = {
                                      MessageDialogButton("Restart",
                                                          MessageDialogButtonType::kDefault),
                                      MessageDialogButton("Later",
                                                          MessageDialogButtonType::kCancel),
                                  };
                                  MessageDialog::show(app_,
                                                      options,
                                                      [this, complete](const MessageDialogResult &result) {
                                                        complete();
                                                        if (result.button.type ==
                                                            MessageDialogButtonType::kDefault) {
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
                                  options.buttons.emplace_back("Close",
                                                               MessageDialogButtonType::kDefault);
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

void MainApp::setTheme(const std::string &theme) {
  if (theme == "dark") {
    app_->setTheme(AppTheme::kDark);
  }
  if (theme == "light") {
    app_->setTheme(AppTheme::kLight);
  }
  if (theme == "system") {
    app_->setTheme(AppTheme::kSystem);
  }
}

void MainApp::showSettingsWindow() {
  if (settings_window_ && !settings_window_->isClosed()) {
    settings_window_->show();
    return;
  }

  settings_window_ = Browser::create(app_);
  settings_window_->onInjectJs = [this](const InjectJsArgs &args, InjectJsAction action) {
    initJavaScriptApi(args.window);
    action.proceed();
  };
  settings_window_->onCanExecuteCommand =
      [this](const CanExecuteCommandArgs &args, CanExecuteCommandAction action) {
        if (app_->isProduction()) {
          action.cannot();
        } else {
          action.can();
        }
      };
  settings_window_->navigation()->loadUrlAndWait(app_->baseUrl() + "/settings");
  settings_window_->setWindowTitleVisible(false);
  settings_window_->setWindowTitlebarVisible(false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kMaximize, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kRestore, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  settings_window_->setSize(700, 520);
  settings_window_->centerWindow();
  settings_window_->show();
}

void MainApp::initJavaScriptApi(const std::shared_ptr<molybden::JsObject> &window) {
  window->putProperty("pasteInFrontApp", [this](std::string text) {
    paste(text);
  });
  window->putProperty("hideAppWindow", [this]() {
    hide();
  });
  window->putProperty("clearEntireHistory", [this]() {
    clearHistory();
  });
  window->putProperty("zoomIn", [window]() {
    window->frame()->browser()->zoom()->in();
  });
  window->putProperty("zoomOut", [window]() {
    window->frame()->browser()->zoom()->out();
  });
  window->putProperty("enableOpenAppShortcut", [this]() {
    enableOpenAppShortcut();
  });
  window->putProperty("disableOpenAppShortcut", [this]() {
    disableOpenAppShortcut();
  });

  window->putProperty("saveTheme", [this](std::string theme) -> void {
    setTheme(theme);
    settings_->saveTheme(theme);
  });
  window->putProperty("getTheme", [this]() -> std::string {
    return settings_->getTheme();
  });
  window->putProperty("saveIgnoreConfidentialContent", [this](bool ignore) -> void {
    settings_->saveIgnoreConfidentialContent(ignore);
  });
  window->putProperty("saveIgnoreTransientContent", [this](bool ignore) -> void {
    settings_->saveIgnoreTransientContent(ignore);
  });
  window->putProperty("shouldIgnoreConfidentialContent", [this]() -> bool {
    return settings_->shouldIgnoreConfidentialContent();
  });
  window->putProperty("shouldIgnoreTransientContent", [this]() -> bool {
    return settings_->shouldIgnoreTransientContent();
  });
  window->putProperty("saveOpenAtLogin", [this](bool open) -> void {
    setOpenAtLogin(open);
    settings_->saveOpenAtLogin(open);
  });
  window->putProperty("shouldOpenAtLogin", [this]() -> bool {
    return settings_->shouldOpenAtLogin();
  });
  window->putProperty("saveWarnOnClearHistory", [this](bool warn) -> void {
    settings_->saveWarnOnClearHistory(warn);
  });
  window->putProperty("shouldWarnOnClearHistory", [this]() -> bool {
    return settings_->shouldWarnOnClearHistory();
  });
  window->putProperty("saveOpenAppShortcut", [this](std::string shortcut) -> void {
    settings_->saveOpenAppShortcut(shortcut);
  });
  window->putProperty("getOpenAppShortcut", [this]() -> std::string {
    return settings_->getOpenAppShortcut();
  });
  window->putProperty("saveCloseAppShortcut", [this](std::string shortcut) -> void {
    settings_->saveCloseAppShortcut(shortcut);
  });
  window->putProperty("getCloseAppShortcut", [this]() -> std::string {
    return settings_->getCloseAppShortcut();
  });
  window->putProperty("saveSelectNextItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveSelectNextItemShortcut(shortcut);
  });
  window->putProperty("getSelectNextItemShortcut", [this]() -> std::string {
    return settings_->getSelectNextItemShortcut();
  });
  window->putProperty("saveSelectPreviousItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveSelectPreviousItemShortcut(shortcut);
  });
  window->putProperty("getSelectPreviousItemShortcut", [this]() -> std::string {
    return settings_->getSelectPreviousItemShortcut();
  });
  window->putProperty("savePasteSelectedItemToActiveAppShortcut",
                      [this](std::string shortcut) -> void {
                        settings_->savePasteSelectedItemToActiveAppShortcut(shortcut);
                      });
  window->putProperty("getPasteSelectedItemToActiveAppShortcut", [this]() -> std::string {
    return settings_->getPasteSelectedItemToActiveAppShortcut();
  });
  window->putProperty("saveEditHistoryItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveEditHistoryItemShortcut(shortcut);
  });
  window->putProperty("getEditHistoryItemShortcut", [this]() -> std::string {
    return settings_->getEditHistoryItemShortcut();
  });
  window->putProperty("saveDeleteHistoryItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveDeleteHistoryItemShortcut(shortcut);
  });
  window->putProperty("getDeleteHistoryItemShortcut", [this]() -> std::string {
    return settings_->getDeleteHistoryItemShortcut();
  });
  window->putProperty("saveClearHistoryShortcut", [this](std::string shortcut) -> void {
    settings_->saveClearHistoryShortcut(shortcut);
  });
  window->putProperty("getClearHistoryShortcut", [this]() -> std::string {
    return settings_->getClearHistoryShortcut();
  });
  window->putProperty("saveSearchHistoryShortcut", [this](std::string shortcut) -> void {
    settings_->saveSearchHistoryShortcut(shortcut);
  });
  window->putProperty("getSearchHistoryShortcut", [this]() -> std::string {
    return settings_->getSearchHistoryShortcut();
  });
  window->putProperty("saveTogglePreviewShortcut", [this](std::string shortcut) -> void {
    settings_->saveTogglePreviewShortcut(shortcut);
  });
  window->putProperty("getTogglePreviewShortcut", [this]() -> std::string {
    return settings_->getTogglePreviewShortcut();
  });
  window->putProperty("saveShowMoreActionsShortcut", [this](std::string shortcut) -> void {
    settings_->saveShowMoreActionsShortcut(shortcut);
  });
  window->putProperty("getShowMoreActionsShortcut", [this]() -> std::string {
    return settings_->getShowMoreActionsShortcut();
  });
  window->putProperty("saveZoomUIInShortcut", [this](std::string shortcut) -> void {
    settings_->saveZoomUIInShortcut(shortcut);
  });
  window->putProperty("getZoomUIInShortcut", [this]() -> std::string {
    return settings_->getZoomUIInShortcut();
  });
  window->putProperty("saveZoomUIOutShortcut", [this](std::string shortcut) -> void {
    settings_->saveZoomUIOutShortcut(shortcut);
  });
  window->putProperty("getZoomUIOutShortcut", [this]() -> std::string {
    return settings_->getZoomUIOutShortcut();
  });
}
