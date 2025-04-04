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
import {ActionName} from "@/actions";

type PasteTransformationCommandsProps = {
  onPasteWithTransformation: (operation: TextFormatOperation) => void
}

export default function PasteTransformationCommands(props: PasteTransformationCommandsProps) {
  const [open, setOpen] = useState(false)

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      handleOpenChange(false)
      e.preventDefault()
    }
    if (e.key === "1") {
      handleMakeLowerCase()
      e.preventDefault()
    }
    if (e.key === "2") {
      handleMakeUpperCase()
      e.preventDefault()
    }
    if (e.key === "3") {
      handleCapitalizeWords()
      e.preventDefault()
    }
    if (e.key === "4") {
      handleMakeSentenceCase()
      e.preventDefault()
    }
    if (e.key === "5") {
      handleRemoveEmptyLines()
      e.preventDefault()
    }
    if (e.key === "6") {
      handleStripAllWhitespaces()
      e.preventDefault()
    }
    if (e.key === "7") {
      handleTrimSurroundingWhitespaces()
      e.preventDefault()
    }
    e.stopPropagation()
  }

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === ActionName.PasteWithTransformation) {
        setOpen(true)
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [])

  useEffect(() => {
    function handleAction(event: Event) {
      handleOpenChange(false)
    }

    window.addEventListener("onDidAppWindowHide", handleAction);
    return () => window.removeEventListener("onDidAppWindowHide", handleAction);
  }, [])

  function handleOpenChange(open: boolean) {
    setOpen(open)
  }

  function handleMakeUpperCase() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.ToUpperCase)
  }

  function handleMakeLowerCase() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.ToLowerCase)
  }

  function handleCapitalizeWords() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.CapitalizeWords)
  }

  function handleMakeSentenceCase() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.ToSentenceCase)
  }

  function handleRemoveEmptyLines() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.RemoveEmptyLines)
  }

  function handleStripAllWhitespaces() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.StripAllWhitespaces)
  }

  function handleTrimSurroundingWhitespaces() {
    handleOpenChange(false)
    props.onPasteWithTransformation(TextFormatOperation.TrimSurroundingWhitespaces)
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
              <CommandGroup heading="Format text when pasting">
                <CommandItem onSelect={handleMakeLowerCase}>
                  <span>make lower case</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="1"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeUpperCase}>
                  <span>MAKE UPPER CASE</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="2"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleCapitalizeWords}>
                  <span>Capitalize Words</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="3"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeSentenceCase}>
                  <span>Sentence case</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="4"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleRemoveEmptyLines}>
                  <span>Remove empty lines</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="5"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleStripAllWhitespaces}>
                  <span>StripAllWhitespaces</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="6"/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleTrimSurroundingWhitespaces}>
                  <span>Trim Surrounding Whitespaces</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut="7"/>
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
