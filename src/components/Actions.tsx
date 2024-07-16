import '../App.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {
  Edit3Icon,
  PanelRightClose,
  SearchIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList,
  CommandShortcut,
} from "@/components/ui/command"
import {useEffect} from "react";
import {
  prefGetClearHistoryShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetSearchHistoryShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import ShortcutLabel from "@/components/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {Popover, PopoverContent, PopoverTrigger} from "@/components/ui/popover";

type ActionsProps = {
  onHideActions: () => void
  onTogglePreview: () => void
  onSearchHistory: () => void
  onEditContent: () => void
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

  function handleOpenChange(open: boolean) {
    setOpen(open)
    if (!open) {
      props.onHideActions()
    }
  }

  function handleEditContent() {
    handleOpenChange(false)
    props.onEditContent()
  }

  function handleSearchHistory() {
    handleOpenChange(false)
    props.onSearchHistory()
  }

  function handleTogglePreview() {
    handleOpenChange(false)
    props.onTogglePreview()
  }

  function handleDeleteItem() {
    handleOpenChange(false)
    props.onDeleteItem()
  }

  function handleDeleteAllItems() {
    handleOpenChange(false)
    props.onDeleteAllItems()
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
              <CommandItem onSelect={handleEditContent}>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span>Edit content...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleSearchHistory}>
                <SearchIcon className="mr-2 h-4 w-4"/>
                <span>Search...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetSearchHistoryShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleTogglePreview}>
                <PanelRightClose className="mr-2 h-4 w-4"/>
                <span>Show/Hide Preview</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleDeleteItem}>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleDeleteAllItems}>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete all...</span>
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
