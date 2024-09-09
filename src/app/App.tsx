import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {isHistoryEmpty} from "@/data"
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

declare const hideAppWindow: () => void;
declare const openSettingsWindow: () => void;
declare const zoomIn: () => void;
declare const zoomOut: () => void;

export default function App() {
  const [appName, setAppName] = useState("")
  const [appIcon, setAppIcon] = useState("")

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

  function setActiveAppInfo(appName: string, appIcon: string): void {
    setAppName(appName)
    setAppIcon(appIcon)
  }

  // Attach the function to the window object
  (window as any).setActiveAppInfo = setActiveAppInfo;

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
        <HistoryPane appName={appName} appIcon={appIcon}/>
      </ThemeProvider>
  )
}
