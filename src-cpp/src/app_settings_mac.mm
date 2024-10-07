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
NSString *prefScreenInfo = @"screen_%@_%@:%@_%@x%@";
NSString *prefAppTheme = @"app.theme";
NSString *prefIgnoreConfidentialContent = @"privacy.ignore_confidential_content";
NSString *prefIgnoreTransientContent = @"privacy.ignore_transient_content";
NSString *prefOpenAtLogin = @"app.open_at_login";
NSString *prefCheckForUpdatesAutomatically = @"app.check_for_updates_automatically";
NSString *prefWarnOnClearHistory = @"app.warn_on_clear_history";
NSString *prefShowIconInMenuBar = @"app.show_icon_in_menu_bar";
NSString *prefIgnoreApps = @"privacy.ignore_apps";
NSString *prefCopyAndMergeEnabled = @"copy_and_merge.enabled";
NSString *prefCopyAndMergeSeparator = @"copy_and_merge.separator";
NSString *prefCopyToClipboardAfterMerge = @"copy_to_clipboard_after_merge";

// Shortcuts.
NSString *prefOpenAppShortcut = @"app.open_app_shortcut2";
NSString *prefCloseAppShortcut = @"app.close_app_shortcut2";
NSString *prefCloseAppShortcut2 = @"app.close_app_shortcut3";
NSString *prefCloseAppShortcut3 = @"app.close_app_shortcut4";
NSString *prefSelectNextItemShortcut = @"app.select_next_item_shortcut2";
NSString *prefSelectPreviousItemShortcut = @"app.select_previous_item_shortcut2";
NSString *prefPasteSelectedItemToActiveAppShortcut = @"app.paste_selected_item_to_active_app_shortcut2";
NSString *prefEditHistoryItemShortcut = @"app.edit_history_item_shortcut2";
NSString *prefOpenInBrowserShortcut = @"app.open_in_browser_shortcut2";
NSString *prefCopyToClipboardShortcut = @"app.copy_to_clipboard_shortcut2";
NSString *prefCopyImageFromTextShortcut = @"app.copy_image_from_text_shortcut";
NSString *prefDeleteHistoryItemShortcut = @"app.delete_history_item_shortcut2";
NSString *prefClearHistoryShortcut = @"app.clear_history_shortcut2";
NSString *prefSearchHistoryShortcut = @"app.search_history_shortcut2";
NSString *prefTogglePreviewShortcut = @"app.toggle_preview_shortcut2";
NSString *prefShowMoreActionsShortcut = @"app.show_more_actions_shortcut2";
NSString *prefZoomUIInShortcut = @"app.zoom_ui_in_shortcut2";
NSString *prefZoomUIOutShortcut = @"app.zoom_ui_out_shortcut2";
NSString *prefOpenSettingsShortcut = @"app.open_settings_shortcut2";
NSString *prefToggleFavoriteShortcut = @"app.toggle_favorite_shortcut2";

AppSettingsMac::AppSettingsMac() = default;

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

void AppSettingsMac::saveWindowBoundsForScreen(int screen_id,
                                               molybden::Rect screen_bounds,
                                               molybden::Rect window_bounds) {
  if (window_bounds.size.isEmpty()) {
    return;
  }
  NSMutableDictionary *prefValue = [[NSMutableDictionary alloc] init];
  prefValue[prefWindowBoundsX] = [NSNumber numberWithInt:window_bounds.origin.x];
  prefValue[prefWindowBoundsY] = [NSNumber numberWithInt:window_bounds.origin.y];
  prefValue[prefWindowBoundsWidth] = [NSNumber numberWithUnsignedInt:window_bounds.size.width];
  prefValue[prefWindowBoundsHeight] = [NSNumber numberWithUnsignedInt:window_bounds.size.height];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [NSString stringWithFormat:prefScreenInfo,
                                             [NSNumber numberWithInt:screen_id],
                                             [NSNumber numberWithInt:screen_bounds.origin.x],
                                             [NSNumber numberWithInt:screen_bounds.origin.y],
                                             [NSNumber numberWithInt:static_cast<int>(screen_bounds.size.width)],
                                             [NSNumber numberWithInt:static_cast<int>(screen_bounds.size.height)]];
  [defaults setObject:prefValue forKey:key];
  [defaults synchronize];
}

molybden::Rect AppSettingsMac::getWindowBoundsForScreen(int screen_id,
                                                        molybden::Rect screen_bounds) {
  NSString *key = [NSString stringWithFormat:prefScreenInfo,
                                             [NSNumber numberWithInt:screen_id],
                                             [NSNumber numberWithInt:screen_bounds.origin.x],
                                             [NSNumber numberWithInt:screen_bounds.origin.y],
                                             [NSNumber numberWithInt:static_cast<int>(screen_bounds.size.width)],
                                             [NSNumber numberWithInt:static_cast<int>(screen_bounds.size.height)]];
  NSDictionary *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (value == nil) {
    return getWindowBoundsForScreen(screen_id);
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

void AppSettingsMac::saveShowIconInMenuBar(bool show) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:show forKey:prefShowIconInMenuBar];
  [defaults synchronize];
}

bool AppSettingsMac::shouldShowIconInMenuBar() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefShowIconInMenuBar] != nil) {
    return [defaults boolForKey:prefShowIconInMenuBar];
  }
  return true;
}

void AppSettingsMac::saveCopyAndMergeEnabled(bool enabled) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:enabled forKey:prefCopyAndMergeEnabled];
  [defaults synchronize];
}

bool AppSettingsMac::isCopyAndMergeEnabled() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefCopyAndMergeEnabled] != nil) {
    return [defaults boolForKey:prefCopyAndMergeEnabled];
  }
  return true;
}

void AppSettingsMac::saveCopyAndMergeSeparator(std::string separator) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:separator.c_str()] forKey:prefCopyAndMergeSeparator];
  [defaults synchronize];
}

std::string AppSettingsMac::getCopyAndMergeSeparator() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *separator = [defaults objectForKey:prefCopyAndMergeSeparator];
  if (separator != nil) {
    return {[separator UTF8String]};
  }
  return "\n";
}

void AppSettingsMac::saveCopyToClipboardAfterMerge(bool copy) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:copy forKey:prefCopyToClipboardAfterMerge];
  [defaults synchronize];
}

bool AppSettingsMac::shouldCopyToClipboardAfterMerge() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefCopyToClipboardAfterMerge] != nil) {
    return [defaults boolForKey:prefCopyToClipboardAfterMerge];
  }
  return true;
}

// Shortcuts.

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
  return "ShiftLeft + MetaLeft + KeyV";
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

void AppSettingsMac::saveCloseAppShortcut2(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCloseAppShortcut2];
  [defaults synchronize];
}

std::string AppSettingsMac::getCloseAppShortcut2() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCloseAppShortcut2];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyW";
}

void AppSettingsMac::saveCloseAppShortcut3(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCloseAppShortcut3];
  [defaults synchronize];
}

std::string AppSettingsMac::getCloseAppShortcut3() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCloseAppShortcut3];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyV";
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
  return "MetaLeft + KeyE";
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
  return "AltLeft + Enter";
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
  return "MetaLeft + KeyC";
}

void AppSettingsMac::saveCopyTextFromImageShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCopyImageFromTextShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getCopyTextFromImageShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCopyImageFromTextShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + ShiftLeft + KeyC";
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
  return "MetaLeft + Backspace";
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
  return "ShiftLeft + MetaLeft + Backspace";
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
  return "MetaLeft + KeyF";
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
  return "MetaLeft + KeyP";
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
  return "MetaLeft + KeyA";
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
  return "MetaLeft + Equal";
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
  return "MetaLeft + Minus";
}

void AppSettingsMac::saveOpenSettingsShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefOpenSettingsShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getOpenSettingsShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefOpenSettingsShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + Comma";
}

void AppSettingsMac::saveAppsToIgnore(std::string apps) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:apps.c_str()] forKey:prefIgnoreApps];
  [defaults synchronize];
}

std::string AppSettingsMac::getAppsToIgnore() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *apps = [defaults objectForKey:prefIgnoreApps];
  if (apps != nil) {
    return [apps UTF8String];
  }
  return "";
}

void AppSettingsMac::saveToggleFavoriteShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefToggleFavoriteShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getToggleFavoriteShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefToggleFavoriteShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyS";
}
