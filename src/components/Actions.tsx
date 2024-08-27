import '../App.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {
  CopyIcon,
  Edit3Icon,
  GlobeIcon,
  PanelRightClose,
  SearchIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList, CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command"
import {useEffect} from "react";
import {
  prefGetClearHistoryShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetSearchHistoryShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import ShortcutLabel from "@/components/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {Popover, PopoverContent, PopoverTrigger} from "@/components/ui/popover";
import {getActiveHistoryItem, getPreviewVisibleState, isUrl} from "@/data";

export type HideActionsReason =
    "cancel"
    | "togglePreview"
    | "searchHistory"
    | "editContent"
    | "copyToClipboard"
    | "openInBrowser"
    | "deleteItem"
    | "deleteAllItems"

type ActionsProps = {
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onSearchHistory: () => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
  onDeleteAllItems: () => void
}

export default function Actions(props: ActionsProps) {
  const [open, setOpen] = React.useState(false)

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e)) {
        e.preventDefault()
        setOpen(true)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function handleKeyDown(e: React.KeyboardEvent) {
    e.stopPropagation()
  }

  let closeReason: HideActionsReason = "cancel"

  function handleOpenChange(open: boolean) {
    setOpen(open)
    if (!open) {
      props.onHideActions(closeReason)
    }
  }

  function handleEditContent() {
    closeReason = "editContent"
    handleOpenChange(false)
    props.onEditContent()
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard()
  }

  function handleSearchHistory() {
    closeReason = "searchHistory"
    handleOpenChange(false)
    props.onSearchHistory()
  }

  function handleTogglePreview() {
    closeReason = "togglePreview"
    handleOpenChange(false)
    props.onTogglePreview()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem()
  }

  function handleDeleteAllItems() {
    closeReason = "deleteAllItems"
    handleOpenChange(false)
    props.onDeleteAllItems()
  }

  function handleOpenInBrowser() {
    closeReason = "openInBrowser"
    handleOpenChange(false)
    props.onOpenInBrowser()
  }

  function isActiveHistoryItemIsUrl() {
    return isUrl(getActiveHistoryItem()?.content)
  }

  return (
      <Popover open={open} onOpenChange={handleOpenChange}>
        <PopoverTrigger asChild>
          <Button variant="ghost" className="p-1 h-8 rounded-sm">
            <p className="px-2">Actions</p>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </Button>
        </PopoverTrigger>
        <PopoverContent align="end" className="w-[300px] pt-2 pb-0 px-0" onKeyDown={handleKeyDown}>
          <Command>
            <CommandList>
              {
                  isActiveHistoryItemIsUrl() &&
                  <CommandItem onSelect={handleOpenInBrowser}>
                    <GlobeIcon className="mr-2 h-4 w-4"/>
                    <span>Open in Browser</span>
                    <CommandShortcut className="flex flex-row">
                      <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                    </CommandShortcut>
                  </CommandItem>
              }
              {
                  isActiveHistoryItemIsUrl() && <CommandSeparator/>
              }
              <CommandItem onSelect={handleEditContent}>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span>Edit Content...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleCopyToClipboard}>
                <CopyIcon className="mr-2 h-4 w-4"/>
                <span>Copy to Clipboard</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandSeparator/>
              <CommandItem onSelect={handleSearchHistory}>
                <SearchIcon className="mr-2 h-4 w-4"/>
                <span>Search...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetSearchHistoryShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleTogglePreview}>
                <PanelRightClose className="mr-2 h-4 w-4"/>
                <span>{getPreviewVisibleState() ? "Hide Preview" : "Show Preview"}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandSeparator/>
              <CommandItem onSelect={handleDeleteItem}>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleDeleteAllItems}>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete All...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetClearHistoryShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
          </Command>
        </PopoverContent>
      </Popover>
  )
}
