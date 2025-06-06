import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {useEffect, useState} from "react";
import {
  prefGetCloseAppShortcut,
  prefGetCloseAppShortcut2,
  prefGetCloseAppShortcut3, prefGetLanguage,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut, prefGetZoomUIResetShortcut
} from "@/pref";
import {isShortcutMatch} from "@/lib/shortcuts";
import {TooltipProvider} from "@/components/ui/tooltip";
import {emitter} from "@/actions";

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

  useEffect(() => {
    emitter.on("ZoomIn", handleZoomIn)
    emitter.on("ZoomOut", handleZoomOut)
    emitter.on("ResetZoom", handleResetZoom)
    return () => {
      emitter.off("ZoomIn", handleZoomIn)
      emitter.off("ZoomOut", handleZoomOut)
      emitter.off("ResetZoom", handleResetZoom)
    };
  }, []);

  function setActiveAppInfo(appName: string, appIcon: string): void {
    setAppName(appName)
    setAppIcon(appIcon)
  }

  function onDidAppWindowHide() {
    emitter.emit("NotifyAppWindowDidHide")
  }

  function handleZoomIn() {
    zoomIn()
    emitter.emit("FocusSearchInput")
  }

  function handleZoomOut() {
    zoomOut()
    emitter.emit("FocusSearchInput")
  }

  function handleResetZoom() {
    resetZoom()
    emitter.emit("FocusSearchInput")
  }

  // Attach the function to the window object
  (window as any).setActiveAppInfo = setActiveAppInfo;
  (window as any).onDidAppWindowHide = onDidAppWindowHide;

  return (
      <ThemeProvider defaultTheme="system">
        <TooltipProvider delayDuration={250}>
          <HistoryPane appName={appName} appIcon={appIcon}/>
        </TooltipProvider>
      </ThemeProvider>
  )
}
