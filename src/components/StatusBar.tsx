import '../App.css';
import {Button} from "@/components/ui/button";
import {
  ChevronDown,
  ChevronUp,
  CornerDownLeft
} from "lucide-react";
import React from "react";
import Actions from "@/components/Actions";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCloseAppShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut
} from "@/components/pref";

type StatusBarProps = {
  appName: string
}

export default function StatusBar(props: StatusBarProps) {
  return (
      <div
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t">
        <div className="flex space-x-1 text-sm text-primary-foreground">
          <Button variant="info" className="p-1 h-8">
            <div className="flex h-6 w-10 rounded bg-card justify-center items-center">
              <span
                  className="text-sm text-card-foreground">{shortcutToDisplayShortcut(prefGetSelectNextItemShortcut())}</span>
            </div>
            <div className="flex h-6 w-10 rounded bg-card justify-center items-center">
              <span
                  className="text-sm text-card-foreground">{shortcutToDisplayShortcut(prefGetSelectPreviousItemShortcut())}</span>
            </div>
            <p className="px-2">Navigate</p>
          </Button>

          <Button variant="ghost" className="p-1 h-8">
            <div className="flex h-6 w-10 rounded bg-card justify-center items-center">
              <span
                  className="text-sm text-card-foreground">{shortcutToDisplayShortcut(prefGetPasteSelectedItemToActiveAppShortcut())}</span>
            </div>
            <p className="px-2">Paste to {props.appName}</p>
          </Button>

          <Button variant="ghost" className="p-1 h-8" title="Close window (Escape or ⌘W)">
            <div className="flex h-6 w-10 rounded bg-card justify-center items-center">
              <span
                  className="text-sm text-card-foreground">{shortcutToDisplayShortcut(prefGetCloseAppShortcut())}</span>
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
