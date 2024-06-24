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

bool AppSettingsMac::hasWindowBoundsForScreen(int screen_id) {
  NSString *key = [NSString stringWithFormat:@"screen_%@", [NSNumber numberWithInt:screen_id]];
  NSDictionary *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  return value != nil;
}

void AppSettingsMac::saveTheme(molybden::AppTheme theme) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (theme == molybden::AppTheme::kLight) {
    [defaults setObject:@"light" forKey:@"app.theme"];
  }
  if (theme == molybden::AppTheme::kDark) {
    [defaults setObject:@"dark" forKey:@"app.theme"];
  }
  if (theme == molybden::AppTheme::kSystem) {
    [defaults setObject:@"system" forKey:@"app.theme"];
  }
  [defaults synchronize];
}

molybden::AppTheme AppSettingsMac::getTheme() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *theme = [defaults objectForKey:@"app.theme"];
  if (theme == nil) {
    return molybden::AppTheme::kSystem;
  }

  if ([theme isEqualToString:@"light"]) {
    return molybden::AppTheme::kLight;
  }
  if ([theme isEqualToString:@"dark"]) {
    return molybden::AppTheme::kDark;
  }
  return molybden::AppTheme::kSystem;
}

bool AppSettingsMac::hasTheme() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults objectForKey:@"app.theme"] != nil;
}

void AppSettingsMac::saveIgnoreConfidentialContent(bool ignore) {

}

bool AppSettingsMac::getIgnoreConfidentialContent() {
  return false;
}

void AppSettingsMac::saveIgnoreTransientContent(bool ignore) {

}

bool AppSettingsMac::getIgnoreTransientContent() {
  return false;
}
