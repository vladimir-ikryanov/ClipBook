import * as React from "react";
import {useState} from "react";
import ShortcutInput from "@/components/ShortcutInput";
import {
  prefGetClearHistoryShortcut,
  prefGetCloseAppShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenAppShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTogglePreviewShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut,
  prefSetClearHistoryShortcut,
  prefSetCloseAppShortcut,
  prefSetDeleteHistoryItemShortcut,
  prefSetEditHistoryItemShortcut,
  prefSetOpenAppShortcut,
  prefSetPasteSelectedItemToActiveAppShortcut,
  prefSetSearchHistoryShortcut,
  prefSetSelectNextItemShortcut,
  prefSetSelectPreviousItemShortcut,
  prefSetShowMoreActionsShortcut,
  prefSetTogglePreviewShortcut,
  prefSetZoomUIInShortcut,
  prefSetZoomUIOutShortcut
} from "@/pref";
import {KeyboardIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";

declare const enableOpenAppShortcut: () => void;
declare const disableOpenAppShortcut: () => void;

export default function Shortcuts() {
  const [openAppShortcut, setOpenAppShortcut] = useState(prefGetOpenAppShortcut());
  const [closeAppShortcut, setCloseAppShortcut] = useState(prefGetCloseAppShortcut());
  const [selectNextItemShortcut, setSelectNextItemShortcut] = useState(prefGetSelectNextItemShortcut());
  const [selectPreviousItemShortcut, setSelectPreviousItemShortcut] = useState(prefGetSelectPreviousItemShortcut());
  const [pasteSelectedItemToActiveAppShortcut, setPasteSelectedItemToActiveAppShortcut] = useState(prefGetPasteSelectedItemToActiveAppShortcut());
  const [editHistoryItemShortcut, setEditHistoryItemShortcut] = useState(prefGetEditHistoryItemShortcut());
  const [deleteHistoryItemShortcut, setDeleteHistoryItemShortcut] = useState(prefGetDeleteHistoryItemShortcut());
  const [clearHistoryShortcut, setClearHistoryShortcut] = useState(prefGetClearHistoryShortcut());
  const [searchHistoryShortcut, setSearchHistoryShortcut] = useState(prefGetSearchHistoryShortcut());
  const [togglePreviewShortcut, setTogglePreviewShortcut] = useState(prefGetTogglePreviewShortcut());
  const [showMoreActionsShortcut, setShowMoreActionsShortcut] = useState(prefGetShowMoreActionsShortcut());
  const [zoomUIInShortcut, setZoomUIInShortcut] = useState(prefGetZoomUIInShortcut());
  const [zoomUIOutShortcut, setZoomUIOutShortcut] = useState(prefGetZoomUIOutShortcut());

  function handleOpenAppShortcutChange(shortcut: string) {
    setOpenAppShortcut(shortcut)
    prefSetOpenAppShortcut(shortcut)
    enableOpenAppShortcut()
  }

  function handleCloseAppShortcutChange(shortcut: string) {
    setCloseAppShortcut(shortcut)
    prefSetCloseAppShortcut(shortcut)
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

  return (
      <div className="flex h-screen">
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings" className="flex flex-row gap-x-2">
                <SettingsIcon className="h-5 w-5 mt-0.5"/>
                <span className="">General</span>
              </a>
            </div>
            <div className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-background rounded-sm shadow">
              <KeyboardIcon className="h-5 w-5 mt-0.5"/>
              <span className="">Shortcuts</span>
            </div>
            <div
                className="flex flex-row py-2 px-2 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/privacy" className="flex flex-row gap-x-2">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
          </div>
        </div>
        <div className="flex flex-col flex-grow">
          <div className="flex pt-12 px-12 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">Shortcuts</span>
          </div>

          <div className="flex flex-col px-12 pb-6 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6">
              <span className="">Open ClipBook</span>
              <ShortcutInput shortcut={openAppShortcut} onSave={handleOpenAppShortcutChange}
                             onStartEditing={disableOpenAppShortcut}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Close ClipBook</span>
              <ShortcutInput shortcut={closeAppShortcut} onSave={handleCloseAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Select next history item</span>
              <ShortcutInput shortcut={selectNextItemShortcut}
                             onSave={handleSelectNextItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Select previous history item</span>
              <ShortcutInput shortcut={selectPreviousItemShortcut}
                             onSave={handleSelectPreviousItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Paste selected item to active app</span>
              <ShortcutInput shortcut={pasteSelectedItemToActiveAppShortcut}
                             onSave={handlePasteSelectedItemToActiveAppShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Edit history item</span>
              <ShortcutInput shortcut={editHistoryItemShortcut}
                             onSave={handleEditHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Delete history item</span>
              <ShortcutInput shortcut={deleteHistoryItemShortcut}
                             onSave={handleDeleteHistoryItemShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Delete all history item</span>
              <ShortcutInput shortcut={clearHistoryShortcut}
                             onSave={handleClearHistoryShortcutChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <span className="">Search</span>
              <ShortcutInput shortcut={searchHistoryShortcut}
                             onSave={handleSearchHistoryShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Show/hide preview</span>
              <ShortcutInput shortcut={togglePreviewShortcut}
                             onSave={handleTogglePreviewShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Show more actions</span>
              <ShortcutInput shortcut={showMoreActionsShortcut}
                             onSave={handleShowMoreActionsShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Zoom app UI in</span>
              <ShortcutInput shortcut={zoomUIInShortcut} onSave={handleZoomUIInShortcutChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <span className="">Zoom app UI out</span>
              <ShortcutInput shortcut={zoomUIOutShortcut}
                             onSave={handleZoomUIOutShortcutChange}/>
            </div>
            <div className="grow"></div>
          </div>
        </div>
      </div>
  )
}
