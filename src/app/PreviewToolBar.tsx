import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {
  PanelRightCloseIcon,
  EllipsisVerticalIcon
} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {prefGetTogglePreviewShortcut} from "@/pref";
import {toBase64Icon} from "@/data";

type PreviewToolBarProps = {
  appName: string
  appIcon: string
  onPaste: () => void
  onHidePreview: () => void
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
        <div className="flex m-2">
          <div className="">
            <Button variant="ghost" className="px-2" title={"Paste to " + props.appName}
                    onClick={handlePaste}>
              <img src={toBase64Icon(props.appIcon)} className="h-6 w-6 mr-2"
                   alt="Application icon"/>
              <span className="text-primary-foreground">Paste to {props.appName}</span>
            </Button>
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <EllipsisVerticalIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            <Button variant="ghost" className="p-2" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <PanelRightCloseIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
          </div>
        </div>
      </div>
  )
}
