import '../app.css';
import React, {KeyboardEvent, MouseEvent, useEffect, useState} from 'react';
import {
  ArrowUpLeftIcon,
  CopyIcon,
  Edit3Icon,
  EyeIcon,
  GlobeIcon, PenIcon, PlusIcon, ScanTextIcon,
  StarIcon,
  StarOffIcon, TagsIcon,
  TrashIcon, TypeIcon, UploadIcon
} from "lucide-react";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut, prefGetOpenInDefaultAppShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut, prefGetQuickLookShortcut,
  prefGetRenameItemShortcut,
  prefGetShowInFinderShortcut,
  prefGetToggleFavoriteShortcut,
} from "@/pref";
import {CommandItem, CommandShortcut} from "@/components/ui/command";
import {Clip, ClipType, getImageText, updateClip} from "@/db";
import {
  AppInfo,
  fileExists, FinderIcon, getDefaultApp, getFileOrImagePath,
  getFilterQuery, getFirstSelectedHistoryItem,
  getHistoryItem, getSelectedHistoryItemIndices, isFilterActive,
  isTextItem,
  toBase64Icon
} from "@/data";
import TagIcon, {allTags, Tag} from "@/tags";
import {Checkbox} from "@/components/ui/checkbox";
import {CheckedState} from "@radix-ui/react-checkbox";
import {emitter} from "@/actions";
import { useTranslation } from 'react-i18next';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuPortal,
  ContextMenuSeparator,
  ContextMenuSub,
  ContextMenuSubContent,
  ContextMenuSubTrigger,
  ContextMenuTrigger
} from "@/components/ui/context-menu";

type HistoryItemContextMenuProps = {
  item: Clip
  index: number
  appName: string
  appIcon: string
  children: React.ReactNode
}

type TagCheckedState = {
  tag: Tag
  checked: boolean
}

const HistoryItemContextMenu = (props: HistoryItemContextMenuProps) => {
  let focusSearchOnClose = true
  
  const { t } = useTranslation()

  const [itemTags, setItemTags] = useState<TagCheckedState[]>([])
  const [defaultApp, setDefaultApp] = useState<AppInfo | undefined>(undefined)

  useEffect(() => {
    let tags: TagCheckedState[] = []
    allTags().forEach(tag => {
      const checked = !!props.item.tags?.includes(tag.id)
      tags.push({tag, checked})
    })
    setItemTags(tags)
  }, [props.item.tags])

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
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

  function isFile() {
    return props.item && props.item.type === ClipType.File
  }

  function isImage() {
    return props.item && props.item.type === ClipType.Image
  }

  function isFileExists() {
    if (isFile()) {
      return fileExists(props.item.filePath)
    }
    return false
  }

  function canShowInFinder() {
    return isFile()
  }

  function canOpenInDefaultApp() {
    return defaultApp !== undefined
  }

  function canShowCopyTextFromImage() {
    if (props.item) {
      if (props.item.type === ClipType.Image && props.item.content.length > 0) {
        return true
      }
      if (getImageText(props.item).length > 0) {
        return true
      }
    }
    return false
  }

  function canShowFormatText() {
    return isTextItem(props.item)
  }

  function canShowQuickLook() {
    return isFile() || isImage()
  }

  function handlePaste() {
    emitter.emit("PasteByIndex", props.index)
  }

  function handlePastePath() {
    emitter.emit("PastePathByIndex", props.index)
  }

  function handleCopyToClipboard() {
    emitter.emit("CopyToClipboardByIndex", props.index)
  }

  function handleCopyPathToClipboard() {
    emitter.emit("CopyPathToClipboardByIndex", props.index)
  }

  function handleCopyTextFromImage() {
    emitter.emit("CopyTextFromImageByIndex", props.index)
  }

  function handleToggleFavorite() {
    props.item.favorite = !props.item.favorite
    emitter.emit("EditItem", props.item)
  }

  function handleEditContent() {
    focusSearchOnClose = false
    emitter.emit("EditContentByIndex", props.index)
  }

  function handleRename() {
    focusSearchOnClose = false
    emitter.emit("RenameItemByIndex", props.index)
  }

  function handleFormatText() {
    focusSearchOnClose = false
    emitter.emit("ShowFormatTextCommandsByIndex", props.index)
  }

  function handleQuickLook() {
    focusSearchOnClose = false
    emitter.emit("QuickLookItemByIndex", props.index)
  }

  function handleDeleteItem() {
    emitter.emit("DeleteItemByIndex", props.index)
  }

  function handleOpenInBrowser() {
    emitter.emit("OpenInBrowserByIndex", props.index)
  }

  function handlePreviewLink() {
    emitter.emit("PreviewLinkItemByIndex", props.index)
  }

  function handleShowInHistory() {
    emitter.emit("ShowInHistory", props.item)
  }

  function handleAssignTag() {
    emitter.emit("AddTagToItemWithId", props.item.id)
  }

  async function handleTagChecked(tag: Tag, checked: CheckedState) {
    if (checked) {
      props.item.tags = [...props.item.tags || [], tag.id]
    } else {
      props.item.tags = props.item.tags?.filter((t) => t !== tag.id)
    }
    await updateClip(props.item.id!, props.item)
    let tags = itemTags.map(tagState => {
      if (tagState.tag.id === tag.id) {
        tagState.checked = !!checked
      }
      return tagState
    })
    setItemTags([...tags])
    emitter.emit("UpdateItemById", props.item.id)
  }

  function getItemLabel(): string {
    let item = getHistoryItem(props.index)
    if (item) {
      return ClipType[item.type]
    }
    return ""
  }

  function handleOpenChange(open: boolean) {
    setDefaultApp(undefined)
    if (open) {
      if (props.item.type === ClipType.File || props.item.type === ClipType.Image) {
        if (!props.item.fileFolder) {
          let filePath = getFileOrImagePath(props.item);
          if (filePath) {
            setDefaultApp(getDefaultApp(filePath))
          }
        }
      }
    } else {
      if (focusSearchOnClose) {
        emitter.emit("FocusSearchInput")
      }
    }
  }

  function handleShowInFinder() {
    emitter.emit("ShowInFinderByIndex", props.index)
  }

  function handleOpenInDefaultApp() {
    emitter.emit("OpenInAppByIndex", {
      app: defaultApp,
      index: props.index
    })
  }

  function handleOpenWith() {
    focusSearchOnClose = false
    emitter.emit("ShowOpenWithCommandsByIndex", props.index)
  }

  return (
      <ContextMenu onOpenChange={handleOpenChange}>
        <ContextMenuTrigger asChild>
          {props.children}
        </ContextMenuTrigger>
        <ContextMenuContent className="p-1.5 bg-actions-background"
                            onKeyDown={handleKeyDown} onMouseDown={handleMouseDown}>
          <ContextMenuItem onClick={handlePaste}>
            <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                 alt="Application icon"/>
            <span className="mr-12">{t('historyItemContextMenu.pasteItemToApp', {itemLabel: getItemLabel(), appName: props.appName})}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          {
              props.item.type === ClipType.File &&
              <ContextMenuItem onClick={handlePastePath}>
                <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                     alt="Application icon"/>
                <span className="mr-12">{t('historyItemContextMenu.pastePathToApp', {appName: props.appName})}</span>
              </ContextMenuItem>
          }
          <ContextMenuItem onClick={handleCopyToClipboard}>
            <CopyIcon className="mr-2 h-4 w-4"/>
            <span className="mr-12">{t('historyItemContextMenu.copyItemToClipboard', {itemLabel: getItemLabel()})}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          {
              props.item.type === ClipType.File &&
              <ContextMenuItem onClick={handleCopyPathToClipboard}>
                <CopyIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.copyPathToClipboard')}</span>
              </ContextMenuItem>
          }
          <ContextMenuSeparator/>
          {
              props.item.type === ClipType.Link &&
              <ContextMenuItem onClick={handleOpenInBrowser}>
                <GlobeIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.openInBrowser')}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              isTextItem(props.item) &&
              <ContextMenuItem onClick={handleEditContent}>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.editContent')}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              canShowCopyTextFromImage() &&
              <ContextMenuItem onClick={handleCopyTextFromImage}>
                <ScanTextIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.copyTextFromImage')}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          <ContextMenuItem onClick={handleToggleFavorite}>
            {
              props.item.favorite ? <StarOffIcon className="mr-2 h-4 w-4"/> :
                  <StarIcon className="mr-2 h-4 w-4"/>
            }
            <span>{props.item.favorite ? t('historyItemContextMenu.removeFromFavorites') : t('historyItemContextMenu.addToFavorites')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          <ContextMenuItem onClick={handleRename}>
            <PenIcon className="mr-2 h-4 w-4"/>
            <span className="mr-12">{t('historyItemContextMenu.renameItem')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          {
              canShowQuickLook() &&
              <ContextMenuItem onClick={handleQuickLook}>
                <EyeIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.quickLook')}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetQuickLookShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              canShowFormatText() &&
              <ContextMenuItem onSelect={handleFormatText}>
                <TypeIcon className="mr-2 h-5 w-5"/>
                <span>{t('historyItemContextMenu.formatText')}</span>
              </ContextMenuItem>
          }
          <ContextMenuSeparator/>
          <ContextMenuSub>
            <ContextMenuSubTrigger>
              <TagsIcon className="mr-2 h-4 w-4"/>
              <span>{t('historyItemContextMenu.tags')}</span>
            </ContextMenuSubTrigger>
            <ContextMenuPortal>
              <ContextMenuSubContent className="p-1.5 bg-actions-background">
                {
                  itemTags.map((tagState: TagCheckedState) => {
                    return (
                        <ContextMenuItem key={tagState.tag.id}>
                          <Checkbox className="mr-2 border-checkbox"
                                    checked={tagState.checked}
                                    onCheckedChange={(checked) => handleTagChecked(tagState.tag, checked)}
                                    onClick={(e) => {
                                      e.stopPropagation(); // Prevent closing the menu
                                    }}/>
                          <TagIcon className="mr-2 h-4 w-4" style={{color: tagState.tag.color}}/>
                          <span className="mr-12">{tagState.tag.name}</span>
                        </ContextMenuItem>
                    )
                  })
                }
                <ContextMenuSeparator/>
                <ContextMenuItem onClick={handleAssignTag}>
                  <PlusIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('historyItemContextMenu.newTag')}</span>
                </ContextMenuItem>
              </ContextMenuSubContent>
            </ContextMenuPortal>
          </ContextMenuSub>
          {
              props.item.type === ClipType.Link && <ContextMenuSeparator/>
          }
          {
              props.item.type === ClipType.Link &&
              <ContextMenuItem onClick={handlePreviewLink}>
                <EyeIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">{t('historyItemContextMenu.preview')}</span>
              </ContextMenuItem>
          }
          {
            (canShowInFinder() || canOpenInDefaultApp()) && <ContextMenuSeparator/>
          }
          {
              canShowInFinder() &&
              <ContextMenuItem onSelect={handleShowInFinder} disabled={!isFileExists()}>
                <img src={toBase64Icon(FinderIcon)} className="mr-2 h-5 w-5"
                     alt="App icon"/>
                <span className="mr-12">{t('historyItemContextMenu.showInFinder')}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetShowInFinderShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              canOpenInDefaultApp() &&
                <ContextMenuItem onSelect={handleOpenInDefaultApp}>
                  {
                    defaultApp ? <img src={toBase64Icon(defaultApp.icon)} className="mr-2 h-5 w-5"
                                      alt="App icon"/> : null
                  }
                  <span className="mr-12">{t('historyItemContextMenu.openInApp', {appName: defaultApp?.name})}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetOpenInDefaultAppShortcut()}/>
                  </CommandShortcut>
                </ContextMenuItem>
          }
          {
              canOpenInDefaultApp() &&
              <ContextMenuItem onSelect={handleOpenWith}>
                <UploadIcon className="mr-2 h-5 w-5"/>
                <span className="mr-12">{t('historyItemContextMenu.openWith')}</span>
              </ContextMenuItem>
          }
          <ContextMenuSeparator/>
          {
            canShowInHistory() &&
              <>
                <ContextMenuItem onClick={handleShowInHistory}>
                  <ArrowUpLeftIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('historyItemContextMenu.showInHistory')}</span>
                </ContextMenuItem>
                <ContextMenuSeparator/>
              </>
          }
          <ContextMenuItem onClick={handleDeleteItem}>
            <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
            <span className="text-actions-danger mr-12">{t('historyItemContextMenu.deleteItem')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>
  )
}

export default HistoryItemContextMenu;
