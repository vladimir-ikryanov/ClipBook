import * as React from "react";
import {useEffect, useState} from "react";
import ShortcutInput from "@/settings/ShortcutInput";
import { useTranslation } from 'react-i18next';
import {
  prefGetCapitalizeShortcut,
  prefGetClearHistoryShortcut,
  prefGetCloseAppShortcut,
  prefGetCloseAppShortcut2,
  prefGetCloseAppShortcut3, prefGetCopyObjectToClipboardShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut, prefGetMakeLowerCaseShortcut, prefGetMakeUpperCaseShortcut,
  prefGetOpenAppShortcut,
  prefGetOpenInBrowserShortcut, prefGetOpenInDefaultAppShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteNextItemToActiveAppShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut, prefGetPasteSelectedObjectToActiveAppShortcut,
  prefGetPauseResumeShortcut, prefGetQuickLookShortcut, prefGetRemoveEmptyLinesShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut, prefGetSentenceCaseShortcut, prefGetShowInFinderShortcut,
  prefGetShowMoreActionsShortcut, prefGetStripAllWhitespacesShortcut,
  prefGetToggleFavoriteShortcut, prefGetToggleFilterShortcut,
  prefGetTogglePreviewShortcut, prefGetTrimSurroundingWhitespacesShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut,
  prefGetZoomUIResetShortcut, prefSetCapitalizeShortcut,
  prefSetClearHistoryShortcut,
  prefSetCloseAppShortcut,
  prefSetCloseAppShortcut2,
  prefSetCloseAppShortcut3, prefSetCopyObjectToClipboardShortcut,
  prefSetCopyToClipboardShortcut,
  prefSetDeleteHistoryItemShortcut,
  prefSetEditHistoryItemShortcut, prefSetMakeLowerCaseShortcut, prefSetMakeUpperCaseShortcut,
  prefSetOpenAppShortcut,
  prefSetOpenInBrowserShortcut, prefSetOpenInDefaultAppShortcut,
  prefSetOpenSettingsShortcut,
  prefSetPasteNextItemToActiveAppShortcut,
  prefSetPasteSelectedItemToActiveAppShortcut, prefSetPasteSelectedObjectToActiveAppShortcut,
  prefSetPauseResumeShortcut, prefSetQuickLookShortcut, prefSetRemoveEmptyLinesShortcut,
  prefSetRenameItemShortcut,
  prefSetSaveImageAsFileShortcut,
  prefSetSelectNextItemShortcut,
  prefSetSelectPreviousItemShortcut, prefSetSentenceCaseShortcut, prefSetShowInFinderShortcut,
  prefSetShowMoreActionsShortcut, prefSetStripAllWhitespacesShortcut,
  prefSetToggleFavoriteShortcut, prefSetToggleFilterShortcut,
  prefSetTogglePreviewShortcut, prefSetTrimSurroundingWhitespacesShortcut,
  prefSetZoomUIInShortcut,
  prefSetZoomUIOutShortcut,
  prefSetZoomUIResetShortcut
} from "@/pref";

declare const closeSettingsWindow: () => void;
declare const enableOpenAppShortcut: () => void;
declare const enablePauseResumeShortcut: () => void;
declare const updateOpenSettingsShortcut: () => void;
declare const enablePasteNextItemToActiveAppShortcut: () => void;

export default function Shortcuts() {
  const { t } = useTranslation();

  const [openAppShortcut, setOpenAppShortcut] = useState(prefGetOpenAppShortcut());
  const [closeAppShortcut, setCloseAppShortcut] = useState(prefGetCloseAppShortcut());
  const [closeAppShortcut2, setCloseAppShortcut2] = useState(prefGetCloseAppShortcut2());
  const [closeAppShortcut3, setCloseAppShortcut3] = useState(prefGetCloseAppShortcut3());
  const [selectNextItemShortcut, setSelectNextItemShortcut] = useState(prefGetSelectNextItemShortcut());
  const [selectPreviousItemShortcut, setSelectPreviousItemShortcut] = useState(prefGetSelectPreviousItemShortcut());
  const [pasteSelectedItemToActiveAppShortcut, setPasteSelectedItemToActiveAppShortcut] = useState(prefGetPasteSelectedItemToActiveAppShortcut());
  const [pasteSelectedObjectToActiveAppShortcut, setPasteSelectedObjectToActiveAppShortcut] = useState(prefGetPasteSelectedObjectToActiveAppShortcut());
  const [pasteNextItemToActiveAppShortcut, setPasteNextItemToActiveAppShortcut] = useState(prefGetPasteNextItemToActiveAppShortcut());
  const [editHistoryItemShortcut, setEditHistoryItemShortcut] = useState(prefGetEditHistoryItemShortcut());
  const [openInBrowserShortcut, setOpenInBrowserShortcut] = useState(prefGetOpenInBrowserShortcut());
  const [showInFinderShortcut, setShowInFinderShortcut] = useState(prefGetShowInFinderShortcut());
  const [openInDefaultAppShortcut, setOpenInDefaultAppShortcut] = useState(prefGetOpenInDefaultAppShortcut());
  const [copyToClipboardShortcut, setCopyToClipboardShortcut] = useState(prefGetCopyToClipboardShortcut());
  const [copyObjectToClipboardShortcut, setCopyObjectToClipboardShortcut] = useState(prefGetCopyObjectToClipboardShortcut());
  const [deleteHistoryItemShortcut, setDeleteHistoryItemShortcut] = useState(prefGetDeleteHistoryItemShortcut());
  const [clearHistoryShortcut, setClearHistoryShortcut] = useState(prefGetClearHistoryShortcut());
  const [togglePreviewShortcut, setTogglePreviewShortcut] = useState(prefGetTogglePreviewShortcut());
  const [showMoreActionsShortcut, setShowMoreActionsShortcut] = useState(prefGetShowMoreActionsShortcut());
  const [zoomUIInShortcut, setZoomUIInShortcut] = useState(prefGetZoomUIInShortcut());
  const [zoomUIOutShortcut, setZoomUIOutShortcut] = useState(prefGetZoomUIOutShortcut());
  const [zoomUIResetShortcut, setZoomUIResetShortcut] = useState(prefGetZoomUIResetShortcut());
  const [openSettingsShortcut, setOpenSettingsShortcut] = useState(prefGetOpenSettingsShortcut());
  const [toggleFavoriteShortcut, setToggleFavoriteShortcut] = useState(prefGetToggleFavoriteShortcut());
  const [saveImageAsFileShortcut, setSaveImageAsFileShortcut] = useState(prefGetSaveImageAsFileShortcut());
  const [pauseResumeShortcut, setPauseResumeShortcut] = useState(prefGetPauseResumeShortcut());
  const [renameItemShortcut, setRenameItemShortcut] = useState(prefGetRenameItemShortcut());
  const [makeLowerCaseShortcut, setMakeLowerCaseShortcut] = useState(prefGetMakeLowerCaseShortcut());
  const [makeUpperCaseShortcut, setMakeUpperCaseShortcut] = useState(prefGetMakeUpperCaseShortcut());
  const [capitalizeShortcut, setCapitalizeShortcut] = useState(prefGetCapitalizeShortcut());
  const [sentenceCaseShortcut, setSentenceCaseShortcut] = useState(prefGetSentenceCaseShortcut());
  const [removeEmptyLinesShortcut, setRemoveEmptyLinesShortcut] = useState(prefGetRemoveEmptyLinesShortcut());
  const [stripAllWhitespacesShortcut, setStripAllWhitespacesShortcut] = useState(prefGetStripAllWhitespacesShortcut());
  const [trimSurroundingWhitespacesShortcut, setTrimSurroundingWhitespacesShortcut] = useState(prefGetTrimSurroundingWhitespacesShortcut());
  const [toggleFilterShortcut, setToggleFilterShortcut] = useState(prefGetToggleFilterShortcut());
  const [quickLookShortcut, setQuickLookShortcut] = useState(prefGetQuickLookShortcut());

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow()
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function handleOpenAppShortcutChange(shortcut: string) {
    setOpenAppShortcut(shortcut)
    prefSetOpenAppShortcut(shortcut)
    enableOpenAppShortcut()
  }

  function handleCloseAppShortcutChange(shortcut: string) {
    setCloseAppShortcut(shortcut)
    prefSetCloseAppShortcut(shortcut)
  }

  function handleCloseAppShortcutChange2(shortcut: string) {
    setCloseAppShortcut2(shortcut)
    prefSetCloseAppShortcut2(shortcut)
  }

  function handleCloseAppShortcutChange3(shortcut: string) {
    setCloseAppShortcut3(shortcut)
    prefSetCloseAppShortcut3(shortcut)
  }

  function handleSelectNextItemShortcutChange(shortcut: string) {
    setSelectNextItemShortcut(shortcut)
    prefSetSelectNextItemShortcut(shortcut)
  }

  function handleSelectPreviousItemShortcutChange(shortcut: string) {
    setSelectPreviousItemShortcut(shortcut)
    prefSetSelectPreviousItemShortcut(shortcut)
  }

  function handlePasteSelectedItemToActiveAppShortcutChange(shortcut: string) {
    setPasteSelectedItemToActiveAppShortcut(shortcut)
    prefSetPasteSelectedItemToActiveAppShortcut(shortcut)
  }

  function handlePasteSelectedObjectToActiveAppShortcutChange(shortcut: string) {
    setPasteSelectedObjectToActiveAppShortcut(shortcut)
    prefSetPasteSelectedObjectToActiveAppShortcut(shortcut)
  }

  function handlePasteNextItemToActiveAppShortcutChange(shortcut: string) {
    setPasteNextItemToActiveAppShortcut(shortcut)
    prefSetPasteNextItemToActiveAppShortcut(shortcut)
    enablePasteNextItemToActiveAppShortcut()
  }

  function handleEditHistoryItemShortcutChange(shortcut: string) {
    setEditHistoryItemShortcut(shortcut)
    prefSetEditHistoryItemShortcut(shortcut)
  }

  function handleRenameHistoryItemShortcutChange(shortcut: string) {
    setRenameItemShortcut(shortcut)
    prefSetRenameItemShortcut(shortcut)
  }

  function handleToggleFilterShortcutChange(shortcut: string) {
    setToggleFilterShortcut(shortcut)
    prefSetToggleFilterShortcut(shortcut)
  }

  function handleOpenInBrowserShortcutChange(shortcut: string) {
    setOpenInBrowserShortcut(shortcut)
    prefSetOpenInBrowserShortcut(shortcut)
  }

  function handleShowInFinderShortcutChange(shortcut: string) {
    setShowInFinderShortcut(shortcut)
    prefSetShowInFinderShortcut(shortcut)
  }

  function handleOpenInDefaultAppShortcutChange(shortcut: string) {
    setOpenInDefaultAppShortcut(shortcut)
    prefSetOpenInDefaultAppShortcut(shortcut)
  }

  function handleCopyToClipboardShortcutChange(shortcut: string) {
    setCopyToClipboardShortcut(shortcut)
    prefSetCopyToClipboardShortcut(shortcut)
  }

  function handleCopyObjectToClipboardShortcutChange(shortcut: string) {
    setCopyObjectToClipboardShortcut(shortcut)
    prefSetCopyObjectToClipboardShortcut(shortcut)
  }

  function handleDeleteHistoryItemShortcutChange(shortcut: string) {
    setDeleteHistoryItemShortcut(shortcut)
    prefSetDeleteHistoryItemShortcut(shortcut)
  }

  function handleClearHistoryShortcutChange(shortcut: string) {
    setClearHistoryShortcut(shortcut)
    prefSetClearHistoryShortcut(shortcut)
  }

  function handleTogglePreviewShortcutChange(shortcut: string) {
    setTogglePreviewShortcut(shortcut)
    prefSetTogglePreviewShortcut(shortcut)
  }

  function handleShowMoreActionsShortcutChange(shortcut: string) {
    setShowMoreActionsShortcut(shortcut)
    prefSetShowMoreActionsShortcut(shortcut)
  }

  function handleZoomUIInShortcutChange(shortcut: string) {
    setZoomUIInShortcut(shortcut)
    prefSetZoomUIInShortcut(shortcut)
  }

  function handleZoomUIOutShortcutChange(shortcut: string) {
    setZoomUIOutShortcut(shortcut)
    prefSetZoomUIOutShortcut(shortcut)
  }

  function handleZoomUIResetShortcutChange(shortcut: string) {
    setZoomUIResetShortcut(shortcut)
    prefSetZoomUIResetShortcut(shortcut)
  }

  function handleOpenSettingsShortcutChange(shortcut: string) {
    setOpenSettingsShortcut(shortcut)
    prefSetOpenSettingsShortcut(shortcut)
    updateOpenSettingsShortcut()
  }

  function handleToggleFavoriteShortcutChange(shortcut: string) {
    setToggleFavoriteShortcut(shortcut)
    prefSetToggleFavoriteShortcut(shortcut)
  }

  function handleQuickLookShortcutChange(shortcut: string) {
    setQuickLookShortcut(shortcut)
    prefSetQuickLookShortcut(shortcut)
  }

  function handleSaveImageAsFileShortcutChange(shortcut: string) {
    setSaveImageAsFileShortcut(shortcut)
    prefSetSaveImageAsFileShortcut(shortcut)
  }

  function handlePauseResumeShortcutChange(shortcut: string) {
    setPauseResumeShortcut(shortcut)
    prefSetPauseResumeShortcut(shortcut)
    enablePauseResumeShortcut()
  }

  function handleMakeLowerCaseShortcutChange(shortcut: string) {
    setMakeLowerCaseShortcut(shortcut)
    prefSetMakeLowerCaseShortcut(shortcut)
  }

  function handleMakeUpperCaseShortcutChange(shortcut: string) {
    setMakeUpperCaseShortcut(shortcut)
    prefSetMakeUpperCaseShortcut(shortcut)
  }

  function handleCapitalizeShortcutChange(shortcut: string) {
    setCapitalizeShortcut(shortcut)
    prefSetCapitalizeShortcut(shortcut)
  }

  function handleSentenceCaseShortcutChange(shortcut: string) {
    setSentenceCaseShortcut(shortcut)
    prefSetSentenceCaseShortcut(shortcut)
  }

  function handleRemoveEmptyLinesShortcutChange(shortcut: string) {
    setRemoveEmptyLinesShortcut(shortcut)
    prefSetRemoveEmptyLinesShortcut(shortcut)
  }

  function handleStripAllWhitespacesShortcutChange(shortcut: string) {
    setStripAllWhitespacesShortcut(shortcut)
    prefSetStripAllWhitespacesShortcut(shortcut)
  }

  function handleTrimSurroundingWhitespacesShortcutChange(shortcut: string) {
    setTrimSurroundingWhitespacesShortcut(shortcut)
    prefSetTrimSurroundingWhitespacesShortcut(shortcut)
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">{t('settings.shortcuts.title')}</span>
          </div>

          <div className="flex flex-col px-8 pb-4 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex items-center justify-between space-x-20 pt-6">
              <span className="">{t('settings.shortcuts.openApp')}</span>
              <ShortcutInput shortcut={openAppShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyV"
                             onSave={handleOpenAppShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span>{t('settings.shortcuts.closeApp')}</span>
              <ShortcutInput shortcut={closeAppShortcut3}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyV"
                             onSave={handleCloseAppShortcutChange3}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span></span>
              <ShortcutInput shortcut={closeAppShortcut2} defaultShortcut="MetaLeft + KeyW"
                             onSave={handleCloseAppShortcutChange2}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span></span>
              <ShortcutInput shortcut={closeAppShortcut} defaultShortcut="Escape"
                             onSave={handleCloseAppShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.selectNextItem')}</span>
              <ShortcutInput shortcut={selectNextItemShortcut}
                             defaultShortcut="ArrowDown"
                             onSave={handleSelectNextItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.selectPreviousItem')}</span>
              <ShortcutInput shortcut={selectPreviousItemShortcut}
                             defaultShortcut="ArrowUp"
                             onSave={handleSelectPreviousItemShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.pasteSelectedItemToActiveApp')}</span>
              <ShortcutInput shortcut={pasteSelectedItemToActiveAppShortcut}
                             defaultShortcut="Enter"
                             onSave={handlePasteSelectedItemToActiveAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.alternatePasteSelectedItemToActiveApp')}</span>
              <ShortcutInput shortcut={pasteSelectedObjectToActiveAppShortcut}
                             defaultShortcut="ShiftLeft + Enter"
                             onSave={handlePasteSelectedObjectToActiveAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.copyToClipboard')}</span>
              <ShortcutInput shortcut={copyToClipboardShortcut}
                             defaultShortcut="MetaLeft + KeyC"
                             onSave={handleCopyToClipboardShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.alternateCopyToClipboard')}</span>
              <ShortcutInput shortcut={copyObjectToClipboardShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyC"
                             onSave={handleCopyObjectToClipboardShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.openInBrowser')}</span>
              <ShortcutInput shortcut={openInBrowserShortcut}
                             defaultShortcut="MetaLeft + Enter"
                             onSave={handleOpenInBrowserShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.showInFinder')}</span>
              <ShortcutInput shortcut={showInFinderShortcut}
                             defaultShortcut="MetaLeft + KeyO"
                             onSave={handleShowInFinderShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.openInDefaultApp')}</span>
              <ShortcutInput shortcut={openInDefaultAppShortcut}
                             defaultShortcut="AltLeft + MetaLeft + KeyO"
                             onSave={handleOpenInDefaultAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.addToFavorites')}</span>
              <ShortcutInput shortcut={toggleFavoriteShortcut}
                             defaultShortcut="MetaLeft + KeyS"
                             onSave={handleToggleFavoriteShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.quickLook')}</span>
              <ShortcutInput shortcut={quickLookShortcut}
                             defaultShortcut="MetaLeft + KeyL"
                             onSave={handleQuickLookShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.saveAsFile')}</span>
              <ShortcutInput shortcut={saveImageAsFileShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyS"
                             onSave={handleSaveImageAsFileShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.editHistoryItem')}</span>
              <ShortcutInput shortcut={editHistoryItemShortcut}
                             defaultShortcut="MetaLeft + KeyE"
                             onSave={handleEditHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.renameHistoryItem')}</span>
              <ShortcutInput shortcut={renameItemShortcut}
                             defaultShortcut="MetaLeft + KeyR"
                             onSave={handleRenameHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.deleteHistoryItem')}</span>
              <ShortcutInput shortcut={deleteHistoryItemShortcut}
                             defaultShortcut="MetaLeft + Backspace"
                             onSave={handleDeleteHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.deleteAllHistoryItems')}</span>
              <ShortcutInput shortcut={clearHistoryShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + Backspace"
                             onSave={handleClearHistoryShortcutChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.showHidePreview')}</span>
              <ShortcutInput shortcut={togglePreviewShortcut}
                             defaultShortcut="MetaLeft + KeyP"
                             onSave={handleTogglePreviewShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.showHideFilter')}</span>
              <ShortcutInput shortcut={toggleFilterShortcut}
                             defaultShortcut="MetaLeft + KeyF"
                             onSave={handleToggleFilterShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.showCommandMenu')}</span>
              <ShortcutInput shortcut={showMoreActionsShortcut}
                             defaultShortcut="MetaLeft + KeyK"
                             onSave={handleShowMoreActionsShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.zoomIn')}</span>
              <ShortcutInput shortcut={zoomUIInShortcut} defaultShortcut="MetaLeft + Equal"
                             onSave={handleZoomUIInShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.zoomOut')}</span>
              <ShortcutInput shortcut={zoomUIOutShortcut}
                             defaultShortcut="MetaLeft + Minus"
                             onSave={handleZoomUIOutShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.zoomReset')}</span>
              <ShortcutInput shortcut={zoomUIResetShortcut}
                             defaultShortcut="MetaLeft + Digit0"
                             onSave={handleZoomUIResetShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.pauseResumeClipBook')}</span>
              <ShortcutInput shortcut={pauseResumeShortcut}
                             defaultShortcut=""
                             onSave={handlePauseResumeShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.openSettings')}</span>
              <ShortcutInput shortcut={openSettingsShortcut}
                             defaultShortcut="MetaLeft + Comma"
                             onSave={handleOpenSettingsShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.pasteNextItemToActiveApp')}</span>
              <ShortcutInput shortcut={pasteNextItemToActiveAppShortcut}
                             defaultShortcut="ControlLeft + KeyV"
                             onSave={handlePasteNextItemToActiveAppShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.makeLowerCase')}</span>
              <ShortcutInput shortcut={makeLowerCaseShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyL"
                             onSave={handleMakeLowerCaseShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.makeUpperCase')}</span>
              <ShortcutInput shortcut={makeUpperCaseShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyU"
                             onSave={handleMakeUpperCaseShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.capitalizeWords')}</span>
              <ShortcutInput shortcut={capitalizeShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyA"
                             onSave={handleCapitalizeShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.sentenceCase')}</span>
              <ShortcutInput shortcut={sentenceCaseShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyS"
                             onSave={handleSentenceCaseShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.removeEmptyLines')}</span>
              <ShortcutInput shortcut={removeEmptyLinesShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyR"
                             onSave={handleRemoveEmptyLinesShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.stripAllWhitespaces')}</span>
              <ShortcutInput shortcut={stripAllWhitespacesShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyT"
                             onSave={handleStripAllWhitespacesShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">{t('settings.shortcuts.trimSurroundingWhitespaces')}</span>
              <ShortcutInput shortcut={trimSurroundingWhitespacesShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyM"
                             onSave={handleTrimSurroundingWhitespacesShortcutChange}/>
            </div>
            <div className="grow"></div>
          </div>
        </div>
      </div>
  )
}
