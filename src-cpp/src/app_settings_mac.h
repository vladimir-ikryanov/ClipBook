#ifndef CLIPBOOK_APP_SETTINGS_MAC_H_
#define CLIPBOOK_APP_SETTINGS_MAC_H_

#include <memory>

#include "app_settings.h"

class AppSettingsMac : public AppSettings {
 public:
  AppSettingsMac();

  void saveLastSystemBootTime(long time) override;
  long getLastSystemBootTime() override;

  void saveLicenseKey(std::string key) override;
  std::string getLicenseKey() override;

  void setShouldDisplayThankYouDialog(bool display) override;
  bool shouldDisplayThankYouDialog() override;

  void saveTheme(std::string theme) override;
  std::string getTheme() override;

  void saveWindowBounds(molybden::Rect window_bounds) override;
  molybden::Rect getWindowBounds() override;

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

  void saveClearHistoryOnQuit(bool clear) override;
  bool shouldClearHistoryOnQuit() override;

  void saveClearHistoryOnMacReboot(bool clear) override;
  bool shouldClearHistoryOnMacReboot() override;

  void saveOpenWindowStrategy(std::string strategy) override;
  std::string getOpenWindowStrategy() override;

  void saveTreatDigitNumbersAsColor(bool treat) override;
  bool shouldTreatDigitNumbersAsColor() override;

  void saveShowPreviewForLinks(bool show) override;
  bool shouldShowPreviewForLinks() override;

  void saveUpdateHistoryAfterAction(bool update) override;
  bool shouldUpdateHistoryAfterAction() override;

  void saveLastUpdateCheckTime(long time) override;
  long getLastUpdateCheckTime() override;

  void saveFeedbackProvided(bool provided) override;
  bool isFeedbackProvided() override;

  void savePasteOnClick(bool paste) override;
  bool shouldPasteOnClick() override;

  void savePlaySoundOnCopy(bool play) override;
  bool shouldPlaySoundOnCopy() override;

  void saveAlwaysDisplay(bool display) override;
  bool shouldAlwaysDisplay() override;

  void saveCopyOnDoubleClick(bool copy) override;
  bool shouldCopyOnDoubleClick() override;

  void saveCopyOnNumberAction(bool copy) override;
  bool shouldCopyOnNumberAction() override;

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

  void saveShowInFinderShortcut(std::string shortcut) override;
  std::string getShowInFinderShortcut() override;

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

  void saveZoomUIResetShortcut(std::string shortcut) override;
  std::string getZoomUIResetShortcut() override;

  void saveOpenSettingsShortcut(std::string shortcut) override;
  std::string getOpenSettingsShortcut() override;

  void saveToggleFavoriteShortcut(std::string shortcut) override;
  std::string getToggleFavoriteShortcut() override;

  void saveNavigateToFirstItemShortcut(std::string shortcut) override;
  std::string getNavigateToFirstItemShortcut() override;

  void saveNavigateToLastItemShortcut(std::string shortcut) override;
  std::string getNavigateToLastItemShortcut() override;

  void saveNavigateToNextGroupOfItemsShortcut(std::string shortcut) override;
  std::string getNavigateToNextGroupOfItemsShortcut() override;

  void saveNavigateToPrevGroupOfItemsShortcut(std::string shortcut) override;
  std::string getNavigateToPrevGroupOfItemsShortcut() override;

  void saveSaveImageAsFileShortcut(std::string shortcut) override;
  std::string getSaveImageAsFileShortcut() override;

  void savePauseResumeShortcut(std::string shortcut) override;
  std::string getPauseResumeShortcut() override;

  void saveRenameItemShortcut(std::string shortcut) override;
  std::string getRenameItemShortcut() override;

  void saveMakeLowerCaseShortcut(std::string shortcut) override;
  std::string getMakeLowerCaseShortcut() override;

  void saveMakeUpperCaseShortcut(std::string shortcut) override;
  std::string getMakeUpperCaseShortcut() override;

  void saveCapitalizeShortcut(std::string shortcut) override;
  std::string getCapitalizeShortcut() override;

  void saveSentenceCaseShortcut(std::string shortcut) override;
  std::string getSentenceCaseShortcut() override;

  void saveRemoveEmptyLinesShortcut(std::string shortcut) override;
  std::string getRemoveEmptyLinesShortcut() override;

  void saveStripAllWhitespacesShortcut(std::string shortcut) override;
  std::string getStripAllWhitespacesShortcut() override;

  void saveTrimSurroundingWhitespacesShortcut(std::string shortcut) override;
  std::string getTrimSurroundingWhitespacesShortcut() override;

 private:
  static molybden::Rect getWindowBoundsForScreen(int screen_id);
};


#endif // CLIPBOOK_APP_SETTINGS_MAC_H_
