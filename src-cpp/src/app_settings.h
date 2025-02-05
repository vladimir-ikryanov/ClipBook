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

  virtual void saveLastSystemBootTime(long time) = 0;
  virtual long getLastSystemBootTime() = 0;

  virtual void saveLicenseKey(std::string key) = 0;
  virtual std::string getLicenseKey() = 0;

  virtual void setShouldDisplayThankYouDialog(bool display) = 0;
  virtual bool shouldDisplayThankYouDialog() = 0;

  virtual void saveTheme(std::string theme) = 0;
  virtual std::string getTheme() = 0;

  virtual void saveWindowBounds(molybden::Rect window_bounds) = 0;
  virtual molybden::Rect getWindowBounds() = 0;

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

  virtual void saveKeepFavoritesOnClearHistory(bool keep) = 0;
  virtual bool shouldKeepFavoritesOnClearHistory() = 0;

  virtual void saveShowIconInMenuBar(bool show) = 0;
  virtual bool shouldShowIconInMenuBar() = 0;

  virtual void saveAppsToIgnore(std::string apps) = 0;
  virtual std::string getAppsToIgnore() = 0;

  virtual void saveCopyAndMergeEnabled(bool enabled) = 0;
  virtual bool isCopyAndMergeEnabled() = 0;

  virtual void saveCopyAndMergeSeparator(std::string separator) = 0;
  virtual std::string getCopyAndMergeSeparator() = 0;

  virtual void saveCopyToClipboardAfterMerge(bool copy) = 0;
  virtual bool shouldCopyToClipboardAfterMerge() = 0;

  virtual void saveClearHistoryOnQuit(bool clear) = 0;
  virtual bool shouldClearHistoryOnQuit() = 0;

  virtual void saveClearHistoryOnMacReboot(bool clear) = 0;
  virtual bool shouldClearHistoryOnMacReboot() = 0;

  virtual void saveOpenWindowStrategy(std::string strategy) = 0;
  virtual std::string getOpenWindowStrategy() = 0;

  virtual void saveTreatDigitNumbersAsColor(bool treat) = 0;
  virtual bool shouldTreatDigitNumbersAsColor() = 0;

  virtual void saveShowPreviewForLinks(bool show) = 0;
  virtual bool shouldShowPreviewForLinks() = 0;

  virtual void saveUpdateHistoryAfterAction(bool update) = 0;
  virtual bool shouldUpdateHistoryAfterAction() = 0;

  virtual void saveLastUpdateCheckTime(long time) = 0;
  virtual long getLastUpdateCheckTime() = 0;

  virtual void saveFeedbackProvided(bool provided) = 0;
  virtual bool isFeedbackProvided() = 0;

  // Shortcuts.

  virtual void saveOpenAppShortcut(std::string shortcut) = 0;
  virtual std::string getOpenAppShortcut() = 0;

  virtual void saveCloseAppShortcut(std::string shortcut) = 0;
  virtual std::string getCloseAppShortcut() = 0;

  virtual void saveCloseAppShortcut2(std::string shortcut) = 0;
  virtual std::string getCloseAppShortcut2() = 0;

  virtual void saveCloseAppShortcut3(std::string shortcut) = 0;
  virtual std::string getCloseAppShortcut3() = 0;

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

  virtual void saveCopyTextFromImageShortcut(std::string shortcut) = 0;
  virtual std::string getCopyTextFromImageShortcut() = 0;

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

  virtual void saveNavigateToFirstItemShortcut(std::string shortcut) = 0;
  virtual std::string getNavigateToFirstItemShortcut() = 0;

  virtual void saveNavigateToLastItemShortcut(std::string shortcut) = 0;
  virtual std::string getNavigateToLastItemShortcut() = 0;

  virtual void saveNavigateToNextGroupOfItemsShortcut(std::string shortcut) = 0;
  virtual std::string getNavigateToNextGroupOfItemsShortcut() = 0;

  virtual void saveNavigateToPrevGroupOfItemsShortcut(std::string shortcut) = 0;
  virtual std::string getNavigateToPrevGroupOfItemsShortcut() = 0;

  virtual void saveSaveImageAsFileShortcut(std::string shortcut) = 0;
  virtual std::string getSaveImageAsFileShortcut() = 0;

  virtual void savePauseResumeShortcut(std::string shortcut) = 0;
  virtual std::string getPauseResumeShortcut() = 0;

  virtual void saveRenameItemShortcut(std::string shortcut) = 0;
  virtual std::string getRenameItemShortcut() = 0;
};


#endif // CLIPBOOK_APP_SETTINGS_H_
