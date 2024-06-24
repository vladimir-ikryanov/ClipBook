#ifndef CLIPBOOK_APP_SETTINGS_MAC_H_
#define CLIPBOOK_APP_SETTINGS_MAC_H_

#include <memory>

#include "app_settings.h"

class AppSettingsMac : public AppSettings {
 public:
  AppSettingsMac();

  void saveTheme(molybden::AppTheme theme) override;

  molybden::AppTheme getTheme() override;

  bool hasTheme() override;

  void saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) override;

  molybden::Rect getWindowBoundsForScreen(int screen_id) override;

  bool hasWindowBoundsForScreen(int screen_id) override;
};


#endif // CLIPBOOK_APP_SETTINGS_MAC_H_
