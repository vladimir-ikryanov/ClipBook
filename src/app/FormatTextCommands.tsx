import '../app.css';

import * as React from "react"
import {useEffect, useState} from "react"
import {VisuallyHidden} from "@radix-ui/react-visually-hidden";

import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput,
  CommandItem,
  CommandList,
  CommandShortcut,
} from "@/components/ui/command"
import ShortcutLabel from "@/app/ShortcutLabel";
import {TextFormatOperation} from "@/data";
import {DialogTitle} from "@/components/ui/dialog";
import {
  prefGetCapitalizeShortcut,
  prefGetMakeLowerCaseShortcut,
  prefGetMakeUpperCaseShortcut,
  prefGetRemoveEmptyLinesShortcut,
  prefGetSentenceCaseShortcut,
  prefGetStripAllWhitespacesShortcut, prefGetTrimSurroundingWhitespacesShortcut
} from "@/pref";

type FormatTextCommandsProps = {
  onFormatText: (operation: TextFormatOperation) => void
}

export default function FormatTextCommands(props: FormatTextCommandsProps) {
  const [open, setOpen] = useState(false)

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      handleOpenChange(false)
      e.preventDefault()
    }
    e.stopPropagation()
  }

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === "formatText") {
        setOpen(true)
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [])

  function handleOpenChange(open: boolean) {
    setOpen(open)
  }

  function handleMakeUpperCase() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.ToUpperCase)
  }

  function handleMakeLowerCase() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.ToLowerCase)
  }

  function handleCapitalizeWords() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.CapitalizeWords)
  }

  function handleMakeSentenceCase() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.ToSentenceCase)
  }

  function handleRemoveEmptyLines() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.RemoveEmptyLines)
  }

  function handleStripAllWhitespaces() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.StripAllWhitespaces)
  }

  function handleTrimSurroundingWhitespaces() {
    handleOpenChange(false)
    props.onFormatText(TextFormatOperation.TrimSurroundingWhitespaces)
  }

  return (
      <div className="" onKeyDown={handleKeyDown}>
        <CommandDialog open={open} onOpenChange={handleOpenChange}>
          <VisuallyHidden>
            <DialogTitle></DialogTitle>
          </VisuallyHidden>
          <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
          <div className="max-h-[70vh] overflow-y-auto mb-1.5">
            <CommandList>
              <CommandGroup heading="Format text">
                <CommandItem onSelect={handleMakeLowerCase}>
                  <span>make lower case</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetMakeLowerCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeUpperCase}>
                  <span>MAKE UPPER CASE</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetMakeUpperCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleCapitalizeWords}>
                  <span>Capitalize Words</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetCapitalizeShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeSentenceCase}>
                  <span>Sentence case</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetSentenceCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleRemoveEmptyLines}>
                  <span>Remove empty lines</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetRemoveEmptyLinesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleStripAllWhitespaces}>
                  <span>StripAllWhitespaces</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetStripAllWhitespacesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleTrimSurroundingWhitespaces}>
                  <span>Trim Surrounding Whitespaces</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetTrimSurroundingWhitespacesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
              </CommandGroup>
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
          </div>
        </CommandDialog>
      </div>
  )
}
