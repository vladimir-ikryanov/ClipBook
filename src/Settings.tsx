import * as React from "react";
import {Label} from "@/components/ui/label";
import {SettingsIcon, ShieldCheckIcon} from "lucide-react";

export default function Settings() {
  return (
      <div className="flex h-screen">
        <div className="flex bg-neutral-100">
          <div className="flex flex-col w-48 my-12 mx-4 gap-y-1">
            <div className="flex flex-row gap-x-2 py-2 px-2 bg-neutral-200 rounded-sm">
              <SettingsIcon className="h-5 w-5 mt-0.5"/>
              <span className="">General</span>
            </div>
            <div className="flex flex-row py-2 px-2 hover:bg-neutral-200 hover:rounded-sm">
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
                <span className="text-2xl pb-4">Settings</span>
              </div>
              <div className="flex items-center justify-between space-x-10">
                <Label htmlFor="necessary" className="flex flex-col text-base">
                  <span className="">Appearance</span>
                  <span className="text-neutral-500 font-normal">Customize how ClipBook looks on your device.</span>
                </Label>
              </div>
            </div>
        </div>
      </div>
  )
}
