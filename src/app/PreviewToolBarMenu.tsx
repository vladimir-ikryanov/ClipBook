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
  TypeIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuPortal,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefShouldShowPreviewForLinks
} from "@/pref";
import {ClipType} from "@/db";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  getFirstSelectedHistoryItem,
  getSelectedHistoryItemIndices,
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
    return props.selectedItemIndices.length === 1 &&
        getFirstSelectedHistoryItem().type === ClipType.Link
  }

  function canSaveImageAsFile() {
    return props.selectedItemIndices.length === 1 && getFirstSelectedHistoryItem().type === ClipType.Image
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
          <DropdownMenuSub>
            <DropdownMenuSubTrigger className="py-2">
              <TypeIcon className="mr-2 h-4 w-4"/>
              <span className="mr-12">Format Text</span>
            </DropdownMenuSubTrigger>
            <DropdownMenuPortal>
              <DropdownMenuSubContent className="p-1.5 bg-actions-background">
                <DropdownMenuItem className="px-2.5 py-2" onClick={() => handleFormatText(TextFormatOperation.ToLowerCase)}>
                  make lower case
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2" onClick={() => handleFormatText(TextFormatOperation.ToUpperCase)}>
                  MAKE UPPER CASE
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2"
                    onClick={() => handleFormatText(TextFormatOperation.CapitalizeWords)}>
                  Capitalize Words
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2"
                    onClick={() => handleFormatText(TextFormatOperation.ToSentenceCase)}>
                  Sentence case
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2"
                    onClick={() => handleFormatText(TextFormatOperation.RemoveEmptyLines)}>
                  Remove empty lines
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2"
                    onClick={() => handleFormatText(TextFormatOperation.StripAllWhitespaces)}>
                  StripAllWhitespaces
                </DropdownMenuItem>
                <DropdownMenuItem className="px-2.5 py-2"
                    onClick={() => handleFormatText(TextFormatOperation.TrimSurroundingWhitespaces)}>
                  Trim Surrounding Whitespaces
                </DropdownMenuItem>
              </DropdownMenuSubContent>
            </DropdownMenuPortal>
          </DropdownMenuSub>
          <DropdownMenuSeparator/>
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

          {
              canFormatText() && renderFormatOptions()
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
  )
}
