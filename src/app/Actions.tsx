import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {useEffect, useState} from "react"
import {
  CommandIcon,
  CopyIcon, DownloadIcon,
  Edit3Icon, EyeIcon,
  GlobeIcon,
  ScanTextIcon,
  SettingsIcon,
  StarIcon,
  StarOffIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
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
  prefGetPasteSelectedItemToActiveAppShortcut, prefGetSaveImageAsFileShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  getFirstSelectedHistoryItem,
  getPreviewVisibleState,
  toBase64Icon,
  getSelectedHistoryItemIndices, getSelectedHistoryItems, isTextItem
} from "@/data";
import {ClipType} from "@/db";
import {HidePreviewPaneIcon, ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";

export type HideActionsReason =
    "cancel"
    | "togglePreview"
    | "toggleFavorite"
    | "paste"
    | "merge"
    | "editContent"
    | "copyToClipboard"
    | "copyTextFromImage"
    | "saveImageAsFile"
    | "openInBrowser"
    | "preview"
    | "openSettings"
    | "deleteItem"
    | "deleteItems"
    | "deleteAllItems"

type ActionsProps = {
  appName: string
  appIcon: string
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onToggleFavorite: () => void
  onPaste: () => void
  onMerge: () => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onSaveImageAsFile: () => void
  onOpenInBrowser: () => void
  onPreviewLink: () => void
  onOpenSettings: () => void
  onDeleteItem: () => void
  onDeleteItems: () => void
  onDeleteAllItems: () => void
}

export default function Actions(props: ActionsProps) {
  const [open, setOpen] = useState(false)

  function closeCommandsPopup() {
    setOpen(false)
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
    e.stopPropagation()
  }

  function handleClick() {
    handleOpenChange(!open)
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

  function canShowCopyToClipboard() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowMergeItems() {
    if (getSelectedHistoryItemIndices().length > 1) {
      return getSelectedHistoryItems().every(item => isTextItem(item))
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

  function canShowCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      return item?.type === ClipType.Image && item?.content.length > 0
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
        <CommandDialog open={open} onOpenChange={handleOpenChange}>
          <Command onKeyDown={handleKeyDown}>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
            <CommandList>
              <CommandItem onSelect={handlePaste}>
                <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                     alt="Application icon"/>
                <span>Paste {getMultipleItemsIndicator()} to {props.appName}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              {
                  canShowMergeItems() &&
                  <CommandItem onSelect={handleMerge}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
                         viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
                         strokeLinecap="round" strokeLinejoin="round"
                         className="lucide lucide-unfold-vertical mr-2 h-4 w-4">
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
                    <CopyIcon className="mr-2 h-4 w-4"/>
                    <span>Copy to Clipboard</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              <CommandSeparator/>
              {
                  canShowOpenInBrowser() &&
                  <CommandItem onSelect={handleOpenInBrowser}>
                    <GlobeIcon className="mr-2 h-4 w-4"/>
                    <span>Open in Browser</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              {
                  canShowCopyTextFromImage() &&
                  <CommandItem onSelect={handleCopyTextFromImage}>
                    <ScanTextIcon className="mr-2 h-4 w-4"/>
                    <span>Copy Text from Image</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              {
                  canShowSaveImageAsFile() &&
                  <CommandItem onSelect={handleSaveImageAsFile}>
                    <DownloadIcon className="mr-2 h-4 w-4"/>
                    <span>Save Image as File...</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              {
                  canShowEditContent() &&
                  <CommandItem onSelect={handleEditContent}>
                    <Edit3Icon className="mr-2 h-4 w-4"/>
                    <span>Edit Content...</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              <CommandItem onSelect={handleToggleFavorite}>
                {
                  canAddToFavorites() ?
                      <StarIcon className="mr-2 h-4 w-4"/> :
                      <StarOffIcon className="mr-2 h-4 w-4"/>
                }
                <span>{canAddToFavorites() ?
                    `Add ${getMultipleItemsIndicator()} to Favorites` :
                    `Remove ${getMultipleItemsIndicator()} from Favorites`}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleTogglePreview}>
                {
                  getPreviewVisibleState() ?
                      <HidePreviewPaneIcon className="mr-2 h-4 w-4"/> :
                      <ShowPreviewPaneIcon className="mr-2 h-4 w-4"/>
                }
                <span>{getPreviewVisibleState() ? "Hide Preview" : "Show Preview"}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              {
                  canShowPreview() && <CommandSeparator/>
              }
              {
                  canShowPreview() &&
                  <CommandItem onSelect={handlePreviewLink}>
                    <EyeIcon className="mr-2 h-4 w-4"/>
                    <span>Preview Link</span>
                  </CommandItem>
              }
              <CommandSeparator/>
              <CommandItem onSelect={handleOpenSettings}>
                <SettingsIcon className="mr-2 h-4 w-4"/>
                <span>{"Settings..."}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetOpenSettingsShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandSeparator/>
              {
                  canShowDeleteItem() &&
                  <CommandItem onSelect={handleDeleteItem}>
                    <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                    <span className="text-actions-danger">Delete</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              {
                  canShowDeleteItems() &&
                  <CommandItem onSelect={handleDeleteItems}>
                    <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                    <span className="text-actions-danger">
                      Delete {getMultipleItemsIndicator()}
                    </span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              <CommandItem onSelect={handleDeleteAllItems}>
                <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                <span className="text-actions-danger">Delete All...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetClearHistoryShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
          </Command>
        </CommandDialog>
      </>
  )
}
