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
NSString *prefCheckForUpdatesAutomatically = @"app.check_for_updates_automatically";
NSString *prefWarnOnClearHistory = @"app.warn_on_clear_history";
NSString *prefOpenAppShortcut = @"app.open_app_shortcut";
NSString *prefCloseAppShortcut = @"app.close_app_shortcut";
NSString *prefSelectNextItemShortcut = @"app.select_next_item_shortcut";
NSString *prefSelectPreviousItemShortcut = @"app.select_previous_item_shortcut";
NSString *prefPasteSelectedItemToActiveAppShortcut = @"app.paste_selected_item_to_active_app_shortcut";
NSString *prefEditHistoryItemShortcut = @"app.edit_history_item_shortcut";
NSString *prefOpenInBrowserShortcut = @"app.open_in_browser_shortcut";
NSString *prefCopyToClipboardShortcut = @"app.copy_to_clipboard_shortcut";
NSString *prefDeleteHistoryItemShortcut = @"app.delete_history_item_shortcut";
NSString *prefClearHistoryShortcut = @"app.clear_history_shortcut";
NSString *prefSearchHistoryShortcut = @"app.search_history_shortcut";
NSString *prefTogglePreviewShortcut = @"app.toggle_preview_shortcut";
NSString *prefShowMoreActionsShortcut = @"app.show_more_actions_shortcut";
NSString *prefZoomUIInShortcut = @"app.zoom_ui_in_shortcut";
NSString *prefZoomUIOutShortcut = @"app.zoom_ui_out_shortcut";

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

void AppSettingsMac::saveCheckForUpdatesAutomatically(bool open) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:open forKey:prefCheckForUpdatesAutomatically];
  [defaults synchronize];
}

bool AppSettingsMac::shouldCheckForUpdatesAutomatically() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefCheckForUpdatesAutomatically] != nil) {
    return [defaults boolForKey:prefCheckForUpdatesAutomatically];
  }
  return true;
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

void AppSettingsMac::saveOpenAppShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefOpenAppShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getOpenAppShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefOpenAppShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Shift + Meta + v";
}

void AppSettingsMac::saveCloseAppShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCloseAppShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getCloseAppShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCloseAppShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Escape";
}

void AppSettingsMac::saveSelectNextItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefSelectNextItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getSelectNextItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefSelectNextItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ArrowDown";
}

void AppSettingsMac::saveSelectPreviousItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefSelectPreviousItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getSelectPreviousItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefSelectPreviousItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ArrowUp";
}

void AppSettingsMac::savePasteSelectedItemToActiveAppShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefPasteSelectedItemToActiveAppShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getPasteSelectedItemToActiveAppShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefPasteSelectedItemToActiveAppShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Enter";
}

void AppSettingsMac::saveEditHistoryItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefEditHistoryItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getEditHistoryItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefEditHistoryItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + e";
}

void AppSettingsMac::saveOpenInBrowserShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefOpenInBrowserShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getOpenInBrowserShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefOpenInBrowserShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Alt + Enter";
}

void AppSettingsMac::saveCopyToClipboardShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCopyToClipboardShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getCopyToClipboardShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCopyToClipboardShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + c";
}

void AppSettingsMac::saveDeleteHistoryItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefDeleteHistoryItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getDeleteHistoryItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefDeleteHistoryItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + Backspace";
}

void AppSettingsMac::saveClearHistoryShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefClearHistoryShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getClearHistoryShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefClearHistoryShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Shift + Meta + Backspace";
}

void AppSettingsMac::saveSearchHistoryShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefSearchHistoryShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getSearchHistoryShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefSearchHistoryShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + f";
}

void AppSettingsMac::saveTogglePreviewShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefTogglePreviewShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getTogglePreviewShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefTogglePreviewShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + p";
}

void AppSettingsMac::saveShowMoreActionsShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefShowMoreActionsShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getShowMoreActionsShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefShowMoreActionsShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + a";
}

void AppSettingsMac::saveZoomUIInShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefZoomUIInShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getZoomUIInShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefZoomUIInShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + =";
}

void AppSettingsMac::saveZoomUIOutShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefZoomUIOutShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getZoomUIOutShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefZoomUIOutShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "Meta + -";
}
