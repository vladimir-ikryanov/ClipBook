#include "app_settings_mac.h"

#include <Foundation/Foundation.h>

NSString *appThemeLight = @"light";
NSString *appThemeDark = @"dark";
NSString *appThemeSystem = @"system";

NSString *prefWindowBoundsX = @"window.bounds.x";
NSString *prefWindowBoundsY = @"window.bounds.y";
NSString *prefWindowBoundsWidth = @"window.bounds.width";
NSString *prefWindowBoundsHeight = @"window.bounds.height";
NSString *prefScreenNumber = @"screen_%@";
NSString *prefAppTheme = @"app.theme";
NSString *prefIgnoreConfidentialContent = @"privacy.ignore_confidential_content";
NSString *prefIgnoreTransientContent = @"privacy.ignore_transient_content";
NSString *prefOpenAtLogin = @"app.open_at_login";
NSString *prefWarnOnClearHistory = @"app.warn_on_clear_history";

AppSettingsMac::AppSettingsMac() = default;

void AppSettingsMac::saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) {
  NSMutableDictionary *prefValue = [[NSMutableDictionary alloc] init];
  prefValue[prefWindowBoundsX] = [NSNumber numberWithInt:bounds.origin.x];
  prefValue[prefWindowBoundsY] = [NSNumber numberWithInt:bounds.origin.y];
  prefValue[prefWindowBoundsWidth] = [NSNumber numberWithUnsignedInt:bounds.size.width];
  prefValue[prefWindowBoundsHeight] = [NSNumber numberWithUnsignedInt:bounds.size.height];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [NSString stringWithFormat:prefScreenNumber, [NSNumber numberWithInt:screen_id]];
  [defaults setObject:prefValue forKey:key];
  [defaults synchronize];
}

molybden::Rect AppSettingsMac::getWindowBoundsForScreen(int screen_id) {
  NSString *key = [NSString stringWithFormat:prefScreenNumber, [NSNumber numberWithInt:screen_id]];
  NSDictionary *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (value == nil) {
    return {};
  }
  auto x = [[value objectForKey:prefWindowBoundsX] intValue];
  auto y = [[value objectForKey:prefWindowBoundsY] intValue];
  auto width = [[value objectForKey:prefWindowBoundsWidth] unsignedIntValue];
  auto height = [[value objectForKey:prefWindowBoundsHeight] unsignedIntValue];
  return {molybden::Point(x, y), molybden::Size(width, height)};
}

void AppSettingsMac::saveTheme(std::string theme) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (theme == "light") {
    [defaults setObject:appThemeLight forKey:prefAppTheme];
  }
  if (theme == "dark") {
    [defaults setObject:appThemeDark forKey:prefAppTheme];
  }
  if (theme == "system") {
    [defaults setObject:appThemeSystem forKey:prefAppTheme];
  }
  [defaults synchronize];
}

std::string AppSettingsMac::getTheme() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *theme = [defaults objectForKey:prefAppTheme];
  if (theme != nil) {
    if ([theme isEqualToString:appThemeLight]) {
      return "light";
    }
    if ([theme isEqualToString:appThemeDark]) {
      return "dark";
    }
  }
  return "system";
}

void AppSettingsMac::saveIgnoreConfidentialContent(bool ignore) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:ignore forKey:prefIgnoreConfidentialContent];
  [defaults synchronize];
}

bool AppSettingsMac::shouldIgnoreConfidentialContent() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefIgnoreConfidentialContent] != nil) {
    return [defaults boolForKey:prefIgnoreConfidentialContent];
  }
  return true;
}

void AppSettingsMac::saveIgnoreTransientContent(bool ignore) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:ignore forKey:prefIgnoreTransientContent];
  [defaults synchronize];
}

bool AppSettingsMac::shouldIgnoreTransientContent() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefIgnoreTransientContent] != nil) {
    return [defaults boolForKey:prefIgnoreTransientContent];
  }
  return true;
}

void AppSettingsMac::saveOpenAtLogin(bool open) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:open forKey:prefOpenAtLogin];
  [defaults synchronize];
}

bool AppSettingsMac::shouldOpenAtLogin() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults boolForKey:prefOpenAtLogin];
}

void AppSettingsMac::saveWarnOnClearHistory(bool warn) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:warn forKey:prefWarnOnClearHistory];
  [defaults synchronize];
}

bool AppSettingsMac::shouldWarnOnClearHistory() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefWarnOnClearHistory] != nil) {
    return [defaults boolForKey:prefWarnOnClearHistory];
  }
  return true;
}
