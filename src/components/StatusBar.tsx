import '../App.css';
import {Button} from "@/components/ui/button";
import {
  ChevronDown,
  ChevronUp, Command,
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
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t draggable">
        <div className="flex space-x-2 text-sm text-primary-foreground">
          <div className="flex flex-row cursor-default p-1">
            <Button disabled={true} className="btn p-0 mr-1 h-6 w-6 rounded bg-card">
              <ChevronUp className="h-5 w-5 text-card-foreground"/>
            </Button>
            <Button disabled={true} className="btn p-0 h-6 w-6 rounded bg-card">
              <ChevronDown className="h-5 w-5 text-card-foreground"/>
            </Button>
            <div className="flex items-center">
              <p className="px-2">Navigate</p>
            </div>
          </div>

          <div className="flex flex-row cursor-default p-1">
            <Button disabled={true} className="btn p-0 h-6 w-6 rounded bg-card">
              <CornerDownLeft className="h-4 w-4 text-card-foreground"/>
            </Button>
            <div className="flex items-center">
              <p className="px-2">Paste to {props.appName}</p>
            </div>
          </div>

          <div className="flex flex-row cursor-default p-1">
            <Button disabled={true} className="btn px-2 h-6 rounded bg-card">
              <span className="text-sm font-mono text-card-foreground">esc</span>
            </Button>
            <div className="flex items-center">
              <p className="px-2">Close</p>
            </div>
          </div>
        </div>

        <div className="flex space-x-2">
          <Actions/>
        </div>
      </div>
  )
}
