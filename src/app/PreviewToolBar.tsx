import '../app.css';
import React, {KeyboardEvent, MouseEvent, useState} from "react";
import {Button} from "@/components/ui/button";
import {
  ChevronDown,
  ClipboardIcon,
  CopyIcon, DownloadIcon, Edit3Icon, EllipsisVerticalIcon, EyeIcon,
  GlobeIcon, PenIcon, RefreshCwIcon, ScanTextIcon,
  StarIcon, TrashIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
  prefShouldShowPreviewForLinks
} from "@/pref";
import {ClipType} from "@/db";
import {HideInfoPaneIcon, HidePreviewPaneIcon, ShowInfoPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getFirstSelectedHistoryItem,
  getHistoryItem,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems, isTextItem, toBase64Icon
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";

export type HideDropdownReason =
    "cancel"
    | "togglePreview"
    | "editContent"
    | "renameItem"
    | "previewLink"
    | "updatePreview"
    | "saveImageAsFile"
    | "deleteItem"

type PreviewToolBarProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  displayInfo: boolean
  onPaste: () => void
  onPasteWithReturn: () => void
  onPasteWithTab: () => void
  onMerge: () => void
  onToggleInfo: () => void
  onHidePreview: () => void
  onSaveImageAsFile: () => void
  onDeleteItem: () => void
  onRenameItem: () => void
  onRequestEditItem: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onToggleFavorite: () => void
  onOpenInBrowser: () => void
  onPreviewLink: () => void
  onUpdateLinkPreview: () => void
  onHideDropdown: (reason: HideDropdownReason) => void
}

export default function PreviewToolBar(props: PreviewToolBarProps) {
  const [openDropdown, setOpenDropdown] = useState(false)
  const [pasteOptionsMenuOpen, setPasteOptionsMenuOpen] = useState(false)

  let closeReason: HideDropdownReason = "cancel"

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
  }

  function handleHidePreview() {
    props.onHidePreview()
  }

  function handlePaste() {
    props.onPaste()
  }

  function handlePasteWithReturn() {
    props.onPasteWithReturn()
  }

  function handlePasteWithTab() {
    props.onPasteWithTab()
  }

  function handleMerge() {
    props.onMerge()
  }

  function handleCopyToClipboard() {
    props.onCopyToClipboard()
  }

  function handleRequestEditItem() {
    closeReason = "editContent"
    handleOpenDropdownChange(false)
    setTimeout(() => {
      props.onRequestEditItem()
    }, 250)
  }

  function handleRenameItem() {
    closeReason = "renameItem"
    handleOpenDropdownChange(false)
    setTimeout(() => {
      props.onRenameItem()
    }, 250)
  }

  function handleSaveImageAsFile() {
    closeReason = "saveImageAsFile"
    handleOpenDropdownChange(false)
    props.onSaveImageAsFile()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenDropdownChange(false)
    props.onDeleteItem()
  }

  function handleToggleInfo() {
    props.onToggleInfo()
  }

  function handleOpenInBrowser() {
    props.onOpenInBrowser()
  }

  function handlePreviewLink() {
    closeReason = "previewLink"
    handleOpenDropdownChange(false)
    props.onPreviewLink()
  }

  function handleUpdateLinkPreview() {
    closeReason = "updatePreview"
    handleOpenDropdownChange(false)
    props.onUpdateLinkPreview()
  }

  function handleCopyTextFromImage() {
    props.onCopyTextFromImage()
  }

  function handleToggleFavorite() {
    props.onToggleFavorite()
  }

  function selectedItemsAreMarkedAsFavorite() {
    return props.selectedItemIndices.every(index => getHistoryItem(index).favorite)
  }

  function canShowCopyToClipboard() {
    return props.selectedItemIndices.length === 1
  }

  function canShowOpenInBrowser() {
    return props.selectedItemIndices.length === 1 &&
        getFirstSelectedHistoryItem().type === ClipType.Link
  }

  function canShowEditContent() {
    return props.selectedItemIndices.length === 1 && isTextItem(getFirstSelectedHistoryItem())
  }

  function canShowRenameItem() {
    return props.selectedItemIndices.length === 1
  }

  function canShowPreviewLink() {
    return canShowOpenInBrowser()
  }

  function canShowCopyTextFromImage() {
    if (props.selectedItemIndices.length === 1) {
      let item = getFirstSelectedHistoryItem()
      return item.type === ClipType.Image && item.content.length > 0
    }
    return false
  }

  function canShowNumberOfSelectedItems() {
    return props.selectedItemIndices.length > 1
  }

  function canShowPasteOptions() {
    return props.selectedItemIndices.length > 1
  }

  function canShowMergeItems() {
    if (props.selectedItemIndices.length > 1) {
      return getSelectedHistoryItems().every(item => isTextItem(item))
    }
    return false
  }

  function canSaveImageAsFile() {
    return props.selectedItemIndices.length === 1 && getFirstSelectedHistoryItem().type === ClipType.Image
  }

  function handlePasteOptionsMenuOpenChange(open: boolean) {
    setPasteOptionsMenuOpen(open)
  }

  function handleOpenDropdownChange(open: boolean) {
    setOpenDropdown(open)
    if (!open) {
      props.onHideDropdown(closeReason)
    }
  }

  function getMultipleItemsIndicator(): string {
    let indices = getSelectedHistoryItemIndices().length
    if (indices > 1) {
      return indices + " Items"
    }
    return ""
  }

  return (
      <div className="flex flex-col">
        <div className="flex m-2 h-10">
          <div className="">
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handlePaste}>
                  <ClipboardIcon className="h-5 w-5" strokeWidth={2}/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2">
                  Paste {getSelectedHistoryItemIndices().length > 1 ? getSelectedHistoryItemIndices().length + " Items" : ""} to {props.appName}
                </div>
                <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
              </TooltipContent>
            </Tooltip>
            {
                canShowPasteOptions() &&
                <DropdownMenu open={pasteOptionsMenuOpen} onOpenChange={handlePasteOptionsMenuOpenChange}>
                  <DropdownMenuTrigger asChild>
                    <Button variant="dropdown" size="dropdown" className={pasteOptionsMenuOpen ? "bg-accent" : ""}>
                      <ChevronDown className="h-4 w-4" strokeWidth={2.5}/>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent className="p-1.5 bg-actions-background" align="start" onKeyDown={handleKeyDown}>
                    <DropdownMenuItem onClick={handlePaste}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span>Paste {getMultipleItemsIndicator()} to {props.appName}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                      </CommandShortcut>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={handlePasteWithReturn}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span className="mr-2">Paste {getMultipleItemsIndicator()} to {props.appName} with Return</span>
                      <span className="w-16"></span>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={handlePasteWithTab}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span className="mr-2">Paste {getMultipleItemsIndicator()} to {props.appName} with Tab</span>
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
            }

            {
                canShowMergeItems() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="toolbar" size="toolbar" onClick={handleMerge}>
                      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
                           viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
                           strokeLinecap="round" strokeLinejoin="round"
                           className="lucide lucide-unfold-vertical h-5 w-5">
                        <path d="M12 22v-6"/>
                        <path d="M12 8V2"/>
                        <path d="M4 12H2"/>
                        <path d="M10 12H8"/>
                        <path d="M16 12h-2"/>
                        <path d="M22 12h-2"/>
                        <path d="m15 5-3 3-3-3"/>
                        <path d="m15 19-3-3-3 3"/>
                      </svg>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">Merge {props.selectedItemIndices.length} items</div>
                  </TooltipContent>
                </Tooltip>
            }

            {
                canShowCopyToClipboard() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="toolbar" size="toolbar" onClick={handleCopyToClipboard}>
                      <CopyIcon className="h-5 w-5" strokeWidth={2}/>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">Copy to Clipboard</div>
                    <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                  </TooltipContent>
                </Tooltip>
            }
            {
                canShowOpenInBrowser() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="toolbar" size="toolbar" onClick={handleOpenInBrowser}>
                      <GlobeIcon className="h-5 w-5" strokeWidth={2}/>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">Open in Browser</div>
                    <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                  </TooltipContent>
                </Tooltip>
            }
            {
                canShowCopyTextFromImage() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="toolbar" size="toolbar" onClick={handleCopyTextFromImage}>
                      <ScanTextIcon className="h-5 w-5" strokeWidth={2}/>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">Copy Text from Image</div>
                    <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                  </TooltipContent>
                </Tooltip>
            }
          </div>
          <div className="flex-auto text-sm pt-2.5 items-center justify-center text-center text-toolbar-button draggable">
            {
                canShowNumberOfSelectedItems() &&
                props.selectedItemIndices.length + " items"
            }
          </div>
          <div className="">
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleToggleFavorite}>
                  <StarIcon
                      className={selectedItemsAreMarkedAsFavorite() ? "h-5 w-5 text-toolbar-buttonSelected" : "h-5 w-5"}
                      strokeWidth={2}/>
                </Button>
              </TooltipTrigger>
              {
                selectedItemsAreMarkedAsFavorite() ?
                    <TooltipContent className="flex items-center">
                      <div className="select-none mr-2">Remove from favorites</div>
                      <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                    </TooltipContent> :
                    <TooltipContent className="flex items-center">
                      <div className="select-none mr-2">Add to favorites</div>
                      <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                    </TooltipContent>
              }
            </Tooltip>

            <DropdownMenu open={openDropdown} onOpenChange={handleOpenDropdownChange}>
              <DropdownMenuTrigger className="text-primary-foreground hover:text-accent-foreground" asChild>
                <Button variant="dropdown" size="toolbar" className={openDropdown ? "bg-accent text-accent-foreground" : ""}>
                  <EllipsisVerticalIcon className="h-5 w-5" strokeWidth={2}/>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent className="p-1.5 bg-actions-background" align="center"
                                   onKeyDown={handleKeyDown} onMouseDown={handleMouseDown}>
                {
                    canShowEditContent() &&
                    <DropdownMenuItem onClick={handleRequestEditItem}>
                      <Edit3Icon className="mr-2 h-4 w-4"/>
                      <span className="mr-12">Edit Content...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </DropdownMenuItem>
                }
                {
                    canShowRenameItem() &&
                    <DropdownMenuItem onClick={handleRenameItem}>
                      <PenIcon className="mr-2 h-4 w-4"/>
                      <span className="mr-12">Rename...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                      </CommandShortcut>
                    </DropdownMenuItem>
                }
                {
                    canShowEditContent() && <DropdownMenuSeparator/>
                }
                {
                    canShowPreviewLink() &&
                    <DropdownMenuItem onClick={handlePreviewLink}>
                      <EyeIcon className="mr-2 h-4 w-4"/>
                      <span className="mr-12">Preview</span>
                    </DropdownMenuItem>
                }
                {
                    canShowPreviewLink() && prefShouldShowPreviewForLinks() &&
                    <DropdownMenuItem onClick={handleUpdateLinkPreview}>
                      <RefreshCwIcon className="mr-2 h-4 w-4"/>
                      <span className="mr-12">Update</span>
                    </DropdownMenuItem>
                }
                {
                    canShowPreviewLink() && <DropdownMenuSeparator/>
                }
                {
                    canSaveImageAsFile() &&
                    <DropdownMenuItem onClick={handleSaveImageAsFile}>
                      <DownloadIcon className="mr-2 h-4 w-4"/>
                      <span className="mr-12">Save as File...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                      </CommandShortcut>
                    </DropdownMenuItem>
                }
                {
                    canSaveImageAsFile() && <DropdownMenuSeparator/>
                }
                <DropdownMenuItem onClick={handleDeleteItem}>
                  <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                  <span className="mr-12 text-actions-danger">
                    {"Delete " + getMultipleItemsIndicator()}
                  </span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleToggleInfo}>
                  {
                    props.displayInfo ? <HideInfoPaneIcon className="h-5 w-5"/> :
                        <ShowInfoPaneIcon className="h-5 w-5"/>
                  }
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div
                    className="select-none mr-1">{props.displayInfo ? "Hide details" : "Show details"}</div>
              </TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}>
                  <HidePreviewPaneIcon className="h-5 w-5"/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2">Hide preview panel</div>
                <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>
  )
}
