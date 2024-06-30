#include "app_settings_mac.h"

#include <Foundation/Foundation.h>

AppSettingsMac::AppSettingsMac() = default;

void AppSettingsMac::saveWindowBoundsForScreen(int screen_id, molybden::Rect bounds) {
  NSMutableDictionary *prefValue = [[NSMutableDictionary alloc] init];
  prefValue[@"window.bounds.x"] = [NSNumber numberWithInt:bounds.origin.x];
  prefValue[@"window.bounds.y"] = [NSNumber numberWithInt:bounds.origin.y];
  prefValue[@"window.bounds.width"] = [NSNumber numberWithUnsignedInt:bounds.size.width];
  prefValue[@"window.bounds.height"] = [NSNumber numberWithUnsignedInt:bounds.size.height];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [NSString stringWithFormat:@"screen_%@", [NSNumber numberWithInt:screen_id]];
  [defaults setObject:prefValue forKey:key];
  [defaults synchronize];
}

molybden::Rect AppSettingsMac::getWindowBoundsForScreen(int screen_id) {
  NSString *key = [NSString stringWithFormat:@"screen_%@", [NSNumber numberWithInt:screen_id]];
  NSDictionary *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (value == nil) {
    return {};
  }
  auto x = [[value objectForKey:@"window.bounds.x"] intValue];
  auto y = [[value objectForKey:@"window.bounds.y"] intValue];
  auto width = [[value objectForKey:@"window.bounds.width"] unsignedIntValue];
  auto height = [[value objectForKey:@"window.bounds.height"] unsignedIntValue];
  return {molybden::Point(x, y), molybden::Size(width, height)};
}

void AppSettingsMac::saveTheme(std::string theme) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (theme == "light") {
    [defaults setObject:@"light" forKey:@"app.theme"];
  }
  if (theme == "dark") {
    [defaults setObject:@"dark" forKey:@"app.theme"];
  }
  if (theme == "system") {
    [defaults setObject:@"system" forKey:@"app.theme"];
  }
  [defaults synchronize];
}

std::string AppSettingsMac::getTheme() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *theme = [defaults objectForKey:@"app.theme"];
  if (theme != nil) {
    if ([theme isEqualToString:@"light"]) {
      return "light";
    }
    if ([theme isEqualToString:@"dark"]) {
      return "dark";
    }
  }
  return "system";
}

void AppSettingsMac::saveIgnoreConfidentialContent(bool ignore) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:ignore forKey:@"privacy.ignore_confidential_content"];
  [defaults synchronize];
}

bool AppSettingsMac::shouldIgnoreConfidentialContent() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults boolForKey:@"privacy.ignore_confidential_content"];
}

void AppSettingsMac::saveIgnoreTransientContent(bool ignore) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:ignore forKey:@"privacy.ignore_transient_content"];
  [defaults synchronize];
}

bool AppSettingsMac::shouldIgnoreTransientContent() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults boolForKey:@"privacy.ignore_transient_content"];
}
