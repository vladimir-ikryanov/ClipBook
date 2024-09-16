import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {useEffect} from "react"
import {
  CopyIcon,
  Edit3Icon,
  GlobeIcon,
  PanelRightClose,
  StarIcon,
  StarOffIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command"
import {
  prefGetClearHistoryShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut, prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetShowMoreActionsShortcut, prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {Popover, PopoverContent, PopoverTrigger} from "@/components/ui/popover";
import {getActiveHistoryItem, getPreviewVisibleState, toBase64Icon} from "@/data";
import {ClipType} from "@/db";

export type HideActionsReason =
    "cancel"
    | "togglePreview"
    | "toggleFavorite"
    | "paste"
    | "editContent"
    | "copyToClipboard"
    | "openInBrowser"
    | "openSettings"
    | "deleteItem"
    | "deleteAllItems"

type ActionsProps = {
  appName: string
  appIcon: string
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onToggleFavorite: () => void
  onPaste: () => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onOpenSettings: () => void
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

  function handlePaste() {
    closeReason = "paste"
    handleOpenChange(false)
    props.onPaste()
  }

  function handleToggleFavorite() {
    closeReason = "toggleFavorite"
    handleOpenChange(false)
    props.onToggleFavorite()
  }

  function handleTogglePreview() {
    closeReason = "togglePreview"
    handleOpenChange(false)
    props.onTogglePreview()
  }

  function handleOpenSettings() {
    closeReason = "openSettings"
    handleOpenChange(false)
    props.onOpenSettings()
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
    return getActiveHistoryItem()?.type === ClipType.Link
  }

  return (
      <Popover open={open} onOpenChange={handleOpenChange}>
        <PopoverTrigger asChild>
          <Button variant="ghost" className="p-1 h-8 rounded-sm">
            <p className="px-2">Actions</p>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </Button>
        </PopoverTrigger>
        <PopoverContent align="end" className="w-[300px] pt-2 pb-0 px-0 bg-actions-background" onKeyDown={handleKeyDown}>
          <Command>
            <CommandList>
              <CommandItem onSelect={handlePaste}>
                <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                     alt="Application icon"/>
                <span>Paste to {props.appName}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
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
              <CommandItem onSelect={handleEditContent}>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span>Edit Content...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleToggleFavorite}>
                {
                  getActiveHistoryItem()?.favorite ?
                      <StarOffIcon className="mr-2 h-4 w-4"/> :
                      <StarIcon className="mr-2 h-4 w-4"/>
                }
                <span>{getActiveHistoryItem()?.favorite ? "Remove from Favorites" : "Add to Favorites"}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
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
              <CommandItem onSelect={handleOpenSettings}>
                <PanelRightClose className="mr-2 h-4 w-4"/>
                <span>{"Settings..."}</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetOpenSettingsShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandSeparator/>
              <CommandItem onSelect={handleDeleteItem}>
                <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                <span className="text-actions-danger">Delete</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
              <CommandItem onSelect={handleDeleteAllItems}>
                <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
                <span className="text-actions-danger">Delete All...</span>
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
