import '../app.css';
import React, {KeyboardEvent, useState} from 'react';
import {
  CopyIcon,
  Edit3Icon,
  EllipsisVerticalIcon,
  PinIcon,
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
} from "@/pref";
import {CommandShortcut} from "@/components/ui/command";
import {Clip} from "@/db";

type ClipDropdownMenuProps = {
  item: Clip
  onOpenChange: (open: boolean) => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
}

const ClipDropdownMenu = (props: ClipDropdownMenuProps) => {
  const [open, setOpen] = useState(false)

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  function handleOpenChange(open: boolean) {
    props.onOpenChange(open)
    setOpen(open)
  }

  function handleTogglePin() {
    props.item.pinned = !props.item.pinned
    props.onEditHistoryItem(props.item)
  }

  return (
      <div>
        <DropdownMenu open={open} onOpenChange={handleOpenChange}>
          <DropdownMenuTrigger className="ml-4 text-primary-foreground hover:text-accent-foreground" asChild>
            <EllipsisVerticalIcon className="h-5 w-6"/>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="p-1 bg-actions-background" align="start"
                               onKeyDown={handleKeyDown}>
            <DropdownMenuItem onClick={props.onCopyToClipboard}>
              <CopyIcon className="mr-2 h-4 w-4"/>
              <span className="mr-12">Copy to Clipboard</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={props.onEditContent}>
              <Edit3Icon className="mr-2 h-4 w-4"/>
              <span>Edit Content...</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleTogglePin}>
              <PinIcon className="mr-2 h-4 w-4"/>
              <span>{props.item.pinned ? "Unpin item" : "Pin item"}</span>
            </DropdownMenuItem>
            <DropdownMenuSeparator/>
            <DropdownMenuItem onClick={props.onDeleteItem}>
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

export default ClipDropdownMenu;
