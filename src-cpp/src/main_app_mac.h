#ifndef CLIPBOOK_MAIN_APP_MAC_H_
#define CLIPBOOK_MAIN_APP_MAC_H_

#include "main_app.h"

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

#include "clipboard_reader_mac.h"

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<mobrowser::App> &app,
                      const std::shared_ptr<AppSettings> &settings);

#ifdef __OBJC__
  void setActiveAppInfo(NSRunningApplication* activeApp);
#endif

  bool init() override;
  void launch() override;

  void show() override;
  void hide() override;
  void hide(bool force) override;
  void activate() override;
  void paste() override;
  void paste(const std::string &filePaths) override;
  void paste(const std::string &text,
             const std::string &rtf,
             const std::string &html,
             const std::string &imageFileName,
             const std::string &filePath) override;
  void sendKey(Key key) override;
  void copyToClipboard(const std::string &filePaths, bool ghost) override;
  void copyToClipboard(const std::string &text,
                       const std::string &rtf,
                       const std::string &html,
                       const std::string &imageFileName,
                       const std::string &filePath,
                       bool ghost) override;
  void copyToClipboardAfterMerge(std::string text) override;
  void setOpenAtLogin(bool open) override;
  AppInfo getAppInfo() override;
  AppInfo getActiveAppInfo() override;
  std::string getFileIconAsBase64(const std::string& app_path, bool large) override;
  std::string getAppNameFromPath(const std::string &app_path) override;
  void preview(const std::string &file_path) override;

 protected:
  void enableOpenAppShortcut() override;
  void disableOpenAppShortcut() override;
  void enablePasteNextItemShortcut() override;
  void disablePasteNextItemShortcut() override;
  void enablePauseResumeShortcut() override;
  void disablePauseResumeShortcut() override;
  void updateOpenSettingsShortcut() override;
  std::string getUserDataDir() override;
  std::string getUpdateServerUrl() override;
  std::string getAppInfo(const std::string &app_path) override;
  std::string getDefaultAppInfo(const std::string &file_path) override;
  std::string getRecommendedAppsInfo(const std::string &file_path) override;
  std::string getAllAppsInfo() override;
  void openInApp(const std::string &file_path, const std::string &app_path) override;

  bool isAccessibilityAccessGranted();
  void showAccessibilityAccessDialog(const std::string &filePaths);
  void showAccessibilityAccessDialog(const std::string &text,
                                     const std::string &imageFileName,
                                     const std::string &filePath);
  void showSystemAccessibilityPreferencesDialog();

 private:
  void restoreWindowBounds();
  mobrowser::Size restoreWindowSize();
  void saveWindowBounds();
  void moveToLastPositionOnActiveScreen();
  void moveToActiveScreenCenter();
  bool moveToInputCursorLocation();
  bool moveToActiveWindowCenter();
  bool moveToScreenWithMousePointer();
  void moveToMousePointerLocation();
  static mobrowser::Shortcut createShortcut(const std::string &shortcut);

  static void addAppToLoginItems();
  static void removeAppFromLoginItems();
  static bool isAppInLoginItems();

  long getSystemBootTime() override;

 private:
  mobrowser::Shortcut open_app_shortcut_;
  mobrowser::Shortcut pause_resume_shortcut_;
  mobrowser::Shortcut open_settings_shortcut_;
  mobrowser::Shortcut paste_next_item_shortcut_;
  std::shared_ptr<ClipboardReaderMac> clipboard_reader_;
  bool should_activate_app_ = false;
#ifdef __OBJC__
  pid_t active_app_pid_ = 0;
  NSPoint getInputCursorLocationOnScreen();
  void moveToScreen(NSScreen *screen);
  void setupApplicationObservers();
  static NSRect getActiveWindowBounds(NSRunningApplication *app);
#endif
};

#endif // CLIPBOOK_MAIN_APP_MAC_H_
