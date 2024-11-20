import * as React from "react";
import {Switch} from "@/components/ui/switch";
import {Label} from "@/components/ui/label";
import {KeyboardIcon, KeyRoundIcon, ListIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {useEffect, useState} from "react";
import {
  prefGetAppsToIgnore,
  prefGetIgnoreConfidentialContent,
  prefGetIgnoreTransientContent, prefSetAppsToIgnore,
  prefSetIgnoreConfidentialContent,
  prefSetIgnoreTransientContent,
} from "@/pref";
import IgnoreAppsPane from "@/settings/IgnoreAppsPane";
import {isLicenseActivated} from "@/licensing";

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

  function renderLicenseItem() {
    return (
        <div
            className="flex flex-row p-0 m-4 hover:bg-background hover:rounded-sm hover:shadow">
          <a href="/settings/license" className="flex flex-row py-2 px-2 gap-x-2 w-full">
            {
              isLicenseActivated() ? <KeyRoundIcon
                      className="h-5 w-5 mt-0.5 text-settings-titleLicenseActivatedLabel"/> :
                  <KeyRoundIcon className="h-5 w-5 mt-0.5"/>
            }
            <div className="">License</div>
            <div className="grow"></div>
            {
                !isLicenseActivated() &&
                <div className="rounded bg-settings-sidebarLabel text-xs px-1.5 py-1">Trial</div>
            }
          </a>
        </div>
    )
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div
                className="flex flex-row gap-x-2 p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings" className="flex flex-row py-2 px-2 gap-x-2 w-full cursor-default">
                <SettingsIcon className="h-5 w-5 mt-0.5"/>
                <span className="">General</span>
              </a>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/history" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <ListIcon className="h-5 w-5 mt-0.5"/>
                <span className="">History</span>
              </a>
            </div>
            <div
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/shortcuts" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <KeyboardIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Shortcuts</span>
              </a>
            </div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-settings-sidebarSelection rounded-sm shadow">
              <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
              <span className="">Privacy</span>
            </div>
            <div className="flex flex-grow"></div>
            {renderLicenseItem()}
          </div>
        </div>

        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">Privacy</span>
          </div>

          <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="ignoreConfidential" className="flex flex-col text-base">
                <span className="">Ignore confidential content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save passwords and other sensitive data copied to the&nbsp;clipboard.
            </span>
              </Label>
              <Switch id="ignoreConfidential" checked={ignoreConfidentialContent}
                      onCheckedChange={handleIgnoreConfidentialContentChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="ignoreTransient" className="flex flex-col text-base">
                <span className="">Ignore transient content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save data temporarily placed to the&nbsp;clipboard.
            </span>
              </Label>
              <Switch id="ignoreTransient" checked={ignoreTransientContent}
                      onCheckedChange={handleIgnoreTransientContentChange}/>
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
