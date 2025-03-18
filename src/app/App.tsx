import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {useEffect, useState} from "react";
import * as React from "react";
import {
  prefGetCloseAppShortcut,
  prefGetCloseAppShortcut2,
  prefGetCloseAppShortcut3,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut, prefGetZoomUIResetShortcut
} from "@/pref";
import {isShortcutMatch} from "@/lib/shortcuts";
import {TooltipProvider} from "@/components/ui/tooltip";

declare const hideAppWindow: () => void;
declare const zoomIn: () => void;
declare const zoomOut: () => void;
declare const resetZoom: () => void;

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
      if (isShortcutMatch(prefGetCloseAppShortcut(), e)
          || isShortcutMatch(prefGetCloseAppShortcut2(), e)
          || isShortcutMatch(prefGetCloseAppShortcut3(), e)) {
        hideAppWindow()
        e.preventDefault()
      }
      // Zoom in the UI with the zoom in shortcut.
      if (isShortcutMatch(prefGetZoomUIInShortcut(), e)) {
        handleZoomIn()
        e.preventDefault()
      }
      // Zoom out the UI with the zoom out shortcut.
      if (isShortcutMatch(prefGetZoomUIOutShortcut(), e)) {
        handleZoomOut()
        e.preventDefault()
      }
      // Reset zoom.
      if (isShortcutMatch(prefGetZoomUIResetShortcut(), e)) {
        handleResetZoom()
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

  function onDidAppWindowHide() {
    window.dispatchEvent(new CustomEvent("onDidAppWindowHide"));
  }

  function handleZoomIn() {
    zoomIn()
  }

  function handleZoomOut() {
    zoomOut()
  }

  function handleResetZoom() {
    resetZoom()
  }

  // Attach the function to the window object
  (window as any).setActiveAppInfo = setActiveAppInfo;
  (window as any).onDidAppWindowHide = onDidAppWindowHide;

  return (
      <ThemeProvider defaultTheme="system">
        <TooltipProvider delayDuration={250}>
          <HistoryPane appName={appName}
                       appIcon={appIcon}
                       onZoomIn={handleZoomIn}
                       onZoomOut={handleZoomOut}
                       onResetZoom={handleResetZoom}/>
        </TooltipProvider>
      </ThemeProvider>
  )
}
