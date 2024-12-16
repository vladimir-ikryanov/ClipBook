#ifndef CLIPBOOK_MAIN_APP_MAC_H_
#define CLIPBOOK_MAIN_APP_MAC_H_

#include "main_app.h"

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

#include "clipboard_reader_mac.h"

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<molybden::App> &app,
                      const std::shared_ptr<AppSettings> &settings);

  bool init() override;
  void launch() override;

  void show() override;
  void hide() override;
  void activate() override;
  void paste() override;
  void paste(const std::string &text,
             const std::string &imageFileName,
             const std::string &imageText) override;
  void sendKey(Key key) override;
  void copyToClipboard(const std::string &text,
                       const std::string &imageFileName,
                       const std::string &imageText) override;
  void copyToClipboardAfterMerge(std::string text) override;
  void setOpenAtLogin(bool open) override;
  AppInfo getActiveAppInfo() override;
  std::string getAppIconAsBase64(const std::string& app_path) override;
  std::string getAppNameFromPath(const std::string &app_path) override;

 protected:
  void enableOpenAppShortcut() override;
  void disableOpenAppShortcut() override;
  void updateOpenSettingsShortcut() override;
  std::string getUserDataDir() override;
  std::string getUpdateServerUrl() override;

  bool isAccessibilityAccessGranted();
  void showAccessibilityAccessDialog(const std::string &text,
                                     const std::string &imageFileName,
                                     const std::string &imageText);
  void showSystemAccessibilityPreferencesDialog();

 private:
  void restoreWindowBounds();
  void saveWindowBounds();
  molybden::Shortcut createShortcut(const std::string &shortcut);
  long getSystemBootTime() override;

  static void addAppToLoginItems();
  static void removeAppFromLoginItems();
  static bool isAppInLoginItems();

 private:
  molybden::Shortcut open_app_shortcut_;
  molybden::Shortcut open_settings_shortcut_;
  std::shared_ptr<ClipboardReaderMac> clipboard_reader_;
#ifdef __OBJC__
  NSRunningApplication *active_app_{};
#endif
};

#endif // CLIPBOOK_MAIN_APP_MAC_H_
