import '../app.css';
import React, {KeyboardEvent} from "react";
import {Button} from "@/components/ui/button";
import {
  ChevronDown,
  ClipboardIcon,
  CopyIcon, EyeIcon,
  GlobeIcon, ScanTextIcon,
  StarIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  PasteItemsSeparator,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetOpenInBrowserShortcut, prefGetPasteItemsSeparator,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut, prefSetPasteItemsSeparator
} from "@/pref";
import {Clip, ClipType} from "@/db";
import {HideInfoPaneIcon, HidePreviewPaneIcon, ShowInfoPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getFirstSelectedHistoryItem,
  getHistoryItem,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems, isTextItem
} from "@/data";

type PreviewToolBarProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  displayInfo: boolean
  onPaste: () => void
  onMerge: () => void
  onToggleInfo: () => void
  onHidePreview: () => void
  onEditHistoryItem: (item: Clip) => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onToggleFavorite: () => void
  onOpenInBrowser: () => void
  onPreviewLink: () => void
}

export default function PreviewToolBar(props: PreviewToolBarProps) {
  const [pasteOptionsMenuOpen, setPasteOptionsMenuOpen] = React.useState(false)
  const [pasteItemsSeparator, setPasteItemsSeparator] = React.useState(prefGetPasteItemsSeparator())

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

  function handleMerge() {
    props.onMerge()
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

  function handlePreviewLink() {
    props.onPreviewLink()
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

  function handlePasteItemsSeparatorChange(value: string) {
    setPasteItemsSeparator(value as PasteItemsSeparator)
    prefSetPasteItemsSeparator(value as PasteItemsSeparator)
  }

  function handlePasteOptionsMenuOpenChange(open: boolean) {
    setPasteOptionsMenuOpen(open)
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
                    <DropdownMenuLabel className="font-normal text-secondary-foreground">
                      When pasting multiple items,<br/>separate them with:
                    </DropdownMenuLabel>
                    <DropdownMenuSeparator/>
                    <DropdownMenuRadioGroup value={pasteItemsSeparator} onValueChange={handlePasteItemsSeparatorChange}>
                      <DropdownMenuRadioItem value={PasteItemsSeparator.RETURN}>
                        <span className="pr-1">Return</span><ShortcutLabel shortcut="Enter"/>
                      </DropdownMenuRadioItem>
                      <DropdownMenuRadioItem value={PasteItemsSeparator.TAB}>
                        <span className="pr-1">Tab</span><ShortcutLabel shortcut="Tab"/>
                      </DropdownMenuRadioItem>
                      <DropdownMenuRadioItem value={PasteItemsSeparator.NONE}>None</DropdownMenuRadioItem>
                    </DropdownMenuRadioGroup>
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
                canShowPreviewLink() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="toolbar" size="toolbar" onClick={handlePreviewLink}>
                      <EyeIcon className="h-5 w-5" strokeWidth={2}/>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2">Preview link</div>
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
