import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";
import {useState} from "react";
import {
  prefGetOpenAtLogin,
  prefGetTheme,
  prefGetWarnOnClearHistory,
  prefSetOpenAtLogin,
  prefSetTheme,
  prefSetWarnOnClearHistory,
} from "@/pref";
import {KeyboardIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";

export default function Settings() {
  const [theme, setTheme] = useState(prefGetTheme());
  const [openAtLogin, setOpenAtLogin] = useState(prefGetOpenAtLogin());
  const [warnOnClearHistory, setWarnOnClearHistory] = useState(prefGetWarnOnClearHistory());

  function handleThemeChange(theme: string) {
    setTheme(theme)
    prefSetTheme(theme)
  }

  function handleOpenAtLoginChange(openAtLogin: boolean) {
    setOpenAtLogin(openAtLogin)
    prefSetOpenAtLogin(openAtLogin)
  }

  function handleWarnOnClearHistoryChange(warnOnClearHistory: boolean) {
    setWarnOnClearHistory(warnOnClearHistory)
    prefSetWarnOnClearHistory(warnOnClearHistory)
  }

  return (
      <div className="flex h-screen">
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-background rounded-sm shadow">
              <SettingsIcon className="h-5 w-5 mt-0.5"/>
              <span className="">General</span>
            </div>
            <div
                className="flex flex-row py-2 px-2 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/shortcuts" className="flex flex-row gap-x-2 w-full">
                <KeyboardIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Shortcuts</span>
              </a>
            </div>
            <div
                className="flex flex-row py-2 px-2 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/privacy" className="flex flex-row gap-x-2 w-full">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
          </div>
        </div>

        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">General</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto">
            <div className="flex items-center justify-between space-x-20 pt-6">
              <Label htmlFor="openAtLogin" className="flex flex-col text-base">
                <span className="">Launch at login</span>
                <span className="text-neutral-500 font-normal text-sm">
Launch ClipBook automatically at&nbsp;login
            </span>
              </Label>
              <Switch id="openAtLogin" checked={openAtLogin}
                      onCheckedChange={handleOpenAtLoginChange}/>
            </div>

            <hr/>

            <div className="flex justify-between space-x-10">
              <Label className="flex flex-col text-base">
                <span className="">Appearance</span>
                <span className="text-neutral-500 font-normal text-sm">Change how ClipBook looks on your&nbsp;device</span>
              </Label>

              <RadioGroup value={theme} onValueChange={handleThemeChange}>
                <div className="flex flex-row gap-x-6">
                  <div className="">
                    <Label htmlFor="r1" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="light" id="r1" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-light.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Light</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r2" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="dark" id="r2" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-dark.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Dark</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r3" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="system" id="r3" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="assets/theme-system.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">System</span>
                      </div>
                    </Label>
                  </div>
                </div>
              </RadioGroup>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="warnOnClearAll" className="flex flex-col text-base">
                <span className="">Warn when clearing all history</span>
                <span className="text-neutral-500 font-normal text-sm">
Display a confirmation dialog when clearing all clipboard&nbsp;history
            </span>
              </Label>
              <Switch id="warnOnClearAll" checked={warnOnClearHistory}
                      onCheckedChange={handleWarnOnClearHistoryChange}/>
            </div>
          </div>
        </div>
      </div>
  )
}
