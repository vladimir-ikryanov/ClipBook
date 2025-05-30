import '../app.css';
import React, {KeyboardEvent, MouseEvent, useState} from "react";
import {Button} from "@/components/ui/button";
import {
  DownloadIcon,
  Edit3Icon,
  EllipsisVerticalIcon,
  EyeIcon,
  PenIcon,
  RefreshCwIcon,
  TrashIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  prefGetCapitalizeShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetMakeLowerCaseShortcut,
  prefGetMakeUpperCaseShortcut,
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
  getFirstSelectedHistoryItem,
  getSelectedHistoryItemIndices, isImageItem, isLinkItem,
  isTextItem,
  TextFormatOperation
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

type PreviewToolBarMenuProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  displayInfo: boolean
  onRequestEditItem: () => void
}

export default function PreviewToolBarMenu(props: PreviewToolBarMenuProps) {
  const {t} = useTranslation()
  
  const [openDropdown, setOpenDropdown] = useState(false)

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
    return props.selectedItemIndices.length === 1 && isTextItem(getFirstSelectedHistoryItem())
  }

  function canShowRenameItem() {
    return props.selectedItemIndices.length === 1
  }

  function canShowPreviewLink() {
    return props.selectedItemIndices.length === 1 && isLinkItem(getFirstSelectedHistoryItem())
  }

  function canSaveImageAsFile() {
    return props.selectedItemIndices.length === 1 && isImageItem(getFirstSelectedHistoryItem())
  }

  function canFormatText() {
    return props.selectedItemIndices.length === 1 && isTextItem(getFirstSelectedHistoryItem())
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

  function renderFormatOptions() {
    return (
        <>
          <DropdownMenuSeparator/>
          <DropdownMenuLabel>{t('preview.toolbarMenu.formatText')}</DropdownMenuLabel>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToLowerCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.makeLowerCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeLowerCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToUpperCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.makeUpperCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeUpperCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.CapitalizeWords)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.capitalizeWords')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetCapitalizeShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToSentenceCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.sentenceCase')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetSentenceCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.RemoveEmptyLines)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.removeEmptyLines')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetRemoveEmptyLinesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.StripAllWhitespaces)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.stripAllWhitespaces')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetStripAllWhitespacesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.TrimSurroundingWhitespaces)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">{t('preview.toolbarMenu.trimSurroundingWhitespaces')}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetTrimSurroundingWhitespacesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
        </>
    )
  }

  return (
      <DropdownMenu open={openDropdown} onOpenChange={handleOpenDropdownChange}>
        <DropdownMenuTrigger className="text-primary-foreground hover:text-accent-foreground"
                             asChild>
          <Button variant="dropdown" size="toolbar"
                  className={openDropdown ? "bg-accent text-accent-foreground" : ""}>
            <EllipsisVerticalIcon className="h-5 w-5" strokeWidth={2}/>
          </Button>
        </DropdownMenuTrigger>
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
              canShowEditContent() && <DropdownMenuSeparator/>
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
              canShowPreviewLink() && <DropdownMenuSeparator/>
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
              canSaveImageAsFile() && <DropdownMenuSeparator/>
          }
          <DropdownMenuItem onClick={handleDeleteItem}>
            <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
            <span className="mr-12 text-actions-danger">
              {t('preview.toolbarMenu.delete', { indicator: getMultipleItemsIndicator() })}
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
  )
}
