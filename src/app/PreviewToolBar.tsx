import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {
  CopyIcon,
  EllipsisVerticalIcon,
  GlobeIcon,
  InfoIcon,
  PanelRightCloseIcon,
  PinIcon, StarIcon,
} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import {Clip, ClipType} from "@/db";

type PreviewToolBarProps = {
  item: Clip
  favorite: boolean
  appName: string
  appIcon: string
  displayInfo: boolean
  onPaste: () => void
  onToggleInfo: () => void
  onHidePreview: () => void
  onEditHistoryItem: (item: Clip) => void
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

  function handleToggleInfo() {
    props.onToggleInfo()
  }

  function handleOpenInBrowser() {
    props.onOpenInBrowser()
  }

  function handleToggleFavorite() {
    props.item.favorite = !props.item.favorite
    props.onEditHistoryItem(props.item)
  }

  return (
      <div className="flex flex-col">
        <div className="flex m-2 h-10">
          <div className="">
            <Button variant="toolbar" size="toolbar" onClick={handleToggleFavorite}
                    title={props.favorite ? "Remove from favorites" : "Add to favorites"}>
              <StarIcon
                  className={props.favorite ? "h-5 w-5 text-toolbar-buttonSelected" : "h-5 w-5"}
                  strokeWidth={2}/>
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleCopyToClipboard}
                    title={"Copy to Clipboard (" + shortcutToDisplayShortcut(prefGetCopyToClipboardShortcut()) + ")"}>
              <CopyIcon className="h-5 w-5 text-toolbar-button" strokeWidth={2}/>
            </Button>
            {
                props.item.type === ClipType.Link &&
                <Button variant="toolbar" size="toolbar" onClick={handleOpenInBrowser}
                        title={"Open in Browser (" + shortcutToDisplayShortcut(prefGetOpenInBrowserShortcut()) + ")"}>
                  <GlobeIcon className="h-5 w-5 text-toolbar-button" strokeWidth={2}/>
                </Button>
            }
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <Button variant="toolbar" size="toolbar" onClick={handleToggleInfo}>
              <InfoIcon className={props.displayInfo ?
                  "h-5 w-5 text-toolbar-buttonSelected" : "h-5 w-5"} strokeWidth={2}/>
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <PanelRightCloseIcon className="h-5 w-5" strokeWidth={2}/>
            </Button>
          </div>
        </div>
      </div>
  )
}
