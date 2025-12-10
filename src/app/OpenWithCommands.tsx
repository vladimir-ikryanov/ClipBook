import '../app.css';

import * as React from "react"
import {useEffect, useState} from "react"
import {VisuallyHidden} from "@radix-ui/react-visually-hidden";

import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command"
import {
  AppInfo,
  getAllApps,
  getDefaultApp, 
  getFileOrImagePath,
  getActiveHistoryItemIndex, 
  getHistoryItem,
  getRecommendedApps,
  toBase64Icon
} from "@/data";
import {DialogTitle} from "@/components/ui/dialog";
import {Clip, ClipType} from "@/db";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

export default function OpenWithCommands() {
  const {t} = useTranslation()
  
  const [open, setOpen] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const [defaultApp, setDefaultApp] = useState<AppInfo | undefined>(undefined)
  const [recommendedApps, setRecommendedApps] = useState<AppInfo[]>([])
  const [otherApps, setOtherApps] = useState<AppInfo[]>([])

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      handleOpenChange(false)
      e.preventDefault()
    }
    e.stopPropagation()
  }

  function handleShowOpenWithCommands() {
    setTimeout(() => {
      handleOpenChange(true)
    }, 200);
  }

  function handleShowOpenWithCommandsByIndex(index: number) {
    setTimeout(() => {
      handleOpenChange(true, index)
    }, 200);
  }

  function handleAppWindowDidHide() {
    handleOpenChange(false)
  }

  useEffect(() => {
    emitter.on("ShowOpenWithCommands", handleShowOpenWithCommands)
    emitter.on("ShowOpenWithCommandsByIndex", handleShowOpenWithCommandsByIndex)
    emitter.on("NotifyAppWindowDidHide", handleAppWindowDidHide)
    return () => {
      emitter.off("ShowOpenWithCommands", handleShowOpenWithCommands)
      emitter.off("ShowOpenWithCommandsByIndex", handleShowOpenWithCommandsByIndex)
      emitter.off("NotifyAppWindowDidHide", handleAppWindowDidHide)
    };
  }, [])

  function handleOpenChange(open: boolean, index: number = -1) {
    setDefaultApp(undefined)
    if (open) {
      let item: Clip;
      setSelectedIndex(index)
      if (index >= 0) {
        item = getHistoryItem(index)
      } else {
        let index = getActiveHistoryItemIndex()
        item = getHistoryItem(index)
      }
      if ((item.type === ClipType.File || item.type === ClipType.Image) && !item.fileFolder) {
        let filePath = getFileOrImagePath(item)
        if (filePath) {
          let defaultAppInfo = getDefaultApp(filePath);
          let defaultAppPath = defaultAppInfo ? defaultAppInfo.path : "";
          setDefaultApp(defaultAppInfo)

          let recommendedAppInfoList = getRecommendedApps(filePath);
          // Remove default app from the recommended apps.
          recommendedAppInfoList = recommendedAppInfoList.filter(app => app.path !== defaultAppPath)

          // Remember current time.
          let allAppInfoList = getAllApps()
          // Remove default app and recommended apps from the all apps.
          allAppInfoList = allAppInfoList.filter(app => app.path !== defaultAppPath)
          allAppInfoList = allAppInfoList.filter(app => !recommendedAppInfoList.find(recommendedApp => recommendedApp.path === app.path))

          setRecommendedApps(recommendedAppInfoList)
          setOtherApps(allAppInfoList)
        }
      }
    } else {
      emitter.emit("FocusSearchInput")
    }
    setOpen(open)
  }

  function handleOpenWithDefaultApp() {
    if (defaultApp) {
      if (selectedIndex >= 0) {
        emitter.emit("OpenFileItemWithAppByIndex", {
          appPath: defaultApp.path,
          index: selectedIndex
        })
      } else {
        emitter.emit("OpenFileItemWithApp", defaultApp.path)
      }
    }
    handleOpenChange(false)
  }

  function handleOpenWithApp(appPath: string) {
    if (selectedIndex >= 0) {
      emitter.emit("OpenFileItemWithAppByIndex", {
        appPath: appPath,
        index: selectedIndex
      })
    } else {
      emitter.emit("OpenFileItemWithApp", appPath)
    }
    handleOpenChange(false)
  }

  return (
      <div className="" onKeyDown={handleKeyDown}>
        <CommandDialog open={open} onOpenChange={handleOpenChange}>
          <VisuallyHidden>
            <DialogTitle></DialogTitle>
          </VisuallyHidden>
          <CommandInput placeholder={t("app.openWithCommands.searchPlaceholder")} autoFocus={true}/>
          <div className="max-h-[70vh] overflow-y-auto mb-1.5">
            <CommandList>
              {
                  defaultApp &&
                  <CommandGroup heading={t("app.openWithCommands.default")}>
                    <CommandItem onSelect={handleOpenWithDefaultApp}>
                      <img src={toBase64Icon(defaultApp.icon)} className="mr-2 h-5 w-5"
                           alt="App icon"/>
                      <span>{defaultApp.name}</span>
                    </CommandItem>
                  </CommandGroup>
              }
              {
                  recommendedApps.length > 0 &&
                  <CommandGroup heading={t("app.openWithCommands.recommended")}>
                    {
                      recommendedApps.map(app => (
                          <CommandItem key={app.path} onSelect={() => handleOpenWithApp(app.path)}>
                            <img src={toBase64Icon(app.icon)} className="mr-2 h-5 w-5"
                                 alt="App icon"/>
                            <span>{app.name}<span className="hidden">{app.path}</span></span>
                          </CommandItem>
                      ))
                    }
                  </CommandGroup>
              }
              {
                  otherApps.length > 0 &&
                  <CommandGroup heading={t("app.openWithCommands.other")}>
                    {
                      otherApps.map(app => (
                          <CommandItem key={app.path} onSelect={() => handleOpenWithApp(app.path)}>
                            <img src={toBase64Icon(app.icon)} className="mr-2 h-5 w-5"
                                 alt="App icon"/>
                            <span>{app.name}<span className="hidden">{app.path}</span></span>
                          </CommandItem>
                      ))
                    }
                  </CommandGroup>
              }
              <CommandEmpty>{t("app.openWithCommands.noResults")}</CommandEmpty>
            </CommandList>
          </div>
        </CommandDialog>
      </div>
  )
}
