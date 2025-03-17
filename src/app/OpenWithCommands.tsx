import '../app.css';

import * as React from "react"
import {useEffect, useState} from "react"
import {VisuallyHidden} from "@radix-ui/react-visually-hidden";

import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command"
import {
  AppInfo, getAllApps,
  getDefaultApp,
  getFirstSelectedHistoryItem, getRecommendedApps,
  toBase64Icon
} from "@/data";
import {DialogTitle} from "@/components/ui/dialog";
import {ClipType} from "@/db";

type OpenWithCommandsProps = {
  onOpenWithApp: (appPath: string) => void
}

export default function OpenWithCommands(props: OpenWithCommandsProps) {
  const [open, setOpen] = useState(false)
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

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === "openWith") {
        handleOpenChange(true)
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [])

  function handleOpenChange(open: boolean) {
    setDefaultApp(undefined)
    if (open) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File && !item.fileFolder) {
        let defaultAppInfo = getDefaultApp(item.filePath);
        let defaultAppPath = defaultAppInfo ? defaultAppInfo.path : "";
        setDefaultApp(defaultAppInfo)

        let recommendedAppInfoList = getRecommendedApps(item.filePath);
        // Remove default app from the recommended apps.
        recommendedAppInfoList = recommendedAppInfoList.filter(app => app.path !== defaultAppPath)

        let allAppInfoList = getAllApps();
        // Remove default app and recommended apps from the all apps.
        allAppInfoList = allAppInfoList.filter(app => app.path !== defaultAppPath)
        allAppInfoList = allAppInfoList.filter(app => !recommendedAppInfoList.find(recommendedApp => recommendedApp.path === app.path))

        setRecommendedApps(recommendedAppInfoList)
        setOtherApps(allAppInfoList)

      }
    }
    setOpen(open)
  }

  function handleOpenWithDefaultApp() {
    if (defaultApp) {
      props.onOpenWithApp(defaultApp.path)
    }
    handleOpenChange(false)
  }

  function handleOpenWithApp(appPath: string) {
    props.onOpenWithApp(appPath)
    handleOpenChange(false)
  }

  return (
      <div className="" onKeyDown={handleKeyDown}>
        <CommandDialog open={open} onOpenChange={handleOpenChange}>
          <VisuallyHidden>
            <DialogTitle></DialogTitle>
          </VisuallyHidden>
          <CommandInput placeholder="Search..." autoFocus={true}/>
          <div className="max-h-[70vh] overflow-y-auto mb-1.5">
            <CommandList>
              {
                  defaultApp &&
                  <CommandGroup heading="Default">
                    <CommandItem onSelect={handleOpenWithDefaultApp}>
                      <img src={toBase64Icon(defaultApp.icon)} className="mr-2 h-5 w-5"
                           alt="App icon"/>
                      <span>{defaultApp.name}</span>
                    </CommandItem>
                  </CommandGroup>
              }
              {
                  recommendedApps.length > 0 &&
                  <CommandGroup heading="Recommended">
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
                  <CommandGroup heading="Other">
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
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
          </div>
        </CommandDialog>
      </div>
  )
}
