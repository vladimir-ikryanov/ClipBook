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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
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
import {deleteAllHistoryItems} from "@/components/History";

type ActionsProps = {
  onHideActions: () => void
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
    console.log("Edit content...");
    handleOpenChange(false)
  }

  function handleSearchHistory() {
    console.log("Search...");
    handleOpenChange(false)
  }

  function handleTogglePreview() {
    console.log("Show/Hide Preview");
    handleOpenChange(false)
  }

  function handleDeleteItem() {
    console.log("Delete");
    handleOpenChange(false)
  }

  function handleDeleteAllItems() {
    deleteAllHistoryItems()
    handleOpenChange(false)
  }

  return (
      <DropdownMenu open={open} onOpenChange={handleOpenChange}>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="p-1 h-8 rounded-sm">
            <p className="px-2">Actions</p>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-[300px]" onKeyDown={handleKeyDown}>
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
        </DropdownMenuContent>
      </DropdownMenu>
  )
}
