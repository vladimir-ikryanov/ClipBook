#ifndef CLIPBOOK_MAIN_APP_MAC_H_
#define CLIPBOOK_MAIN_APP_MAC_H_

#include "main_app.h"

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#include "active_app_observer.h"
#endif

#include "clipboard_reader_mac.h"

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<molybden::App> &app,
                      const std::shared_ptr<AppSettings> &settings);

#ifdef __OBJC__
  void setActiveAppInfo(NSRunningApplication* activeApp);
  void onActiveAppChanged(NSNotification* notification);
#endif

  bool init() override;
  void launch() override;

  void show() override;
  void hide() override;
  void hide(bool force) override;
  void activate() override;
  void paste() override;
  void paste(const std::string &text,
             const std::string &imageFileName,
             const std::string &filePath) override;
  void sendKey(Key key) override;
  void copyToClipboard(const std::string &text,
                       const std::string &imageFileName,
                       const std::string &filePath,
                       bool ghost) override;
  void copyToClipboardAfterMerge(std::string text) override;
  void setOpenAtLogin(bool open) override;
  AppInfo getAppInfo() override;
  AppInfo getActiveAppInfo() override;
  std::string getFileIconAsBase64(const std::string& app_path, bool large) override;
  std::string getAppNameFromPath(const std::string &app_path) override;

 protected:
  void enableOpenAppShortcut() override;
  void disableOpenAppShortcut() override;
  void updatePauseResumeShortcut() override;
  void updateOpenSettingsShortcut() override;
  std::string getUserDataDir() override;
  std::string getUpdateServerUrl() override;

  bool isAccessibilityAccessGranted();
  void showAccessibilityAccessDialog(const std::string &text,
                                     const std::string &imageFileName,
                                     const std::string &filePath);
  void showSystemAccessibilityPreferencesDialog();

 private:
  void restoreWindowBounds();
  molybden::Size restoreWindowSize();
  void saveWindowBounds();
  void moveToLastPositionOnActiveScreen();
  void moveToActiveScreenCenter();
  bool moveToInputCursorLocation();
  bool moveToActiveWindowCenter();
  bool moveToScreenWithMousePointer();
  void moveToMousePointerLocation();
  static molybden::Shortcut createShortcut(const std::string &shortcut);
  long getSystemBootTime() override;

  static void addAppToLoginItems();
  static void removeAppFromLoginItems();
  static bool isAppInLoginItems();

 private:
  molybden::Shortcut open_app_shortcut_;
  molybden::Shortcut pause_resume_shortcut_;
  molybden::Shortcut open_settings_shortcut_;
  std::shared_ptr<ClipboardReaderMac> clipboard_reader_;
  bool should_activate_app_ = false;
#ifdef __OBJC__
  ActiveAppObserver* observer_ = nullptr;
  pid_t active_app_pid_ = 0;
  NSPoint getInputCursorLocationOnScreen();
  void moveToScreen(NSScreen *screen);
  static NSRect getActiveWindowBounds(NSRunningApplication *app);
#endif
};

#endif // CLIPBOOK_MAIN_APP_MAC_H_
