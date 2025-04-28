import * as React from "react";
import {Button} from "@/components/ui/button";

export default function Welcome() {
  return (
      <div className="flex h-screen bg-background">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo_256x256@2x.png" className="h-44 w-44 mt-28 mx-auto text-secondary-foreground" alt=""/>
          <p className="text-center pt-8 text-3xl font-bold text-foreground">
            Welcome to ClipBook
          </p>
          <p className="text-center pt-2 mx-16">
            ClipBook stores everything you copy and lets you quickly access your clipboard history
            whenever you need it.
          </p>
          <div className="items-center pt-8">
            <Button onClick={() => window.location.href = "/accessibility"}
                className="bg-settings-primary-button text-white p-5 hover:bg-settings-primary-button-hover m-2">Get
              Started</Button>
          </div>
        </div>
      </div>
  )
}
