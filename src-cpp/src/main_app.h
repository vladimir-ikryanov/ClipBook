#ifndef CLIPBOOK_MAIN_APP_H_
#define CLIPBOOK_MAIN_APP_H_

#include <memory>
#include <string>

#include "molybden.hpp"
#include "app_settings.h"
#include "url_request_interceptor.h"

class MainApp : public std::enable_shared_from_this<MainApp> {
 public:
  explicit MainApp(const std::shared_ptr<molybden::App> &app,
                   const std::shared_ptr<AppSettings> &settings);

  [[nodiscard]] std::shared_ptr<molybden::App> app() const;
  [[nodiscard]] std::shared_ptr<molybden::Browser> browser() const;
  [[nodiscard]] std::shared_ptr<AppSettings> settings() const;

  virtual bool init();
  virtual void launch();

  virtual void show();
  virtual void hide();
  virtual void activate() = 0;
  virtual void paste() = 0;
  virtual void paste(const std::string &text) = 0;
  virtual void copyToClipboard(const std::string &text) = 0;
  virtual void setOpenAtLogin(bool open) = 0;

 protected:
  void setActiveAppName(const std::string &app_name);
  void clearHistory();
  void checkForUpdates(bool user_initiated = false);
  void checkForUpdates(const std::function<void()> &complete, bool user_initiated);
  void runUpdateChecker();
  void showAboutDialog();
  void showUpToDateDialog(const std::function<void()> &complete);
  void showRestartRequiredDialog(const std::string &app_version,
                                 const std::function<void()> &complete);
  void showUpdateFailedDialog(const std::string &text, const std::function<void()> &complete);
  void showUpdateCheckFailedDialog(const std::string &error_msg,
                                   const std::function<void()> &complete);
  void showUpdateAvailableDialog(const std::shared_ptr<molybden::AppUpdate> &app_update,
                                 const std::function<void()> &complete);
  void showSettingsWindow();
  void setTheme(const std::string &theme);
  void initJavaScriptApi(const std::shared_ptr<molybden::JsObject> &window);

  virtual void enableOpenAppShortcut() = 0;
  virtual void disableOpenAppShortcut() = 0;
  virtual std::string getUserDataDir() = 0;
  virtual std::string getUpdateServerUrl() = 0;

 protected:
  bool first_run_;
  bool auto_hide_disabled_;
  bool app_window_visible_;
  bool checking_for_updates_;
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Browser> app_window_;
  std::shared_ptr<molybden::Browser> settings_window_;
  std::shared_ptr<molybden::CustomMenuItem> open_menu_item_;
  std::shared_ptr<molybden::CustomMenuItem> check_for_updates_item_;
  std::shared_ptr<AppSettings> settings_;

 private:
  std::shared_ptr<UrlRequestInterceptor> request_interceptor_;
};

#endif // CLIPBOOK_MAIN_APP_H_
