declare const saveTheme: (theme: string) => void;
declare const getTheme: () => string;
declare const saveOpenAtLogin: (openAtLogin: boolean) => void;
declare const shouldOpenAtLogin: () => boolean;
declare const saveCheckForUpdatesAutomatically: (value: boolean) => void;
declare const shouldCheckForUpdatesAutomatically: () => boolean;
declare const saveWarnOnClearHistory: (warn: boolean) => void;
declare const shouldWarnOnClearHistory: () => boolean;
declare const saveIgnoreTransientContent: (ignore: boolean) => void;
declare const saveIgnoreConfidentialContent: (ignore: boolean) => void;
declare const shouldIgnoreTransientContent: () => boolean;
declare const shouldIgnoreConfidentialContent: () => boolean;
declare const saveShowIconInMenuBar: (showIcon: boolean) => void;
declare const shouldShowIconInMenuBar: () => boolean;
declare const setAppsToIgnore: (apps: string) => void;
declare const getAppsToIgnore: () => string;

declare const saveOpenAppShortcut: (shortcut: string) => void;
declare const getOpenAppShortcut: () => string;
declare const saveCloseAppShortcut: (shortcut: string) => void;
declare const getCloseAppShortcut: () => string;
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
declare const saveCopyToClipboardShortcut: (shortcut: string) => void;
declare const getCopyToClipboardShortcut: () => string;
declare const saveDeleteHistoryItemShortcut: (shortcut: string) => void;
declare const getDeleteHistoryItemShortcut: () => string;
declare const saveClearHistoryShortcut: (shortcut: string) => void;
declare const getClearHistoryShortcut: () => string;
declare const saveSearchHistoryShortcut: (shortcut: string) => void;
declare const getSearchHistoryShortcut: () => string;
declare const saveTogglePreviewShortcut: (shortcut: string) => void;
declare const getTogglePreviewShortcut: () => string;
declare const saveShowMoreActionsShortcut: (shortcut: string) => void;
declare const getShowMoreActionsShortcut: () => string;
declare const saveZoomUIInShortcut: (shortcut: string) => void;
declare const getZoomUIInShortcut: () => string;
declare const saveZoomUIOutShortcut: (shortcut: string) => void;
declare const getZoomUIOutShortcut: () => string;
declare const saveOpenSettingsShortcut: (shortcut: string) => void;
declare const getOpenSettingsShortcut: () => string;
declare const saveToggleFavoriteShortcut: (shortcut: string) => void;
declare const getToggleFavoriteShortcut: () => string;

export function prefGetTheme() {
  return getTheme()
}

export function prefSetTheme(theme: string) {
  saveTheme(theme)
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

export function prefGetSearchHistoryShortcut() {
  return getSearchHistoryShortcut()
}

export function prefSetSearchHistoryShortcut(shortcut: string) {
  saveSearchHistoryShortcut(shortcut)
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
