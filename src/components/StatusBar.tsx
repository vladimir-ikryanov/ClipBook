import '../App.css';
import {Button} from "@/components/ui/button";
import {
  ChevronDown,
  ChevronUp, Command, CommandIcon,
  CornerDownLeft,
  Delete
} from "lucide-react";
import React from "react";
import Actions from "@/components/Actions";

type StatusBarProps = {
  appName: string
}

export default function StatusBar(props: StatusBarProps) {
  return (
      <div
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t">
        <div className="flex space-x-1 text-sm text-primary-foreground">
          <Button disabled={true} variant="ghost" className="p-1 h-8">
            <div className="flex h-6 w-6 p-1.5 rounded bg-card">
              <ChevronUp className="h-3 w-3 text-card-foreground"/>
            </div>
            <div className="flex h-6 w-6 p-1.5 ml-1 rounded bg-card">
              <ChevronDown className="h-3 w-3 text-card-foreground"/>
            </div>
            <p className="px-2">Navigate</p>
          </Button>


          <Button disabled={true} variant="ghost" className="p-1 h-8">
            <div className="flex h-6 w-6 p-1.5 rounded bg-card">
              <CornerDownLeft className="h-3 w-3 text-card-foreground"/>
            </div>
            <p className="px-2">Paste to {props.appName}</p>
          </Button>

          <Button disabled={true} variant="ghost" className="p-1 h-8">
            <div className="flex h-6 w-10 rounded bg-card justify-center items-center">
              <span className="font-mono text-sm text-card-foreground">esc</span>
            </div>
            <p className="px-2">Close</p>
          </Button>
        </div>

        <div className="flex space-x-2">
          <Actions/>
        </div>
      </div>
  )
}
