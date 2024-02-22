import History from "@/components/History";
import {ThemeProvider} from "@/components/theme-provider"

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";
import * as React from "react";

declare const hideAppWindow: () => void;

export default function App() {
  const [history, setHistory] = useState(getHistoryItems())
  const [appName, setAppName] = useState("")

  React.useEffect(() => {
    const down = (e: KeyboardEvent) => {
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

  function setActiveAppName(appName: string): void {
    setAppName(appName)
  }

  // Attach the function to the window object
  (window as any).addClipboardData = addClipboardData;
  (window as any).setActiveAppName = setActiveAppName;

  return (
      <ThemeProvider defaultTheme="system">
        <div className="flex h-screen">
          <History items={history} appName={appName} onUpdateHistory={handleUpdateHistory}/>
        </div>
      </ThemeProvider>
  )
}
