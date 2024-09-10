import '../app.css';
import React from "react";
import {Button} from "@/components/ui/button";
import {
  ClipboardIcon,
  CopyIcon,
  GlobeIcon,
  StarIcon,
} from "lucide-react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetToggleFavoriteShortcut,
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
                props.displayInfo ?
                    <svg xmlns="http://www.w3.org/2000/svg"
                         width="20"
                         height="20"
                         viewBox="0 0 24 24"
                         fill="none"
                         stroke="currentColor"
                         stroke-width="2"
                         stroke-linecap="round"
                         stroke-linejoin="round"
                         className="h-5 w-5">
                      <rect x="3" y="3" width="18" height="18" rx="2"/>
                      <rect fill="currentColor" x="4" y="14" width="16" height="6"/>
                    </svg>
                    :
                    <svg xmlns="http://www.w3.org/2000/svg"
                         width="20"
                         height="20"
                         viewBox="0 0 24 24"
                         fill="none"
                         stroke="currentColor"
                         stroke-width="2"
                         stroke-linecap="round"
                         stroke-linejoin="round"
                         className="h-5 w-5">
                      <rect x="3" y="3" width="18" height="18" rx="2"/>
                      <line x1="4" y1="14" x2="20" y2="14"/>
                    </svg>
              }
            </Button>
            <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}
                    title={"Hide preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <svg xmlns="http://www.w3.org/2000/svg"
                   width="20"
                   height="20"
                   viewBox="0 0 24 24"
                   fill="none"
                   stroke="currentColor"
                   stroke-width="2"
                   stroke-linecap="round"
                   stroke-linejoin="round"
                   className="h-5 w-5">
                <rect x="3" y="3" width="18" height="18" rx="2"/>
                <rect fill="currentColor" x="14" y="4" width="6" height="16"/>
              </svg>
            </Button>
          </div>
        </div>
      </div>
  )
}
