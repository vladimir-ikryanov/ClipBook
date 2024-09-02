import '../app.css';
import {Button} from "@/components/ui/button";
import React from "react";
import Actions, {HideActionsReason} from "@/app/Actions";
import {
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";

type ActionsBarProps = {
  appName: string
  appIcon: string
  onPaste: () => void
  onClose: () => void
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onSearchHistory: () => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
  onDeleteAllItems: () => void
}

export default function ActionsBar(props: ActionsBarProps) {
  return (
      <div
          className="flex items-center justify-between p-2 border-t-solid border-t-border border-t">
        <div className="flex space-x-1 text-sm text-primary-foreground">
          <Button variant="info" className="p-1 h-8 rounded-sm">
            <ShortcutLabel
                shortcut={prefGetSelectNextItemShortcut() + " + " + prefGetSelectPreviousItemShortcut()}/>
            <p className="px-2">Navigate</p>
          </Button>

          <Button variant="ghost" className="p-1 h-8 rounded-sm" onClick={props.onPaste}>
            <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            <p className="px-2 text-">Paste to {props.appName}</p>
          </Button>
        </div>

        <div className="flex space-x-2">
          <Actions appName={props.appName}
                   appIcon={props.appIcon}
                   onHideActions={props.onHideActions}
                   onEditContent={props.onEditContent}
                   onCopyToClipboard={props.onCopyToClipboard}
                   onOpenInBrowser={props.onOpenInBrowser}
                   onPaste={props.onPaste}
                   onTogglePreview={props.onTogglePreview}
                   onDeleteItem={props.onDeleteItem}
                   onDeleteAllItems={props.onDeleteAllItems}/>
        </div>
      </div>
  )
}
