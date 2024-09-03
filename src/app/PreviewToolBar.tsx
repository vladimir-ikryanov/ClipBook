import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {PanelRightCloseIcon} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {prefGetTogglePreviewShortcut} from "@/pref";
import {toBase64Icon} from "@/data";
import PreviewActions, {HidePreviewActionsReason} from "@/app/PreviewActions";

type PreviewToolBarProps = {
  appName: string
  appIcon: string
  onPaste: () => void
  onHidePreview: () => void
  onHideActions: (reason: HidePreviewActionsReason) => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
}

export default function PreviewToolBar(props: PreviewToolBarProps) {
  function handleHidePreview() {
    props.onHidePreview()
  }

  function handlePaste() {
    props.onPaste()
  }

  return (
      <div className="flex flex-col">
        <div className="flex m-2 h-10">
          <div className="">
            <Button variant="toolbar" size="toolbar" title={"Paste to " + props.appName}
                    onClick={handlePaste}>
              <img src={toBase64Icon(props.appIcon)} className="h-6 w-6 mr-2"
                   alt="Application icon"/>
              <span className="text-primary-foreground">Paste to {props.appName}</span>
            </Button>
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <PreviewActions onHideActions={props.onHideActions}
                            onCopyToClipboard={props.onCopyToClipboard}
                            onOpenInBrowser={props.onOpenInBrowser}
                            onDeleteItem={props.onDeleteItem}/>
            <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <PanelRightCloseIcon className="h-6 w-6 text-primary-foreground" strokeWidth={1.5}/>
            </Button>
          </div>
        </div>
      </div>
  )
}
