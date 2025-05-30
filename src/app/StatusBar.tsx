import '../app.css';
import {Button} from "@/components/ui/button";
import React, {useState} from "react";
import {
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {XIcon} from "lucide-react";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

declare const restartApp: () => void;
declare const isUpdateAvailable: () => boolean;

type StatusBarProps = {
  appName: string
}

export default function StatusBar(props: StatusBarProps) {
  const {t} = useTranslation()
  
  const [updateAvailable, setUpdateAvailable] = useState(isUpdateAvailable)

  function handleUpdateAvailable() {
    setUpdateAvailable(true)
  }

  function handlePaste() {
    emitter.emit("Paste")
  }

  // Attach the function to the window object
  (window as any).updateAvailable = handleUpdateAvailable;

  return (
      <div
          className={`flex items-center justify-between px-1.5 pb-2 pt-1.5 border-t-solid border-t-border border-t ${updateAvailable ? "bg-gradient-to-r from-status-bar-highlight-green-start from-[0%] via-20% via-status-bar-highlight-green-middle to-transparent to-80%" : ""}`}>
        {
          updateAvailable ? (
              <div className="group flex text-sm items-center h-8">
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="ghost"
                            className="p-0 ml-1 h-6 w-6 rounded-sm outline-none bg-transparent hover:bg-green-700/10"
                            onClick={() => setUpdateAvailable(false)}>
                      <div className="rounded-full bg-status-bar-green w-2 h-2 group-hover:hidden"></div>
                      <div className="hidden group-hover:flex">
                        <XIcon className="x-4 h-4"/>
                      </div>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">{t('statusBar.hideNotification')}</div>
                  </TooltipContent>
                </Tooltip>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="ghost"
                            className="px-2 h-8 rounded-sm outline-none hover:bg-status-bar-green-button"
                            onClick={() => restartApp()}>
                      {t('statusBar.updateClipBook')}
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">
                      <strong>{t('statusBar.newVersionAvailable')}</strong><br/>{t('statusBar.clickToInstallUpdate')}
                    </div>
                  </TooltipContent>
                </Tooltip>
              </div>
          ) : (
              <div className="flex text-sm text-primary-foreground">
                <Button variant="info" className="p-1 h-8 rounded-sm outline-none">
                  <ShortcutLabel
                      shortcut={prefGetSelectNextItemShortcut() + " + " + prefGetSelectPreviousItemShortcut()}/>
                  <p className="pl-2">{t('statusBar.navigate')}</p>
                </Button>
              </div>
          )
        }

        <div className="flex">
          <Button variant="ghost" className="p-1 h-8 rounded-sm outline-none group" onClick={handlePaste}>
            <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            <p className="pl-2 pr-1 text-">{t('statusBar.pasteTo', {appName: props.appName})}</p>
          </Button>
        </div>
      </div>
  )
}
