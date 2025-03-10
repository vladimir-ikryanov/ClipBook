import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {useEffect, useState} from "react"
import {
  CommandIcon,
  CopyIcon, DownloadIcon,
  Edit3Icon, EyeIcon,
  GlobeIcon, PenIcon,
  ScanTextIcon,
  SettingsIcon,
  StarIcon,
  StarOffIcon,
  TrashIcon, Undo2Icon, ZoomIn, ZoomOut
} from "lucide-react"

import { VisuallyHidden } from "@radix-ui/react-visually-hidden";

import {
  CommandDialog,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command"
import {
  prefGetClearHistoryShortcut,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut, prefGetShowInFinderShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut,
  prefGetZoomUIResetShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  getFirstSelectedHistoryItem,
  getPreviewVisibleState,
  toBase64Icon,
  getSelectedHistoryItemIndices, getSelectedHistoryItems, isTextItem
} from "@/data";
import {ClipType, getImageText} from "@/db";
import {HidePreviewPaneIcon, ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import {DialogTitle} from "@/components/ui/dialog";

declare const canZoomIn: () => boolean;
declare const canZoomOut: () => boolean;
declare const canResetZoom: () => boolean;

export type HideActionsReason =
    "cancel"
    | "togglePreview"
    | "toggleFavorite"
    | "paste"
    | "pasteWithTab"
    | "pasteWithReturn"
    | "pasteWithTransformation"
    | "pastePath"
    | "merge"
    | "editContent"
    | "renameItem"
    | "copyToClipboard"
    | "copyPathToClipboard"
    | "copyTextFromImage"
    | "saveImageAsFile"
    | "openInBrowser"
    | "showInFinder"
    | "preview"
    | "zoomIn"
    | "zoomOut"
    | "resetZoom"
    | "openSettings"
    | "deleteItem"
    | "deleteItems"
    | "deleteAllItems"

type CommandsProps = {
  appName: string
  appIcon: string
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onToggleFavorite: () => void
  onPaste: () => void
  onPasteWithTab: () => void
  onPasteWithReturn: () => void
  onPasteWithTransformation: () => void
  onPastePath: () => void
  onMerge: () => void
  onEditContent: () => void
  onRenameItem: () => void
  onCopyToClipboard: () => void
  onCopyPathToClipboard: () => void
  onCopyTextFromImage: () => void
  onSaveImageAsFile: () => void
  onOpenInBrowser: () => void
  onShowInFinder: () => void
  onPreviewLink: () => void
  onZoomIn: () => void
  onZoomOut: () => void
  onResetZoom: () => void
  onOpenSettings: () => void
  onDeleteItem: () => void
  onDeleteItems: () => void
  onDeleteAllItems: () => void
}

export default function Commands(props: CommandsProps) {
  const [open, setOpen] = useState(false)

  function closeCommandsPopup() {
    handleOpenChange(false)
  }

  (window as any).closeCommandsPopup = closeCommandsPopup

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e)) {
        e.preventDefault()
        setOpen(true)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function handleKeyDown(e: React.KeyboardEvent) {
    // Close the app window with the close app shortcut.
    if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e.nativeEvent)) {
      e.preventDefault()
      handleOpenChange(false)
    }
    e.stopPropagation()
  }

  function handleClick() {
    handleOpenChange(true)
  }

  let closeReason: HideActionsReason = "cancel"

  function handleOpenChange(open: boolean) {
    setOpen(open)
    if (!open) {
      props.onHideActions(closeReason)
    }
  }

  function handleEditContent() {
    closeReason = "editContent"
    handleOpenChange(false)
    props.onEditContent()
  }

  function handleRenameItem() {
    closeReason = "renameItem"
    handleOpenChange(false)
    props.onRenameItem()
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard()
  }

  function handlePaste() {
    closeReason = "paste"
    handleOpenChange(false)
    props.onPaste()
  }

  function handlePasteWithTab() {
    closeReason = "pasteWithTab"
    handleOpenChange(false)
    props.onPasteWithTab()
  }

  function handlePasteWithReturn() {
    closeReason = "pasteWithReturn"
    handleOpenChange(false)
    props.onPasteWithReturn()
  }

  function handleMerge() {
    closeReason = "merge"
    handleOpenChange(false)
    props.onMerge()
  }

  function handleToggleFavorite() {
    closeReason = "toggleFavorite"
    handleOpenChange(false)
    props.onToggleFavorite()
  }

  function handleTogglePreview() {
    closeReason = "togglePreview"
    handleOpenChange(false)
    props.onTogglePreview()
  }

  function handleOpenSettings() {
    closeReason = "openSettings"
    handleOpenChange(false)
    props.onOpenSettings()
  }

  function handleZoomIn() {
    closeReason = "zoomIn"
    handleOpenChange(false)
    props.onZoomIn()
  }

  function handleZoomOut() {
    closeReason = "zoomOut"
    handleOpenChange(false)
    props.onZoomOut()
  }

  function handleResetZoom() {
    closeReason = "resetZoom"
    handleOpenChange(false)
    props.onResetZoom()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem()
  }

  function handleDeleteItems() {
    closeReason = "deleteItems"
    handleOpenChange(false)
    props.onDeleteItems()
  }

  function handleDeleteAllItems() {
    closeReason = "deleteAllItems"
    handleOpenChange(false)
    props.onDeleteAllItems()
  }

  function handleOpenInBrowser() {
    closeReason = "openInBrowser"
    handleOpenChange(false)
    props.onOpenInBrowser()
  }

  function handleShowInFinder() {
    closeReason = "showInFinder"
    handleOpenChange(false)
    props.onShowInFinder()
  }

  function handlePreviewLink() {
    closeReason = "preview"
    handleOpenChange(false)
    props.onPreviewLink()
  }

  function handleCopyTextFromImage() {
    closeReason = "copyTextFromImage"
    handleOpenChange(false)
    props.onCopyTextFromImage()
  }

  function handleSaveImageAsFile() {
    closeReason = "saveImageAsFile"
    handleOpenChange(false)
    props.onSaveImageAsFile()
  }

  function handlePasteWithTransformation() {
    closeReason = "pasteWithTransformation"
    handleOpenChange(false)
    props.onPasteWithTransformation()
  }

  function handlePastePath() {
    closeReason = "pastePath"
    handleOpenChange(false)
    props.onPastePath()
  }

  function handleCopyPathToClipboard() {
    closeReason = "copyPathToClipboard"
    handleOpenChange(false)
    props.onCopyPathToClipboard()
  }

  function canShowCopyToClipboard() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowMultiplePaste() {
    return getSelectedHistoryItemIndices().length > 1
  }

  function canShowInFinder() {
    return isFile()
  }

  function canShowCopyPath() {
    return isFile()
  }

  function canShowPastePath() {
    return isFile()
  }

  function isFile() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      return item && item.type === ClipType.File
    }
    return false
  }

  function canPasteWithTransformation() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item) {
        return isTextItem(item)
      }
    }
    return false
  }

  function canShowMergeItems() {
    if (getSelectedHistoryItemIndices().length > 1) {
      return getSelectedHistoryItems().every(item => isTextItem(item) || item.type === ClipType.File)
    }
    return false
  }

  function canShowOpenInBrowser() {
    if (getSelectedHistoryItemIndices().length === 1) {
      return getFirstSelectedHistoryItem()?.type === ClipType.Link
    }
    return false
  }

  function canShowPreview() {
    return canShowOpenInBrowser()
  }

  function canShowRenameItem() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item) {
        if (item.type === ClipType.Image && item.content.length > 0) {
          return true
        }
        if (getImageText(item).length > 0) {
          return true
        }
      }
    }
    return false
  }

  function canShowSaveImageAsFile() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      return item?.type === ClipType.Image
    }
    return false
  }

  function canShowEditContent() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      let type = item?.type;
      return type === ClipType.Text ||
          type === ClipType.Link ||
          type === ClipType.Email ||
          type === ClipType.Color
    }
    return false
  }

  function canAddToFavorites() {
    return getSelectedHistoryItems().some(item => !item.favorite)
  }

  function canShowDeleteItem() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowDeleteItems() {
    return getSelectedHistoryItemIndices().length > 1
  }

  function getMultipleItemsIndicator(): string {
    let indices = getSelectedHistoryItemIndices().length
    if (indices > 1) {
      return indices + " Items"
    }
    return ""
  }

  return (
      <>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="toolbar" size="toolbar" onClick={handleClick}>
              <CommandIcon className="h-5 w-5"/>
            </Button>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div className="select-none mr-2">Show more actions</div>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </TooltipContent>
        </Tooltip>
        <div className="" onKeyDown={handleKeyDown}>
          <CommandDialog open={open} onOpenChange={handleOpenChange}>
            <VisuallyHidden>
              <DialogTitle></DialogTitle>
            </VisuallyHidden>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
            <div className="max-h-[70vh] overflow-y-auto mb-1.5">
              <CommandList>
                <CommandItem onSelect={handlePaste}>
                  <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                       alt="Application icon"/>
                  <span>Paste {getMultipleItemsIndicator()} to {props.appName}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                {
                    canPasteWithTransformation() &&
                    <CommandItem onSelect={handlePasteWithTransformation}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>
                    Paste {getMultipleItemsIndicator()} to {props.appName} with Formatting...
                  </span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithReturn}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste {getMultipleItemsIndicator()} to {props.appName} with Return</span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithTab}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste {getMultipleItemsIndicator()} to {props.appName} with Tab</span>
                    </CommandItem>
                }
                {
                    canShowPastePath() &&
                    <CommandItem onSelect={handlePastePath}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste Path to {props.appName}</span>
                    </CommandItem>
                }
                {
                    canShowMergeItems() &&
                    <CommandItem onSelect={handleMerge}>
                      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
                           viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
                           strokeLinecap="round" strokeLinejoin="round"
                           className="lucide lucide-unfold-vertical mr-2 h-5 w-5">
                        <path d="M12 22v-6"/>
                        <path d="M12 8V2"/>
                        <path d="M4 12H2"/>
                        <path d="M10 12H8"/>
                        <path d="M16 12h-2"/>
                        <path d="M22 12h-2"/>
                        <path d="m15 5-3 3-3-3"/>
                        <path d="m15 19-3-3-3 3"/>
                      </svg>
                      <span>Merge {getMultipleItemsIndicator()}</span>
                    </CommandItem>
                }
                {
                    canShowCopyToClipboard() &&
                    <CommandItem onSelect={handleCopyToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>Copy to Clipboard</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyPath() &&
                    <CommandItem onSelect={handleCopyPathToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>Copy Path to Clipboard</span>
                    </CommandItem>
                }
                <CommandSeparator/>
                {
                    canShowOpenInBrowser() &&
                    <CommandItem onSelect={handleOpenInBrowser}>
                      <GlobeIcon className="mr-2 h-5 w-5"/>
                      <span>Open in Browser</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowInFinder() &&
                    <CommandItem onSelect={handleShowInFinder}>
                      <svg xmlns="http://www.w3.org/2000/svg"
                           aria-label="Finder" role="img"
                           viewBox="0 0 512 512" className="mr-2 h-5 w-5">
                        <rect
                            width="512" height="512"
                            rx="15%"
                            fill="url(#a)"/>
                        <defs>
                          <linearGradient id="a" x2="0" y1="100%">
                            <stop offset="0" stop-color="#1e73f2"/>
                            <stop offset="1" stop-color="#19d3fd"/>
                          </linearGradient>
                          <linearGradient id="b" x2="0" y1="100%">
                            <stop offset="0" stop-color="#dbe9f4"/>
                            <stop offset="1" stop-color="#f7f6f6"/>
                          </linearGradient>
                        </defs>
                        <path fill="url(#b)"
                              d="M435.2 0H274.4c-21.2 49.2-59.2 129.6-60.8 283.4a9.9 9.9 0 0010 10.1h58.7a9.9 9.9 0 019.9 10.2A933.3 933.3 0 00311.3 512h123.9a76.8 76.8 0 0076.8-76.8V76.8A76.8 76.8 0 00435.2 0z"/>
                        <path fill="none" stroke="#000000" stroke-linecap="round" stroke-width="20"
                              d="M371 149v34m-229-34v34m263.4 147.2a215.2 215.2 0 01-298.8 0"/>
                      </svg>
                      <span>Show in Finder</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetShowInFinderShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyTextFromImage() &&
                    <CommandItem onSelect={handleCopyTextFromImage}>
                      <ScanTextIcon className="mr-2 h-5 w-5"/>
                      <span>Copy Text from Image</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowSaveImageAsFile() &&
                    <CommandItem onSelect={handleSaveImageAsFile}>
                      <DownloadIcon className="mr-2 h-5 w-5"/>
                      <span>Save Image as File...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowEditContent() &&
                    <CommandItem onSelect={handleEditContent}>
                      <Edit3Icon className="mr-2 h-5 w-5"/>
                      <span>Edit Content...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandItem onSelect={handleToggleFavorite}>
                  {
                    canAddToFavorites() ?
                        <StarIcon className="mr-2 h-5 w-5"/> :
                        <StarOffIcon className="mr-2 h-5 w-5"/>
                  }
                  <span>{canAddToFavorites() ?
                      `Add ${getMultipleItemsIndicator()} to Favorites` :
                      `Remove ${getMultipleItemsIndicator()} from Favorites`}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                {
                    canShowPreview() && <CommandSeparator/>
                }
                {
                    canShowPreview() &&
                    <CommandItem onSelect={handlePreviewLink}>
                      <EyeIcon className="mr-2 h-5 w-5"/>
                      <span>Preview Link</span>
                    </CommandItem>
                }
                {
                    canShowRenameItem() &&
                    <CommandItem onSelect={handleRenameItem}>
                      <PenIcon className="mr-2 h-5 w-5"/>
                      <span>Rename...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandSeparator/>
                <CommandItem onSelect={handleTogglePreview}>
                  {
                    getPreviewVisibleState() ?
                        <HidePreviewPaneIcon className="mr-2 h-5 w-5"/> :
                        <ShowPreviewPaneIcon className="mr-2 h-5 w-5"/>
                  }
                  <span>{getPreviewVisibleState() ? "Hide Preview" : "Show Preview"}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomIn} disabled={!canZoomIn()}>
                  <ZoomIn className="mr-2 h-5 w-5"/>
                  <span>Zoom In</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIInShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomOut} disabled={!canZoomOut()}>
                  <ZoomOut className="mr-2 h-5 w-5"/>
                  <span>Zoom Out</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIOutShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleResetZoom} disabled={!canResetZoom()}>
                  <Undo2Icon className="mr-2 h-5 w-5"/>
                  <span>Reset Zoom</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIResetShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                <CommandItem onSelect={handleOpenSettings}>
                  <SettingsIcon className="mr-2 h-5 w-5"/>
                  <span>{"Settings..."}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetOpenSettingsShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                {
                    canShowDeleteItem() &&
                    <CommandItem onSelect={handleDeleteItem}>
                      <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                      <span className="text-actions-danger">Delete</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowDeleteItems() &&
                    <CommandItem onSelect={handleDeleteItems}>
                      <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                      <span className="text-actions-danger">
                      Delete {getMultipleItemsIndicator()}
                    </span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandItem onSelect={handleDeleteAllItems}>
                  <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                  <span className="text-actions-danger">Delete All...</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetClearHistoryShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandEmpty>No results found.</CommandEmpty>
              </CommandList>
            </div>
          </CommandDialog>
        </div>
      </>
  )
}
