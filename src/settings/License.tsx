import * as React from "react";
import {KeyboardIcon, KeyRoundIcon, ListIcon, SettingsIcon, ShieldCheckIcon} from "lucide-react";
import {useEffect} from "react";
import {Button} from "@/components/ui/button";
import {Input} from "@/components/ui/input";

declare const closeSettingsWindow: () => void;

export default function License() {
  const [licenseKey, setLicenseKey] = React.useState("")
  const [licenseKeyInvalid, setLicenseKeyInvalid] = React.useState(true)

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

  function handleBuyLicense() {
    console.log("Buy License")
  }

  function handleActivateLicense() {
    console.log("Activate License")
  }

  function handleLicenseKeyChange(e: React.ChangeEvent<HTMLInputElement>) {
    setLicenseKey(e.target.value)
    setLicenseKeyInvalid(e.target.value.length !== 36)
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
                className="flex flex-row p-0 mx-4 hover:bg-background hover:rounded-sm hover:shadow">
              <a href="/settings/privacy" className="flex flex-row py-2 px-2 gap-x-2 w-full">
                <ShieldCheckIcon className="h-5 w-5 mt-0.5"/>
                <span className="">Privacy</span>
              </a>
            </div>
            <div className="flex flex-grow"></div>
            <div
                className="flex flex-row gap-x-2 py-2 px-2 m-4 bg-settings-sidebarSelection rounded-sm shadow">
              <KeyRoundIcon className="h-5 w-5 mt-0.5"/>
              <span className="">License</span>
            </div>
          </div>
        </div>

        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">ClipBook License</span>
          </div>

          <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto">
            <div className="flex flex-col pt-6 pb-1">
              <p className="mb-6 text-pretty">
                You are currently using a trial version of ClipBook. To continue using ClipBook,
                please purchase a license key from online store and activate it.
              </p>
              <p className="mb-2">License key:</p>
              <Input placeholder="XXXX-0000-0000-0000-0000000000000000"
                     onChange={handleLicenseKeyChange}
                     className="mb-4 text-lg placeholder:text-settings-inputPlaceholder"/>
              <div className="grid grid-cols-2 space-x-2">
                <Button onClick={handleActivateLicense} disabled={licenseKeyInvalid}
                        variant="activate">Activate</Button>
                <Button onClick={handleBuyLicense} variant="buy">Buy License</Button>
              </div>
            </div>
          </div>
        </div>
      </div>
  )
}
