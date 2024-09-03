import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {addHistoryItem, clear, getHistoryItems, isHistoryEmpty, setFilterQuery} from "@/data"
import {useEffect, useState} from "react";
import * as React from "react";
import {Clipboard} from "lucide-react";
import {
  prefGetCloseAppShortcut,
  prefGetOpenSettingsShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut
} from "@/pref";
import {isShortcutMatch} from "@/lib/shortcuts";
import {Clip} from "@/db";

declare const hideAppWindow: () => void;
declare const openSettingsWindow: () => void;
declare const zoomIn: () => void;
declare const zoomOut: () => void;

export default function App() {
  const [history, setHistory] = useState(getHistoryItems())
  const [appName, setAppName] = useState("")
  const [appIcon, setAppIcon] = useState("")
  const [searchQuery, setSearchQuery] = useState("")

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Prevent leaving the history items with the tab key.
      if (e.key === "Tab") {
        e.preventDefault()
      }
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetCloseAppShortcut(), e)) {
        hideAppWindow()
        e.preventDefault()
      }
      // Zoom in the UI with the zoom in shortcut.
      if (isShortcutMatch(prefGetZoomUIInShortcut(), e)) {
        zoomIn()
        e.preventDefault()
      }
      // Zoom out the UI with the zoom out shortcut.
      if (isShortcutMatch(prefGetZoomUIOutShortcut(), e)) {
        zoomOut()
        e.preventDefault()
      }
      // Open the settings window with the settings shortcut.
      if (isShortcutMatch(prefGetOpenSettingsShortcut(), e)) {
        openSettingsWindow()
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  async function addClipboardData(content: string, sourceAppPath: string) {
    let clips = await addHistoryItem(content, sourceAppPath)
    setHistory([...clips])
  }

  function handleUpdateHistory(): void {
    setHistory(getHistoryItems())
  }

  function handleSearchQueryChange(searchQuery: string): void {
    setSearchQuery(searchQuery)
    setFilterQuery(searchQuery)
    setHistory(getHistoryItems())
  }

  function setActiveAppInfo(appName: string, appIcon: string): void {
    setAppName(appName)
    setAppIcon(appIcon)
  }

  async function clearHistory() {
    setHistory(await clear())
  }

  // Attach the function to the window object
  (window as any).addClipboardData = addClipboardData;
  (window as any).setActiveAppInfo = setActiveAppInfo;
  (window as any).clearHistory = clearHistory;

  if (isHistoryEmpty()) {
    return (
        <ThemeProvider defaultTheme="system">
          <div className="flex h-screen draggable">
            <div className="flex flex-col text-center m-auto">
              <Clipboard className="h-24 w-24 m-auto text-secondary-foreground"/>
              <p className="text-center pt-8 text-2xl font-semibold text-foreground">
                Your clipboard is empty
              </p>
              <p className="text-center pt-2">
                Start copying text or links to build your history.
              </p>
            </div>
          </div>
        </ThemeProvider>
    )
  }

  return (
      <ThemeProvider defaultTheme="system">
        <HistoryPane history={history}
                     appName={appName}
                     appIcon={appIcon}
                     searchQuery={searchQuery}
                     onUpdateHistory={handleUpdateHistory}
                     onSearchQueryChange={handleSearchQueryChange}/>
      </ThemeProvider>
  )
}
