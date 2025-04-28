import * as React from "react";
import {Button} from "@/components/ui/button";

declare const enableAccessibilityAccess: () => void;
declare const openUrl: (url: string) => void;

export default function Accessibility() {
  function enableAccess(): void {
    enableAccessibilityAccess()
  }

  function handleReadMore(): void {
    openUrl("https://clipbook.app/blog/paste-to-other-applications/?utm_source=app")
  }

  return (
      <div className="flex h-screen bg-background">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo_256x256@2x.png" className="h-24 w-24 mx-auto text-secondary-foreground"
               alt=""/>
          <p className="text-center pt-4 text-2xl font-bold text-foreground">
            Enable Accessibility Access
          </p>
          <p className="text-center pt-2 mx-20">
            To paste directly to other applications, allow ClipBook to access
            the <a href="#" onClick={handleReadMore} className="text-settings-primary-button underline">accessibility
            features</a> of your Mac in <strong>System Settings</strong>.
          </p>
          <img src="assets/enable-accessibility.png" alt="" className="mx-20 my-10 rounded-xl"/>
          <div className="items-center">
            <Button
                className="bg-settings-secondary-button text-settings-secondary-button-text p-5 hover:bg-settings-secondary-button-hover m-2"
                onClick={() => window.location.href = "/enjoy"}>I'll Do It Later</Button>
            <Button onClick={enableAccess}
                    className="bg-settings-primary-button text-white p-5 hover:bg-settings-primary-button-hover m-2">Allow
              Access</Button>
          </div>
        </div>
      </div>
  )
}
