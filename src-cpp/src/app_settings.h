#ifndef CLIPBOOK_APP_SETTINGS_H_
#define CLIPBOOK_APP_SETTINGS_H_

#include <memory>

#include "molybden.hpp"

struct AppInfo {
  std::string path;
};

class AppSettings {
 public:
  static std::shared_ptr<AppSettings> create();

  virtual void saveTheme(std::string theme) = 0;
  virtual std::string getTheme() = 0;

  virtual void saveWindowBoundsForScreen(int screen_id, molybden::Rect screen_bounds, molybden::Rect window_bounds) = 0;
  virtual molybden::Rect getWindowBoundsForScreen(int screen_id, molybden::Rect screen_bounds) = 0;

  virtual void saveIgnoreConfidentialContent(bool ignore) = 0;
  virtual bool shouldIgnoreConfidentialContent() = 0;

  virtual void saveIgnoreTransientContent(bool ignore) = 0;
  virtual bool shouldIgnoreTransientContent() = 0;

  virtual void saveOpenAtLogin(bool open) = 0;
  virtual bool shouldOpenAtLogin() = 0;

  virtual void saveCheckForUpdatesAutomatically(bool value) = 0;
  virtual bool shouldCheckForUpdatesAutomatically() = 0;

  virtual void saveWarnOnClearHistory(bool warn) = 0;
  virtual bool shouldWarnOnClearHistory() = 0;

  virtual void saveShowIconInMenuBar(bool show) = 0;
  virtual bool shouldShowIconInMenuBar() = 0;

  virtual void saveAppsToIgnore(std::string apps) = 0;
  virtual std::string getAppsToIgnore() = 0;

  // Shortcuts.

  virtual void saveOpenAppShortcut(std::string shortcut) = 0;
  virtual std::string getOpenAppShortcut() = 0;

  virtual void saveCloseAppShortcut(std::string shortcut) = 0;
  virtual std::string getCloseAppShortcut() = 0;

  virtual void saveSelectNextItemShortcut(std::string shortcut) = 0;
  virtual std::string getSelectNextItemShortcut() = 0;

  virtual void saveSelectPreviousItemShortcut(std::string shortcut) = 0;
  virtual std::string getSelectPreviousItemShortcut() = 0;

  virtual void savePasteSelectedItemToActiveAppShortcut(std::string shortcut) = 0;
  virtual std::string getPasteSelectedItemToActiveAppShortcut() = 0;

  virtual void saveEditHistoryItemShortcut(std::string shortcut) = 0;
  virtual std::string getEditHistoryItemShortcut() = 0;

  virtual void saveOpenInBrowserShortcut(std::string shortcut) = 0;
  virtual std::string getOpenInBrowserShortcut() = 0;

  virtual void saveCopyToClipboardShortcut(std::string shortcut) = 0;
  virtual std::string getCopyToClipboardShortcut() = 0;

  virtual void saveDeleteHistoryItemShortcut(std::string shortcut) = 0;
  virtual std::string getDeleteHistoryItemShortcut() = 0;

  virtual void saveClearHistoryShortcut(std::string shortcut) = 0;
  virtual std::string getClearHistoryShortcut() = 0;

  virtual void saveSearchHistoryShortcut(std::string shortcut) = 0;
  virtual std::string getSearchHistoryShortcut() = 0;

  virtual void saveTogglePreviewShortcut(std::string shortcut) = 0;
  virtual std::string getTogglePreviewShortcut() = 0;

  virtual void saveShowMoreActionsShortcut(std::string shortcut) = 0;
  virtual std::string getShowMoreActionsShortcut() = 0;

  virtual void saveZoomUIInShortcut(std::string shortcut) = 0;
  virtual std::string getZoomUIInShortcut() = 0;

  virtual void saveZoomUIOutShortcut(std::string shortcut) = 0;
  virtual std::string getZoomUIOutShortcut() = 0;

  virtual void saveOpenSettingsShortcut(std::string shortcut) = 0;
  virtual std::string getOpenSettingsShortcut() = 0;

  virtual void saveToggleFavoriteShortcut(std::string shortcut) = 0;
  virtual std::string getToggleFavoriteShortcut() = 0;
};


#endif // CLIPBOOK_APP_SETTINGS_H_
