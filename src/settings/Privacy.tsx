import * as React from "react";
import {Switch} from "@/components/ui/switch";
import {Label} from "@/components/ui/label";
import {useEffect, useState} from "react";
import {
  prefGetAppsToIgnore,
  prefGetIgnoreConfidentialContent,
  prefGetIgnoreTransientContent,
  prefIsIgnoreConfidentialContentManaged,
  prefIsIgnoreTransientContentManaged,
  prefSetAppsToIgnore,
  prefSetIgnoreConfidentialContent,
  prefSetIgnoreTransientContent,
} from "@/pref";
import IgnoreAppsPane from "@/settings/IgnoreAppsPane";

declare const closeSettingsWindow: () => void;
declare const selectAppsToIgnore: () => string[];

export default function Privacy() {
  const [ignoreTransientContent, setIgnoreTransientContent] = useState(prefGetIgnoreTransientContent());
  const [ignoreConfidentialContent, setIgnoreConfidentialContent] = useState(prefGetIgnoreConfidentialContent());
  const [appsToIgnore, setAppsToIgnore] = useState(prefGetAppsToIgnore());

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

  function handleIgnoreTransientContentChange(checked: boolean) {
    setIgnoreTransientContent(checked)
    prefSetIgnoreTransientContent(checked)
  }

  function handleIgnoreConfidentialContentChange(checked: boolean) {
    setIgnoreConfidentialContent(checked)
    prefSetIgnoreConfidentialContent(checked)
  }

  function handleSelectApps() {
    selectAppsToIgnore()
  }

  function handleRemoveApps(apps: string[]) {
    let updatedApps = appsToIgnore.filter((app) => !apps.includes(app));
    setAppsToIgnore(updatedApps)
    prefSetAppsToIgnore(updatedApps)
  }

  function addAppToIgnore(app: string) {
    let apps = [...appsToIgnore, app];
    setAppsToIgnore(apps)
    prefSetAppsToIgnore(apps)
  }

  // Attach the function to the window object
  (window as any).addAppToIgnore = addAppToIgnore;

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">Privacy</span>
          </div>

          <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="ignoreConfidential" className="flex flex-col text-base">
                <span className="">Ignore confidential content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save passwords and other sensitive data copied to the&nbsp;clipboard.
            </span>
              </Label>
              <Switch id="ignoreConfidential" checked={ignoreConfidentialContent}
                      onCheckedChange={handleIgnoreConfidentialContentChange}
                      disabled={prefIsIgnoreConfidentialContentManaged()}/>
            </div>
            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="ignoreTransient" className="flex flex-col text-base">
                <span className="">Ignore transient content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save data temporarily placed to the&nbsp;clipboard.
            </span>
              </Label>
              <Switch id="ignoreTransient" checked={ignoreTransientContent}
                      onCheckedChange={handleIgnoreTransientContentChange}
                      disabled={prefIsIgnoreTransientContentManaged()}/>
            </div>

            <hr/>

            <div className="flex flex-col">
              <Label className="flex flex-col text-base">
                <span className="">Ignore applications</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Do not save content copied from the following&nbsp;applications.
                </span>
              </Label>
              <IgnoreAppsPane apps={appsToIgnore} onSelectApps={handleSelectApps} onRemoveApps={handleRemoveApps}/>
            </div>
          </div>
        </div>
      </div>
  )
}
