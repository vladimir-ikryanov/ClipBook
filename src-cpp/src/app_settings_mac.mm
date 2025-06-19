#include "app_settings_mac.h"

#include <Foundation/Foundation.h>

NSString *appThemeLight = @"light";
NSString *appThemeDark = @"dark";
NSString *appThemeSystem = @"system";

NSString *prefWindowBounds = @"window_bounds";
NSString *prefWindowBoundsX = @"window.bounds.x";
NSString *prefWindowBoundsY = @"window.bounds.y";
NSString *prefWindowBoundsWidth = @"window.bounds.width";
NSString *prefWindowBoundsHeight = @"window.bounds.height";
NSString *prefScreenNumber = @"screen_%@";
NSString *prefScreenInfo = @"screen_%@_%@:%@_%@x%@";
NSString *prefAppLanguage = @"app.language";
NSString *prefAppTheme = @"app.theme";
NSString *prefIgnoreConfidentialContent = @"privacy.ignore_confidential_content";
NSString *prefIgnoreTransientContent = @"privacy.ignore_transient_content";
NSString *prefOpenAtLogin = @"app.open_at_login";
NSString *prefCheckForUpdatesAutomatically = @"app.check_for_updates_automatically";
NSString *prefAllowCheckForUpdates = @"app.allow_check_for_updates";
NSString *prefLastUpdateCheckTime = @"app.last_update_check_time";
NSString *prefWarnOnClearHistory = @"app.warn_on_clear_history";
NSString *prefKeepFavoritesOnClearHistory = @"app.keep_favorites_on_clear_history";
NSString *prefShowIconInMenuBar = @"app.show_icon_in_menu_bar";
NSString *prefIgnoreApps = @"privacy.ignore_apps";
NSString *prefCopyAndMergeEnabled = @"copy_and_merge.enabled";
NSString *prefCopyAndMergeSeparator = @"copy_and_merge.separator";
NSString *prefCopyToClipboardAfterMerge = @"copy_to_clipboard_after_merge";
NSString *prefClearHistoryOnQuit = @"clear_history_on_quit";
NSString *prefClearHistoryOnMacReboot = @"clear_history_on_mac_reboot";
NSString *prefOpenWindowStrategy = @"open_window_strategy";
NSString *prefTreatDigitNumbersAsColor = @"treat_digit_numbers_as_color";
NSString *prefShowPreviewForLinks = @"show_preview_for_links";
NSString *prefUpdateHistoryAfterAction = @"update_history_after_action";
NSString *prefIsFeedbackProvided = @"is_feedback_provided";
NSString *prefPasteOnClick = @"paste_on_click";
NSString *prefPlaySoundOnCopy = @"play_sound_on_copy";
NSString *prefAlwaysDisplay = @"always_display";
NSString *prefCopyOnDoubleClick = @"copy_on_double_click";
NSString *prefCopyOnNumberAction = @"copy_on_number_action";

NSString *prefLastSystemBootTime = @"last_system_boot_time";
NSString *prefLicenseKey = @"license_key";

// Shortcuts.
NSString *prefOpenAppShortcut = @"app.open_app_shortcut2";
NSString *prefCloseAppShortcut = @"app.close_app_shortcut2";
NSString *prefCloseAppShortcut2 = @"app.close_app_shortcut3";
NSString *prefCloseAppShortcut3 = @"app.close_app_shortcut4";
NSString *prefSelectNextItemShortcut = @"app.select_next_item_shortcut2";
NSString *prefSelectPreviousItemShortcut = @"app.select_previous_item_shortcut2";
NSString *prefPasteSelectedItemToActiveAppShortcut = @"app.paste_selected_item_to_active_app_shortcut2";
NSString *prefPasteSelectedObjectToActiveAppShortcut = @"app.paste_selected_object_to_active_app_shortcut2";
NSString *prefEditHistoryItemShortcut = @"app.edit_history_item_shortcut2";
NSString *prefOpenInBrowserShortcut = @"app.open_in_browser_shortcut2";
NSString *prefShowInFinderShortcut = @"app.show_in_finder_shortcut";
NSString *prefQuickLookShortcut = @"app.quick_look_shortcut";
NSString *prefOpenInDefaultAppShortcut = @"app.open_in_default_app_shortcut";
NSString *prefCopyToClipboardShortcut = @"app.copy_to_clipboard_shortcut2";
NSString *prefCopyObjectToClipboardShortcut = @"app.copy_object_to_clipboard_shortcut2";
NSString *prefCopyImageFromTextShortcut = @"app.copy_image_from_text_shortcut";
NSString *prefDeleteHistoryItemShortcut = @"app.delete_history_item_shortcut2";
NSString *prefClearHistoryShortcut = @"app.clear_history_shortcut2";
NSString *prefSearchHistoryShortcut = @"app.search_history_shortcut2";
NSString *prefTogglePreviewShortcut = @"app.toggle_preview_shortcut2";
NSString *prefShowMoreActionsShortcut = @"app.show_more_actions_shortcut3";
NSString *prefZoomUIInShortcut = @"app.zoom_ui_in_shortcut2";
NSString *prefZoomUIOutShortcut = @"app.zoom_ui_out_shortcut2";
NSString *prefZoomUIResetShortcut = @"app.zoom_ui_reset_shortcut";
NSString *prefOpenSettingsShortcut = @"app.open_settings_shortcut2";
NSString *prefToggleFavoriteShortcut = @"app.toggle_favorite_shortcut2";
NSString *prefNavigateToFirstItemShortcut = @"app.navigate_to_first_item_shortcut";
NSString *prefNavigateToLastItemShortcut = @"app.navigate_to_last_item_shortcut";
NSString *prefNavigateToNextGroupOfItemsShortcut = @"app.navigate_to_next_group_of_items_shortcut";
NSString *prefNavigateToPrevGroupOfItemsShortcut = @"app.navigate_to_prev_group_of_items_shortcut";
NSString *prefSaveImageAsFileShortcut = @"app.save_image_as_file_shortcut";
NSString *prefPauseResumeShortcut = @"app.pause_resume_shortcut";
NSString *prefRenameItemShortcut = @"app.rename_item_shortcut";
NSString *prefMakeLowerCaseShortcut = @"app.make_lower_case_shortcut";
NSString *prefMakeUpperCaseShortcut = @"app.make_upper_case_shortcut";
NSString *prefCapitalizeShortcut = @"app.capitalize_shortcut";
NSString *prefSentenceCaseShortcut = @"app.sentence_case_shortcut";
NSString *prefRemoveEmptyLinesShortcut = @"app.remove_empty_lines_shortcut";
NSString *prefStripAllWhitespacesShortcut = @"app.strip_all_whitespaces_shortcut";
NSString *prefTrimSurroundingWhitespacesShortcut = @"app.trim_surrounding_whitespaces_shortcut";
NSString *prefToggleFilterShortcut = @"app.toggle_filter_shortcut";
NSString *prefPasteNextItemShortcut = @"app.paste_next_item_shortcut";

/**
 * Checks if the device is managed by MDM.
 */
bool isDeviceManaged() {
  CFStringRef domain = CFSTR("com.ikryanov.clipbook.managed");
  CFPropertyListRef managedPrefs = CFPreferencesCopyAppValue(CFSTR(""), domain);
  if (managedPrefs) {
    CFRelease(managedPrefs);
    return true;
  }
  return false;
}

/**
 * Checks if the given preference is managed by MDM.
 */
bool isManaged(NSString *prefName) {
  CFStringRef domain = CFSTR("com.ikryanov.clipbook.managed");
  CFPropertyListRef managedPrefs = CFPreferencesCopyAppValue((__bridge CFStringRef)prefName, domain);
  if (managedPrefs) {
    CFRelease(managedPrefs);
    return true;
  }
  return false;
}

bool prefReadBoolValue(NSString *key, bool defaultValue) {
  CFStringRef domain = CFSTR("com.ikryanov.clipbook.managed");
  CFPropertyListRef managedPrefs = CFPreferencesCopyAppValue((__bridge CFStringRef)key, domain);
  if (managedPrefs) {
    if (CFGetTypeID(managedPrefs) == CFBooleanGetTypeID()) {
      BOOL value = CFBooleanGetValue((CFBooleanRef)managedPrefs);
      CFRelease(managedPrefs);
      return value;
    }
    CFRelease(managedPrefs);
  }
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:key] != nil) {
    return [defaults boolForKey:key];
  }
  return defaultValue;
}

AppSettingsMac::AppSettingsMac() = default;

void AppSettingsMac::saveLastSystemBootTime(long time) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSNumber numberWithLong:time] forKey:prefLastSystemBootTime];
  [defaults synchronize];
}

long AppSettingsMac::getLastSystemBootTime() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSNumber *time = [defaults objectForKey:prefLastSystemBootTime];
  if (time != nil) {
    return [time longValue];
  }
  return -1;
}

void AppSettingsMac::saveLicenseKey(std::string key) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:key.c_str()] forKey:prefLicenseKey];
  [defaults synchronize];
}

std::string AppSettingsMac::getLicenseKey() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [defaults objectForKey:prefLicenseKey];
  if (key != nil) {
    return [key UTF8String];
  }
  return "";
}

void AppSettingsMac::saveWindowBounds(molybden::Rect window_bounds) {
  NSMutableDictionary *prefValue = [[NSMutableDictionary alloc] init];
  prefValue[prefWindowBoundsX] = [NSNumber numberWithInt:window_bounds.origin.x];
  prefValue[prefWindowBoundsY] = [NSNumber numberWithInt:window_bounds.origin.y];
  prefValue[prefWindowBoundsWidth] = [NSNumber numberWithUnsignedInt:window_bounds.size.width];
  prefValue[prefWindowBoundsHeight] = [NSNumber numberWithUnsignedInt:window_bounds.size.height];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:prefValue forKey:prefWindowBounds];
  [defaults synchronize];
}

molybden::Rect AppSettingsMac::getWindowBounds() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *value = [defaults objectForKey:prefWindowBounds];
  if (value == nil) {
    return {};
  }
  auto x = [[value objectForKey:prefWindowBoundsX] intValue];
  auto y = [[value objectForKey:prefWindowBoundsY] intValue];
  auto width = [[value objectForKey:prefWindowBoundsWidth] unsignedIntValue];
  auto height = [[value objectForKey:prefWindowBoundsHeight] unsignedIntValue];
  return {molybden::Point(x, y), molybden::Size(width, height)};
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

void AppSettingsMac::saveLanguage(std::string code) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:code.c_str()] forKey:prefAppLanguage];
  [defaults synchronize];
}

std::string AppSettingsMac::getLanguage() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *language = [defaults objectForKey:prefAppLanguage];
  if (language != nil) {
    return {[language UTF8String]};
  }
  return kEnglishUS;
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
  return prefReadBoolValue(prefIgnoreConfidentialContent, true);
}

bool AppSettingsMac::isIgnoreConfidentialContentManaged() {
  return isManaged(prefIgnoreConfidentialContent);
}

void AppSettingsMac::saveIgnoreTransientContent(bool ignore) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:ignore forKey:prefIgnoreTransientContent];
  [defaults synchronize];
}

bool AppSettingsMac::shouldIgnoreTransientContent() {
  return prefReadBoolValue(prefIgnoreTransientContent, true);
}

bool AppSettingsMac::isIgnoreTransientContentManaged() {
  return isManaged(prefIgnoreTransientContent);
}

void AppSettingsMac::saveOpenAtLogin(bool open) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:open forKey:prefOpenAtLogin];
  [defaults synchronize];
}

bool AppSettingsMac::shouldOpenAtLogin() {
  return prefReadBoolValue(prefOpenAtLogin, false);
}

bool AppSettingsMac::isOpenAtLoginManaged() {
  return isManaged(prefOpenAtLogin);
}

void AppSettingsMac::saveCheckForUpdatesAutomatically(bool open) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:open forKey:prefCheckForUpdatesAutomatically];
  [defaults synchronize];
}

bool AppSettingsMac::shouldCheckForUpdatesAutomatically() {
  return prefReadBoolValue(prefCheckForUpdatesAutomatically, true);
}

bool AppSettingsMac::isCheckForUpdatesAutomaticallyManaged() {
  return isManaged(prefCheckForUpdatesAutomatically);
}

bool AppSettingsMac::isAllowCheckForUpdates() {
  return prefReadBoolValue(prefAllowCheckForUpdates, true);
}

void AppSettingsMac::saveWarnOnClearHistory(bool warn) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:warn forKey:prefWarnOnClearHistory];
  [defaults synchronize];
}

bool AppSettingsMac::shouldWarnOnClearHistory() {
  return prefReadBoolValue(prefWarnOnClearHistory, true);
}

bool AppSettingsMac::isWarnOnClearHistoryManaged() {
  return isManaged(prefWarnOnClearHistory);
}

void AppSettingsMac::saveKeepFavoritesOnClearHistory(bool keep) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:keep forKey:prefKeepFavoritesOnClearHistory];
  [defaults synchronize];
}

bool AppSettingsMac::shouldKeepFavoritesOnClearHistory() {
  return prefReadBoolValue(prefKeepFavoritesOnClearHistory, true);
}

bool AppSettingsMac::isKeepFavoritesOnClearHistoryManaged() {
  return isManaged(prefKeepFavoritesOnClearHistory);
}

void AppSettingsMac::saveShowIconInMenuBar(bool show) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:show forKey:prefShowIconInMenuBar];
  [defaults synchronize];
}

bool AppSettingsMac::shouldShowIconInMenuBar() {
  return prefReadBoolValue(prefShowIconInMenuBar, true);
}

bool AppSettingsMac::isShowIconInMenuBarManaged() {
  return isManaged(prefShowIconInMenuBar);
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
  return false;
}

bool AppSettingsMac::isCopyAndMergeEnabledManaged() {
  return false;
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

void AppSettingsMac::saveTreatDigitNumbersAsColor(bool treat) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:treat forKey:prefTreatDigitNumbersAsColor];
  [defaults synchronize];
}

bool AppSettingsMac::shouldTreatDigitNumbersAsColor() {
  return prefReadBoolValue(prefTreatDigitNumbersAsColor, true);
}

bool AppSettingsMac::isTreatDigitNumbersAsColorManaged() {
  return false;
}

void AppSettingsMac::saveShowPreviewForLinks(bool show) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:show forKey:prefShowPreviewForLinks];
  [defaults synchronize];
}

bool AppSettingsMac::shouldShowPreviewForLinks() {
  return prefReadBoolValue(prefShowPreviewForLinks, true);
}

bool AppSettingsMac::isShowPreviewForLinksManaged() {
  return isManaged(prefShowPreviewForLinks);
}

void AppSettingsMac::saveUpdateHistoryAfterAction(bool update) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:update forKey:prefUpdateHistoryAfterAction];
  [defaults synchronize];
}

bool AppSettingsMac::shouldUpdateHistoryAfterAction() {
  return prefReadBoolValue(prefUpdateHistoryAfterAction, true);
}

bool AppSettingsMac::isUpdateHistoryAfterActionManaged() {
  return isManaged(prefUpdateHistoryAfterAction);
}

void AppSettingsMac::saveLastUpdateCheckTime(long time) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSNumber numberWithLong:time] forKey:prefLastUpdateCheckTime];
  [defaults synchronize];
}

long AppSettingsMac::getLastUpdateCheckTime() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSNumber *time = [defaults objectForKey:prefLastUpdateCheckTime];
  if (time != nil) {
    return [time longValue];
  }
  return -1;
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

void AppSettingsMac::savePasteSelectedObjectToActiveAppShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefPasteSelectedObjectToActiveAppShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getPasteSelectedObjectToActiveAppShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefPasteSelectedObjectToActiveAppShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + Enter";
}

void AppSettingsMac::savePasteNextItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefPasteNextItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getPasteNextItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefPasteNextItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ControlLeft + KeyV";
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
  return "MetaLeft + Enter";
}

void AppSettingsMac::saveShowInFinderShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefShowInFinderShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getShowInFinderShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefShowInFinderShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyO";
}

void AppSettingsMac::saveQuickLookShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefQuickLookShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getQuickLookShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefQuickLookShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyL";
}

void AppSettingsMac::saveOpenInDefaultAppShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefOpenInDefaultAppShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getOpenInDefaultAppShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefOpenInDefaultAppShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "AltLeft + MetaLeft + KeyO";
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

void AppSettingsMac::saveCopyObjectToClipboardShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCopyObjectToClipboardShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getCopyObjectToClipboardShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCopyObjectToClipboardShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyC";
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
  return "ShiftLeft + MetaLeft + KeyC";
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
  return "MetaLeft + Slash";
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
  return "MetaLeft + KeyK";
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

void AppSettingsMac::saveZoomUIResetShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefZoomUIResetShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getZoomUIResetShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefZoomUIResetShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + Digit0";
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

bool AppSettingsMac::isAppsToIgnoreManaged() {
  return isManaged(prefIgnoreApps);
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

void AppSettingsMac::saveClearHistoryOnQuit(bool clear) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:clear forKey:prefClearHistoryOnQuit];
  [defaults synchronize];
}

bool AppSettingsMac::shouldClearHistoryOnQuit() {
  return prefReadBoolValue(prefClearHistoryOnQuit, false);
}

bool AppSettingsMac::isClearHistoryOnQuitManaged() {
  return isManaged(prefClearHistoryOnQuit);
}

void AppSettingsMac::saveClearHistoryOnMacReboot(bool clear) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:clear forKey:prefClearHistoryOnMacReboot];
  [defaults synchronize];
}

bool AppSettingsMac::shouldClearHistoryOnMacReboot() {
  return prefReadBoolValue(prefClearHistoryOnMacReboot, false);
}

bool AppSettingsMac::isClearHistoryOnMacRebootManaged() {
  return isManaged(prefClearHistoryOnMacReboot);
}

void AppSettingsMac::saveNavigateToFirstItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefNavigateToFirstItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getNavigateToFirstItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefNavigateToFirstItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + ArrowUp";
}

void AppSettingsMac::saveNavigateToLastItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefNavigateToLastItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getNavigateToLastItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefNavigateToLastItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + ArrowDown";
}

void AppSettingsMac::saveNavigateToNextGroupOfItemsShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefNavigateToNextGroupOfItemsShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getNavigateToNextGroupOfItemsShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefNavigateToNextGroupOfItemsShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "AltLeft + ArrowDown";
}

void AppSettingsMac::saveNavigateToPrevGroupOfItemsShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefNavigateToPrevGroupOfItemsShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getNavigateToPrevGroupOfItemsShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefNavigateToPrevGroupOfItemsShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "AltLeft + ArrowUp";
}

void AppSettingsMac::saveSaveImageAsFileShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefSaveImageAsFileShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getSaveImageAsFileShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefSaveImageAsFileShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyS";
}

void AppSettingsMac::savePauseResumeShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefPauseResumeShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getPauseResumeShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefPauseResumeShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "";
}

void AppSettingsMac::saveOpenWindowStrategy(std::string strategy) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:strategy.c_str()] forKey:prefOpenWindowStrategy];
  [defaults synchronize];
}

std::string AppSettingsMac::getOpenWindowStrategy() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *strategy = [defaults objectForKey:prefOpenWindowStrategy];
  if (strategy != nil) {
    return {[strategy UTF8String]};
  }
  return "activeScreenLastPosition";
}

bool AppSettingsMac::isOpenWindowStrategyManaged() {
  return false;
}

void AppSettingsMac::saveRenameItemShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefRenameItemShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getRenameItemShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefRenameItemShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyR";
}

void AppSettingsMac::saveFeedbackProvided(bool provided) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:provided forKey:prefIsFeedbackProvided];
  [defaults synchronize];
}

bool AppSettingsMac::isFeedbackProvided() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults boolForKey:prefIsFeedbackProvided];
}

void AppSettingsMac::savePasteOnClick(bool paste) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:paste forKey:prefPasteOnClick];
  [defaults synchronize];
}

bool AppSettingsMac::shouldPasteOnClick() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefPasteOnClick] != nil) {
    return [defaults boolForKey:prefPasteOnClick];
  }
  return false;
}

bool AppSettingsMac::isPasteOnClickManaged() {
  return false;
}

void AppSettingsMac::savePlaySoundOnCopy(bool play) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:play forKey:prefPlaySoundOnCopy];
  [defaults synchronize];
}

bool AppSettingsMac::shouldPlaySoundOnCopy() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefPlaySoundOnCopy] != nil) {
    return [defaults boolForKey:prefPlaySoundOnCopy];
  }
  return false;
}

bool AppSettingsMac::isPlaySoundOnCopyManaged() {
  return false;
}

void AppSettingsMac::saveAlwaysDisplay(bool display) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:display forKey:prefAlwaysDisplay];
  [defaults synchronize];
}

bool AppSettingsMac::shouldAlwaysDisplay() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefAlwaysDisplay] != nil) {
    return [defaults boolForKey:prefAlwaysDisplay];
  }
  return false;
}

void AppSettingsMac::saveMakeLowerCaseShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefMakeLowerCaseShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getMakeLowerCaseShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefMakeLowerCaseShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyL";
}

void AppSettingsMac::saveMakeUpperCaseShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefMakeUpperCaseShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getMakeUpperCaseShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefMakeUpperCaseShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyU";
}

void AppSettingsMac::saveCapitalizeShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefCapitalizeShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getCapitalizeShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefCapitalizeShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyA";
}

void AppSettingsMac::saveSentenceCaseShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefSentenceCaseShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getSentenceCaseShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefSentenceCaseShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyS";
}

void AppSettingsMac::saveRemoveEmptyLinesShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefRemoveEmptyLinesShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getRemoveEmptyLinesShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefRemoveEmptyLinesShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyR";
}

void AppSettingsMac::saveStripAllWhitespacesShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefStripAllWhitespacesShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getStripAllWhitespacesShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefStripAllWhitespacesShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyT";
}

void AppSettingsMac::saveTrimSurroundingWhitespacesShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefTrimSurroundingWhitespacesShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getTrimSurroundingWhitespacesShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefTrimSurroundingWhitespacesShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "ShiftLeft + MetaLeft + KeyM";
}

void AppSettingsMac::saveCopyOnDoubleClick(bool copy) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:copy forKey:prefCopyOnDoubleClick];
  [defaults synchronize];
}

bool AppSettingsMac::shouldCopyOnDoubleClick() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefCopyOnDoubleClick] != nil) {
    return [defaults boolForKey:prefCopyOnDoubleClick];
  }
  return false;
}

bool AppSettingsMac::isCopyOnDoubleClickManaged() {
  return false;
}

void AppSettingsMac::saveCopyOnNumberAction(bool copy) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:copy forKey:prefCopyOnNumberAction];
  [defaults synchronize];
}

bool AppSettingsMac::shouldCopyOnNumberAction() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:prefCopyOnNumberAction] != nil) {
    return [defaults boolForKey:prefCopyOnNumberAction];
  }
  return false;
}

bool AppSettingsMac::isCopyOnNumberActionManaged() {
  return false;
}

void AppSettingsMac::saveToggleFilterShortcut(std::string shortcut) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSString stringWithUTF8String:shortcut.c_str()] forKey:prefToggleFilterShortcut];
  [defaults synchronize];
}

std::string AppSettingsMac::getToggleFilterShortcut() {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *shortcut = [defaults objectForKey:prefToggleFilterShortcut];
  if (shortcut != nil) {
    return {[shortcut UTF8String]};
  }
  return "MetaLeft + KeyF";
}

bool AppSettingsMac::allowCheckForUpdates() {
  return prefReadBoolValue(prefAllowCheckForUpdates, true);
}

bool AppSettingsMac::isDeviceManaged() {
  return ::isDeviceManaged();
}
