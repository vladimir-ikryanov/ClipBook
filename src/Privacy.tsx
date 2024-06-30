import * as React from "react";
import {Switch} from "@/components/ui/switch";
import {Label} from "@/components/ui/label";
import {SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {useState} from "react";

declare const saveIgnoreTransientContent: (ignore: boolean) => void;
declare const saveIgnoreConfidentialContent: (ignore: boolean) => void;

declare const shouldIgnoreTransientContent: () => boolean;
declare const shouldIgnoreConfidentialContent: () => boolean;

export default function Privacy() {
  const [ignoreTransientContent, setIgnoreTransientContent] = useState(shouldIgnoreTransientContent());
  const [ignoreConfidentialContent, setIgnoreConfidentialContent] = useState(shouldIgnoreConfidentialContent());

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
        <div className="flex bg-secondary">
          <div className="flex flex-col w-52 gap-y-1">
            <div className="flex draggable p-6"></div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 mx-4 hover:bg-background hover:rounded-sm">
              <a href="/settings" className="flex flex-row gap-x-2">
                <SettingsIcon className="h-5 w-5 mt-0.5"/>
                <span className="">General</span>
              </a>
            </div>
            <div className="flex flex-row gap-x-2 py-2 px-2 mx-4 bg-background rounded-sm">
              <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
              <span className="">Privacy</span>
            </div>
          </div>
        </div>
        <div className="flex flex-col flex-grow">
          <div className="grid gap-6 p-10 pt-0">
            <div className="flex pt-10 draggable border-b border-b-border">
              <span className="text-2xl pb-4">Privacy settings</span>
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
