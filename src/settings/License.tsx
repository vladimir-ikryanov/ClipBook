import * as React from "react";
import {useEffect, useState} from "react";
import {Button} from "@/components/ui/button";
import {Input} from "@/components/ui/input";
import {prefGetLicenseKey, prefSetLicenseKey} from "@/pref";
import {isLicenseActivated} from "@/licensing";
import ActivationErrorMessage from "@/settings/ActivationErrorMessage";

declare const closeSettingsWindow: () => void;
declare const buyLicense: () => void;
declare const helpWithActivation: () => void;
declare const activateLicense: (licenseKey: string) => void;
declare const deactivateLicense: (licenseKey: string) => void;

export default function License() {
  const [licenseKey, setLicenseKey] = useState(prefGetLicenseKey())
  const [licenseKeyInvalid, setLicenseKeyInvalid] = useState(isLicenseKeyFormatInvalid(licenseKey))
  const [isActivated, setIsActivated] = useState(isLicenseActivated())
  const [showErrorMessage, setShowErrorMessage] = useState(false)
  const [errorMessage, setErrorMessage] = useState("")

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
    buyLicense()
  }

  function handleActivateLicense() {
    activateLicense(licenseKey)
  }

  function handleDeactivateLicense() {
    deactivateLicense(licenseKey)
  }

  function handleClose() {
    setShowErrorMessage(false)
  }

  function handleHelp() {
    setShowErrorMessage(false)
    helpWithActivation()
  }

  function isLicenseKeyFormatInvalid(licenseKey: string) {
    return licenseKey.length !== 36
  }

  function removeSpaces(licenseKey: string): string {
    let input = document.getElementById("licenseKey") as HTMLInputElement
    licenseKey = licenseKey.replaceAll(' ', '')
    input.value = licenseKey
    return licenseKey
  }

  function handleLicenseKeyChange(e: React.ChangeEvent<HTMLInputElement>) {
    let key = removeSpaces(e.target.value)
    setLicenseKey(key)
    setLicenseKeyInvalid(isLicenseKeyFormatInvalid(key))
    prefSetLicenseKey(key)
  }

  function licenseActivationCompleted(error: string) {
    setErrorMessage(error)
    if (error) {
      setShowErrorMessage(true)
      setIsActivated(false)
    } else {
      setShowErrorMessage(false)
      setIsActivated(true)
    }
  }

  function licenseDeactivationCompleted(error: string) {
    setErrorMessage(error)
    if (error) {
      setShowErrorMessage(true)
      setIsActivated(true)
    } else {
      setShowErrorMessage(false)
      setIsActivated(false)
    }
  }

  (window as any).licenseActivationCompleted = licenseActivationCompleted;
  (window as any).licenseDeactivationCompleted = licenseDeactivationCompleted;

  function renderTitle() {
    if (isActivated) {
      return <span
          className="text-sm rounded-sm border border-settings-titleLicenseActivatedLabel text-settings-titleLicenseActivatedLabel px-2 py-1 ml-4">Activated</span>
    }
    return <span
        className="text-sm rounded-sm border border-settings-titleLicenseTrialLabel text-settings-titleLicenseTrialLabel px-2 py-1 ml-4">Trial</span>
  }

  return (
      <div className="flex select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky items-center">
            <span className="text-2xl pb-3 font-semibold">ClipBook License</span>
            <div className="pb-2.5">
              {renderTitle()}
            </div>
          </div>

          <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex flex-col pt-6 pb-1">
              {
                  !isActivated &&
                  <p className="mb-6 text-pretty">
                    You are currently using a <span
                      className="text-searchHighlight">trial version</span> of ClipBook. To continue
                    using
                    ClipBook,
                    please purchase a license key from online store and activate it.
                  </p>
              }
              <p className="mb-2">License key:</p>
              <Input id="licenseKey"
                     placeholder="XXXX-0000-0000-0000-0000000000000000"
                     onChange={handleLicenseKeyChange}
                     value={licenseKey}
                     disabled={isActivated}
                     className="mb-4 text-lg placeholder:text-settings-inputPlaceholder"/>
              <ActivationErrorMessage visible={showErrorMessage} message={errorMessage} onClose={handleClose} onHelp={handleHelp}/>
              {
                  !isActivated &&
                  <p className="text-secondary-foreground text-sm text-pretty mb-4">
                    You can find your license key in the email you received after purchasing ClipBook.
                  </p>
              }
              {
                  !isActivated &&
                  <div className="grid grid-cols-2 space-x-2">
                    <Button onClick={handleActivateLicense} disabled={licenseKeyInvalid}
                            variant="primary">Activate</Button>
                    <Button onClick={handleBuyLicense} variant="secondary">Buy License</Button>
                  </div>
              }
              {
                  isActivated &&
                  <Button onClick={handleDeactivateLicense} variant="primary">Deactivate</Button>
              }
            </div>
          </div>
        </div>
      </div>
  )
}
