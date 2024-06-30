#ifndef CLIPBOOK_MAIN_APP_MAC_H_
#define CLIPBOOK_MAIN_APP_MAC_H_

#include "main_app.h"

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<molybden::App> &app,
                      const std::shared_ptr<AppSettings> &settings);

  bool init() override;

  void show() override;
  void hide() override;
  void activate() override;
  void paste() override;
  void paste(const std::string &text) override;
  void setOpenAtLogin(bool open) override;

 protected:
  std::string getUserDataDir() override;
  std::string getUpdateServerUrl() override;

 private:
  void restoreWindowBounds();
  void saveWindowBounds();
  void addAppToLoginItems();
  void removeAppFromLoginItems();
  bool isAppInLoginItems();

 private:
#ifdef __OBJC__
  NSRunningApplication *active_app_{};
#endif
};

#endif // CLIPBOOK_MAIN_APP_MAC_H_
