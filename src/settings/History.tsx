import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {useEffect, useState} from "react";
import {
  CopyAndMergeSeparator,
  prefGetClearHistoryOnMacReboot,
  prefGetClearHistoryOnQuit,
  prefGetCopyAndMergeEnabled,
  prefGetCopyAndMergeSeparator,
  prefGetCopyToClipboardAfterMerge,
  prefGetKeepFavoritesOnClearHistory,
  prefGetWarnOnClearHistory,
  prefSetClearHistoryOnMacReboot,
  prefSetClearHistoryOnQuit,
  prefSetCopyAndMergeEnabled,
  prefSetCopyAndMergeSeparator,
  prefSetCopyToClipboardAfterMerge,
  prefSetKeepFavoritesOnClearHistory, prefSetPasteOnClick,
  prefSetShowPreviewForLinks,
  prefSetTreatDigitNumbersAsColor, prefSetUpdateHistoryAfterAction,
  prefSetWarnOnClearHistory, prefShouldPasteOnClick,
  prefShouldShowPreviewForLinks,
  prefShouldTreatDigitNumbersAsColor,
  prefShouldUpdateHistoryAfterAction,
} from "@/pref";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

declare const closeSettingsWindow: () => void;

export default function History() {
  const [warnOnClearHistory, setWarnOnClearHistory] = useState(prefGetWarnOnClearHistory())
  const [keepFavoritesOnClearHistory, setKeepFavoritesOnClearHistory] = useState(prefGetKeepFavoritesOnClearHistory())
  const [copyAndMergeEnabled, setCopyAndMergeEnabled] = useState(prefGetCopyAndMergeEnabled())
  const [copyToClipboardAfterMerge, setCopyToClipboardAfterMerge] = useState(prefGetCopyToClipboardAfterMerge())
  const [copyAndMergeSeparator, setCopyAndMergeSeparator] = useState(prefGetCopyAndMergeSeparator())
  const [clearHistoryOnQuit, setClearHistoryOnQuit] = useState(prefGetClearHistoryOnQuit())
  const [clearHistoryOnMacReboot, setClearHistoryOnMacReboot] = useState(prefGetClearHistoryOnMacReboot())
  const [treatDigitNumbersAsColor, setTreatDigitNumbersAsColor] = useState(prefShouldTreatDigitNumbersAsColor())
  const [showPreviewForLinks, setShowPreviewForLinks] = useState(prefShouldShowPreviewForLinks())
  const [updateHistoryAfterAction, setUpdateHistoryAfterAction] = useState(prefShouldUpdateHistoryAfterAction())
  const [pasteOnClick, setPasteOnClick] = useState(prefShouldPasteOnClick())

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

  function handleClearHistoryOnMacRebootChange(clearHistoryOnMacReboot: boolean) {
    setClearHistoryOnMacReboot(clearHistoryOnMacReboot)
    prefSetClearHistoryOnMacReboot(clearHistoryOnMacReboot)
  }

  function handleTreatDigitNumbersAsColorChange(treatDigitNumbersAsColor: boolean) {
    setTreatDigitNumbersAsColor(treatDigitNumbersAsColor)
    prefSetTreatDigitNumbersAsColor(treatDigitNumbersAsColor)
  }

  function handleShowPreviewForLinksChange(showPreviewForLinks: boolean) {
    setShowPreviewForLinks(showPreviewForLinks)
    prefSetShowPreviewForLinks(showPreviewForLinks)
  }

  function handleUpdateHistoryAfterActionChange(updateHistoryAfterAction: boolean) {
    setUpdateHistoryAfterAction(updateHistoryAfterAction)
    prefSetUpdateHistoryAfterAction(updateHistoryAfterAction)
  }

  function handlePasteOnClickChange(pasteOnClick: boolean) {
    setPasteOnClick(pasteOnClick)
    prefSetPasteOnClick(pasteOnClick)
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">History</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="updateHistoryAfterAction" className="flex flex-col text-base">
                <span className="">Update history after paste or copy</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  Move the item to the top of the history list after paste or copy&nbsp;action.
                </span>
              </Label>
              <Switch id="updateHistoryAfterAction" checked={updateHistoryAfterAction}
                      onCheckedChange={handleUpdateHistoryAfterActionChange}/>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20 pb-1">
              <Label htmlFor="pasteOnClick" className="flex flex-col text-base">
                <span className="">Paste on click</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  Select history item on mouse over and paste on&nbsp;click.
                </span>
              </Label>
              <Switch id="pasteOnClick" checked={pasteOnClick}
                      onCheckedChange={handlePasteOnClickChange}/>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20 pb-1">
              <Label htmlFor="copyAndMerge" className="flex flex-col text-base">
                <span className="">Copy and merge</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
Press <kbd>⌘</kbd><kbd>C</kbd><kbd>C</kbd> to append the currently selected text to the previously copied text in the clipboard&nbsp;history.
            </span>
              </Label>
              <Switch id="copyAndMerge" checked={copyAndMergeEnabled}
                      onCheckedChange={handleCopyAndMergeChange}/>
            </div>

            <div className="flex items-center justify-between space-x-10 py-1">
              <Label className="flex flex-col text-base">
                <span className="">Copy and merge separator</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Select how the appended text should be separated from the previously copied&nbsp;text.
                </span>
              </Label>
              <Select defaultValue={copyAndMergeSeparator}
                      onValueChange={handleCopyAndMergeSeparatorChange}
                      disabled={!copyAndMergeEnabled}>
                <SelectTrigger className="w-[150px]">
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

            <div className="flex items-center justify-between space-x-12 pb-1">
              <Label htmlFor="digitToColor" className="flex flex-col text-base">
                <span className="">
                  Recognize 8-digit number as a color
                </span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  Treat 8-digit, 6-digit, 4-digit, and 3-digit numbers as a hex color&nbsp;code.
                </span>
              </Label>
              <Switch id="digitToColor" checked={treatDigitNumbersAsColor}
                      onCheckedChange={handleTreatDigitNumbersAsColorChange}/>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-12 pb-1">
              <Label htmlFor="showPreviewForLinks" className="flex flex-col text-base">
                <span className="">
                  Show preview for links
                </span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  Fetch and display a favicon, title, description, and social card image for&nbsp;links.
                </span>
              </Label>
              <Switch id="showPreviewForLinks" checked={showPreviewForLinks}
                      onCheckedChange={handleShowPreviewForLinksChange}/>
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
            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="clearHistoryOnMacReboot" className="flex flex-col text-base">
                <span className="">Clear entire history on Mac restart</span>
                <span className="text-neutral-500 font-normal text-sm">
Clear the entire clipboard history on Mac&nbsp;shutdown/restart.
            </span>
              </Label>
              <Switch id="clearHistoryOnMacReboot" checked={clearHistoryOnMacReboot}
                      onCheckedChange={handleClearHistoryOnMacRebootChange}/>
            </div>
          </div>
        </div>
      </div>
  )
}
