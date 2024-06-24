#ifndef CLIPBOOK_APP_SETTINGS_H_
#define CLIPBOOK_APP_SETTINGS_H_

#include <memory>

#include "molybden/ui/geometry.hpp"
#include "molybden/app/app_theme.hpp"

class AppSettings {
 public:
  static std::shared_ptr<AppSettings> create();

  virtual void saveTheme(molybden::AppTheme theme) = 0;

  virtual molybden::AppTheme getTheme() = 0;

  virtual bool hasTheme() = 0;

  virtual void saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) = 0;

  virtual molybden::Rect getWindowBoundsForScreen(int screen_id) = 0;

  virtual bool hasWindowBoundsForScreen(int screen_id) = 0;
};


#endif // CLIPBOOK_APP_SETTINGS_H_
