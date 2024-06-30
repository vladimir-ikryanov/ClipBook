import * as React from "react";
import {Label} from "@/components/ui/label";
import {SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";
import {useState} from "react";

declare const saveTheme: (theme: string) => void;
declare const getTheme: () => string;
declare const saveOpenAtLogin: (openAtLogin: boolean) => void;
declare const shouldOpenAtLogin: () => boolean;

export default function Settings() {
  const [theme, setTheme] = useState(getTheme());
  const [openAtLogin, setOpenAtLogin] = useState(shouldOpenAtLogin());

  function handleThemeChange(theme: string) {
    setTheme(theme)
    saveTheme(theme)
  }

  function handleOpenAtLoginChange(openAtLogin: boolean) {
    setOpenAtLogin(openAtLogin)
    saveOpenAtLogin(openAtLogin)
  }

  return (
      <div className="flex h-screen">
        <div className="flex bg-neutral-100">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-neutral-200 rounded-sm">
              <SettingsIcon className="h-5 w-5 mt-0.5"/>
              <span className="">General</span>
            </div>
            <div className="flex flex-row py-2 px-2 mx-4 hover:bg-neutral-200 hover:rounded-sm">
              <a href="/settings/privacy" className="flex flex-row gap-x-2">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
          </div>
        </div>
        <div className="flex flex-col flex-grow">
          <div className="grid gap-6 p-10 pt-0">
            <div className="flex pt-10 draggable border-b border-b-neutral-200">
              <span className="text-2xl pb-4">General settings</span>
            </div>

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
              <Label htmlFor="openAtLogin" className="flex flex-col text-base">
                <span className="">Launch at login</span>
                <span className="text-neutral-500 font-normal text-sm">
Launch ClipBook automatically at&nbsp;login
            </span>
              </Label>
              <Switch id="openAtLogin" checked={openAtLogin}
                      onCheckedChange={handleOpenAtLoginChange}/>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="warnOnClearAll" className="flex flex-col text-base">
                <span className="">Warn when clearing all history</span>
                <span className="text-neutral-500 font-normal text-sm">
Display a confirmation dialog when clearing all clipboard&nbsp;history
            </span>
              </Label>
              <Switch id="warnOnClearAll" defaultChecked/>
            </div>
          </div>
        </div>
      </div>
  )
}
