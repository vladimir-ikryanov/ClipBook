import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {useEffect, useState} from "react";
import {
  CopyAndMergeSeparator, prefGetClearHistoryOnQuit,
  prefGetCopyAndMergeEnabled,
  prefGetCopyAndMergeSeparator,
  prefGetCopyToClipboardAfterMerge,
  prefGetKeepFavoritesOnClearHistory,
  prefGetWarnOnClearHistory, prefSetClearHistoryOnQuit,
  prefSetCopyAndMergeEnabled,
  prefSetCopyAndMergeSeparator,
  prefSetCopyToClipboardAfterMerge, prefSetKeepFavoritesOnClearHistory,
  prefSetWarnOnClearHistory,
} from "@/pref";
import {KeyboardIcon, ListIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

declare const closeSettingsWindow: () => void;

export default function History() {
  const [warnOnClearHistory, setWarnOnClearHistory] = useState(prefGetWarnOnClearHistory());
  const [keepFavoritesOnClearHistory, setKeepFavoritesOnClearHistory] = useState(prefGetKeepFavoritesOnClearHistory());
  const [copyAndMergeEnabled, setCopyAndMergeEnabled] = useState(prefGetCopyAndMergeEnabled());
  const [copyToClipboardAfterMerge, setCopyToClipboardAfterMerge] = useState(prefGetCopyToClipboardAfterMerge());
  const [copyAndMergeSeparator, setCopyAndMergeSeparator] = useState(prefGetCopyAndMergeSeparator());
  const [clearHistoryOnQuit, setClearHistoryOnQuit] = useState(prefGetClearHistoryOnQuit());

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

  function handleWarnOnClearHistoryChange(warnOnClearHistory: boolean) {
    setWarnOnClearHistory(warnOnClearHistory)
    prefSetWarnOnClearHistory(warnOnClearHistory)
  }

  function handleKeepFavoritesOnClearHistoryChange(keepFavoritesOnClearHistory: boolean) {
    setKeepFavoritesOnClearHistory(keepFavoritesOnClearHistory)
    prefSetKeepFavoritesOnClearHistory(keepFavoritesOnClearHistory)
  }

  function handleCopyAndMergeChange(copyAndMerge: boolean) {
    setCopyAndMergeEnabled(copyAndMerge)
    prefSetCopyAndMergeEnabled(copyAndMerge)
  }

  function handleCopyToClipboardAfterMergeChange(copyToClipboardAfterMerge: boolean) {
    setCopyToClipboardAfterMerge(copyToClipboardAfterMerge)
    prefSetCopyToClipboardAfterMerge(copyToClipboardAfterMerge)
  }

  function handleCopyAndMergeSeparatorChange(separator: CopyAndMergeSeparator) {
    setCopyAndMergeSeparator(separator)
    prefSetCopyAndMergeSeparator(separator)
  }

  function handleClearHistoryOnQuitChange(clearHistoryOnQuit: boolean) {
    setClearHistoryOnQuit(clearHistoryOnQuit)
    prefSetClearHistoryOnQuit(clearHistoryOnQuit)
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div
                className="flex flex-row gap-x-2 p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings" className="flex flex-row py-2 px-2 gap-x-2 w-full cursor-default">
                <SettingsIcon className="h-5 w-5 mt-0.5"/>
                <span className="">General</span>
              </a>
            </div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-settings-sidebarSelection rounded-sm shadow">
              <ListIcon className="h-5 w-5 mt-0.5"/>
              <span className="">History</span>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/shortcuts" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <KeyboardIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Shortcuts</span>
              </a>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/privacy" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
          </div>
        </div>

        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">History</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="copyAndMerge" className="flex flex-col text-base">
                <span className="">Copy and merge</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
Press <kbd>⌘</kbd><kbd>C</kbd><kbd>C</kbd> to append the currently selected text to the previously copied text in the clipboard&nbsp;history.
            </span>
              </Label>
              <Switch id="copyAndMerge" checked={copyAndMergeEnabled}
                      onCheckedChange={handleCopyAndMergeChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label className="flex flex-col text-base">
                <span className="">Copy and merge separator</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Select how the appended text should be separated from the previously copied&nbsp;text.
                </span>
              </Label>
              <Select defaultValue={copyAndMergeSeparator}
                      onValueChange={handleCopyAndMergeSeparatorChange}
                      disabled={!copyAndMergeEnabled}>
                <SelectTrigger className="w-[120px]">
                  <SelectValue/>
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={CopyAndMergeSeparator.LINE}>New line</SelectItem>
                  <SelectItem value={CopyAndMergeSeparator.SPACE}>Space</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="copyToClipboardAfterMerge" className="flex flex-col text-base">
                <span className="">Paste back to system clipboard</span>
                <span className="text-neutral-500 font-normal text-sm">
Automatically copy the merged text to the system clipboard after&nbsp;merging.
                </span>
              </Label>
              <Switch id="copyToClipboardAfterMerge"
                      checked={copyToClipboardAfterMerge}
                      onCheckedChange={handleCopyToClipboardAfterMergeChange}
                      disabled={!copyAndMergeEnabled}/>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="warnOnClearAll" className="flex flex-col text-base">
                <span className="">Warn when clearing entire history</span>
                <span className="text-neutral-500 font-normal text-sm">
Display a confirmation dialog when clearing entire clipboard&nbsp;history.
            </span>
              </Label>
              <Switch id="warnOnClearAll" checked={warnOnClearHistory}
                      onCheckedChange={handleWarnOnClearHistoryChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="keepFavoritesOnClearAll" className="flex flex-col text-base">
                <span className="">Keep favorites when clearing entire history</span>
                <span className="text-neutral-500 font-normal text-sm">
Do not remove items market as favorite when clearing entire clipboard&nbsp;history.
            </span>
              </Label>
              <Switch id="keepFavoritesOnClearAll" checked={keepFavoritesOnClearHistory}
                      onCheckedChange={handleKeepFavoritesOnClearHistoryChange}/>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="clearHistoryOnQuit" className="flex flex-col text-base">
                <span className="">Clear entire history on quit</span>
                <span className="text-neutral-500 font-normal text-sm">
Clear the entire clipboard history when ClipBook is&nbsp;terminated.
            </span>
              </Label>
              <Switch id="clearHistoryOnQuit" checked={clearHistoryOnQuit}
                      onCheckedChange={handleClearHistoryOnQuitChange}/>
            </div>
          </div>
        </div>
      </div>
  )
}
