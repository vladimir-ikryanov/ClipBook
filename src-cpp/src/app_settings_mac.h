#ifndef CLIPBOOK_APP_SETTINGS_MAC_H_
#define CLIPBOOK_APP_SETTINGS_MAC_H_

#include <memory>

#include "app_settings.h"

class AppSettingsMac : public AppSettings {
 public:
  AppSettingsMac();

  void saveTheme(std::string theme) override;
  std::string getTheme() override;

  void saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) override;
  molybden::Rect getWindowBoundsForScreen(int screen_id) override;

  void saveIgnoreConfidentialContent(bool ignore) override;
  bool shouldIgnoreConfidentialContent() override;

  void saveIgnoreTransientContent(bool ignore) override;
  bool shouldIgnoreTransientContent() override;
};


#endif // CLIPBOOK_APP_SETTINGS_MAC_H_
