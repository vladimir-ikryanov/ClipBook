import * as React from "react";
import {Label} from "@/components/ui/label";
import {SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";

export default function Settings() {
  return (
      <div className="flex h-screen">
        <div className="flex bg-neutral-100">
          <div className="flex flex-col w-48 gap-y-1">
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
                <span className="text-neutral-500 font-normal">Change how ClipBook looks on your&nbsp;device.</span>
              </Label>

              <RadioGroup defaultValue="system">
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

            <div className="flex items-center justify-between space-x-20 mt-2">
              <Label htmlFor="editContent" className="flex flex-col text-base">
                <span className="">Edit content of a clipboard history item</span>
                <span className="text-neutral-500 font-normal">
Allow editing content of the currently selected clipboard history item in the&nbsp;Preview&nbsp;pane.
            </span>
              </Label>
              <Switch id="editContent" defaultChecked/>
            </div>

            <div className="flex items-center justify-between space-x-20">
              <Label htmlFor="warnOnClearAll" className="flex flex-col text-base">
                <span className="">Display warning when clearing all history</span>
                <span className="text-neutral-500 font-normal">
Display a confirmation dialog when clearing all clipboard&nbsp;history.
            </span>
              </Label>
              <Switch id="warnOnClearAll" defaultChecked/>
            </div>
          </div>
        </div>
      </div>
  )
}