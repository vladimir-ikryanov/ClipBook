#ifndef CLIPBOOK_APP_SETTINGS_H_
#define CLIPBOOK_APP_SETTINGS_H_

#include <memory>

#include "molybden.hpp"

class AppSettings {
 public:
  static std::shared_ptr<AppSettings> create();

  virtual void saveTheme(std::string theme) = 0;
  virtual std::string getTheme() = 0;

  virtual void saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) = 0;
  virtual molybden::Rect getWindowBoundsForScreen(int screen_id) = 0;

  virtual void saveIgnoreConfidentialContent(bool ignore) = 0;
  virtual bool shouldIgnoreConfidentialContent() = 0;

  virtual void saveIgnoreTransientContent(bool ignore) = 0;
  virtual bool shouldIgnoreTransientContent() = 0;

  virtual void saveOpenAtLogin(bool open) = 0;
  virtual bool shouldOpenAtLogin() = 0;
};


#endif // CLIPBOOK_APP_SETTINGS_H_
