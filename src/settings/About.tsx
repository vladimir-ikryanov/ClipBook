import * as React from "react";
import {useEffect, useState} from "react";
import {RefreshCcwIcon} from "lucide-react";
import {Button} from "@/components/ui/button";
import {prefAllowCheckForUpdates} from "@/pref";
import CheckForUpdatesResult from "@/settings/CheckForUpdatesResult";
import { useTranslation } from 'react-i18next';

declare const closeSettingsWindow: () => void;
declare const checkForUpdates: () => void;
declare const openUrl: (url: string) => void;
declare const getArch: () => string;
declare const getVersion: () => string;
declare const isUpdateAvailable: () => boolean;
declare const restartApp: () => void;

export default function About() {
  const { t } = useTranslation()
  const [updateAvailable, setUpdateAvailable] = useState(isUpdateAvailable)
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

  function handleUpdateAvailable() {
    setUpdateAvailable(true)
  }

  // Attach the function to the window object
  (window as any).updateAvailable = handleUpdateAvailable;
  (window as any).setUpdateCheckInProgress = setUpdateCheckInProgress

  function renderActionButton() {
    if (updateAvailable) {
      return (
          <Button variant="secondary" size="sm" className="px-4 mt-4" onClick={() => {restartApp()}}>
            {t('statusBar.updateClipBook')}
          </Button>
      )
    }
    return (
        <Button variant="secondary" size="sm" className="px-4 mt-4"
                onClick={handleCheckForUpdates} disabled={checkingForUpdates || !prefAllowCheckForUpdates()}>
          {
            checkingForUpdates ? <RefreshCcwIcon className="animate-spin h-4 w-4 mr-2"/> : null
          }
          {
            checkingForUpdates ? t('settings.about.checkingForUpdates') : t('settings.about.checkForUpdates')
          }
        </Button>
    )
  }

  return (
      <div className="flex flex-col min-h-screen relative overflow-hidden">
        <div className="absolute top-20 left-10 w-72 h-72 bg-purple-700 rounded-full filter blur-xl opacity-10 animate-blob"></div>
        <div className="absolute top-96 left-96 w-52 h-52 bg-blue-700 rounded-full filter blur-xl opacity-5 animate-blob2"></div>
        <div className="flex draggable h-20"></div>
        <div className="flex flex-col relative flex-grow items-center justify-center">
          <img src="/assets/logo_256x256@2x.png" className="w-28 h-28"/>
          <h1 className="text-3xl font-semibold mb-3 mt-1">ClipBook</h1>
          <p className="text-secondary-foreground">{t('settings.about.version', { version: getVersion(), arch: getArch() })}</p>
          {renderActionButton()}
          <div className="justify-center text-center mt-4">
            <CheckForUpdatesResult/>
          </div>
        </div>
        <div className="flex flex-col items-center justify-center text-sm text-secondary-foreground p-6">
          <div className="flex">
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickWebsite}>{t('settings.about.links.website')}</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickSupport}>{t('settings.about.links.support')}</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickChangelog}>{t('settings.about.links.changelog')}</Button>
            <Button variant="link" size="sm" className="text-secondary-foreground" onClick={handleClickFeedback}>{t('settings.about.links.feedback')}</Button>
          </div>
          <span className="text-xs">{t('settings.about.copyright')}</span>
        </div>
      </div>
  )
}
