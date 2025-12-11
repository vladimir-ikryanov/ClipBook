import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {useEffect, useState} from "react"
import {
  ArrowUpLeftIcon,
  ClipboardIcon,
  CommandIcon,
  CopyIcon,
  DownloadIcon,
  Edit3Icon,
  EyeIcon,
  GlobeIcon,
  PenIcon,
  ScanTextIcon,
  SettingsIcon,
  StarIcon,
  StarOffIcon,
  TrashIcon,
  TypeIcon,
  Undo2Icon,
  UnfoldVerticalIcon,
  UploadIcon,
  ZoomIn,
  ZoomOut
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
  prefGetCopyObjectToClipboardShortcut,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenInDefaultAppShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetPasteSelectedObjectToActiveAppShortcut,
  prefGetQuickLookShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefGetShowInFinderShortcut,
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
  getPreviewVisibleState,
  toBase64Icon,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems,
  isTextItem,
  AppInfo,
  getDefaultApp,
  getFileOrImagePath, 
  fileExists, 
  getFilterQuery, 
  isFilterActive, 
  FinderIcon,
  getActiveHistoryItemIndex,
  getHistoryItem
} from "@/data";
import {ClipType, getHTML, getImageText, getRTF} from "@/db";
import {HidePreviewPaneIcon, ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import {DialogTitle} from "@/components/ui/dialog";
import {emitter} from "@/actions";
import { useTranslation } from 'react-i18next';

declare const canZoomIn: () => boolean;
declare const canZoomOut: () => boolean;
declare const canResetZoom: () => boolean;

type CommandsProps = {
  appName: string
  appIcon: string
}

export default function Commands(props: CommandsProps) {
  const { t } = useTranslation()

  const [open, setOpen] = useState(false)
  const [defaultApp, setDefaultApp] = useState<AppInfo | undefined>(undefined)
  const [canZoomInState, setCanZoomInState] = useState(false)
  const [canZoomOutState, setCanZoomOutState] = useState(false)
  const [canResetZoomState, setCanResetZoomState] = useState(false)

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e)) {
        e.preventDefault()
        handleOpenChange(true)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  useEffect(() => {
    function handleAppWindowDidHide() {
      handleOpenChange(false)
    }

    emitter.on("NotifyAppWindowDidHide", handleAppWindowDidHide)
    return () => emitter.off("NotifyAppWindowDidHide", handleAppWindowDidHide);
  }, [])

  function handleKeyDown(e: React.KeyboardEvent) {
    if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e.nativeEvent)) {
      e.preventDefault()
      handleOpenChange(false, true)
    }
    e.stopPropagation()
  }

  function show() {
    handleOpenChange(true)
  }

  function handleOpenChange(open: boolean, focusSearch: boolean = false) {
    setDefaultApp(undefined)
    if (open) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item.type === ClipType.File || item.type === ClipType.Image) {
        if (!item.fileFolder) {
          let filePath = getFileOrImagePath(item);
          if (filePath) {
            setDefaultApp(getDefaultApp(filePath))
          }
        }
      }
      setCanZoomInState(canZoomIn())
      setCanZoomOutState(canZoomOut())
      setCanResetZoomState(canResetZoom())
    } else {
      if (focusSearch) {
        emitter.emit("FocusSearchInput")
      }
    }
    setOpen(open)
  }

  function handleEditContent() {
    handleOpenChange(false)
    emitter.emit("EditContent")
  }

  function handleRenameItem() {
    handleOpenChange(false)
    emitter.emit("RenameItem")
  }

  function handleFormatText() {
    handleOpenChange(false)
    emitter.emit("ShowFormatTextCommands")
  }

  function handleSplit() {
    handleOpenChange(false)
    emitter.emit("Split")
  }

  function handleCopyToClipboard() {
    handleOpenChange(false)
    emitter.emit("CopyToClipboard")
  }

  function handleCopyObjectToClipboard() {
    handleOpenChange(false)
    emitter.emit("CopyObjectToClipboard")
  }

  function handlePaste() {
    handleOpenChange(false)
    emitter.emit("Paste")
  }

  function handlePasteObject() {
    handleOpenChange(false)
    emitter.emit("PasteObject")
  }

  function handlePasteWithTab() {
    handleOpenChange(false)
    emitter.emit("PasteWithTab")
  }

  function handlePasteWithReturn() {
    handleOpenChange(false)
    emitter.emit("PasteWithReturn")
  }

  function handleMerge() {
    handleOpenChange(false)
    emitter.emit("Merge")
  }

  function handleToggleFavorite() {
    handleOpenChange(false)
    emitter.emit("ToggleFavorite")
  }

  function handleTogglePreview() {
    handleOpenChange(false)
    emitter.emit("TogglePreview")
  }

  function handleOpenSettings() {
    handleOpenChange(false)
    emitter.emit("OpenSettings")
  }

  function handleZoomIn() {
    handleOpenChange(false)
    emitter.emit("ZoomIn")
  }

  function handleZoomOut() {
    handleOpenChange(false)
    emitter.emit("ZoomOut")
  }

  function handleResetZoom() {
    handleOpenChange(false)
    emitter.emit("ResetZoom")
  }

  function handleDeleteItem() {
    handleOpenChange(false)
    emitter.emit("DeleteItem")
  }

  function handleDeleteItems() {
    handleOpenChange(false)
    emitter.emit("DeleteItems")
  }

  function handleDeleteAllItems() {
    handleOpenChange(false)
    emitter.emit("DeleteAllItems")
  }

  function handleOpenInBrowser() {
    handleOpenChange(false)
    emitter.emit("OpenInBrowser")
  }

  function handleShowInHistory() {
    handleOpenChange(false)
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index)
    emitter.emit("ShowInHistory", item)
  }

  function handleShowInFinder() {
    handleOpenChange(false)
    emitter.emit("ShowInFinder")
  }

  function handleOpenInDefaultApp() {
    handleOpenChange(false)
    emitter.emit("OpenInApp", defaultApp)
  }

  function handleOpenWith() {
    handleOpenChange(false)
    emitter.emit("ShowOpenWithCommands")
  }

  function handlePreviewLink() {
    handleOpenChange(false)
    emitter.emit("PreviewLinkItem")
  }

  function handleQuickLook() {
    handleOpenChange(false)
    emitter.emit("QuickLookItem")
  }

  function handleCopyTextFromImage() {
    handleOpenChange(false)
    emitter.emit("CopyTextFromImage")
  }

  function handleSaveImageAsFile() {
    handleOpenChange(false)
    emitter.emit("SaveImageAsFile")
  }

  function handlePasteWithTransformation() {
    handleOpenChange(false)
    emitter.emit("ShowPasteTransformationCommands")
  }

  function handlePastePath() {
    handleOpenChange(false)
    emitter.emit("PastePath")
  }

  function handleCopyPathToClipboard() {
    handleOpenChange(false)
    emitter.emit("CopyPathToClipboard")
  }

  function canShowCopyToClipboard() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowCopyObjectToClipboard() {
    return isObjectSelected()
  }

  function canShowMultiplePaste() {
    return getSelectedHistoryItemIndices().length > 1
  }

  function isFile() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && item.type === ClipType.File
    }
    return false
  }

  function isImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && item.type === ClipType.Image
    }
    return false
  }

  function canShowInFinder() {
    return isFile()
  }

  function canQuickLook() {
    return isFile() || isImage()
  }

  function canOpenInDefaultApp() {
    return defaultApp !== undefined
  }

  function canShowCopyPath() {
    return isFile()
  }

  function canShowPastePath() {
    return isFile()
  }

  function isFileExists() {
    if (isFile()) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item) {
        return fileExists(item.filePath)
      }
    }
    return false
  }

  function canPasteWithTransformation() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item) {
        return isTextItem(item)
      }
    }
    return false
  }

  function canPasteObject() {
    return isObjectSelected()
  }

  function isObjectSelected() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (item && item.type === ClipType.Text) {
        return getRTF(item).length > 0 || getHTML(item).length > 0
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
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item?.type === ClipType.Link
    }
    return false
  }

  function canShowInHistory() {
    if (getSelectedHistoryItemIndices().length > 1) {
      return false
    }
    let filterQuery = getFilterQuery()
    if (filterQuery.length > 0) {
      return true
    }
    return isFilterActive()
  }

  function canShowPreview() {
    return canShowOpenInBrowser()
  }

  function canShowRenameItem() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowFormatText() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return isTextItem(item)
    }
    return false
  }

  function canShowSplit() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      if (isTextItem(item)) {
        // Check if the item content has text with line breaks and has at least two lines.
        let text = item.content
        let lines = text.split(/\r?\n/).filter(line => line.trim() !== "")
        return lines.length > 1
      }
    }
    return false
  }

  function canShowCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
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
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index);
    return item?.type === ClipType.Image
  }

  function canShowEditContent() {
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index);
    let type = item?.type;
    return item && (type === ClipType.Text ||
      type === ClipType.Link ||
      type === ClipType.Email ||
      type === ClipType.Color)
  }

  function canAddToFavorites() {
    let items = getSelectedHistoryItems()
    if (items.length === 0) {
      items.push(getHistoryItem(getActiveHistoryItemIndex()))
    }
    return items.some(item => {
      return item && !item.favorite
    })
  }

  function canShowDeleteItem() {
    return getSelectedHistoryItemIndices().length === 0
  }

  function canShowDeleteItems() {
    return getSelectedHistoryItemIndices().length !== 0
  }

  function getMultipleItemsIndicator(): string {
    let items = getSelectedHistoryItems()
    if (items.length === 0) {
      items.push(getHistoryItem(getActiveHistoryItemIndex()))
    }
    let indices = items.length
    if (indices > 1) {
      return indices + t('commands.items')
    }
    return ""
  }

  function getItemLabel(): string {
    let items = getSelectedHistoryItems()
    if (items.length !== 0) {
      return ""
    }
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index);
    if (item) {
      return ClipType[item.type]
    }
    return ""
  }

  function activeAppIcon() {
    if (props.appIcon === "") {
      return <ClipboardIcon className="mr-2 h-5 w-5"/>
    }
    return <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                       alt="Application icon"/>
  }

  function getActiveAppName(): string {
    return props.appName === "" ? t('commands.activeApp') : props.appName
  }

  return (
      <>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="toolbar" size="toolbar" onClick={show}>
              <CommandIcon className="h-5 w-5"/>
            </Button>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div className="select-none mr-2 ml-1">{t('commands.showMoreActions')}</div>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </TooltipContent>
        </Tooltip>
        <div className="" onKeyDown={handleKeyDown}>
          <CommandDialog open={open} onOpenChange={(open) => handleOpenChange(open, true)}>
            <VisuallyHidden>
              <DialogTitle></DialogTitle>
            </VisuallyHidden>
            <CommandInput placeholder={t('commands.typeCommandOrSearch')} autoFocus={true}/>
            <div className="max-h-[70vh] overflow-y-auto mb-1.5 scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
              <CommandList>
                <CommandItem onSelect={handlePaste}>
                  {activeAppIcon()}
                  <span>{t('commands.pasteItemToApp', {itemLabel: getItemLabel(), itemsLabel: getMultipleItemsIndicator(), appName: getActiveAppName()})}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                {
                    canPasteObject() &&
                    <CommandItem onSelect={handlePasteObject}>
                      {activeAppIcon()}
                      <span>
                        {
                          getMultipleItemsIndicator().length > 0 ?
                              t('commands.pasteObjectsToApp', {itemsLabel: getMultipleItemsIndicator(), appName: getActiveAppName()}) :
                              t('commands.pasteObjectToApp', {appName: getActiveAppName()})
                        }
                      </span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetPasteSelectedObjectToActiveAppShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canPasteWithTransformation() &&
                    <CommandItem onSelect={handlePasteWithTransformation}>
                      {activeAppIcon()}
                      <span>
                        {t('commands.pasteItemToAppWithFormatting', {itemLabel: getItemLabel(), itemsLabel: getMultipleItemsIndicator(), appName: getActiveAppName()})}
                      </span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithReturn}>
                      {activeAppIcon()}
                      <span>{t('commands.pasteItemsToAppWithReturn', {itemsLabel: getMultipleItemsIndicator(), appName: getActiveAppName()})}</span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithTab}>
                      {activeAppIcon()}
                      <span>{t('commands.pasteItemsToAppWithTab', {itemsLabel: getMultipleItemsIndicator(), appName: getActiveAppName()})}</span>
                    </CommandItem>
                }
                {
                    canShowPastePath() &&
                    <CommandItem onSelect={handlePastePath}>
                      {activeAppIcon()}
                      <span>{t('commands.pastePathToApp', {appName: getActiveAppName()})}</span>
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
                      <span>{t('commands.mergeItems', {itemsLabel: getMultipleItemsIndicator()})}</span>
                    </CommandItem>
                }
                {
                    canShowCopyToClipboard() &&
                    <CommandItem onSelect={handleCopyToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.copyItemToClipboard', {itemLabel: getItemLabel()})}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyObjectToClipboard() &&
                    <CommandItem onSelect={handleCopyObjectToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.copyObjectToClipboard')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyObjectToClipboardShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyPath() &&
                    <CommandItem onSelect={handleCopyPathToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.copyPathToClipboard')}</span>
                    </CommandItem>
                }
                <CommandSeparator/>
                {
                    canShowInHistory() &&
                    <>
                      <CommandItem onSelect={handleShowInHistory}>
                        <ArrowUpLeftIcon className="mr-2 h-5 w-5"/>
                        <span>{t('commands.showInHistory')}</span>
                      </CommandItem>
                      <CommandSeparator/>
                    </>
                }
                {
                    canShowOpenInBrowser() &&
                    <CommandItem onSelect={handleOpenInBrowser}>
                      <GlobeIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.openInBrowser')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyTextFromImage() &&
                    <CommandItem onSelect={handleCopyTextFromImage}>
                      <ScanTextIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.copyTextFromImage')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowSaveImageAsFile() &&
                    <CommandItem onSelect={handleSaveImageAsFile}>
                      <DownloadIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.saveImageAsFile')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowEditContent() &&
                    <CommandItem onSelect={handleEditContent}>
                      <Edit3Icon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.editContent')}</span>
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
                      t('commands.addToFavorites', {itemsLabel: getMultipleItemsIndicator()}) :
                      t('commands.removeFromFavorites', {itemsLabel: getMultipleItemsIndicator()})}</span>
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
                      <span>{t('commands.previewLink')}</span>
                    </CommandItem>
                }
                {
                    canShowRenameItem() &&
                    <CommandItem onSelect={handleRenameItem}>
                      <PenIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.renameItem')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowFormatText() &&
                    <CommandItem onSelect={handleFormatText}>
                      <TypeIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.formatText')}</span>
                    </CommandItem>
                }
                {
                    canShowSplit() &&
                    <CommandItem onSelect={handleSplit}>
                      <UnfoldVerticalIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.split')}</span>
                    </CommandItem>
                }
                {
                    canQuickLook() &&
                    <CommandItem onSelect={handleQuickLook} disabled={isFile() && !isFileExists()}>
                      <EyeIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.quickLook')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetQuickLookShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandSeparator/>
                {
                    canShowInFinder() &&
                    <CommandItem onSelect={handleShowInFinder} disabled={!isFileExists()}>
                      <img src={toBase64Icon(FinderIcon)} className="mr-2 h-5 w-5"
                           alt="App icon"/>
                      <span>{t('commands.showInFinder')}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetShowInFinderShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canOpenInDefaultApp() &&
                    <CommandItem onSelect={handleOpenInDefaultApp}>
                      {
                        defaultApp ? <img src={toBase64Icon(defaultApp.icon)} className="mr-2 h-5 w-5"
                                          alt="App icon"/> : null
                      }
                      <span>{t('commands.openInApp', {appName: defaultApp?.name})}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetOpenInDefaultAppShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canOpenInDefaultApp() &&
                    <CommandItem onSelect={handleOpenWith}>
                      <UploadIcon className="mr-2 h-5 w-5"/>
                      <span>{t('commands.openWith')}</span>
                    </CommandItem>
                }
                {
                  (canShowInFinder() || canOpenInDefaultApp()) && <CommandSeparator/>
                }
                <CommandItem onSelect={handleTogglePreview}>
                  {
                    getPreviewVisibleState() ?
                        <HidePreviewPaneIcon className="mr-2 h-5 w-5"/> :
                        <ShowPreviewPaneIcon className="mr-2 h-5 w-5"/>
                  }
                  <span>{getPreviewVisibleState() ? t('commands.hidePreview') : t('commands.showPreview')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomIn} disabled={!canZoomInState}>
                  <ZoomIn className="mr-2 h-5 w-5"/>
                  <span>{t('commands.zoomIn')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIInShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomOut} disabled={!canZoomOutState}>
                  <ZoomOut className="mr-2 h-5 w-5"/>
                  <span>{t('commands.zoomOut')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIOutShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleResetZoom} disabled={!canResetZoomState}>
                  <Undo2Icon className="mr-2 h-5 w-5"/>
                  <span>{t('commands.resetZoom')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIResetShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                <CommandItem onSelect={handleOpenSettings}>
                  <SettingsIcon className="mr-2 h-5 w-5"/>
                  <span>{t('commands.settings')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetOpenSettingsShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                {
                    canShowDeleteItem() &&
                    <CommandItem onSelect={handleDeleteItem}>
                      <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                      <span className="text-actions-danger">{t('commands.deleteItem')}</span>
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
                      {t('commands.deleteItems', {itemsLabel: getMultipleItemsIndicator()})}
                    </span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandItem onSelect={handleDeleteAllItems}>
                  <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                  <span className="text-actions-danger">{t('commands.deleteAllItems')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetClearHistoryShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandEmpty>{t('commands.noResultsFound')}</CommandEmpty>
              </CommandList>
            </div>
          </CommandDialog>
        </div>
      </>
  )
}
