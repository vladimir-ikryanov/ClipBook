import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {
  ClipboardIcon,
  CopyIcon,
  GlobeIcon, ScanTextIcon,
  StarIcon,
} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import {Clip, ClipType} from "@/db";
import {HideInfoPaneIcon, HidePreviewPaneIcon, ShowInfoPaneIcon} from "@/app/Icons";

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
  onCopyTextFromImage: () => void
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

  function handleCopyToClipboard() {
    props.onCopyToClipboard()
  }

  function handleToggleInfo() {
    props.onToggleInfo()
  }

  function handleOpenInBrowser() {
    props.onOpenInBrowser()
  }

  function handleCopyTextFromImage() {
    props.onCopyTextFromImage()
  }

  function handleToggleFavorite() {
    props.item.favorite = !props.item.favorite
    props.onEditHistoryItem(props.item)
  }

  return (
      <div className="flex flex-col">
        <div className="flex m-2 h-10">
          <div className="">
            <Button variant="toolbar" size="toolbar" onClick={handlePaste}
                    title={"Paste to " + props.appName + " (" + shortcutToDisplayShortcut(prefGetPasteSelectedItemToActiveAppShortcut()) + ")"}>
              <ClipboardIcon className="h-5 w-5" strokeWidth={2}/>
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleCopyToClipboard}
                    title={"Copy to Clipboard (" + shortcutToDisplayShortcut(prefGetCopyToClipboardShortcut()) + ")"}>
              <CopyIcon className="h-5 w-5" strokeWidth={2}/>
            </Button>
            {
                props.item.type === ClipType.Link &&
                <Button variant="toolbar" size="toolbar" onClick={handleOpenInBrowser}
                        title={"Open in Browser (" + shortcutToDisplayShortcut(prefGetOpenInBrowserShortcut()) + ")"}>
                  <GlobeIcon className="h-5 w-5" strokeWidth={2}/>
                </Button>
            }
            {
                props.item.type === ClipType.Image && props.item.content.length > 0 &&
                <Button variant="toolbar" size="toolbar" onClick={handleCopyTextFromImage}
                        title={"Copy Text from Image (" + shortcutToDisplayShortcut(prefGetCopyTextFromImageShortcut()) + ")"}>
                  <ScanTextIcon className="h-5 w-5" strokeWidth={2}/>
                </Button>
            }
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <Button variant="toolbar" size="toolbar" onClick={handleToggleFavorite}
                    title={props.favorite ? "Remove from favorites (" + shortcutToDisplayShortcut(prefGetToggleFavoriteShortcut()) + ")"
                        : "Add to favorites (" + shortcutToDisplayShortcut(prefGetToggleFavoriteShortcut()) + ")"}>
              <StarIcon
                  className={props.favorite ? "h-5 w-5 text-toolbar-buttonSelected" : "h-5 w-5"}
                  strokeWidth={2}/>
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleToggleInfo}
                    title={props.displayInfo ? "Hide details" : "Show details"}>
              {
                props.displayInfo ? <HideInfoPaneIcon className="h-5 w-5"/> : <ShowInfoPaneIcon className="h-5 w-5"/>
              }
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <HidePreviewPaneIcon className="h-5 w-5"/>
            </Button>
          </div>
        </div>
      </div>
  )
}
