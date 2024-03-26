import History from "@/components/History";
import {ThemeProvider} from "@/components/theme-provider"

import {addHistoryItem, clear, getHistoryItems, setFilterQuery} from "@/data"
import {useEffect, useState} from "react";
import * as React from "react";

declare const hideAppWindow: () => void;

export default function App() {
  const [history, setHistory] = useState(getHistoryItems())
  const [appName, setAppName] = useState("")
  const [isVisible, setIsVisible] = useState(false);

  const forceRerender = () => {
    // Toggle the state to trigger re-render
    setIsVisible(prev => !prev);
  };

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
  (window as any).forceRerender = forceRerender;
  (window as any).addClipboardData = addClipboardData;
  (window as any).setActiveAppName = setActiveAppName;
  (window as any).clearHistory = clearHistory;

  return (
      <ThemeProvider defaultTheme="system">
        <History items={history} appName={appName} onUpdateHistory={handleUpdateHistory}
                 onFilterHistory={handleFilterHistory}/>
      </ThemeProvider>
  )
}
