import '../app.css';
import React, {KeyboardEvent, useEffect, useState} from "react";
import {Button} from "@/components/ui/button";
import {
  CheckIcon,
  ChevronDown,
  ClipboardIcon,
  CopyIcon,
  GlobeIcon,
  ScanTextIcon,
  StarIcon,
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
import {Clip, ClipType, getImageText} from "@/db";
import {HideInfoPaneIcon, HidePreviewPaneIcon, ShowInfoPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getActiveHistoryItemIndex,
  getHistoryItem,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems, getSelectedItemTextTypes, isTextItem, toBase64Icon
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";
import PreviewToolBarMenu from "@/app/PreviewToolBarMenu";
import TextTypeToggle from "@/app/TextTypeToggle";
import {emitter} from "@/actions";
import { useTranslation } from 'react-i18next';

type PreviewToolBarProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  displayInfo: boolean
  onRequestEditItem: () => void
}

export default function PreviewToolBar(props: PreviewToolBarProps) {
  const { t } = useTranslation()

  const [selectedItem, setSelectedItem] = useState<Clip>()
  const [pasteOptionsMenuOpen, setPasteOptionsMenuOpen] = useState(false)
  const [isCopying, setIsCopying] = useState(false)
  const [isCopyingTextFromImage, setIsCopyingTextFromImage] = useState(false)
  const [showCheckIcon, setShowCheckIcon] = useState(false)
  const [showCheckIconTextFromImage, setShowCheckIconTextFromImage] = useState(false)

  useEffect(() => {
    if (props.selectedItemIndices.length <= 1) {
      let index = getActiveHistoryItemIndex()
      setSelectedItem(getHistoryItem(index))
    } else {
      setSelectedItem(undefined)
    }
  }, [props.selectedItemIndices])

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  function handleHidePreview() {
    emitter.emit("TogglePreview")
  }

  function handlePaste() {
    emitter.emit("Paste")
  }

  function handlePasteWithReturn() {
    emitter.emit("PasteWithReturn")
  }

  function handlePasteWithTab() {
    emitter.emit("PasteWithTab")
  }

  function handleMerge() {
    emitter.emit("Merge")
  }

  function handleCopyToClipboard() {
    emitter.emit("CopyToClipboard")

    if (isCopying) {
      return
    }

    setIsCopying(true)

    setTimeout(() => {
      setShowCheckIcon(true);
    }, 150);

    setTimeout(() => {
      setShowCheckIcon(false);
      setIsCopying(false);
    }, 1000);
  }

  function handleToggleDetails() {
    emitter.emit("ToggleDetails")
  }

  function handleOpenInBrowser() {
    emitter.emit("OpenInBrowser")
  }

  function handleCopyTextFromImage() {
    emitter.emit("CopyTextFromImage")

    if (isCopyingTextFromImage) {
      return
    }

    setIsCopyingTextFromImage(true)

    setTimeout(() => {
      setShowCheckIconTextFromImage(true)
    }, 150)

    setTimeout(() => {
      setIsCopyingTextFromImage(false)
      setShowCheckIconTextFromImage(false)
    }, 1000)
  }

  function handleToggleFavorite() {
    emitter.emit("ToggleFavorite")
  }

  function selectedItemsAreMarkedAsFavorite() {
    if (props.selectedItemIndices.length > 1) {
      return props.selectedItemIndices.every(index => {
        let item = getHistoryItem(index)
        return item && item.favorite
      })
    }
    return selectedItem?.favorite ?? false
    
  }

  function canShowCopyToClipboard() {
    return props.selectedItemIndices.length === 0
  }

  function canShowOpenInBrowser() {
    if (getSelectedHistoryItems().length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item) {
        return item.type === ClipType.Link
      }
    }
    return false
  }

  function canShowCopyTextFromImage() {
    if (props.selectedItemIndices.length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item) {
        if (getImageText(item).length > 0) {
          return true
        }
        return item.type === ClipType.Image && item.content.length > 0
      }
    }
    return false
  }

  function canShowNumberOfSelectedItems() {
    return props.selectedItemIndices.length !== 0
  }

  function canShowPasteOptions() {
    return props.selectedItemIndices.length !== 0
  }

  function canShowMergeItems() {
    if (props.selectedItemIndices.length !== 0) {
      return getSelectedHistoryItems().every(item => {
        return item && (isTextItem(item) || item.type === ClipType.File)
      })
    }
    return false
  }

  function handlePasteOptionsMenuOpenChange(open: boolean) {
    setPasteOptionsMenuOpen(open)
  }

  function getMultipleItemsIndicator(): string {
    let numberOfItems = getSelectedHistoryItemIndices().length
    if (numberOfItems > 1) {
      return t('preview.toolbar.items', { count: numberOfItems })
    }
    if (numberOfItems === 1) {
      return t('preview.toolbar.item', { count: numberOfItems })
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
                <div className="select-none mr-2 ml-1">
                  {t('preview.toolbar.pasteTo', { indicator: getMultipleItemsIndicator(), appName: props.appName })}
                </div>
                <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
              </TooltipContent>
            </Tooltip>
            {
                canShowPasteOptions() &&
                <DropdownMenu open={pasteOptionsMenuOpen}
                              onOpenChange={handlePasteOptionsMenuOpenChange}>
                  <DropdownMenuTrigger asChild>
                    <Button variant="dropdown" size="dropdown"
                            className={pasteOptionsMenuOpen ? "bg-accent" : ""}>
                      <ChevronDown className="h-4 w-4" strokeWidth={2.5}/>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent className="p-1.5 bg-actions-background" align="start"
                                       onKeyDown={handleKeyDown}>
                    <DropdownMenuItem onClick={handlePaste}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span>{t('preview.toolbar.pasteTo', { indicator: getMultipleItemsIndicator(), appName: props.appName })}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                      </CommandShortcut>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={handlePasteWithReturn}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span
                          className="mr-2">{t('preview.toolbar.pasteToWithReturn', { indicator: getMultipleItemsIndicator(), appName: props.appName })}</span>
                      <span className="w-16"></span>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={handlePasteWithTab}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                           alt="Application icon"/>
                      <span
                          className="mr-2">{t('preview.toolbar.pasteToWithTab', { indicator: getMultipleItemsIndicator(), appName: props.appName })}</span>
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
                    <div className="select-none mr-1 ml-1">
                      {t('preview.toolbar.mergeItems', { count: props.selectedItemIndices.length })}
                    </div>
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
                    <div className="select-none mr-2 ml-1">{t('preview.toolbar.copyToClipboard')}</div>
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
                    <div className="select-none mr-2 ml-1">{t('preview.toolbar.openInBrowser')}</div>
                    <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                  </TooltipContent>
                </Tooltip>
            }
            {
                canShowCopyTextFromImage() &&
                <Tooltip>
                  <TooltipTrigger asChild>
                  <Button
                        variant="copy"
                        size="toolbar"
                        onClick={handleCopyTextFromImage}
                        disabled={isCopyingTextFromImage}
                        className="relative"
                    >
                      <div className="relative w-5 h-5">
                        <ScanTextIcon
                            className={`absolute inset-0 h-5 w-5 transition-opacity duration-150 ${
                                isCopyingTextFromImage ? "opacity-0" : "opacity-100"
                            }`}
                            strokeWidth={2}
                        />
                        <CheckIcon
                            className={`absolute inset-0 h-5 w-5 !text-checked transition-opacity duration-150 ${
                                showCheckIconTextFromImage ? "opacity-100" : "opacity-0"
                            }`}
                            strokeWidth={3}
                        />
                      </div>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent className="flex items-center">
                    <div className="select-none mr-2 ml-1">{t('preview.toolbar.copyTextFromImage')}</div>
                    <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                  </TooltipContent>
                </Tooltip>
            }
          </div>
          <div className="flex-grow draggable"></div>
          {
            !canShowNumberOfSelectedItems() &&
              <TextTypeToggle item={selectedItem} types={getSelectedItemTextTypes(selectedItem)}/>
          }
          <div className="draggable">
            {
                canShowNumberOfSelectedItems() &&
                <div
                    className="text-sm pt-2.5 items-center justify-center text-center text-toolbar-button">
                  {getMultipleItemsIndicator()}
                </div>
            }
          </div>
          <div className="flex-grow draggable"></div>
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
                      <div className="select-none mr-2 ml-1">{t('preview.toolbar.removeFromFavorites')}</div>
                      <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                    </TooltipContent> :
                    <TooltipContent className="flex items-center">
                      <div className="select-none mr-2 ml-1">{t('preview.toolbar.addToFavorites')}</div>
                      <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                    </TooltipContent>
              }
            </Tooltip>

            <PreviewToolBarMenu selectedItemIndices={props.selectedItemIndices}
                                appName={props.appName}
                                appIcon={props.appIcon}
                                displayInfo={props.displayInfo}
                                onRequestEditItem={props.onRequestEditItem}
            />
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleToggleDetails}>
                  {
                    props.displayInfo ? <HideInfoPaneIcon className="h-5 w-5"/> :
                        <ShowInfoPaneIcon className="h-5 w-5"/>
                  }
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div
                    className="select-none mr-1 ml-1">{props.displayInfo ? t('preview.toolbar.hideDetails') : t('preview.toolbar.showDetails')}</div>
              </TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleHidePreview}>
                  <HidePreviewPaneIcon className="h-5 w-5"/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2 ml-1">{t('preview.toolbar.hidePreviewPanel')}</div>
                <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>
  )
}
