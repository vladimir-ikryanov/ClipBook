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
declare const saveWarnOnClearHistory: (warn: boolean) => void;
declare const shouldWarnOnClearHistory: () => boolean;
declare const saveIgnoreTransientContent: (ignore: boolean) => void;
declare const saveIgnoreConfidentialContent: (ignore: boolean) => void;
declare const shouldIgnoreTransientContent: () => boolean;
declare const shouldIgnoreConfidentialContent: () => boolean;

export default function Settings() {
  const [theme, setTheme] = useState(getTheme());
  const [openAtLogin, setOpenAtLogin] = useState(shouldOpenAtLogin());
  const [warnOnClearHistory, setWarnOnClearHistory] = useState(shouldWarnOnClearHistory());
  const [ignoreTransientContent, setIgnoreTransientContent] = useState(shouldIgnoreTransientContent());
  const [ignoreConfidentialContent, setIgnoreConfidentialContent] = useState(shouldIgnoreConfidentialContent());

  function handleThemeChange(theme: string) {
    setTheme(theme)
    saveTheme(theme)
  }

  function handleOpenAtLoginChange(openAtLogin: boolean) {
    setOpenAtLogin(openAtLogin)
    saveOpenAtLogin(openAtLogin)
  }

  function handleWarnOnClearHistoryChange(warnOnClearHistory: boolean) {
    setWarnOnClearHistory(warnOnClearHistory)
    saveWarnOnClearHistory(warnOnClearHistory)
  }

  function handleIgnoreTransientContentChange(checked: boolean) {
    setIgnoreTransientContent(checked)
    saveIgnoreTransientContent(checked)
  }

  function handleIgnoreConfidentialContentChange(checked: boolean) {
    setIgnoreConfidentialContent(checked)
    saveIgnoreConfidentialContent(checked)
  }

  return (
      <div className="flex h-screen">
        <div className="flex flex-col flex-grow">
          <div className="grid gap-6 p-16 pt-0">
            <div className="flex pt-12 draggable border-b border-b-border">
              <span className="text-2xl pb-3 font-semibold">General settings</span>
            </div>

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

            <div className="flex pt-10 border-b border-b-border">
              <span className="text-2xl pb-3 font-semibold">Privacy settings</span>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="ignoreConfidential" className="flex flex-col text-base">
                <span className="">Ignore confidential content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save passwords and other sensitive data copied to the&nbsp;clipboard
            </span>
              </Label>
              <Switch id="ignoreConfidential" checked={ignoreConfidentialContent}
                      onCheckedChange={handleIgnoreConfidentialContentChange}/>
            </div>
            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="ignoreTransient" className="flex flex-col text-base">
                <span className="">Ignore transient content</span>
                <span className="text-neutral-500 font-normal text-sm">
              Do not save data temporarily placed to the&nbsp;clipboard
            </span>
              </Label>
              <Switch id="ignoreTransient" checked={ignoreTransientContent}
                      onCheckedChange={handleIgnoreTransientContentChange}/>
            </div>
          </div>
        </div>
      </div>
  )
}
