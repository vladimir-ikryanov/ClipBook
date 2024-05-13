import * as React from "react";
import {Button} from "@/components/ui/button";

export default function Welcome() {
  return (
      <div className="flex h-screen bg-neutral-100">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo.svg" className="h-44 w-44 mt-28 mx-auto text-secondary-foreground" alt=""/>
          <p className="text-center pt-8 text-3xl font-bold text-foreground">
            Welcome to ClipBook
          </p>
          <p className="text-center pt-2 mx-16">
            ClipBook stores everything you copy and lets you quickly access your clipboard history
            whenever you need it.
          </p>
          <div className="items-center pt-8">
            <Button onClick={() => window.location.href = "/accessibility"}
                className="bg-gradient-to-b from-blue-500 to-blue-600 text-white p-5 hover:from-blue-600 hover:to-blue-700">Get
              Started</Button>
          </div>
        </div>
      </div>
  )
}
