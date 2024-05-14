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
      <div className="flex h-screen bg-neutral-100">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo.svg" className="h-24 w-24 mx-auto text-secondary-foreground"
               alt=""/>
          <p className="text-center pt-4 text-2xl font-bold text-foreground">
            Enable Accessibility Access
          </p>
          <p className="text-center pt-2 mx-20">
            To paste directly to other applications, allow ClipBook to access
            the <a href="#" onClick={handleReadMore} className="text-blue-700 underline">accessibility
            features</a> of your Mac in <strong>System Settings</strong>.
          </p>
          <img src="assets/enable-accessibility.png" alt="" className="mx-20 my-10 rounded-xl"/>
          <div className="items-center">
            <Button
                className="bg-white text-black p-5 border-neutral-200 hover:border-neutral-300 border-solid border m-2"
                onClick={() => window.location.href = "/enjoy"}>I'll Do It Later</Button>
            <Button onClick={enableAccess}
                    className="bg-gradient-to-b from-blue-500 to-blue-600 text-white p-5 hover:from-blue-600 hover:to-blue-700 m-2">Allow
              Access</Button>
          </div>
        </div>
      </div>
  )
}
