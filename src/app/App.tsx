import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {useEffect, useState} from "react";
import * as React from "react";
import {
  prefGetCloseAppShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut
} from "@/pref";
import {isShortcutMatch} from "@/lib/shortcuts";

declare const hideAppWindow: () => void;
declare const zoomIn: () => void;
declare const zoomOut: () => void;

export default function App() {
  const [appName, setAppName] = useState("")
  const [appIcon, setAppIcon] = useState("")

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Prevent leaving the history items with the tab key.
      if (e.code === "Tab") {
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

  return (
      <ThemeProvider defaultTheme="system">
        <HistoryPane appName={appName} appIcon={appIcon}/>
      </ThemeProvider>
  )
}
