import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";
import {useState} from "react";
import ShortcutInput from "@/components/ShortcutInput";
import {
  prefGetClearHistoryShortcut,
  prefGetCloseAppShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetIgnoreConfidentialContent,
  prefGetIgnoreTransientContent,
  prefGetOpenAppShortcut,
  prefGetOpenAtLogin,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTheme,
  prefGetTogglePreviewShortcut,
  prefGetWarnOnClearHistory,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut, prefSetClearHistoryShortcut,
  prefSetCloseAppShortcut, prefSetDeleteHistoryItemShortcut, prefSetEditHistoryItemShortcut,
  prefSetIgnoreConfidentialContent,
  prefSetIgnoreTransientContent,
  prefSetOpenAppShortcut,
  prefSetOpenAtLogin,
  prefSetPasteSelectedItemToActiveAppShortcut, prefSetSearchHistoryShortcut,
  prefSetSelectNextItemShortcut,
  prefSetSelectPreviousItemShortcut, prefSetShowMoreActionsShortcut,
  prefSetTheme, prefSetTogglePreviewShortcut,
  prefSetWarnOnClearHistory, prefSetZoomUIInShortcut, prefSetZoomUIOutShortcut
} from "@/components/pref";

export default function Settings() {
  const [theme, setTheme] = useState(prefGetTheme());
  const [openAtLogin, setOpenAtLogin] = useState(prefGetOpenAtLogin());
  const [warnOnClearHistory, setWarnOnClearHistory] = useState(prefGetWarnOnClearHistory());
  const [ignoreTransientContent, setIgnoreTransientContent] = useState(prefGetIgnoreTransientContent());
  const [ignoreConfidentialContent, setIgnoreConfidentialContent] = useState(prefGetIgnoreConfidentialContent());
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

  function handleThemeChange(theme: string) {
    setTheme(theme)
    prefSetTheme(theme)
  }

  function handleOpenAtLoginChange(openAtLogin: boolean) {
    setOpenAtLogin(openAtLogin)
    prefSetOpenAtLogin(openAtLogin)
  }

  function handleWarnOnClearHistoryChange(warnOnClearHistory: boolean) {
    setWarnOnClearHistory(warnOnClearHistory)
    prefSetWarnOnClearHistory(warnOnClearHistory)
  }

  function handleIgnoreTransientContentChange(checked: boolean) {
    setIgnoreTransientContent(checked)
    prefSetIgnoreTransientContent(checked)
  }

  function handleIgnoreConfidentialContentChange(checked: boolean) {
    setIgnoreConfidentialContent(checked)
    prefSetIgnoreConfidentialContent(checked)
  }

  function handleOpenAppShortcutChange(shortcut: string) {
    setOpenAppShortcut(shortcut)
    prefSetOpenAppShortcut(shortcut)
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
        <div className="flex flex-col flex-grow">
          <div className="grid gap-6 p-16 pt-0">
            <div className="flex pt-12 draggable border-b border-b-border">
              <span className="text-2xl pb-3 font-semibold">General settings</span>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="openAtLogin" className="flex flex-col text-base">
                <span className="">Launch at login</span>
                <span className="text-neutral-500 font-normal text-sm">
Launch ClipBook automatically at&nbsp;login
            </span>
              </Label>
              <Switch id="openAtLogin" checked={openAtLogin}
                      onCheckedChange={handleOpenAtLoginChange}/>
            </div>

            <hr/>

            <div className="flex justify-between space-x-10">
              <Label className="flex flex-col text-base">
                <span className="">Appearance</span>
                <span className="text-neutral-500 font-normal text-sm">Change how ClipBook looks on your&nbsp;device</span>
              </Label>

              <RadioGroup value={theme} onValueChange={handleThemeChange}>
                <div className="flex flex-row gap-x-6">
                  <div className="">
                    <Label htmlFor="r1" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="light" id="r1" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-light.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Light</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r2" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="dark" id="r2" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-dark.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Dark</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r3" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="system" id="r3" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-system.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">System</span>
                      </div>
                    </Label>
                  </div>
                </div>
              </RadioGroup>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="warnOnClearAll" className="flex flex-col text-base">
                <span className="">Warn when clearing all history</span>
                <span className="text-neutral-500 font-normal text-sm">
Display a confirmation dialog when clearing all clipboard&nbsp;history
            </span>
              </Label>
              <Switch id="warnOnClearAll" checked={warnOnClearHistory}
                      onCheckedChange={handleWarnOnClearHistoryChange}/>
            </div>

            <div className="flex pt-10 border-b border-b-border">
              <span className="text-2xl pb-3 font-semibold">Privacy settings</span>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="ignoreConfidential" className="flex flex-col text-base">
                <span className="">Ignore confidential content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save passwords and other sensitive data copied to the&nbsp;clipboard
            </span>
              </Label>
              <Switch id="ignoreConfidential" checked={ignoreConfidentialContent}
                      onCheckedChange={handleIgnoreConfidentialContentChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="ignoreTransient" className="flex flex-col text-base">
                <span className="">Ignore transient content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save data temporarily placed to the&nbsp;clipboard
            </span>
              </Label>
              <Switch id="ignoreTransient" checked={ignoreTransientContent}
                      onCheckedChange={handleIgnoreTransientContentChange}/>
            </div>

            <div className="grid gap-4">
              <div className="flex pt-12 border-b border-b-border">
                <span className="text-2xl pb-3 font-semibold">Shortcuts</span>
              </div>

              <div className="flex items-center justify-between space-x-20 pt-6">
                <span className="">Open ClipBook</span>
                <ShortcutInput shortcut={openAppShortcut} onSave={handleOpenAppShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Close ClipBook</span>
                <ShortcutInput shortcut={closeAppShortcut} onSave={handleCloseAppShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Select next history item</span>
                <ShortcutInput shortcut={selectNextItemShortcut} onSave={handleSelectNextItemShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Select previous history item</span>
                <ShortcutInput shortcut={selectPreviousItemShortcut} onSave={handleSelectPreviousItemShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Paste selected item to active app</span>
                <ShortcutInput shortcut={pasteSelectedItemToActiveAppShortcut} onSave={handlePasteSelectedItemToActiveAppShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Edit history item</span>
                <ShortcutInput shortcut={editHistoryItemShortcut} onSave={handleEditHistoryItemShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Delete history item</span>
                <ShortcutInput shortcut={deleteHistoryItemShortcut} onSave={handleDeleteHistoryItemShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Delete all history item</span>
                <ShortcutInput shortcut={clearHistoryShortcut} onSave={handleClearHistoryShortcutChange}/>
              </div>

              <div className="flex items-center justify-between space-x-20">
                <span className="">Search</span>
                <ShortcutInput shortcut={searchHistoryShortcut} onSave={handleSearchHistoryShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Show/hide preview</span>
                <ShortcutInput shortcut={togglePreviewShortcut} onSave={handleTogglePreviewShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Show more actions</span>
                <ShortcutInput shortcut={showMoreActionsShortcut} onSave={handleShowMoreActionsShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Zoom app UI in</span>
                <ShortcutInput shortcut={zoomUIInShortcut} onSave={handleZoomUIInShortcutChange}/>
              </div>
              <div className="flex items-center justify-between space-x-20">
                <span className="">Zoom app UI out</span>
                <ShortcutInput shortcut={zoomUIOutShortcut} onSave={handleZoomUIOutShortcutChange}/>
              </div>
            </div>
          </div>
        </div>
      </div>
  )
}
