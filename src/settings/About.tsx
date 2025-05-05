import * as React from "react";
import {useEffect, useState} from "react";
import {RefreshCcwIcon} from "lucide-react";
import {Button} from "@/components/ui/button";

declare const closeSettingsWindow: () => void;
declare const checkForUpdates: () => void;
declare const openUrl: (url: string) => void;
declare const getArch: () => string;
declare const getVersion: () => string;

export default function About() {
  const [checkingForUpdates, setCheckingForUpdates] = useState(false)

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

  function handleCheckForUpdates() {
    checkForUpdates()
  }

  function setUpdateCheckInProgress(inProgress: boolean) {
    setCheckingForUpdates(inProgress)
  }

  function handleClickWebsite() {
    openUrl("https://clipbook.app?utm_source=app")
  }

  function handleClickSupport() {
    openUrl("https://clipbook.app/contacts/")
  }

  function handleClickChangelog() {
    openUrl("https://clipbook.app/changelog/")
  }

  function handleClickFeedback() {
    openUrl("https://feedback.clipbook.app/board/all")
  }

  (window as any).setUpdateCheckInProgress = setUpdateCheckInProgress

  return (
      <div className="flex flex-col relative min-h-screen">
        <div className="absolute top-20 left-10 w-72 h-72 bg-purple-700 rounded-full filter blur-2xl opacity-15 animate-blob"></div>
        <div className="absolute top-96 left-96 w-52 h-52 bg-blue-700 rounded-full filter blur-2xl opacity-15 animate-blob2"></div>
        <div className="flex draggable h-20"></div>
        <div className="flex flex-col relative flex-grow items-center justify-center">
          <img src="/assets/logo_256x256@2x.png" className="w-28 h-28"/>
          <h1 className="text-3xl font-semibold mb-3 mt-1">ClipBook</h1>
          <p className="text-secondary-foreground">Version {getVersion()} ({getArch()})</p>
          <Button variant="secondary" size="sm" className="px-4 mt-4"
                  onClick={handleCheckForUpdates} disabled={checkingForUpdates}>
            {
              checkingForUpdates ? <RefreshCcwIcon className="animate-spin h-4 w-4 mr-2"/> : null
            }
            {
              checkingForUpdates ? "Checking for updates..." : "Check for Updates..."
            }
          </Button>
        </div>
        <div className="flex flex-col items-center justify-center text-sm text-secondary-foreground p-6">
          <div className="flex">
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickWebsite}>Website</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickSupport}>Support</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickChangelog}>Changelog</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickFeedback}>Feedback</Button>
          </div>
          <span className="text-xs">© 2025 ClipBook. All rights reserved.</span>
        </div>
      </div>
  )
}
