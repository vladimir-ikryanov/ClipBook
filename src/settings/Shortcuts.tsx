import * as React from "react";
import {useEffect, useState} from "react";
import ShortcutInput from "@/settings/ShortcutInput";
import {
  prefGetClearHistoryShortcut,
  prefGetCloseAppShortcut,
  prefGetCloseAppShortcut2,
  prefGetCloseAppShortcut3,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenAppShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut, prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut,
  prefSetClearHistoryShortcut,
  prefSetCloseAppShortcut, prefSetCloseAppShortcut2, prefSetCloseAppShortcut3,
  prefSetCopyToClipboardShortcut,
  prefSetDeleteHistoryItemShortcut,
  prefSetEditHistoryItemShortcut,
  prefSetOpenAppShortcut,
  prefSetOpenInBrowserShortcut,
  prefSetOpenSettingsShortcut,
  prefSetPasteSelectedItemToActiveAppShortcut,
  prefSetSearchHistoryShortcut,
  prefSetSelectNextItemShortcut,
  prefSetSelectPreviousItemShortcut,
  prefSetShowMoreActionsShortcut, prefSetToggleFavoriteShortcut,
  prefSetTogglePreviewShortcut,
  prefSetZoomUIInShortcut,
  prefSetZoomUIOutShortcut
} from "@/pref";
import {KeyboardIcon, KeyRoundIcon, ListIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";

declare const enableOpenAppShortcut: () => void;
declare const closeSettingsWindow: () => void;
declare const updateOpenSettingsShortcut: () => void;

export default function Shortcuts() {
  const [openAppShortcut, setOpenAppShortcut] = useState(prefGetOpenAppShortcut());
  const [closeAppShortcut, setCloseAppShortcut] = useState(prefGetCloseAppShortcut());
  const [closeAppShortcut2, setCloseAppShortcut2] = useState(prefGetCloseAppShortcut2());
  const [closeAppShortcut3, setCloseAppShortcut3] = useState(prefGetCloseAppShortcut3());
  const [selectNextItemShortcut, setSelectNextItemShortcut] = useState(prefGetSelectNextItemShortcut());
  const [selectPreviousItemShortcut, setSelectPreviousItemShortcut] = useState(prefGetSelectPreviousItemShortcut());
  const [pasteSelectedItemToActiveAppShortcut, setPasteSelectedItemToActiveAppShortcut] = useState(prefGetPasteSelectedItemToActiveAppShortcut());
  const [editHistoryItemShortcut, setEditHistoryItemShortcut] = useState(prefGetEditHistoryItemShortcut());
  const [openInBrowserShortcut, setOpenInBrowserShortcut] = useState(prefGetOpenInBrowserShortcut());
  const [copyToClipboardShortcut, setCopyToClipboardShortcut] = useState(prefGetCopyToClipboardShortcut());
  const [deleteHistoryItemShortcut, setDeleteHistoryItemShortcut] = useState(prefGetDeleteHistoryItemShortcut());
  const [clearHistoryShortcut, setClearHistoryShortcut] = useState(prefGetClearHistoryShortcut());
  const [searchHistoryShortcut, setSearchHistoryShortcut] = useState(prefGetSearchHistoryShortcut());
  const [togglePreviewShortcut, setTogglePreviewShortcut] = useState(prefGetTogglePreviewShortcut());
  const [showMoreActionsShortcut, setShowMoreActionsShortcut] = useState(prefGetShowMoreActionsShortcut());
  const [zoomUIInShortcut, setZoomUIInShortcut] = useState(prefGetZoomUIInShortcut());
  const [zoomUIOutShortcut, setZoomUIOutShortcut] = useState(prefGetZoomUIOutShortcut());
  const [openSettingsShortcut, setOpenSettingsShortcut] = useState(prefGetOpenSettingsShortcut());
  const [toggleFavoriteShortcut, setToggleFavoriteShortcut] = useState(prefGetToggleFavoriteShortcut());

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

  function handleEditHistoryItemShortcutChange(shortcut: string) {
    setEditHistoryItemShortcut(shortcut)
    prefSetEditHistoryItemShortcut(shortcut)
  }

  function handleOpenInBrowserShortcutChange(shortcut: string) {
    setOpenInBrowserShortcut(shortcut)
    prefSetOpenInBrowserShortcut(shortcut)
  }

  function handleCopyToClipboardShortcutChange(shortcut: string) {
    setCopyToClipboardShortcut(shortcut)
    prefSetCopyToClipboardShortcut(shortcut)
  }

  function handleDeleteHistoryItemShortcutChange(shortcut: string) {
    setDeleteHistoryItemShortcut(shortcut)
    prefSetDeleteHistoryItemShortcut(shortcut)
  }

  function handleClearHistoryShortcutChange(shortcut: string) {
    setClearHistoryShortcut(shortcut)
    prefSetClearHistoryShortcut(shortcut)
  }

  function handleSearchHistoryShortcutChange(shortcut: string) {
    setSearchHistoryShortcut(shortcut)
    prefSetSearchHistoryShortcut(shortcut)
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

  function handleOpenSettingsShortcutChange(shortcut: string) {
    setOpenSettingsShortcut(shortcut)
    prefSetOpenSettingsShortcut(shortcut)
    updateOpenSettingsShortcut()
  }

  function handleToggleFavoriteShortcutChange(shortcut: string) {
    setToggleFavoriteShortcut(shortcut)
    prefSetToggleFavoriteShortcut(shortcut)
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div
                className="flex flex-row gap-x-2 p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <SettingsIcon className="h-5 w-5 mt-0.5"/>
                <span className="">General</span>
              </a>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/history" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <ListIcon className="h-5 w-5 mt-0.5"/>
                <span className="">History</span>
              </a>
            </div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-settings-sidebarSelection rounded-sm shadow">
              <KeyboardIcon className="h-5 w-5 mt-0.5"/>
              <span className="">Shortcuts</span>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/privacy" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
            <div className="flex flex-grow"></div>
            <div
                className="flex flex-row p-0 m-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/license" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <KeyRoundIcon className="h-5 w-5 mt-0.5"/>
                <div className="">License</div>
                <div className="grow"></div>
                <div className="rounded bg-settings-sidebarLabel text-xs px-1.5 py-1">Trial</div>
              </a>
            </div>
          </div>
        </div>
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">Shortcuts</span>
          </div>

          <div className="flex flex-col px-8 pb-4 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6">
              <span className="">Open ClipBook</span>
              <ShortcutInput shortcut={openAppShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + KeyV"
                             onSave={handleOpenAppShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span>Close ClipBook</span>
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
              <span className="">Select next history item</span>
              <ShortcutInput shortcut={selectNextItemShortcut}
                             defaultShortcut="ArrowDown"
                             onSave={handleSelectNextItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Select previous history item</span>
              <ShortcutInput shortcut={selectPreviousItemShortcut}
                             defaultShortcut="ArrowUp"
                             onSave={handleSelectPreviousItemShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Paste selected item to active app</span>
              <ShortcutInput shortcut={pasteSelectedItemToActiveAppShortcut}
                             defaultShortcut="Enter"
                             onSave={handlePasteSelectedItemToActiveAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Copy to Clipboard</span>
              <ShortcutInput shortcut={copyToClipboardShortcut}
                             defaultShortcut="MetaLeft + KeyC"
                             onSave={handleCopyToClipboardShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Open in Browser</span>
              <ShortcutInput shortcut={openInBrowserShortcut}
                             defaultShortcut="AltLeft + Enter"
                             onSave={handleOpenInBrowserShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Add to favorites</span>
              <ShortcutInput shortcut={toggleFavoriteShortcut}
                             defaultShortcut="MetaLeft + KeyS"
                             onSave={handleToggleFavoriteShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Edit history item</span>
              <ShortcutInput shortcut={editHistoryItemShortcut}
                             defaultShortcut="MetaLeft + KeyE"
                             onSave={handleEditHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Delete history item</span>
              <ShortcutInput shortcut={deleteHistoryItemShortcut}
                             defaultShortcut="MetaLeft + Backspace"
                             onSave={handleDeleteHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Delete all history items</span>
              <ShortcutInput shortcut={clearHistoryShortcut}
                             defaultShortcut="ShiftLeft + MetaLeft + Backspace"
                             onSave={handleClearHistoryShortcutChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <span className="">Show/hide preview</span>
              <ShortcutInput shortcut={togglePreviewShortcut}
                             defaultShortcut="MetaLeft + KeyP"
                             onSave={handleTogglePreviewShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Show more actions</span>
              <ShortcutInput shortcut={showMoreActionsShortcut}
                             defaultShortcut="MetaLeft + KeyA"
                             onSave={handleShowMoreActionsShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Make UI text bigger</span>
              <ShortcutInput shortcut={zoomUIInShortcut} defaultShortcut="MetaLeft + Equal"
                             onSave={handleZoomUIInShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Make UI text smaller</span>
              <ShortcutInput shortcut={zoomUIOutShortcut}
                             defaultShortcut="MetaLeft + Minus"
                             onSave={handleZoomUIOutShortcutChange}/>
            </div>
            <hr/>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Open Settings</span>
              <ShortcutInput shortcut={openSettingsShortcut}
                             defaultShortcut="MetaLeft + Comma"
                             onSave={handleOpenSettingsShortcutChange}/>
            </div>
            <div className="grow"></div>
          </div>
        </div>
      </div>
  )
}
