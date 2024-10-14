#ifndef CLIPBOOK_APP_SETTINGS_MAC_H_
#define CLIPBOOK_APP_SETTINGS_MAC_H_

#include <memory>

#include "app_settings.h"

class AppSettingsMac : public AppSettings {
 public:
  AppSettingsMac();

  void saveTheme(std::string theme) override;
  std::string getTheme() override;

  void saveWindowBoundsForScreen(int screen_id, molybden::Rect screen_bounds, molybden::Rect window_bounds) override;
  molybden::Rect getWindowBoundsForScreen(int screen_id, molybden::Rect screen_bounds) override;

  void saveIgnoreConfidentialContent(bool ignore) override;
  bool shouldIgnoreConfidentialContent() override;

  void saveIgnoreTransientContent(bool ignore) override;
  bool shouldIgnoreTransientContent() override;

  void saveOpenAtLogin(bool open) override;
  bool shouldOpenAtLogin() override;

  void saveCheckForUpdatesAutomatically(bool open) override;
  bool shouldCheckForUpdatesAutomatically() override;

  void saveWarnOnClearHistory(bool warn) override;
  bool shouldWarnOnClearHistory() override;

  void saveKeepFavoritesOnClearHistory(bool keep) override;
  bool shouldKeepFavoritesOnClearHistory() override;

  void saveShowIconInMenuBar(bool show) override;
  bool shouldShowIconInMenuBar() override;

  void saveAppsToIgnore(std::string apps) override;
  std::string getAppsToIgnore() override;

  void saveCopyAndMergeEnabled(bool enabled) override;
  bool isCopyAndMergeEnabled() override;

  void saveCopyAndMergeSeparator(std::string separator) override;
  std::string getCopyAndMergeSeparator() override;

  void saveCopyToClipboardAfterMerge(bool copy) override;
  bool shouldCopyToClipboardAfterMerge() override;

  // Shortcuts.

  void saveOpenAppShortcut(std::string shortcut) override;
  std::string getOpenAppShortcut() override;

  void saveCloseAppShortcut(std::string shortcut) override;
  std::string getCloseAppShortcut() override;

  void saveCloseAppShortcut2(std::string shortcut) override;
  std::string getCloseAppShortcut2() override;

  void saveCloseAppShortcut3(std::string shortcut) override;
  std::string getCloseAppShortcut3() override;

  void saveSelectNextItemShortcut(std::string shortcut) override;
  std::string getSelectNextItemShortcut() override;

  void saveSelectPreviousItemShortcut(std::string shortcut) override;
  std::string getSelectPreviousItemShortcut() override;

  void savePasteSelectedItemToActiveAppShortcut(std::string shortcut) override;
  std::string getPasteSelectedItemToActiveAppShortcut() override;

  void saveEditHistoryItemShortcut(std::string shortcut) override;
  std::string getEditHistoryItemShortcut() override;

  void saveOpenInBrowserShortcut(std::string shortcut) override;
  std::string getOpenInBrowserShortcut() override;

  void saveCopyToClipboardShortcut(std::string shortcut) override;
  std::string getCopyToClipboardShortcut() override;

  void saveCopyTextFromImageShortcut(std::string shortcut) override;
  std::string getCopyTextFromImageShortcut() override;

  void saveDeleteHistoryItemShortcut(std::string shortcut) override;
  std::string getDeleteHistoryItemShortcut() override;

  void saveClearHistoryShortcut(std::string shortcut) override;
  std::string getClearHistoryShortcut() override;

  void saveSearchHistoryShortcut(std::string shortcut) override;
  std::string getSearchHistoryShortcut() override;

  void saveTogglePreviewShortcut(std::string shortcut) override;
  std::string getTogglePreviewShortcut() override;

  void saveShowMoreActionsShortcut(std::string shortcut) override;
  std::string getShowMoreActionsShortcut() override;

  void saveZoomUIInShortcut(std::string shortcut) override;
  std::string getZoomUIInShortcut() override;

  void saveZoomUIOutShortcut(std::string shortcut) override;
  std::string getZoomUIOutShortcut() override;

  void saveOpenSettingsShortcut(std::string shortcut) override;
  std::string getOpenSettingsShortcut() override;

  void saveToggleFavoriteShortcut(std::string shortcut) override;
  std::string getToggleFavoriteShortcut() override;

 private:
  static molybden::Rect getWindowBoundsForScreen(int screen_id);
};


#endif // CLIPBOOK_APP_SETTINGS_MAC_H_
