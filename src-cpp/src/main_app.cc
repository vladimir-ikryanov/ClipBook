#include <thread>
#include <iostream>
#include <fstream>
#include <filesystem>
#include <utility>

#include "main_app.h"
#include "utils.h"
#include "webview.h"

#ifdef OFFICIAL_BUILD
#include "licensing/licensing.h"
#endif

using namespace molybden;

namespace fs = std::filesystem;

std::string kKeyboardShortcutsUrl =
    "https://clipbook.app/blog/keyboard-shortcuts/?utm_source=clipbook";
std::string kProductUpdatesUrl =
    "https://clipbook.app/blog/?utm_source=clipbook";
std::string kContactSupportUrl =
    "mailto:vladimir.ikryanov@clipbook.app?subject=ClipBook%20Support&body=Please%20describe%20your%20issue%20here.";
std::string kFeatureRequestUrl =
    "https://feedback.clipbook.app/?utm_source=clipbook";
int32_t kUpdateCheckIntervalInHours = 48;

MainApp::MainApp(const std::shared_ptr<App> &app, const std::shared_ptr<AppSettings> &settings)
    : app_(app),
      first_run_(false),
      auto_hide_disabled_(false),
      app_window_visible_(false),
      checking_for_updates_(false),
      app_paused_(false),
      after_system_reboot_(false),
      settings_(settings) {
  request_interceptor_ = std::make_shared<UrlRequestInterceptor>(
      app_->profile()->path(), app_->getPath(molybden::PathKey::kAppResources));
}

bool MainApp::init() {
  app_->profile()->network()->onInterceptUrlRequest = [this](const InterceptUrlRequestArgs &args,
                                                             InterceptUrlRequestAction action) {
    request_interceptor_->intercept(args, std::move(action));
  };

  const auto label = "Open " + app_->name();
  open_app_item_ = menu::Item(label, [this](const CustomMenuItemActionArgs &args) {
    show();
  });

  open_settings_item_ = menu::Item("Settings...", [this](const CustomMenuItemActionArgs &args) {
    showSettingsWindow();
  });

  auto pause_label = "Pause " + app_->name();
  pause_resume_item_ = menu::Item(pause_label, [this](const CustomMenuItemActionArgs &args) {
    if (isPaused()) {
      resume();
    } else {
      pause();
    }
  });

  check_for_updates_item_ =
      menu::Item("Check for Updates...", [this](const CustomMenuItemActionArgs &args) {
        checkForUpdates(true);
      });

  // Restore the application theme.
  setTheme(settings_->getTheme());

  // Register a global shortcut to show the app.
  enableOpenAppShortcut();
  // Update the pause/resume shortcut.
  updatePauseResumeShortcut();
  // Update the open settings shortcut.
  updateOpenSettingsShortcut();

  // Check if the app is running after system reboot.
  auto system_boot_time = getSystemBootTime();
  auto last_system_boot_time = settings_->getLastSystemBootTime();
  if (system_boot_time > last_system_boot_time) {
    after_system_reboot_ = true;
    settings_->saveLastSystemBootTime(system_boot_time);
  }

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
  if (settings_->shouldShowIconInMenuBar()) {
    createTray();
  }

  BrowserOptions options;
  options.window_type = WindowType::kFloating;
  app_window_ = Browser::create(app_, options);
  app_window_->settings()->disableOverscrollHistoryNavigation();
  app_window_->onInjectJs = [this](const InjectJsArgs &args, InjectJsAction action) {
    initJavaScriptApi(args.window);
    action.proceed();
  };

  app_window_->onCanExecuteCommand =
      [this](const CanExecuteCommandArgs &args, CanExecuteCommandAction action) {
        if (app_->isProduction()) {
          action.cannot();
        } else {
          if (args.command_id == BrowserCommandId::kDevTools) {
            action.can();
          } else {
            action.cannot();
          }
        }
      };

  // Hide the window when the focus is lost.
  app_window_->onFocusLost += [this](const FocusLost &event) {
    if (app()->isProduction()) {
      hide();
    }
  };

  // Hide all standard window buttons.
  app_window_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  app_window_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  app_window_->setWindowButtonVisible(WindowButtonType::kClose, false);

  // Hide window title and title bar.
  app_window_->setWindowTitleVisible(false);
  app_window_->setWindowTitlebarVisible(false);

  // Display the window always on top of other windows.
  app_window_->setAlwaysOnTop(true);

  // Disable window animation to make the app feel faster.
  app_window_->setWindowAnimationEnabled(false);

  // Set the initial window size and position if it's the first run.
  if (first_run_ || !app_->isProduction()) {
    app_window_->setSize(820, 540);
    app_window_->centerWindow();
  }

  app_window_->navigation()->loadUrlAndWait(app_->baseUrl());

#ifdef OFFICIAL_BUILD
  activateLicense([this](const std::string &licenseKey) {
    settings_->saveLicenseKey(licenseKey);
    settings_->setShouldDisplayThankYouDialog(true);
    app_window_->navigation()->reloadIgnoringCache();
  }, [](const std::string &error) {
    LOG(ERROR) << "Failed to activate a license key: " << error;
  });
#endif
}

void MainApp::show() {
  app_window_->show();
  auto frame = app_window_->mainFrame();
  if (frame) {
    frame->executeJavaScript("activateApp()");
  }
  app_window_visible_ = true;

  // Request the app to check for updates when it's shown/active.
  if (settings_->shouldCheckForUpdatesAutomatically()) {
    checkForUpdates();
  }
}

void MainApp::hide() {
  if (!auto_hide_disabled_) {
    auto frame = app_window_->mainFrame();
    if (frame) {
      frame->executeJavaScript("closeCommandsPopup()");
    }
    app_window_->hide();
    app_window_visible_ = false;
  }
}

std::shared_ptr<molybden::App> MainApp::app() const {
  return app_;
}

std::shared_ptr<molybden::Browser> MainApp::browser() const {
  return app_window_;
}

std::shared_ptr<AppSettings> MainApp::settings() const {
  return settings_;
}

void MainApp::setActiveAppInfo(const std::string &app_name, const std::string& app_icon) {
  auto frame = app_window_->mainFrame();
  if (frame) {
    frame->executeJavaScript("setActiveAppInfo(\"" + app_name + "\", \"" + app_icon + "\")");
  }
}

void MainApp::clearHistory() {
  if (settings_->shouldWarnOnClearHistory()) {
    auto_hide_disabled_ = true;
    activate();
    MessageDialogOptions options;
    options.message = "Are you sure you want to clear entire history?";
    options.informative_text = "This action cannot be undone.";
    options.buttons = {
        MessageDialogButton("Clear", MessageDialogButtonType::kDefault),
        MessageDialogButton("Cancel", MessageDialogButtonType::kCancel),
    };
    MessageDialog::show(app_window_, options, [this](const MessageDialogResult &result) {
      if (result.button.type == MessageDialogButtonType::kDefault) {
        std::thread([this]() {
          app_window_->mainFrame()->executeJavaScript("clearHistory()");
        }).detach();
      }
      auto_hide_disabled_ = false;
    });
  } else {
    app_window_->mainFrame()->executeJavaScript("clearHistory()");
  }
}

void MainApp::checkForUpdates(bool user_initiated) {
  // Skip the update check if it's already in progress.
  if (checking_for_updates_) {
    return;
  }

  // Skip the update check when the last check was less than 48 hours ago.
  if (!user_initiated) {
    auto last_update_check_time = settings_->getLastUpdateCheckTime();
    auto current_time = getCurrentTimeMillis();
    auto elapsed_time = current_time - last_update_check_time;
    if (elapsed_time < (kUpdateCheckIntervalInHours * 60 * 60 * 1000)) {
      return;
    }
  }

  // Save the last update check time.
  settings_->saveLastUpdateCheckTime(getCurrentTimeMillis());

  checking_for_updates_ = true;
  check_for_updates_item_->setEnabled(false);
  if (settings_window_) {
    auto settings_frame = settings_window_->mainFrame();
    if (settings_frame) {
      settings_frame->executeJavaScript("setUpdateCheckInProgress(true)");
    }
  }
  checkForUpdates([this]() {
    checking_for_updates_ = false;
    check_for_updates_item_->setEnabled(true);
    std::thread([this]() {
      if (settings_window_) {
        auto settings_frame = settings_window_->mainFrame();
        if (settings_frame) {
          settings_frame->executeJavaScript("setUpdateCheckInProgress(false)");
        }
      }
    }).detach();
  }, user_initiated);
}

void MainApp::checkForUpdates(const std::function<void()> &complete, bool user_initiated) {
  auto url = getUpdateServerUrl();
  app_->checkForUpdate(url, [this, complete, user_initiated](const CheckForUpdateResult &result) {
    std::string error_msg = result.error_message;
    if (!error_msg.empty()) {
      if (user_initiated) {
        showUpdateCheckFailedDialog(error_msg, complete);
      } else {
        complete();
      }
    } else {
      auto app_update = result.app_update;
      if (app_update) {
        showUpdateAvailableDialog(app_update, complete);
      } else {
        if (user_initiated) {
          showUpToDateDialog(complete);
        } else {
          complete();
        }
      }
    }
  });
}

void MainApp::showUpdateAvailableDialog(const std::shared_ptr<molybden::AppUpdate> &app_update,
                                        const std::function<void()> &complete) {
  MessageDialogOptions options;
  options.title = "Update Available";
  options.message = "A new version of " + app_->name() + " is available.";
  options.informative_text = "Would you like to update?";
  options.buttons = {
      MessageDialogButton("Update", MessageDialogButtonType::kDefault),
      MessageDialogButton("Later", MessageDialogButtonType::kCancel),
  };
  auto callback = [this, complete, app_update](const MessageDialogResult &result) {
    if (result.button.type == MessageDialogButtonType::kDefault) {
      app_update->onAppUpdateInstalled += [this, complete](const AppUpdateInstalled &event) {
        showRestartRequiredDialog(event.app_update->version(), complete);
      };
      app_update->onAppUpdateFailed += [this, complete](const AppUpdateFailed &event) {
        showUpdateFailedDialog(event.message, complete);
      };
      app_update->install();
    } else {
      app_update->dismiss();
      complete();
    }
  };
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this, callback](const MessageDialogResult &result) {
      callback(result);
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options, callback);
  }
}

void MainApp::showRestartRequiredDialog(const std::string &app_version,
                                        const std::function<void()> &complete) {
  MessageDialogOptions options;
  options.title = "Restart Required";
  options.message = app_->name() + " has been updated to version " + app_version + ".";
  options.informative_text = "Please restart the application to apply the update.";
  options.buttons = {
      MessageDialogButton("Restart", MessageDialogButtonType::kDefault),
      MessageDialogButton("Later", MessageDialogButtonType::kCancel),
  };
  auto callback = [this, complete](const MessageDialogResult &result) {
    complete();
    if (result.button.type == MessageDialogButtonType::kDefault) {
      std::thread([this]() {
        app_->restart();
      }).detach();
    }
  };
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this, callback](const MessageDialogResult &result) {
      callback(result);
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options, callback);
  }
}

void MainApp::showUpdateFailedDialog(const std::string &text,
                                     const std::function<void()> &complete) {
  MessageDialogOptions options;
  options.title = "Update Failed";
  options.type = MessageDialogType::kError;
  options.message = "An error occurred while installing the update :(";
  options.informative_text = text;
  options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this](const MessageDialogResult &) {
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options);
  }
  complete();
}

void MainApp::showUpdateCheckFailedDialog(const std::string &error_msg,
                                          const std::function<void()> &complete) {
  MessageDialogOptions options;
  options.title = "Update Check Failed";
  options.type = MessageDialogType::kError;
  options.message = "Oops! An error occurred while checking for updates :(";
  options.informative_text = error_msg;
  options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this](const MessageDialogResult &) {
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options);
  }
  complete();
}

void MainApp::showUpToDateDialog(const std::function<void()> &complete) {
  MessageDialogOptions options;
  options.title = "Up to Date";
  options.message = app_->name() + " is up to date!";
  options.informative_text = "You are using the latest version of " + app_->name() + ".";
  options.buttons.emplace_back("Close", MessageDialogButtonType::kDefault);
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this](const MessageDialogResult &) {
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options);
  }
  complete();
}

void MainApp::showAboutDialog() {
  MessageDialogOptions options;
  options.title = "About " + app_->name();
  options.message = app_->name();

  std::string arch;
#ifdef ARCH_MAC_X64
  arch = "(Intel)";
#endif
#ifdef ARCH_MAC_ARM64
  arch = "(Apple Silicon)";
#endif
#ifdef ARCH_MAC_UNIVERSAL
  arch = "(Universal)";
#endif

  options.informative_text =
      "Version " + app_->version() + " " + arch + "\n\n© 2025 ClipBook. All rights reserved.";
  options.buttons = {
      MessageDialogButton("Visit Website", MessageDialogButtonType::kNone),
      MessageDialogButton("Close", MessageDialogButtonType::kDefault)
  };
  if (app_window_visible_) {
    auto_hide_disabled_ = true;
    MessageDialog::show(app_window_, options, [this](const MessageDialogResult &result) {
      if (result.button.type == MessageDialogButtonType::kNone) {
        app_->desktop()->openUrl("https://clipbook.app?utm_source=app&utm_medium=about");
      }
      auto_hide_disabled_ = false;
    });
  } else {
    activate();
    MessageDialog::show(app_, options);
  }
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
  showSettingsWindow("/settings");
}

void MainApp::showSettingsWindow(const std::string &section) {
  if (settings_window_ && !settings_window_->isClosed()) {
    settings_window_->navigation()->loadUrl(app_->baseUrl() + section);
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
  settings_window_->navigation()->loadUrlAndWait(app_->baseUrl() + section);
  settings_window_->setWindowTitleVisible(false);
  settings_window_->setWindowTitlebarVisible(false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kMaximize, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kRestore, false);
  settings_window_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  settings_window_->setSize(700, 760);
  settings_window_->centerWindow();
  settings_window_->show();
}

void MainApp::showWelcomeWindow() {
  welcome_window_ = Browser::create(app_);
  welcome_window_->onInjectJs = [this](const InjectJsArgs &args, InjectJsAction action) {
    initJavaScriptApi(args.window);
    action.proceed();
  };
  welcome_window_->navigation()->loadUrlAndWait(app_->baseUrl() + "/welcome");
  welcome_window_->setWindowTitleVisible(false);
  welcome_window_->setWindowTitlebarVisible(false);
  welcome_window_->setWindowButtonVisible(WindowButtonType::kMaximize, false);
  welcome_window_->setWindowButtonVisible(WindowButtonType::kMinimize, false);
  welcome_window_->setWindowButtonVisible(WindowButtonType::kRestore, false);
  welcome_window_->setWindowButtonVisible(WindowButtonType::kZoom, false);
  welcome_window_->setSize(500, 700);
  welcome_window_->centerWindow();
  welcome_window_->show();
}

void MainApp::initJavaScriptApi(const std::shared_ptr<molybden::JsObject> &window) {
  // Welcome window.
  window->putProperty("enableAccessibilityAccess", [this]() {
    paste();
    welcome_window_->loadUrl(app_->baseUrl() + "/enjoy");
  });
  window->putProperty("openHistory", [this]() {
    welcome_window_->hide();
    show();
  });
  window->putProperty("openUrl", [this](std::string url) {
    app_->desktop()->openUrl(url);
  });

  // App window.
  window->putProperty("pasteItemInFrontApp",
                      [this](std::string text, std::string imageFileName, std::string imageText) {
                        paste(text, imageFileName, imageText);
                      });
  window->putProperty("pressReturn", [this]() {
    sendKey(Key::kReturn);
  });
  window->putProperty("pressTab", [this]() {
    sendKey(Key::kTab);
  });
  window->putProperty("copyToClipboard",
                      [this](std::string text, std::string imageFileName, std::string imageText) {
                        copyToClipboard(text, imageFileName, imageText);
                      });
  window->putProperty("copyToClipboardAfterMerge", [this](std::string text) {
    copyToClipboardAfterMerge(std::move(text));
  });
  window->putProperty("saveImageAsFile", [this](std::string imageFileName, int imageWidth, int imageHeight) {
    saveImageAsFile(imageFileName, imageWidth, imageHeight);
  });
  window->putProperty("deleteImage", [this](std::string imageFileName) {
    deleteImage(std::move(imageFileName));
  });
  window->putProperty("openInBrowser", [this](std::string url) {
    app_->desktop()->openUrl(url);
  });
  window->putProperty("previewLink", [this](std::string url) {
    previewLink(url);
  });
  window->putProperty("hideAppWindow", [this]() {
    hide();
  });
  window->putProperty("closeSettingsWindow", [this]() {
    if (settings_window_) {
      settings_window_->hide();
      settings_window_->close();
    }
  });
  window->putProperty("openSettingsWindow", [this]() {
    hide();
    activate();
    showSettingsWindow();
  });
  window->putProperty("clearEntireHistory", [this]() {
    clearHistory();
  });
  window->putProperty("zoomIn", [window]() {
    auto zoom = window->frame()->browser()->zoom();
    if (zoom->level() < molybden::k200) {
      zoom->in();
    }
  });
  window->putProperty("zoomOut", [window]() {
    auto zoom = window->frame()->browser()->zoom();
    if (zoom->level() > molybden::k50) {
      zoom->out();
    }
  });
  window->putProperty("canZoomIn", [window]() -> bool {
    auto zoom = window->frame()->browser()->zoom();
    return zoom->level() < molybden::k200;
  });
  window->putProperty("canZoomOut", [window]() -> bool {
    auto zoom = window->frame()->browser()->zoom();
    return zoom->level() > molybden::k50;
  });
  window->putProperty("resetZoom", [window]() {
    window->frame()->browser()->zoom()->reset();
  });
  window->putProperty("canResetZoom", [window]() -> bool {
    auto zoom = window->frame()->browser()->zoom();
    return zoom->level() != molybden::k100;
  });
  window->putProperty("enableOpenAppShortcut", [this]() {
    enableOpenAppShortcut();
  });
  window->putProperty("disableOpenAppShortcut", [this]() {
    disableOpenAppShortcut();
  });
  window->putProperty("updateOpenSettingsShortcut", [this]() {
    updateOpenSettingsShortcut();
  });
  window->putProperty("isAfterSystemReboot", [this]() -> bool {
    return after_system_reboot_;
  });
  window->putProperty("isFeedbackProvided", [this]() -> bool {
#ifdef OFFICIAL_BUILD
    return settings_->isFeedbackProvided();
#endif
    return true;
  });
  window->putProperty("setFeedbackProvided", [this](bool provided) {
#ifdef OFFICIAL_BUILD
    settings_->saveFeedbackProvided(provided);
#endif
  });
  window->putProperty("buyLicense", [this]() {
    app_->desktop()->openUrl("https://clipbook.app/checkout/");
  });
  window->putProperty("helpWithActivation", [this]() {
    app_->desktop()->openUrl("mailto:vladimir.ikryanov@clipbook.app?subject=ClipBook%20Activation%20Error&body=License%20Key:%20" + settings_->getLicenseKey());
  });
  window->putProperty("isTrial", []() -> bool {
#ifdef OFFICIAL_BUILD
    return isTrial();
#endif
    return false;
  });
  window->putProperty("getTrialDaysLeft", [this]() -> int {
#ifdef OFFICIAL_BUILD
    return getTrialDaysLeft(app_->version());
#endif
    return 0;
  });
  window->putProperty("isActivated", [this]() -> bool {
#ifdef OFFICIAL_BUILD
    return isLicenseActivated(settings_->getLicenseKey());
#endif
    return true;
  });
  window->putProperty("activateLicense", [this](std::string licenseKey) {
#ifdef OFFICIAL_BUILD
    activateLicense(licenseKey, [this]() {
      settings_window_->mainFrame()->executeJavaScript("licenseActivationCompleted('')");
    }, [this](const std::string &error) {
      settings_window_->mainFrame()->executeJavaScript(
          "licenseActivationCompleted('" + error + "')");
    });
#endif
  });
  window->putProperty("deactivateLicense", [this](std::string licenseKey) {
#ifdef OFFICIAL_BUILD
    deactivateLicense(licenseKey, [this]() {
      settings_window_->mainFrame()->executeJavaScript("licenseDeactivationCompleted('')");
    }, [this](const std::string &error) {
      settings_window_->mainFrame()->executeJavaScript(
          "licenseDeactivationCompleted('" + error + "')");
    });
#endif
  });
  window->putProperty("openSettingsLicense", [this]() {
    hide();
    showSettingsWindow("/settings/license");
  });
  window->putProperty("sendFeedback", [this](std::string text) {
#ifdef OFFICIAL_BUILD
    sendFeedback(text);
#endif
  });
  window->putProperty("shouldDisplayThankYouDialog", [this]() -> bool {
    return settings_->shouldDisplayThankYouDialog();
  });
  window->putProperty("saveDisplayThankYouDialog", [this](bool display) {
    settings_->setShouldDisplayThankYouDialog(display);
  });

  window->putProperty("saveTheme", [this](std::string theme) -> void {
    setTheme(theme);
    settings_->saveTheme(theme);
  });
  window->putProperty("getTheme", [this]() -> std::string {
    return settings_->getTheme();
  });
  window->putProperty("saveLicenseKey", [this](std::string key) -> void {
    settings_->saveLicenseKey(std::move(key));
  });
  window->putProperty("getLicenseKey", [this]() -> std::string {
    return settings_->getLicenseKey();
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
  window->putProperty("saveCheckForUpdatesAutomatically", [this](bool value) -> void {
    settings_->saveCheckForUpdatesAutomatically(value);
  });
  window->putProperty("shouldCheckForUpdatesAutomatically", [this]() -> bool {
    return settings_->shouldCheckForUpdatesAutomatically();
  });
  window->putProperty("saveWarnOnClearHistory", [this](bool warn) -> void {
    settings_->saveWarnOnClearHistory(warn);
  });
  window->putProperty("shouldWarnOnClearHistory", [this]() -> bool {
    return settings_->shouldWarnOnClearHistory();
  });
  window->putProperty("saveKeepFavoritesOnClearHistory", [this](bool keep) -> void {
    settings_->saveKeepFavoritesOnClearHistory(keep);
  });
  window->putProperty("shouldKeepFavoritesOnClearHistory", [this]() -> bool {
      return settings_->shouldKeepFavoritesOnClearHistory();
  });
  window->putProperty("saveShowIconInMenuBar", [this](bool show) -> void {
    setShowIconInMenuBar(show);
    settings_->saveShowIconInMenuBar(show);
  });
  window->putProperty("shouldShowIconInMenuBar", [this]() -> bool {
    return settings_->shouldShowIconInMenuBar();
  });
  window->putProperty("saveCopyAndMergeEnabled", [this](bool enabled) -> void {
    settings_->saveCopyAndMergeEnabled(enabled);
  });
  window->putProperty("isCopyAndMergeEnabled", [this]() -> bool {
    return settings_->isCopyAndMergeEnabled();
  });
  window->putProperty("saveCopyAndMergeSeparator", [this](std::string separator) -> void {
    settings_->saveCopyAndMergeSeparator(separator);
  });
  window->putProperty("getCopyAndMergeSeparator", [this]() -> std::string {
    return settings_->getCopyAndMergeSeparator();
  });
  window->putProperty("saveCopyToClipboardAfterMerge", [this](bool copy) -> void {
    settings_->saveCopyToClipboardAfterMerge(copy);
  });
  window->putProperty("shouldCopyToClipboardAfterMerge", [this]() -> bool {
    return settings_->shouldCopyToClipboardAfterMerge();
  });
  window->putProperty("saveClearHistoryOnQuit", [this](bool clear) -> void {
    settings_->saveClearHistoryOnQuit(clear);
  });
  window->putProperty("shouldClearHistoryOnQuit", [this]() -> bool {
    return settings_->shouldClearHistoryOnQuit();
  });
  window->putProperty("saveClearHistoryOnMacReboot", [this](bool clear) -> void {
    settings_->saveClearHistoryOnMacReboot(clear);
  });
  window->putProperty("shouldClearHistoryOnMacReboot", [this]() -> bool {
      return settings_->shouldClearHistoryOnMacReboot();
  });
  window->putProperty("saveOpenWindowStrategy", [this](std::string strategy) -> void {
    settings_->saveOpenWindowStrategy(std::move(strategy));
  });
  window->putProperty("getOpenWindowStrategy", [this]() -> std::string {
    return settings_->getOpenWindowStrategy();
  });

  // Application shortcuts.
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
  window->putProperty("saveCloseAppShortcut2", [this](std::string shortcut) -> void {
    settings_->saveCloseAppShortcut2(shortcut);
  });
  window->putProperty("getCloseAppShortcut2", [this]() -> std::string {
    return settings_->getCloseAppShortcut2();
  });
  window->putProperty("saveCloseAppShortcut3", [this](std::string shortcut) -> void {
    settings_->saveCloseAppShortcut3(shortcut);
  });
  window->putProperty("getCloseAppShortcut3", [this]() -> std::string {
    return settings_->getCloseAppShortcut3();
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
  window->putProperty("saveOpenInBrowserShortcut", [this](std::string shortcut) -> void {
    settings_->saveOpenInBrowserShortcut(shortcut);
  });
  window->putProperty("getOpenInBrowserShortcut", [this]() -> std::string {
    return settings_->getOpenInBrowserShortcut();
  });
  window->putProperty("saveCopyToClipboardShortcut", [this](std::string shortcut) -> void {
    settings_->saveCopyToClipboardShortcut(shortcut);
  });
  window->putProperty("getCopyToClipboardShortcut", [this]() -> std::string {
    return settings_->getCopyToClipboardShortcut();
  });
  window->putProperty("saveCopyTextFromImageShortcut", [this](std::string shortcut) -> void {
    settings_->saveCopyTextFromImageShortcut(shortcut);
  });
  window->putProperty("getCopyTextFromImageShortcut", [this]() -> std::string {
    return settings_->getCopyTextFromImageShortcut();
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
  window->putProperty("saveZoomUIResetShortcut", [this](std::string shortcut) -> void {
    settings_->saveZoomUIResetShortcut(shortcut);
  });
  window->putProperty("getZoomUIResetShortcut", [this]() -> std::string {
    return settings_->getZoomUIResetShortcut();
  });
  window->putProperty("saveOpenSettingsShortcut", [this](std::string shortcut) -> void {
    settings_->saveOpenSettingsShortcut(shortcut);
  });
  window->putProperty("getOpenSettingsShortcut", [this]() -> std::string {
    return settings_->getOpenSettingsShortcut();
  });
  window->putProperty("saveToggleFavoriteShortcut", [this](std::string shortcut) -> void {
    settings_->saveToggleFavoriteShortcut(shortcut);
  });
  window->putProperty("getToggleFavoriteShortcut", [this]() -> std::string {
    return settings_->getToggleFavoriteShortcut();
  });
  window->putProperty("saveNavigateToFirstItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveNavigateToFirstItemShortcut(shortcut);
  });
  window->putProperty("getNavigateToFirstItemShortcut", [this]() -> std::string {
    return settings_->getNavigateToFirstItemShortcut();
  });
  window->putProperty("saveNavigateToLastItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveNavigateToLastItemShortcut(shortcut);
  });
  window->putProperty("getNavigateToLastItemShortcut", [this]() -> std::string {
    return settings_->getNavigateToLastItemShortcut();
  });
  window->putProperty("saveNavigateToNextGroupOfItemsShortcut",
                      [this](std::string shortcut) -> void {
                        settings_->saveNavigateToNextGroupOfItemsShortcut(shortcut);
                      });
  window->putProperty("getNavigateToNextGroupOfItemsShortcut", [this]() -> std::string {
    return settings_->getNavigateToNextGroupOfItemsShortcut();
  });
  window->putProperty("saveNavigateToPrevGroupOfItemsShortcut",
                      [this](std::string shortcut) -> void {
                        settings_->saveNavigateToPrevGroupOfItemsShortcut(shortcut);
                      });
  window->putProperty("getNavigateToPrevGroupOfItemsShortcut", [this]() -> std::string {
    return settings_->getNavigateToPrevGroupOfItemsShortcut();
  });
  window->putProperty("saveSaveImageAsFileShortcut", [this](std::string shortcut) -> void {
    settings_->saveSaveImageAsFileShortcut(shortcut);
  });
  window->putProperty("getSaveImageAsFileShortcut", [this]() -> std::string {
    return settings_->getSaveImageAsFileShortcut();
  });
  window->putProperty("savePauseResumeShortcut", [this](std::string shortcut) -> void {
    settings_->savePauseResumeShortcut(shortcut);
    updatePauseResumeShortcut();
  });
  window->putProperty("getPauseResumeShortcut", [this]() -> std::string {
    return settings_->getPauseResumeShortcut();
  });
  window->putProperty("saveRenameItemShortcut", [this](std::string shortcut) -> void {
    settings_->saveRenameItemShortcut(shortcut);
  });
  window->putProperty("getRenameItemShortcut", [this]() -> std::string {
    return settings_->getRenameItemShortcut();
  });

  window->putProperty("selectAppsToIgnore", [this]() {
    selectAppsToIgnore();
  });
  window->putProperty("getAppsToIgnore", [this]() -> std::string {
    return settings_->getAppsToIgnore();
  });
  window->putProperty("setAppsToIgnore", [this](std::string apps) -> void {
    settings_->saveAppsToIgnore(apps);
  });
  window->putProperty("getAppIconAsBase64", [this](std::string app_path) -> std::string {
    return getAppIconAsBase64(app_path);
  });
  window->putProperty("getAppNameFromPath", [this](std::string app_path) -> std::string {
    return getAppNameFromPath(app_path);
  });
  window->putProperty("setTreatDigitNumbersAsColor", [this](bool treat) -> void {
    settings_->saveTreatDigitNumbersAsColor(treat);
  });
  window->putProperty("shouldTreatDigitNumbersAsColor", [this]() -> bool {
    return settings_->shouldTreatDigitNumbersAsColor();
  });
  window->putProperty("setShowPreviewForLinks", [this](bool show) -> void {
    settings_->saveShowPreviewForLinks(show);
  });
  window->putProperty("shouldShowPreviewForLinks", [this]() -> bool {
    return settings_->shouldShowPreviewForLinks();
  });
  window->putProperty("fetchLinkPreviewDetails", [this](std::string url, std::shared_ptr<JsObject> callback) {
    std::thread([this, url, callback]() {
      fetchLinkPreviewDetails(url, callback);
    }).detach();
  });
  window->putProperty("setUpdateHistoryAfterAction", [this](bool update) -> void {
    settings_->saveUpdateHistoryAfterAction(update);
  });
  window->putProperty("shouldUpdateHistoryAfterAction", [this]() -> bool {
    return settings_->shouldUpdateHistoryAfterAction();
  });
  window->putProperty("setPasteOnClick", [this](bool paste) -> void {
    settings_->savePasteOnClick(paste);
  });
  window->putProperty("shouldPasteOnClick", [this]() -> bool {
    return settings_->shouldPasteOnClick();
  });

  // Settings window.
  window->putProperty("checkForUpdates", [this]() -> void {
    std::thread([this]() {
      checkForUpdates(true);
    }).detach();
  });
}

void MainApp::fetchLinkPreviewDetails(const std::string &url, const std::shared_ptr<molybden::JsObject> &callback) {
  // If the given URL is already being fetched, ignore the request.
  if (std::find(fetch_url_requests_.begin(), fetch_url_requests_.end(), url) != fetch_url_requests_.end()) {
    LOG(INFO) << "Skip fetching link preview: " << url;
    return;
  }
  fetch_url_requests_.push_back(url);
  HeadlessWebView headless(app_, getLinkImagesDir());
  LinkPreviewDetails details;
  auto success = headless.fetchLinkPreviewDetails(url, details);
  fetch_url_requests_.remove(url);
  callback->call("run",
                 success,
                 details.title,
                 details.description,
                 details.imageFileName,
                 details.faviconFileName);
}

bool MainApp::isPaused() const {
  return app_paused_;
}

void MainApp::pause() {
  tray_->setImage(app_->getPath(PathKey::kAppResources) + "/pausedTemplate.png");
  pause_resume_item_->setTitle("Resume " + app_->name());
  app_paused_ = true;
}

void MainApp::resume() {
  tray_->setImage(app_->getPath(PathKey::kAppResources) + "/imageTemplate.png");
  pause_resume_item_->setTitle("Pause " + app_->name());
  app_paused_ = false;
}

void MainApp::setShowIconInMenuBar(bool show) {
  if (show) {
    createTray();
  } else {
    destroyTray();
  }
}

void MainApp::createTray() {
  if (tray_ && !tray_->isDestroyed()) {
    return;
  }

  tray_ = Tray::create(app_);
  if (app_paused_) {
    tray_->setImage(app_->getPath(PathKey::kAppResources) + "/pausedTemplate.png");
  } else {
    tray_->setImage(app_->getPath(PathKey::kAppResources) + "/imageTemplate.png");
  }
  tray_->onClicked += [this](const TrayClicked& event) {
    if (event.mouse_button == MouseButton::kPrimary) {
      show();
    }
    if (event.mouse_button == MouseButton::kSecondary) {
      tray_->openMenu(CustomMenu::create(
          {
              open_app_item_,
              menu::Separator(),
              menu::Menu("Help", {
                  menu::Item("Keyboard Shortcuts", [this](const CustomMenuItemActionArgs &args) {
                    app_->desktop()->openUrl(kKeyboardShortcutsUrl);
                  }),
                  menu::Separator(),
                  menu::Item("Product Updates", [this](const CustomMenuItemActionArgs &args) {
                    app_->desktop()->openUrl(kProductUpdatesUrl);
                  }),
                  menu::Item("Feature Request", [this](const CustomMenuItemActionArgs &args) {
                    app_->desktop()->openUrl(kFeatureRequestUrl);
                  }),
                  menu::Separator(),
                  menu::Item("Contact Support", [this](const CustomMenuItemActionArgs &args) {
                    app_->desktop()->openUrl(kContactSupportUrl);
                  }),
              }),
              menu::Separator(),
              menu::Item("About " + app_->name(), [this](const CustomMenuItemActionArgs &args) {
                showAboutDialog();
              }),
              check_for_updates_item_,
              open_settings_item_,
              menu::Separator(),
              pause_resume_item_,
              menu::Item("Quit", [this](const CustomMenuItemActionArgs &) {
                std::thread([this]() {
                  quit();
                }).detach();
              })
          }));
    }
  };
}

void MainApp::quit() {
  if (settings_->shouldClearHistoryOnQuit()) {
    app_window_->mainFrame()->executeJavaScript("clearHistory()");
  }
  app_->quit();
}

void MainApp::destroyTray() {
  if (tray_ && !tray_->isDestroyed()) {
    tray_->destroy();
  }
}

void MainApp::selectAppsToIgnore() {
  molybden::OpenDialogOptions options;
  options.default_path = "/Applications";
  options.button_label = "Choose";
  options.features.allow_multiple_selections = true;
  options.filters = {{"Applications", {"app"}}};
  molybden::OpenDialog::show(settings_window_, options, [this](molybden::OpenDialogResult result) {
    if (result.canceled) {
      return;
    }
    auto apps_to_ignore = settings_->getAppsToIgnore();
    for (const auto &path : result.paths) {
      if (apps_to_ignore.find(path) == std::string::npos) {
        settings_window_->mainFrame()->executeJavaScript("addAppToIgnore(\"" + path + "\")");
      }
    }
  });
}

std::string MainApp::getImagesDir() {
  return app_->profile()->path() + "/images";
}

std::string MainApp::getLinkImagesDir() {
  return app_->profile()->path() + "/images/links";
}

void MainApp::deleteImage(const std::string &imageFileName) {
  std::string filePath = getImagesDir() + "/" + imageFileName;
  if (fs::exists(filePath)) {
      fs::remove(filePath);
      auto infoFilePath = fs::path(filePath).replace_extension(".info");
      if (fs::exists(infoFilePath)) {
          fs::remove(infoFilePath);
      }
  }
}

long MainApp::getSystemBootTime() {
  return -1;
}

void MainApp::previewLink(const std::string &url) {
  if (!preview_window_ || preview_window_->isClosed()) {
    preview_window_ = Browser::create(app_);
    preview_window_->setSize(1280, 800);
    preview_window_->setAlwaysOnTop(true);
    preview_window_->centerWindow();
  }
  preview_window_->navigation()->loadUrl(url);
  preview_window_->show();
}

void MainApp::saveImageAsFile(const std::string &imageFileName, int imageWidth, int imageHeight) {
  auto_hide_disabled_ = true;
  if (save_images_dir_.empty()) {
    save_images_dir_ = getUserHomeDir();
  }
  std::string destImageFileName = "image_" + std::to_string(imageWidth) + "x" + std::to_string(imageHeight) + ".png";
  auto destImageFilePath = save_images_dir_ + "/" + destImageFileName;

  SaveDialogOptions options;
  options.title = "Save Image As";
  options.default_path = destImageFilePath;
  options.filters = {{"Images", {"PNG"}}};
  options.button_label = "Save";
  SaveDialog::show(browser(), options, [this, imageFileName](SaveDialogResult result) {
    auto_hide_disabled_ = false;
    if (!result.canceled) {
      save_images_dir_ = fs::path(result.path).parent_path().string();
      std::string srcImageFilePath = getImagesDir() + "/" + imageFileName;
      fs::copy_file(srcImageFilePath, result.path, fs::copy_options::overwrite_existing);
      // Show the saved file in Finder.
      app_->desktop()->showPath(result.path);
    }
  });
}
