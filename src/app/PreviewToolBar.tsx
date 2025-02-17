import '../app.css';
import React, {KeyboardEvent, useState} from "react";
import {Button} from "@/components/ui/button";
import {
  CheckIcon,
  ChevronDown,
  ClipboardIcon,
  CopyIcon,
  GlobeIcon, ScanTextIcon,
  StarIcon
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
} from "@/pref";
import {ClipType} from "@/db";
import {HideInfoPaneIcon, HidePreviewPaneIcon, ShowInfoPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getFirstSelectedHistoryItem,
  getHistoryItem,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems, isTextItem, TextFormatOperation, toBase64Icon
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";
import PreviewToolBarMenu, {HideDropdownReason} from "@/app/PreviewToolBarMenu";

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
  onFormatText: (operation: TextFormatOperation) => void
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
  const [pasteOptionsMenuOpen, setPasteOptionsMenuOpen] = useState(false)
  const [isCopying, setIsCopying] = useState(false)
  const [showCheckIcon, setShowCheckIcon] = useState(false)

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
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

    if (isCopying) {
      return
    }

    setIsCopying(true)

    // Step 1: Fade out the Copy icon
    setTimeout(() => {
      setShowCheckIcon(true); // Step 2: Wait 200ms, then show Check icon
    }, 150);

    // Step 3: Reset after 1 seconds
    setTimeout(() => {
      setShowCheckIcon(false);
      setIsCopying(false);
    }, 1000);
  }

  function handleToggleInfo() {
    props.onToggleInfo()
  }

  function handleOpenInBrowser() {
    props.onOpenInBrowser()
  }

  function handleUpdateLinkPreview() {
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

  function handlePasteOptionsMenuOpenChange(open: boolean) {
    setPasteOptionsMenuOpen(open)
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
                    <Button
                        variant="copy"
                        size="toolbar"
                        onClick={handleCopyToClipboard}
                        disabled={isCopying}
                        className="relative"
                    >
                      <div className="relative w-5 h-5">
                        <CopyIcon
                            className={`absolute inset-0 h-5 w-5 transition-opacity duration-150 ${
                                isCopying ? "opacity-0" : "opacity-100"
                            }`}
                            strokeWidth={2}
                        />
                        <CheckIcon
                            className={`absolute inset-0 h-5 w-5 !text-checked transition-opacity duration-150 ${
                                showCheckIcon ? "opacity-100" : "opacity-0"
                            }`}
                            strokeWidth={3}
                        />
                      </div>
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

            <PreviewToolBarMenu selectedItemIndices={props.selectedItemIndices}
                                appName={props.appName}
                                appIcon={props.appIcon}
                                displayInfo={props.displayInfo}
                                onPaste={props.onPaste}
                                onPasteWithReturn={props.onPasteWithReturn}
                                onPasteWithTab={props.onPasteWithTab}
                                onMerge={props.onMerge}
                                onToggleInfo={handleToggleInfo}
                                onHidePreview={props.onHidePreview}
                                onSaveImageAsFile={props.onSaveImageAsFile}
                                onRequestEditItem={props.onRequestEditItem}
                                onRenameItem={props.onRenameItem}
                                onFormatText={props.onFormatText}
                                onDeleteItem={props.onDeleteItem}
                                onCopyToClipboard={props.onCopyToClipboard}
                                onCopyTextFromImage={props.onCopyTextFromImage}
                                onOpenInBrowser={props.onOpenInBrowser}
                                onToggleFavorite={props.onToggleFavorite}
                                onPreviewLink={props.onPreviewLink}
                                onUpdateLinkPreview={handleUpdateLinkPreview}
                                onHideDropdown={props.onHideDropdown}/>

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
