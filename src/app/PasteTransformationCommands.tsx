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
import {emitter} from "@/actions";

export default function PasteTransformationCommands() {
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
    function handleAppWindowDidHide() {
      handleOpenChange(false)
    }

    function handleShowPasteTransformationCommands() {
      setOpen(true)
    }

    emitter.on("NotifyAppWindowDidHide", handleAppWindowDidHide)
    emitter.on("ShowPasteTransformationCommands", handleShowPasteTransformationCommands)
    return () => {
      emitter.off("NotifyAppWindowDidHide", handleAppWindowDidHide)
      emitter.off("ShowPasteTransformationCommands", handleShowPasteTransformationCommands)
    };
  }, [])

  function handleOpenChange(open: boolean) {
    setOpen(open)
    if (!open) {
      emitter.emit("FocusSearchInput")
    }
  }

  function handleMakeUpperCase() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.ToUpperCase)
  }

  function handleMakeLowerCase() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.ToLowerCase)
  }

  function handleCapitalizeWords() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.CapitalizeWords)
  }

  function handleMakeSentenceCase() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.ToSentenceCase)
  }

  function handleRemoveEmptyLines() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.RemoveEmptyLines)
  }

  function handleStripAllWhitespaces() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.StripAllWhitespaces)
  }

  function handleTrimSurroundingWhitespaces() {
    handleOpenChange(false)
    emitter.emit("PasteWithTransformation", TextFormatOperation.TrimSurroundingWhitespaces)
  }

  return (
      <div onKeyDown={handleKeyDown}>
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
