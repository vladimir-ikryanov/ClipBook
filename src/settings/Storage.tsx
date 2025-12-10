import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {useEffect, useState} from "react";
import {
  prefGetClearHistoryOnMacReboot,
  prefGetClearHistoryOnQuit,
  prefIsClearHistoryOnMacRebootManaged, 
  prefIsClearHistoryOnQuitManaged,
  prefSetClearHistoryOnMacReboot,
  prefSetClearHistoryOnQuit,
  prefGetRetentionPeriodText,
  prefGetRetentionPeriodImage,
  prefGetRetentionPeriodFile,
  prefGetRetentionPeriodLink,
  prefGetRetentionPeriodEmail,
  prefGetRetentionPeriodColor,
  prefSetRetentionPeriodText,
  prefSetRetentionPeriodImage,
  prefSetRetentionPeriodFile,
  prefSetRetentionPeriodLink,
  prefSetRetentionPeriodEmail,
  prefSetRetentionPeriodColor,
} from "@/pref";
import { useTranslation } from 'react-i18next';
import { RetentionPeriodSlider } from "./RetentionPeriodSlider";
import { ClipType } from "@/db";

declare const closeSettingsWindow: () => void;

export default function Storage() {
  const { t } = useTranslation();

  const [clearHistoryOnQuit, setClearHistoryOnQuit] = useState(prefGetClearHistoryOnQuit())
  const [clearHistoryOnMacReboot, setClearHistoryOnMacReboot] = useState(prefGetClearHistoryOnMacReboot())
  const [retentionPeriodText, setRetentionPeriodText] = useState(prefGetRetentionPeriodText())
  const [retentionPeriodImage, setRetentionPeriodImage] = useState(prefGetRetentionPeriodImage())
  const [retentionPeriodFile, setRetentionPeriodFile] = useState(prefGetRetentionPeriodFile())
  const [retentionPeriodLink, setRetentionPeriodLink] = useState(prefGetRetentionPeriodLink())
  const [retentionPeriodEmail, setRetentionPeriodEmail] = useState(prefGetRetentionPeriodEmail())
  const [retentionPeriodColor, setRetentionPeriodColor] = useState(prefGetRetentionPeriodColor())

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

  function handleClearHistoryOnQuitChange(clearHistoryOnQuit: boolean) {
    setClearHistoryOnQuit(clearHistoryOnQuit)
    prefSetClearHistoryOnQuit(clearHistoryOnQuit)
  }

  function handleClearHistoryOnMacRebootChange(clearHistoryOnMacReboot: boolean) {
    setClearHistoryOnMacReboot(clearHistoryOnMacReboot)
    prefSetClearHistoryOnMacReboot(clearHistoryOnMacReboot)
  }

  function handleRetentionPeriodTextChange(retentionPeriodText: number) {
    setRetentionPeriodText(retentionPeriodText)
    prefSetRetentionPeriodText(retentionPeriodText)
  }

  function handleRetentionPeriodImageChange(retentionPeriodImage: number) {
    setRetentionPeriodImage(retentionPeriodImage)
    prefSetRetentionPeriodImage(retentionPeriodImage)
  }

  function handleRetentionPeriodFileChange(retentionPeriodFile: number) {
    setRetentionPeriodFile(retentionPeriodFile)
    prefSetRetentionPeriodFile(retentionPeriodFile)
  }

  function handleRetentionPeriodLinkChange(retentionPeriodLink: number) {
    setRetentionPeriodLink(retentionPeriodLink)
    prefSetRetentionPeriodLink(retentionPeriodLink)
  }

  function handleRetentionPeriodEmailChange(retentionPeriodEmail: number) {
    setRetentionPeriodEmail(retentionPeriodEmail)
    prefSetRetentionPeriodEmail(retentionPeriodEmail)
  }

  function handleRetentionPeriodColorChange(retentionPeriodColor: number) {
    setRetentionPeriodColor(retentionPeriodColor)
    prefSetRetentionPeriodColor(retentionPeriodColor)
  }
  
  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">{t('settings.storage.title')}</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex flex-col pt-6 pb-1">
              <Label className="flex flex-col text-base pr-20">
                <span className="">{t('settings.storage.retentionPeriod.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.storage.retentionPeriod.description')}
                </span>
              </Label>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.Text} value={retentionPeriodText} onValueChange={handleRetentionPeriodTextChange} /> 
              </div>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.Image} value={retentionPeriodImage} onValueChange={handleRetentionPeriodImageChange} /> 
              </div>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.File} value={retentionPeriodFile} onValueChange={handleRetentionPeriodFileChange} /> 
              </div>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.Link} value={retentionPeriodLink} onValueChange={handleRetentionPeriodLinkChange} /> 
              </div>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.Email} value={retentionPeriodEmail} onValueChange={handleRetentionPeriodEmailChange} /> 
              </div>
              <div className="bg-settings-tableRow rounded-lg p-4 mt-4">
                <RetentionPeriodSlider clipType={ClipType.Color} value={retentionPeriodColor} onValueChange={handleRetentionPeriodColorChange} /> 
              </div>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="clearHistoryOnQuit" className="flex flex-col text-base">
                <span className="">{t('settings.storage.clearHistoryOnQuit.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.storage.clearHistoryOnQuit.description')}
                </span>
              </Label>
              <Switch id="clearHistoryOnQuit" checked={clearHistoryOnQuit}
                      onCheckedChange={handleClearHistoryOnQuitChange}
                      disabled={prefIsClearHistoryOnQuitManaged()}/>
            </div>
            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="clearHistoryOnMacReboot" className="flex flex-col text-base">
                <span className="">{t('settings.storage.clearHistoryOnMacReboot.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.storage.clearHistoryOnMacReboot.description')}
                </span>
              </Label>
              <Switch id="clearHistoryOnMacReboot" checked={clearHistoryOnMacReboot}
                      onCheckedChange={handleClearHistoryOnMacRebootChange}
                      disabled={prefIsClearHistoryOnMacRebootManaged()}/>
            </div>
          </div>
        </div>
      </div>
  )
}
