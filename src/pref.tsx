declare const saveTheme: (theme: string) => void;
declare const getTheme: () => string;
declare const saveLicenseKey: (licenseKey: string) => void;
declare const getLicenseKey: () => string;
declare const saveOpenAtLogin: (openAtLogin: boolean) => void;
declare const shouldOpenAtLogin: () => boolean;
declare const saveCheckForUpdatesAutomatically: (value: boolean) => void;
declare const shouldCheckForUpdatesAutomatically: () => boolean;
declare const saveWarnOnClearHistory: (warn: boolean) => void;
declare const shouldWarnOnClearHistory: () => boolean;
declare const saveKeepFavoritesOnClearHistory: (keep: boolean) => void;
declare const shouldKeepFavoritesOnClearHistory: () => boolean;
declare const saveIgnoreTransientContent: (ignore: boolean) => void;
declare const saveIgnoreConfidentialContent: (ignore: boolean) => void;
declare const shouldIgnoreTransientContent: () => boolean;
declare const shouldIgnoreConfidentialContent: () => boolean;
declare const saveShowIconInMenuBar: (showIcon: boolean) => void;
declare const shouldShowIconInMenuBar: () => boolean;
declare const setAppsToIgnore: (apps: string) => void;
declare const getAppsToIgnore: () => string;
declare const saveCopyAndMergeEnabled: (enabled: boolean) => void;
declare const isCopyAndMergeEnabled: () => boolean;
declare const saveCopyAndMergeSeparator: (separator: string) => void;
declare const getCopyAndMergeSeparator: () => string;
declare const saveCopyToClipboardAfterMerge: (copy: boolean) => void;
declare const shouldCopyToClipboardAfterMerge: () => boolean;
declare const saveClearHistoryOnQuit: (clear: boolean) => void;
declare const shouldClearHistoryOnQuit: () => boolean;
declare const saveClearHistoryOnMacReboot: (clear: boolean) => void;
declare const shouldClearHistoryOnMacReboot: () => boolean;
declare const saveOpenWindowStrategy: (strategy: string) => void;
declare const getOpenWindowStrategy: () => string;
declare const setTreatDigitNumbersAsColor: (treat: boolean) => void;
declare const shouldTreatDigitNumbersAsColor: () => boolean;
declare const setShowPreviewForLinks: (show: boolean) => void;
declare const shouldShowPreviewForLinks: () => boolean;
declare const setUpdateHistoryAfterAction: (update: boolean) => void;
declare const shouldUpdateHistoryAfterAction: () => boolean;
declare const shouldPasteOnClick: () => boolean;
declare const setPasteOnClick: (paste: boolean) => void;
declare const shouldPlaySoundOnCopy: () => boolean;
declare const setPlaySoundOnCopy: (play: boolean) => void;
declare const shouldAlwaysDisplay: () => boolean;
declare const setAlwaysDisplay: (display: boolean) => void;
declare const setFeedbackProvided: (provided: boolean) => void;
declare const isFeedbackProvided: () => boolean;
declare const setCopyOnDoubleClick: (copy: boolean) => void;
declare const shouldCopyOnDoubleClick: () => boolean;
declare const setCopyOnNumberAction: (copy: boolean) => void;
declare const shouldCopyOnNumberAction: () => boolean;

declare const saveOpenAppShortcut: (shortcut: string) => void;
declare const getOpenAppShortcut: () => string;
declare const saveCloseAppShortcut: (shortcut: string) => void;
declare const getCloseAppShortcut: () => string;
declare const saveCloseAppShortcut2: (shortcut: string) => void;
declare const getCloseAppShortcut2: () => string;
declare const saveCloseAppShortcut3: (shortcut: string) => void;
declare const getCloseAppShortcut3: () => string;
declare const saveSelectNextItemShortcut: (shortcut: string) => void;
declare const getSelectNextItemShortcut: () => string;
declare const saveSelectPreviousItemShortcut: (shortcut: string) => void;
declare const getSelectPreviousItemShortcut: () => string;
declare const savePasteSelectedItemToActiveAppShortcut: (shortcut: string) => void;
declare const getPasteSelectedItemToActiveAppShortcut: () => string;
declare const saveEditHistoryItemShortcut: (shortcut: string) => void;
declare const getEditHistoryItemShortcut: () => string;
declare const saveOpenInBrowserShortcut: (shortcut: string) => void;
declare const getOpenInBrowserShortcut: () => string;
declare const saveShowInFinderShortcut: (shortcut: string) => void;
declare const getShowInFinderShortcut: () => string;
declare const saveOpenInDefaultAppShortcut: (shortcut: string) => void;
declare const getOpenInDefaultAppShortcut: () => string;
declare const saveCopyToClipboardShortcut: (shortcut: string) => void;
declare const getCopyToClipboardShortcut: () => string;
declare const saveCopyTextFromImageShortcut: (shortcut: string) => void;
declare const getCopyTextFromImageShortcut: () => string;
declare const saveDeleteHistoryItemShortcut: (shortcut: string) => void;
declare const getDeleteHistoryItemShortcut: () => string;
declare const saveClearHistoryShortcut: (shortcut: string) => void;
declare const getClearHistoryShortcut: () => string;
declare const saveTogglePreviewShortcut: (shortcut: string) => void;
declare const getTogglePreviewShortcut: () => string;
declare const saveShowMoreActionsShortcut: (shortcut: string) => void;
declare const getShowMoreActionsShortcut: () => string;
declare const saveZoomUIInShortcut: (shortcut: string) => void;
declare const getZoomUIInShortcut: () => string;
declare const saveZoomUIOutShortcut: (shortcut: string) => void;
declare const getZoomUIOutShortcut: () => string;
declare const saveZoomUIResetShortcut: (shortcut: string) => void;
declare const getZoomUIResetShortcut: () => string;
declare const saveOpenSettingsShortcut: (shortcut: string) => void;
declare const getOpenSettingsShortcut: () => string;
declare const saveToggleFavoriteShortcut: (shortcut: string) => void;
declare const getToggleFavoriteShortcut: () => string;
declare const saveNavigateToFirstItemShortcut: (shortcut: string) => void;
declare const getNavigateToFirstItemShortcut: () => string;
declare const saveNavigateToLastItemShortcut: (shortcut: string) => void;
declare const getNavigateToLastItemShortcut: () => string;
declare const saveNavigateToNextGroupOfItemsShortcut: (shortcut: string) => void;
declare const getNavigateToNextGroupOfItemsShortcut: () => string;
declare const saveNavigateToPrevGroupOfItemsShortcut: (shortcut: string) => void;
declare const getNavigateToPrevGroupOfItemsShortcut: () => string;
declare const getSaveImageAsFileShortcut: () => string;
declare const saveSaveImageAsFileShortcut: (shortcut: string) => void;
declare const savePauseResumeShortcut: (shortcut: string) => void;
declare const getPauseResumeShortcut: () => string;
declare const saveRenameItemShortcut: (shortcut: string) => void;
declare const getRenameItemShortcut: () => string;
declare const saveMakeLowerCaseShortcut: (shortcut: string) => void;
declare const getMakeLowerCaseShortcut: () => string;
declare const saveMakeUpperCaseShortcut: (shortcut: string) => void;
declare const getMakeUpperCaseShortcut: () => string;
declare const saveCapitalizeShortcut: (shortcut: string) => void;
declare const getCapitalizeShortcut: () => string;
declare const saveSentenceCaseShortcut: (shortcut: string) => void;
declare const getSentenceCaseShortcut: () => string;
declare const saveRemoveEmptyLinesShortcut: (shortcut: string) => void;
declare const getRemoveEmptyLinesShortcut: () => string;
declare const saveStripAllWhitespacesShortcut: (shortcut: string) => void;
declare const getStripAllWhitespacesShortcut: () => string;
declare const saveTrimSurroundingWhitespacesShortcut: (shortcut: string) => void;
declare const getTrimSurroundingWhitespacesShortcut: () => string;
declare const saveToggleFilterShortcut: (shortcut: string) => void;
declare const getToggleFilterShortcut: () => string;

export enum OpenWindowStrategy {
  ACTIVE_SCREEN_LAST_POSITION = "activeScreenLastPosition",
  ACTIVE_SCREEN_CENTER = "activeScreenCenter",
  ACTIVE_WINDOW_CENTER = "activeWindowCenter",
  SCREEN_WITH_CURSOR = "screenWithCursor",
  MOUSE_CURSOR = "mouseCursor",
  INPUT_CURSOR = "inputCursor",
}

export enum DoubleClickStrategy {
  COPY = "copy",
  PASTE = "paste",
}

export enum NumberActionStrategy {
  COPY = "copy",
  PASTE = "paste",
}

export function prefGetTheme() {
  return getTheme()
}

export function prefSetTheme(theme: string) {
  saveTheme(theme)
}

export function prefSetLicenseKey(licenseKey: string) {
  saveLicenseKey(licenseKey)
}

export function prefGetLicenseKey() {
  return getLicenseKey()
}

export function prefGetOpenAtLogin() {
  return shouldOpenAtLogin()
}

export function prefSetOpenAtLogin(openAtLogin: boolean) {
  saveOpenAtLogin(openAtLogin)
}

export function prefGetCheckForUpdatesAutomatically() {
  return shouldCheckForUpdatesAutomatically()
}

export function prefSetCheckForUpdatesAutomatically(checkForUpdatesAutomatically: boolean) {
  saveCheckForUpdatesAutomatically(checkForUpdatesAutomatically)
}

export function prefGetWarnOnClearHistory() {
  return shouldWarnOnClearHistory()
}

export function prefSetWarnOnClearHistory(warn: boolean) {
  saveWarnOnClearHistory(warn)
}

export function prefGetKeepFavoritesOnClearHistory() {
  return shouldKeepFavoritesOnClearHistory()
}

export function prefSetKeepFavoritesOnClearHistory(keep: boolean) {
  saveKeepFavoritesOnClearHistory(keep)
}

export function prefGetIgnoreTransientContent() {
  return shouldIgnoreTransientContent()
}

export function prefSetIgnoreTransientContent(ignore: boolean) {
  saveIgnoreTransientContent(ignore)
}

export function prefGetIgnoreConfidentialContent() {
  return shouldIgnoreConfidentialContent()
}

export function prefSetIgnoreConfidentialContent(ignore: boolean) {
  saveIgnoreConfidentialContent(ignore)
}

export function prefGetOpenAppShortcut() {
  return getOpenAppShortcut()
}

export function prefSetOpenAppShortcut(shortcut: string) {
  saveOpenAppShortcut(shortcut)
}

export function prefGetCloseAppShortcut() {
  return getCloseAppShortcut()
}

export function prefSetCloseAppShortcut(shortcut: string) {
  saveCloseAppShortcut(shortcut)
}

export function prefGetCloseAppShortcut2() {
  return getCloseAppShortcut2()
}

export function prefSetCloseAppShortcut2(shortcut: string) {
  saveCloseAppShortcut2(shortcut)
}

export function prefGetCloseAppShortcut3() {
  return getCloseAppShortcut3()
}

export function prefSetCloseAppShortcut3(shortcut: string) {
  saveCloseAppShortcut3(shortcut)
}

export function prefGetSelectNextItemShortcut() {
  return getSelectNextItemShortcut()
}

export function prefSetSelectNextItemShortcut(shortcut: string) {
  saveSelectNextItemShortcut(shortcut)
}

export function prefGetSelectPreviousItemShortcut() {
  return getSelectPreviousItemShortcut()
}

export function prefSetSelectPreviousItemShortcut(shortcut: string) {
  saveSelectPreviousItemShortcut(shortcut)
}

export function prefGetPasteSelectedItemToActiveAppShortcut() {
  return getPasteSelectedItemToActiveAppShortcut()
}

export function prefSetPasteSelectedItemToActiveAppShortcut(shortcut: string) {
  savePasteSelectedItemToActiveAppShortcut(shortcut)
}

export function prefGetEditHistoryItemShortcut() {
  return getEditHistoryItemShortcut()
}

export function prefSetEditHistoryItemShortcut(shortcut: string) {
  saveEditHistoryItemShortcut(shortcut)
}

export function prefGetOpenInBrowserShortcut() {
  return getOpenInBrowserShortcut()
}

export function prefSetOpenInBrowserShortcut(shortcut: string) {
  saveOpenInBrowserShortcut(shortcut)
}

export function prefGetShowInFinderShortcut() {
  return getShowInFinderShortcut()
}

export function prefSetShowInFinderShortcut(shortcut: string) {
  saveShowInFinderShortcut(shortcut)
}

export function prefGetOpenInDefaultAppShortcut() {
  return getOpenInDefaultAppShortcut()
}

export function prefSetOpenInDefaultAppShortcut(shortcut: string) {
  saveOpenInDefaultAppShortcut(shortcut)
}

export function prefGetCopyToClipboardShortcut() {
  return getCopyToClipboardShortcut()
}

export function prefSetCopyToClipboardShortcut(shortcut: string) {
  saveCopyToClipboardShortcut(shortcut)
}

export function prefGetDeleteHistoryItemShortcut() {
  return getDeleteHistoryItemShortcut()
}

export function prefSetDeleteHistoryItemShortcut(shortcut: string) {
  saveDeleteHistoryItemShortcut(shortcut)
}

export function prefGetClearHistoryShortcut() {
  return getClearHistoryShortcut()
}

export function prefSetClearHistoryShortcut(shortcut: string) {
  saveClearHistoryShortcut(shortcut)
}

export function prefGetTogglePreviewShortcut() {
  return getTogglePreviewShortcut()
}

export function prefSetTogglePreviewShortcut(shortcut: string) {
  saveTogglePreviewShortcut(shortcut)
}

export function prefGetShowMoreActionsShortcut() {
  return getShowMoreActionsShortcut()
}

export function prefSetShowMoreActionsShortcut(shortcut: string) {
  saveShowMoreActionsShortcut(shortcut)
}

export function prefGetZoomUIInShortcut() {
  return getZoomUIInShortcut()
}

export function prefSetZoomUIInShortcut(shortcut: string) {
  saveZoomUIInShortcut(shortcut)
}

export function prefGetZoomUIOutShortcut() {
  return getZoomUIOutShortcut()
}

export function prefSetZoomUIOutShortcut(shortcut: string) {
  saveZoomUIOutShortcut(shortcut)
}

export function prefGetZoomUIResetShortcut() {
  return getZoomUIResetShortcut()
}

export function prefSetZoomUIResetShortcut(shortcut: string) {
  saveZoomUIResetShortcut(shortcut)
}

export function prefGetOpenSettingsShortcut() {
  return getOpenSettingsShortcut()
}

export function prefSetOpenSettingsShortcut(shortcut: string) {
  saveOpenSettingsShortcut(shortcut)
}

export function prefGetToggleFavoriteShortcut() {
  return getToggleFavoriteShortcut()
}

export function prefSetToggleFavoriteShortcut(shortcut: string) {
  saveToggleFavoriteShortcut(shortcut)
}

export function prefSetShowIconInMenuBar(showIcon: boolean) {
  saveShowIconInMenuBar(showIcon)
}

export function prefGetShowIconInMenuBar() {
  return shouldShowIconInMenuBar()
}

export function prefGetAppsToIgnore(): string[] {
  let apps = getAppsToIgnore();
  if (apps === "") {
    return []
  }
  return apps.split(",")
}

export function prefSetAppsToIgnore(apps: string[]) {
  setAppsToIgnore(apps.join(","))
}

export function prefGetCopyTextFromImageShortcut() {
  return getCopyTextFromImageShortcut()
}

export function prefSetCopyTextFromImageShortcut(shortcut: string) {
  saveCopyTextFromImageShortcut(shortcut)
}

export function prefGetCopyAndMergeEnabled() {
  return isCopyAndMergeEnabled()
}

export function prefSetCopyAndMergeEnabled(enabled: boolean) {
  saveCopyAndMergeEnabled(enabled)
}

export enum CopyAndMergeSeparator {
  LINE = "\n",
  SPACE = " ",
}

export function prefGetCopyAndMergeSeparator(): CopyAndMergeSeparator {
  let separator = getCopyAndMergeSeparator();
  if (separator === " ") {
    return CopyAndMergeSeparator.SPACE
  }
  return CopyAndMergeSeparator.LINE
}

export function prefSetCopyAndMergeSeparator(separator: CopyAndMergeSeparator) {
  saveCopyAndMergeSeparator(separator)
}

export function prefGetCopyToClipboardAfterMerge() {
  return shouldCopyToClipboardAfterMerge()
}

export function prefSetCopyToClipboardAfterMerge(copy: boolean) {
  saveCopyToClipboardAfterMerge(copy)
}

export function prefGetQuickPasteModifier() {
  return "MetaLeft"
}

export function prefGetQuickPasteShortcuts(): string[] {
  const shortcuts = [];
  let modifier = prefGetQuickPasteModifier();
  for (let i = 1; i <= 9; i++) {
    shortcuts.push(`${modifier} + Digit${i}`)
  }
  return shortcuts
}

export function prefGetClearHistoryOnQuit() {
  return shouldClearHistoryOnQuit()
}

export function prefSetClearHistoryOnQuit(clear: boolean) {
  saveClearHistoryOnQuit(clear)
}

export function prefGetClearHistoryOnMacReboot() {
  return shouldClearHistoryOnMacReboot()
}

export function prefSetClearHistoryOnMacReboot(clear: boolean) {
  saveClearHistoryOnMacReboot(clear)
}

export function prefGetNavigateToFirstItemShortcut() {
  return getNavigateToFirstItemShortcut()
}

export function prefSetNavigateToFirstItemShortcut(shortcut: string) {
  saveNavigateToFirstItemShortcut(shortcut)
}

export function prefGetNavigateToLastItemShortcut() {
  return getNavigateToLastItemShortcut()
}

export function prefSetNavigateToLastItemShortcut(shortcut: string) {
  saveNavigateToLastItemShortcut(shortcut)
}

export function prefGetNavigateToNextGroupOfItemsShortcut() {
  return getNavigateToNextGroupOfItemsShortcut()
}

export function prefSetNavigateToNextGroupOfItemsShortcut(shortcut: string) {
  saveNavigateToNextGroupOfItemsShortcut(shortcut)
}

export function prefGetNavigateToPrevGroupOfItemsShortcut() {
  return getNavigateToPrevGroupOfItemsShortcut()
}

export function prefSetNavigateToPrevGroupOfItemsShortcut(shortcut: string) {
  saveNavigateToPrevGroupOfItemsShortcut(shortcut)
}

export function prefGetOpenWindowStrategy(): OpenWindowStrategy {
  let strategy = getOpenWindowStrategy()
  if (strategy === null) {
    return OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION
  }
  if (strategy === OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION) {
    return OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION
  } else if (strategy === OpenWindowStrategy.ACTIVE_SCREEN_CENTER) {
    return OpenWindowStrategy.ACTIVE_SCREEN_CENTER
  } else if (strategy === OpenWindowStrategy.ACTIVE_WINDOW_CENTER) {
    return OpenWindowStrategy.ACTIVE_WINDOW_CENTER
  } else if (strategy === OpenWindowStrategy.SCREEN_WITH_CURSOR) {
    return OpenWindowStrategy.SCREEN_WITH_CURSOR
  } else if (strategy === OpenWindowStrategy.MOUSE_CURSOR) {
    return OpenWindowStrategy.MOUSE_CURSOR
  } else if (strategy === OpenWindowStrategy.INPUT_CURSOR) {
    return OpenWindowStrategy.INPUT_CURSOR
  }
  return OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION
}

export function prefSetOpenWindowStrategy(strategy: OpenWindowStrategy) {
  saveOpenWindowStrategy(strategy)
}

export function prefSetTreatDigitNumbersAsColor(treat: boolean) {
  setTreatDigitNumbersAsColor(treat)
}

export function prefShouldTreatDigitNumbersAsColor() {
  return shouldTreatDigitNumbersAsColor()
}

export function prefSetShowPreviewForLinks(show: boolean) {
  setShowPreviewForLinks(show)
}

export function prefShouldShowPreviewForLinks() {
  return shouldShowPreviewForLinks()
}

export function prefGetSaveImageAsFileShortcut() {
  return getSaveImageAsFileShortcut()
}

export function prefSetSaveImageAsFileShortcut(shortcut: string) {
  saveSaveImageAsFileShortcut(shortcut)
}

export function prefGetPauseResumeShortcut() {
  return getPauseResumeShortcut()
}

export function prefSetPauseResumeShortcut(shortcut: string) {
  savePauseResumeShortcut(shortcut)
}

export function prefSetUpdateHistoryAfterAction(update: boolean) {
  setUpdateHistoryAfterAction(update)
}

export function prefShouldUpdateHistoryAfterAction() {
  return shouldUpdateHistoryAfterAction()
}

export function prefSetRenameItemShortcut(shortcut: string) {
  saveRenameItemShortcut(shortcut)
}

export function prefGetRenameItemShortcut() {
  return getRenameItemShortcut()
}

export function prefIsFeedbackProvided() {
  return isFeedbackProvided()
}

export function prefSetFeedbackProvided(provided: boolean) {
  setFeedbackProvided(provided)
}

export function prefShouldPasteOnClick() {
  return shouldPasteOnClick()
}

export function prefSetPasteOnClick(paste: boolean) {
  setPasteOnClick(paste)
}

export function prefShouldPlaySoundOnCopy() {
  return shouldPlaySoundOnCopy()
}

export function prefSetPlaySoundOnCopy(play: boolean) {
  setPlaySoundOnCopy(play)
}

export function prefShouldAlwaysDisplay() {
  return shouldAlwaysDisplay()
}

export function prefSetAlwaysDisplay(display: boolean) {
  setAlwaysDisplay(display)
}

export function prefGetMakeLowerCaseShortcut() {
  return getMakeLowerCaseShortcut()
}

export function prefSetMakeLowerCaseShortcut(shortcut: string) {
  saveMakeLowerCaseShortcut(shortcut)
}

export function prefGetMakeUpperCaseShortcut() {
  return getMakeUpperCaseShortcut()
}

export function prefSetMakeUpperCaseShortcut(shortcut: string) {
  saveMakeUpperCaseShortcut(shortcut)
}

export function prefGetCapitalizeShortcut() {
  return getCapitalizeShortcut()
}

export function prefSetCapitalizeShortcut(shortcut: string) {
  saveCapitalizeShortcut(shortcut)
}

export function prefGetSentenceCaseShortcut() {
  return getSentenceCaseShortcut()
}

export function prefSetSentenceCaseShortcut(shortcut: string) {
  saveSentenceCaseShortcut(shortcut)
}

export function prefGetRemoveEmptyLinesShortcut() {
  return getRemoveEmptyLinesShortcut()
}

export function prefSetRemoveEmptyLinesShortcut(shortcut: string) {
  saveRemoveEmptyLinesShortcut(shortcut)
}

export function prefGetStripAllWhitespacesShortcut() {
  return getStripAllWhitespacesShortcut()
}

export function prefSetStripAllWhitespacesShortcut(shortcut: string) {
  saveStripAllWhitespacesShortcut(shortcut)
}

export function prefGetTrimSurroundingWhitespacesShortcut() {
  return getTrimSurroundingWhitespacesShortcut()
}

export function prefSetTrimSurroundingWhitespacesShortcut(shortcut: string) {
  saveTrimSurroundingWhitespacesShortcut(shortcut)
}

export function prefGetToggleFilterShortcut() {
  return getToggleFilterShortcut()
}

export function prefSetToggleFilterShortcut(shortcut: string) {
  saveToggleFilterShortcut(shortcut)
}

export function prefSetCopyOnDoubleClick(copy: boolean) {
  setCopyOnDoubleClick(copy)
}

export function prefShouldCopyOnDoubleClick() {
  return shouldCopyOnDoubleClick()
}

export function prefSetCopyOnNumberAction(copy: boolean) {
  setCopyOnNumberAction(copy)
}

export function prefShouldCopyOnNumberAction() {
  return shouldCopyOnNumberAction()
}
