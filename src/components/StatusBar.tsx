import '../App.css';
import {Button} from "@/components/ui/button";
import React from "react";
import Actions from "@/components/Actions";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCloseAppShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut
} from "@/pref";
import ShortcutLabel from "@/components/ShortcutLabel";

type StatusBarProps = {
  appName: string
  moreActionsButtonRef?: React.Ref<HTMLButtonElement>
}

export default function StatusBar(props: StatusBarProps) {
  return (
      <div
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t">
        <div className="flex space-x-1 text-sm text-primary-foreground">
          <Button variant="info" className="p-1 h-8">
            <ShortcutLabel shortcut={prefGetSelectNextItemShortcut()}/>
            <ShortcutLabel shortcut={prefGetSelectPreviousItemShortcut()}/>
            <p className="px-2">Navigate</p>
          </Button>

          <Button variant="ghost" className="p-1 h-8">
            <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            <p className="px-2">Paste to {props.appName}</p>
          </Button>

          <Button variant="ghost" className="p-1 h-8" title="Close window (Escape or ⌘W)">
            <ShortcutLabel shortcut={prefGetCloseAppShortcut()}/>
            <p className="px-2">Close</p>
          </Button>
        </div>

        <div className="flex space-x-2">
          <Actions moreActionsButtonRef={props.moreActionsButtonRef}/>
        </div>
      </div>
  )
}
