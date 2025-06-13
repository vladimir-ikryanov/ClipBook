#ifndef CLIPBOOK_MAIN_APP_H_
#define CLIPBOOK_MAIN_APP_H_

#include <memory>
#include <string>
#include <list>

#include "molybden.hpp"
#include "app_settings.h"
#include "url_request_interceptor.h"
#include "webview.h"

class MainApp : public std::enable_shared_from_this<MainApp> {
 public:
  enum Key {
    kCmdV = 0,
    kReturn,
    kTab
  };
  explicit MainApp(const std::shared_ptr<molybden::App> &app,
                   const std::shared_ptr<AppSettings> &settings);

  static void updateLanguage(std::shared_ptr<molybden::Browser> window);

  [[nodiscard]] std::shared_ptr<molybden::App> app() const;
  [[nodiscard]] std::shared_ptr<molybden::Browser> browser() const;
  [[nodiscard]] std::shared_ptr<AppSettings> settings() const;

  void pause();
  void resume();
  bool isPaused() const;

  void showWelcomeWindow();

  std::string getImagesDir();
  std::string getLinkImagesDir();

  virtual bool init();
  virtual void launch();

  virtual void show();
  virtual void hide();
  virtual void hide(bool force);
  virtual void activate() = 0;
  virtual void paste() = 0;
  virtual void paste(const std::string &filePaths) = 0;
  virtual void paste(const std::string &text,
                     const std::string &rtf,
                     const std::string &html,
                     const std::string &imageFileName,
                     const std::string &filePath) = 0;
  virtual void sendKey(Key key) = 0;
  virtual void copyToClipboard(const std::string &filePaths, bool ghost) = 0;
  virtual void copyToClipboard(const std::string &text,
                               const std::string &rtf,
                               const std::string &html,
                               const std::string &imageFileName,
                               const std::string &filePath,
                               bool ghost) = 0;
  virtual void copyToClipboardAfterMerge(std::string text) = 0;
  virtual void setOpenAtLogin(bool open) = 0;
  virtual AppInfo getAppInfo() = 0;
  virtual AppInfo getActiveAppInfo() = 0;
  virtual std::string getFileIconAsBase64(const std::string& app_path, bool large) = 0;
  virtual std::string getAppNameFromPath(const std::string &app_path) = 0;
  virtual void preview(const std::string &file_path) = 0;

 protected:
  void pasteNextItemToActiveApp();
  void setActiveAppInfo(const std::string &app_name, const std::string& app_icon);
  void clearHistory();
  void checkForUpdates(bool user_initiated = false);
  void checkForUpdates(const std::function<void()> &complete, bool user_initiated);
  void showAboutDialog();
  void showUpToDateDialog(const std::function<void()> &complete);
  void showRestartRequiredDialog(const std::string &app_version,
                                 const std::function<void()> &complete);
  void showUpdateFailedDialog(const std::string &text, const std::function<void()> &complete);
  void showUpdateCheckFailedDialog(const std::string &error_msg,
                                   const std::function<void()> &complete);
  void showUpdateAvailableDialog(const std::shared_ptr<molybden::AppUpdate> &app_update,
                                 const std::function<void()> &complete);
  void notifyUpdateAvailable();
  void showSettingsWindow();
  void showSettingsWindow(const std::string &section);
  void selectAppsToIgnore();

  void setTheme(const std::string &theme);
  void setShowIconInMenuBar(bool show);
  void createTray();
  void destroyTray();
  void initJavaScriptApi(const std::shared_ptr<molybden::JsObject> &window);
  void deleteImage(const std::string &imageFileName);
  void fetchLinkPreviewDetails(const std::string &url, const std::shared_ptr<molybden::JsObject> &callback);
  void previewLink(const std::string &url);
  void saveImageAsFile(const std::string &imageFileName, int imageWidth, int imageHeight);

  void onLanguageChanged();
  std::string i18n(const std::string &key);

  void quit();

  // Returns the boot time of the system in seconds since Unix epoch or -1 if failed.
  virtual long getSystemBootTime();

  virtual void enableOpenAppShortcut() = 0;
  virtual void disableOpenAppShortcut() = 0;
  virtual void enablePasteNextItemShortcut() = 0;
  virtual void disablePasteNextItemShortcut() = 0;
  virtual void enablePauseResumeShortcut() = 0;
  virtual void disablePauseResumeShortcut() = 0;
  virtual void updateOpenSettingsShortcut() = 0;
  virtual std::string getUserDataDir() = 0;
  virtual std::string getUpdateServerUrl() = 0;
  virtual std::string getAppInfo(const std::string &app_path) = 0;
  virtual std::string getDefaultAppInfo(const std::string &file_path) = 0;
  virtual std::string getRecommendedAppsInfo(const std::string &file_path) = 0;
  virtual std::string getAllAppsInfo() = 0;
  virtual void openInApp(const std::string &file_path, const std::string &app_path) = 0;

 protected:
  bool first_run_;
  bool auto_hide_disabled_;
  bool app_window_visible_;
  bool checking_for_updates_;
  bool app_paused_;
  bool after_system_reboot_;
  bool update_available_;
  long long app_hide_time_;
  std::string save_images_dir_;
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Tray> tray_;
  std::shared_ptr<molybden::Browser> app_window_;
  std::shared_ptr<molybden::Browser> preview_window_;
  std::shared_ptr<molybden::Browser> welcome_window_;
  std::shared_ptr<molybden::Browser> settings_window_;
  std::shared_ptr<molybden::CustomMenuItem> open_app_item_;
  std::shared_ptr<molybden::CustomMenuItem> open_settings_item_;
  std::shared_ptr<molybden::CustomMenuItem> pause_resume_item_;
  std::shared_ptr<molybden::CustomMenuItem> check_for_updates_item_;
  std::shared_ptr<molybden::CustomMenuItem> about_item_;
  std::shared_ptr<molybden::CustomMenuItem> quit_item_;
  std::shared_ptr<molybden::CustomMenu> help_menu_;
  std::shared_ptr<molybden::CustomMenuItem> shortcuts_item_;
  std::shared_ptr<molybden::CustomMenuItem> changelog_item_;
  std::shared_ptr<molybden::CustomMenuItem> feedback_item_;
  std::shared_ptr<molybden::CustomMenuItem> support_item_;
  std::shared_ptr<AppSettings> settings_;

  std::list<std::string> fetch_url_requests_;

 private:
  std::shared_ptr<UrlRequestInterceptor> request_interceptor_;
};

#endif // CLIPBOOK_MAIN_APP_H_
