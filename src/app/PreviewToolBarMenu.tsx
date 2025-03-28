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
import {ClipType} from "@/db";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getFirstSelectedHistoryItem,
  getSelectedHistoryItemIndices, isImageItem, isLinkItem,
  isTextItem,
  TextFormatOperation
} from "@/data";
import {CommandShortcut} from "@/components/ui/command";

export type HideDropdownReason =
    "cancel"
    | "togglePreview"
    | "editContent"
    | "renameItem"
    | "formatText"
    | "previewLink"
    | "updatePreview"
    | "saveImageAsFile"
    | "deleteItem"

type PreviewToolBarMenuProps = {
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

export default function PreviewToolBarMenu(props: PreviewToolBarMenuProps) {
  const [openDropdown, setOpenDropdown] = useState(false)

  let closeReason: HideDropdownReason = "cancel"

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
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

  function handleFormatText(operation: TextFormatOperation) {
    closeReason = "formatText"
    handleOpenDropdownChange(false)
    props.onFormatText(operation)
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

  function renderFormatOptions() {
    return (
        <>
          <DropdownMenuSeparator/>
          <DropdownMenuLabel>Format Text</DropdownMenuLabel>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToLowerCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">make lower case</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeLowerCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToUpperCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">MAKE UPPER CASE</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetMakeUpperCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.CapitalizeWords)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">Capitalize Words</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetCapitalizeShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.ToSentenceCase)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">Sentence case</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetSentenceCaseShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.RemoveEmptyLines)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">Remove empty lines</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetRemoveEmptyLinesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.StripAllWhitespaces)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">StripAllWhitespaces</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetStripAllWhitespacesShortcut()}/>
            </CommandShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleFormatText(TextFormatOperation.TrimSurroundingWhitespaces)}>
            <div className="mr-2 h-4 w-4"></div>
            <span className="mr-12">Trim Surrounding Whitespaces</span>
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
          {
              canFormatText() && renderFormatOptions()
          }
        </DropdownMenuContent>
      </DropdownMenu>
  )
}
