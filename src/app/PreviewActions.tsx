import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {
  CopyIcon,
  GlobeIcon,
  EllipsisVerticalIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
  CommandItem,
  CommandList,
  CommandShortcut
} from "@/components/ui/command"
import {
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetOpenInBrowserShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {Popover, PopoverContent, PopoverTrigger} from "@/components/ui/popover";
import {getActiveHistoryItem, isUrl} from "@/data";

export type HidePreviewActionsReason =
    "cancel"
    | "copyToClipboard"
    | "openInBrowser"
    | "deleteItem"

type PreviewActionsProps = {
  onHideActions: (reason: HidePreviewActionsReason) => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
}

export default function PreviewActions(props: PreviewActionsProps) {
  const [open, setOpen] = React.useState(false)

  function handleKeyDown(e: React.KeyboardEvent) {
    e.stopPropagation()
  }

  let closeReason: HidePreviewActionsReason = "cancel"

  function handleOpenChange(open: boolean): void {
    setOpen(open)
    if (!open) {
      props.onHideActions(closeReason)
    }
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem()
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
          <Button variant="ghost" className="p-2" title={"More actions"}>
            <EllipsisVerticalIcon className="h-5 w-5 text-primary-foreground"/>
          </Button>
        </PopoverTrigger>
        <PopoverContent align="end" className="w-[250px] py-2 px-0 bg-actions-background"
                        onKeyDown={handleKeyDown}>
          <Command>
            <CommandList>
              <CommandItem onSelect={handleCopyToClipboard}>
                <CopyIcon className="mr-2 h-4 w-4"/>
                <span>Copy to Clipboard</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                </CommandShortcut>
              </CommandItem>
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
              <CommandItem onSelect={handleDeleteItem}>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                </CommandShortcut>
              </CommandItem>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>
  )
}
