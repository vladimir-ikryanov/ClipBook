import History from "@/components/History";
import {ThemeProvider} from "@/components/theme-provider"

import {addHistoryItem, clear, getHistoryItems, isHistoryEmpty, setFilterQuery} from "@/data"
import {useEffect, useState} from "react";
import * as React from "react";
import {Clipboard} from "lucide-react";

declare const hideAppWindow: () => void;

export default function App() {
  const [history, setHistory] = useState(getHistoryItems())
  const [appName, setAppName] = useState("")
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Prevent leaving the history items with the tab key.
      if (e.key === "Tab") {
        e.preventDefault()
      }
      if (e.key === "Escape") {
        e.preventDefault()
        hideAppWindow()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function addClipboardData(data: string): void {
    setHistory([...addHistoryItem(data)])
  }

  function handleUpdateHistory(): void {
    setHistory(getHistoryItems())
  }

  function handleFilterHistory(searchQuery: string): void {
    setFilterQuery(searchQuery)
    setHistory(getHistoryItems())
  }

  function setActiveAppName(appName: string): void {
    setAppName(appName)
  }

  function clearHistory(): void {
    setHistory(clear())
  }

  // Attach the function to the window object
  (window as any).addClipboardData = addClipboardData;
  (window as any).setActiveAppName = setActiveAppName;
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
  )}

  return (
    <ThemeProvider defaultTheme="system">
        <History items={history} appName={appName} onUpdateHistory={handleUpdateHistory}
                 onFilterHistory={handleFilterHistory}/>
      </ThemeProvider>
  )
}
