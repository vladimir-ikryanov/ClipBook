import '../app.css';
import {KeyboardEvent, MouseEvent, useEffect, useState} from "react";
import {Button} from "@/components/ui/button";
import {
  DownloadIcon,
  Edit3Icon,
  EllipsisVerticalIcon,
  EyeIcon,
  PenIcon, 
  PlusIcon,
  RefreshCwIcon, 
  TagsIcon,
  TrashIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel, 
  DropdownMenuPortal,
  DropdownMenuSeparator, 
  DropdownMenuSub, 
  DropdownMenuSubContent, 
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  prefGetCapitalizeShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetMakeLowerCaseShortcut,
  prefGetMakeUpperCaseShortcut,
  prefGetQuickLookShortcut,
  prefGetRemoveEmptyLinesShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefGetSentenceCaseShortcut,
  prefGetStripAllWhitespacesShortcut,
  prefGetTrimSurroundingWhitespacesShortcut,
  prefShouldShowPreviewForLinks
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getActiveHistoryItemIndex,
  getHistoryItem,
  getSelectedHistoryItemIndices, 
  isFileItem, 
  isImageItem, 
  isLinkItem,
  isTextItem,
  TagCheckedState,
  TextFormatOperation
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";
import TagIcon, {allTags, Tag} from "@/tags";
import {Checkbox} from "@/components/ui/checkbox";
import {CheckedState} from "@radix-ui/react-checkbox";
import {updateClip} from "@/db";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";

type PreviewToolBarMenuProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  displayInfo: boolean
  onRequestEditItem: () => void
}

export default function PreviewToolBarMenu(props: PreviewToolBarMenuProps) {
  const {t} = useTranslation()

  const [itemTags, setItemTags] = useState<TagCheckedState[]>([])
  const [openDropdown, setOpenDropdown] = useState(false)

  function selectedItem() {
    let index = getActiveHistoryItemIndex()
    return getHistoryItem(index)
  }

  useEffect(() => {
    let tags: TagCheckedState[] = []
    allTags().forEach(tag => {
      let item = selectedItem()
      if (item) {
        const checked = !!item.tags?.includes(tag.id)
        tags.push({tag, checked})
      }
    })
    setItemTags(tags)
  }, [])

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
  }

  function handleRequestEditItem() {
    handleOpenDropdownChange(false)
    setTimeout(() => {
      props.onRequestEditItem()
    }, 250)
  }

  function handleRenameItem() {
    handleOpenDropdownChange(false)
    emitter.emit("RenameItem")
  }

  function handleSaveImageAsFile() {
    handleOpenDropdownChange(false)
    emitter.emit("SaveImageAsFile")
  }

  function handleQuickLook() {
    handleOpenDropdownChange(false)
    emitter.emit("QuickLookItem")
  }

  function handleDeleteItem() {
    handleOpenDropdownChange(false)
    emitter.emit("DeleteItem")
  }

  function handlePreviewLink() {
    handleOpenDropdownChange(false)
    emitter.emit("PreviewLinkItem")
  }

  function handleUpdateLinkPreview() {
    handleOpenDropdownChange(false)
    emitter.emit("UpdateLinkPreview")
  }

  function handleFormatText(operation: TextFormatOperation) {
    handleOpenDropdownChange(false)
    emitter.emit("FormatText", {
      operation: operation,
      index: -1
    })
  }

  function canShowEditContent() {
    return isText()
  }

  function canShowRenameItem() {
    return props.selectedItemIndices.length === 1
  }

  function canShowPreviewLink() {
    return isLink()
  }

  function canSaveImageAsFile() {
    return isImage()
  }

  function canFormatText() {
    return isText()
  }

  function canShowTags() {
    return props.selectedItemIndices.length === 0
  }

  function canShowQuickLook() {
    return isFile() || isImage()
  }

  function isText() {
    if (getSelectedHistoryItemIndices().length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && isTextItem(item)
    }
    return false
  }

  function isLink() {
    if (getSelectedHistoryItemIndices().length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && isLinkItem(item)
    }
    return false
  }

  function isFile() {
    if (getSelectedHistoryItemIndices().length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && isFileItem(item)
    }
    return false
  }

  function isImage() {
    if (getSelectedHistoryItemIndices().length === 0) {
      let index = getActiveHistoryItemIndex()
      let item = getHistoryItem(index)
      return item && isImageItem(item)
    }
    return false
  }

  function handleOpenDropdownChange(open: boolean) {
    setOpenDropdown(open)
  }

  function getMultipleItemsIndicator(): string {
    let indices = getSelectedHistoryItemIndices().length
    if (indices > 1) {
      return indices + " Items"
    }
    return ""
  }

  function handleAssignTag() {
    let item = selectedItem()
    if (item) {
      emitter.emit("AddTagToItemWithId", item.id)
    }
  }

  async function handleTagChecked(tag: Tag, checked: CheckedState) {
    let item = selectedItem()
    if (!item) {
      return
    }
    if (checked) {
      item.tags = [...item.tags || [], tag.id]
    } else {
      item.tags = item.tags?.filter((t) => t !== tag.id)
    }
    await updateClip(item.id!, item)
    let tags = itemTags.map(tagState => {
      if (tagState.tag.id === tag.id) {
        tagState.checked = !!checked
      }
      return tagState
    })
    setItemTags([...tags])
    emitter.emit("UpdateItemById", item.id)
  }

  function renderFormatOptions() {
    return (
        <>
          <DropdownMenuSeparator/>
          <DropdownMenuLabel>{t('preview.toolbarMenu.formatText')}</DropdownMenuLabel>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToLowerCase)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.makeLowerCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeLowerCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToUpperCase)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.makeUpperCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeUpperCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.CapitalizeWords)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.capitalizeWords')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetCapitalizeShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToSentenceCase)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.sentenceCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetSentenceCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.RemoveEmptyLines)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.removeEmptyLines')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetRemoveEmptyLinesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem
              onClick={() => handleFormatText(TextFormatOperation.StripAllWhitespaces)}>
            <span className="ml-0.5 mr-12">{t('preview.toolbarMenu.stripAllWhitespaces')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetStripAllWhitespacesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem
              onClick={() => handleFormatText(TextFormatOperation.TrimSurroundingWhitespaces)}>
            <span
                className="ml-0.5 mr-12">{t('preview.toolbarMenu.trimSurroundingWhitespaces')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetTrimSurroundingWhitespacesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
        </>
    )
  }

  return (
      <Tooltip>
        <DropdownMenu open={openDropdown} onOpenChange={handleOpenDropdownChange}>
          <TooltipTrigger asChild>
            <DropdownMenuTrigger className="text-primary-foreground hover:text-accent-foreground"
                                 asChild>
              <Button variant="dropdown" size="toolbar"
                      className={openDropdown ? "bg-accent text-accent-foreground" : ""}>
                <EllipsisVerticalIcon className="h-5 w-5" strokeWidth={2}/>
              </Button>
            </DropdownMenuTrigger>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div className="select-none mx-1">
              {t('preview.toolbar.more')}
            </div>
          </TooltipContent>
          <DropdownMenuContent className="p-1.5 bg-actions-background" align="center"
                               onKeyDown={handleKeyDown} onMouseDown={handleMouseDown}>
            {
                canShowEditContent() &&
                <DropdownMenuItem onClick={handleRequestEditItem}>
                  <Edit3Icon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('preview.toolbarMenu.editContent')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                canShowRenameItem() &&
                <DropdownMenuItem onClick={handleRenameItem}>
                  <PenIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('preview.toolbarMenu.rename')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                canShowQuickLook() &&
                <DropdownMenuItem onClick={handleQuickLook}>
                  <EyeIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('commands.quickLook')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetQuickLookShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                canShowPreviewLink() && <DropdownMenuSeparator/>
            }
            {
                canShowPreviewLink() &&
                <DropdownMenuItem onClick={handlePreviewLink}>
                  <EyeIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('preview.toolbarMenu.preview')}</span>
                </DropdownMenuItem>
            }
            {
                canShowPreviewLink() && prefShouldShowPreviewForLinks() &&
                <DropdownMenuItem onClick={handleUpdateLinkPreview}>
                  <RefreshCwIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('preview.toolbarMenu.update')}</span>
                </DropdownMenuItem>
            }
            {
                canSaveImageAsFile() && <DropdownMenuSeparator/>
            }
            {
                canSaveImageAsFile() &&
                <DropdownMenuItem onClick={handleSaveImageAsFile}>
                  <DownloadIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">{t('preview.toolbarMenu.saveAsFile')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                canShowTags() && <DropdownMenuSeparator/>
            }
            {
                canShowTags() &&
                <DropdownMenuSub>
                  <DropdownMenuSubTrigger>
                    <TagsIcon className="mr-2 h-4 w-4"/>
                    <span>{t('historyItemContextMenu.tags')}</span>
                  </DropdownMenuSubTrigger>
                  <DropdownMenuPortal>
                    <DropdownMenuSubContent className="p-1.5 bg-actions-background">
                      {
                        itemTags.map((tagState: TagCheckedState) => {
                          return (
                              <DropdownMenuItem key={tagState.tag.id}>
                                <Checkbox className="mr-2 border-checkbox"
                                          checked={tagState.checked}
                                          onCheckedChange={(checked) => handleTagChecked(tagState.tag, checked)}
                                          onClick={(e) => {
                                            e.stopPropagation(); // Prevent closing the menu
                                          }}/>
                                <TagIcon className="mr-2 h-4 w-4"
                                         style={{color: tagState.tag.color}}/>
                                <span className="mr-12">{tagState.tag.name}</span>
                              </DropdownMenuItem>
                          )
                        })
                      }
                      <DropdownMenuSeparator/>
                      <DropdownMenuItem onClick={handleAssignTag}>
                        <PlusIcon className="mr-2 h-4 w-4"/>
                        <span className="mr-12">{t('historyItemContextMenu.newTag')}</span>
                      </DropdownMenuItem>
                    </DropdownMenuSubContent>
                  </DropdownMenuPortal>
                </DropdownMenuSub>
            }
            {
                canShowTags() && <DropdownMenuSeparator/>
            }
            <DropdownMenuItem onClick={handleDeleteItem}>
              <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
              <span className="mr-12 text-actions-danger">
              {t('preview.toolbarMenu.delete', {indicator: getMultipleItemsIndicator()})}
            </span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            {
                canFormatText() && renderFormatOptions()
            }
          </DropdownMenuContent>
        </DropdownMenu>
      </Tooltip>
  )
}
