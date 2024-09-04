import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {CopyIcon, GlobeIcon, InfoIcon, PanelRightCloseIcon, StarIcon} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import PreviewActions, {HidePreviewActionsReason} from "@/app/PreviewActions";
import {Clip, ClipType} from "@/db";

type PreviewToolBarProps = {
  item: Clip
  appName: string
  appIcon: string
  displayInfo: boolean
  onPaste: () => void
  onToggleInfo: () => void
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

  function handleCopyToClipboard() {
    props.onCopyToClipboard()
  }

  function handlePaste() {
    props.onPaste()
  }

  function handleToggleInfo() {
    props.onToggleInfo()
  }

  function handleOpenInBrowser() {
    props.onOpenInBrowser()
  }

  return (
      <div className="flex flex-col">
        <div className="flex m-2 h-10">
          <div className="">
            <Button variant="toolbar" size="toolbar" onClick={handleCopyToClipboard}
                    title={"Copy to Clipboard (" + shortcutToDisplayShortcut(prefGetCopyToClipboardShortcut()) + ")"}>
              <CopyIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            {
                props.item.type === ClipType.Link &&
                <Button variant="toolbar" size="toolbar" onClick={handleOpenInBrowser}
                        title={"Open in Browser (" + shortcutToDisplayShortcut(prefGetOpenInBrowserShortcut()) + ")"}>
                  <GlobeIcon className="h-5 w-5 text-primary-foreground"/>
                </Button>
            }
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <Button variant="toolbar" size="toolbar">
              <StarIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleToggleInfo}>
              <InfoIcon
                  className={props.displayInfo ? "h-5 w-5 text-toolbar" : "h-5 w-5 text-primary-foreground"}/>
            </Button>
            <PreviewActions onHideActions={props.onHideActions}
                            onCopyToClipboard={props.onCopyToClipboard}
                            onOpenInBrowser={props.onOpenInBrowser}
                            onDeleteItem={props.onDeleteItem}/>
            <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <PanelRightCloseIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
          </div>
        </div>
      </div>
  )
}
