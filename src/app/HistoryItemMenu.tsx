import '../app.css';
import React, {KeyboardEvent, useState} from 'react';
import {
  CopyIcon,
  Edit3Icon,
  EllipsisVerticalIcon, GlobeIcon, StarIcon,
  StarOffIcon,
  TrashIcon
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem, DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetToggleFavoriteShortcut,
} from "@/pref";
import {CommandShortcut} from "@/components/ui/command";
import {Clip, ClipType} from "@/db";
import {toBase64Icon} from "@/data";

export type HideClipDropdownMenuReason =
    "cancel"
    | "paste"
    | "pin"
    | "editContent"
    | "copyToClipboard"
    | "deleteItem"

type HistoryItemMenuProps = {
  item: Clip
  appName: string
  appIcon: string
  onOpenChange: (open: boolean) => void
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onPaste: () => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
}

const HistoryItemMenu = (props: HistoryItemMenuProps) => {
  const [open, setOpen] = useState(false)

  let closeReason: HideClipDropdownMenuReason = "cancel"

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  function handleOpenChange(open: boolean) {
    props.onOpenChange(open)
    setOpen(open)
    if (!open) {
      props.onHideClipDropdownMenu(closeReason)
    }
  }

  function handlePaste() {
    closeReason = "paste"
    handleOpenChange(false)
    props.onPaste()
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard()
  }

  function handlePin() {
    closeReason = "pin"
    handleOpenChange(false)
    props.item.favorite = !props.item.favorite
    props.onEditHistoryItem(props.item)
  }

  function handleEditContent() {
    closeReason = "editContent"
    handleOpenChange(false)
    props.onEditContent()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem()
  }

  return (
      <div>
        <DropdownMenu open={open} onOpenChange={handleOpenChange}>
          <DropdownMenuTrigger className="ml-4 text-primary-foreground hover:text-accent-foreground" asChild>
            <EllipsisVerticalIcon className="h-5 w-5"/>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="p-1 bg-actions-background" align="start"
                               onKeyDown={handleKeyDown}>
            <DropdownMenuItem onClick={handlePaste}>
              <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                   alt="Application icon"/>
              <span>Paste to {props.appName}</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleCopyToClipboard}>
              <CopyIcon className="mr-2 h-4 w-4"/>
              <span className="mr-12">Copy to Clipboard</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuSeparator/>
            {
              props.item.type === ClipType.Link &&
              <DropdownMenuItem onClick={props.onOpenInBrowser}>
                <GlobeIcon className="mr-2 h-4 w-4"/>
                <span>Open in Browser</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                </CommandShortcut>
              </DropdownMenuItem>
            }
            <DropdownMenuItem onClick={handleEditContent}>
              <Edit3Icon className="mr-2 h-4 w-4"/>
              <span>Edit Content...</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handlePin}>
              {
                props.item.favorite ? <StarOffIcon className="mr-2 h-4 w-4"/> : <StarIcon className="mr-2 h-4 w-4"/>
              }
              <span>{props.item.favorite ? "Remove from Favorites" : "Add to Favorites"}</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuSeparator/>
            <DropdownMenuItem onClick={handleDeleteItem}>
              <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
              <span className="text-actions-danger">Delete</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
  )
}

export default HistoryItemMenu;
