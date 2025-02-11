import '../app.css';
import {Button} from "@/components/ui/button";
import React from "react";
import {
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";

type ActionsBarProps = {
  appName: string
  onPaste: () => void
}

export default function ActionsBar(props: ActionsBarProps) {
  return (
      <div
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t">
        <div className="flex text-sm text-primary-foreground">
          <Button variant="info" className="p-1 h-8 rounded-sm outline-none">
            <ShortcutLabel
                shortcut={prefGetSelectNextItemShortcut() + " + " + prefGetSelectPreviousItemShortcut()}/>
            <p className="pl-2">Navigate</p>
          </Button>
        </div>

        <div className="flex">
          <Button variant="ghost" className="p-1 h-8 rounded-sm outline-none" onClick={props.onPaste}>
            <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            <p className="pl-2 pr-1 text-">Paste to {props.appName}</p>
          </Button>
        </div>
      </div>
  )
}
