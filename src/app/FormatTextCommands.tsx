import '../app.css';

import * as React from "react"
import {useEffect, useState} from "react"
import {VisuallyHidden} from "@radix-ui/react-visually-hidden";

import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
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
  prefGetStripAllWhitespacesShortcut,
  prefGetTrimSurroundingWhitespacesShortcut
} from "@/pref";
import {emitter} from "@/actions";
import { useTranslation } from 'react-i18next';

export default function FormatTextCommands() {
  const { t } = useTranslation()

  const [open, setOpen] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      handleOpenChange(false)
      e.preventDefault()
    }
    e.stopPropagation()
  }

  function handleShowFormatTextCommands() {
    setTimeout(() => {
      setOpen(true)
    }, 100);
  }

  function handleShowFormatTextCommandsByIndex(index: number) {
    setTimeout(() => {
      setSelectedIndex(index)
      setOpen(true)
    }, 100);
  }

  function handleAppWindowDidHide() {
    handleOpenChange(false)
  }

  useEffect(() => {
    emitter.on("ShowFormatTextCommands", handleShowFormatTextCommands)
    emitter.on("ShowFormatTextCommandsByIndex", handleShowFormatTextCommandsByIndex)
    emitter.on("NotifyAppWindowDidHide", handleAppWindowDidHide)
    return () => {
      emitter.off("ShowFormatTextCommands", handleShowFormatTextCommands)
      emitter.off("ShowFormatTextCommandsByIndex", handleShowFormatTextCommandsByIndex)
      emitter.off("NotifyAppWindowDidHide", handleAppWindowDidHide)
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
    emitter.emit("FormatText", {
      operation: TextFormatOperation.ToUpperCase,
      index: selectedIndex
    })
  }

  function handleMakeLowerCase() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.ToLowerCase,
      index: selectedIndex
    })
  }

  function handleCapitalizeWords() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.CapitalizeWords,
      index: selectedIndex
    })
  }

  function handleMakeSentenceCase() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.ToSentenceCase,
      index: selectedIndex
    })
  }

  function handleRemoveEmptyLines() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.RemoveEmptyLines,
      index: selectedIndex
    })
  }

  function handleStripAllWhitespaces() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.StripAllWhitespaces,
      index: selectedIndex
    })
  }

  function handleTrimSurroundingWhitespaces() {
    handleOpenChange(false)
    emitter.emit("FormatText", {
      operation: TextFormatOperation.TrimSurroundingWhitespaces,
      index: selectedIndex
    })
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
                  <span>{t('formatText.makeLowerCase')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetMakeLowerCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeUpperCase}>
                  <span>{t('formatText.makeUpperCase')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetMakeUpperCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleCapitalizeWords}>
                  <span>{t('formatText.capitalizeWords')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetCapitalizeShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleMakeSentenceCase}>
                  <span>{t('formatText.sentenceCase')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetSentenceCaseShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleRemoveEmptyLines}>
                  <span>{t('formatText.removeEmptyLines')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetRemoveEmptyLinesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleStripAllWhitespaces}>
                  <span>{t('formatText.stripAllWhitespaces')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetStripAllWhitespacesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleTrimSurroundingWhitespaces}>
                  <span>{t('formatText.trimSurroundingWhitespaces')}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetTrimSurroundingWhitespacesShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
              </CommandGroup>
              <CommandEmpty>{t('commands.noResultsFound')}</CommandEmpty>
            </CommandList>
          </div>
        </CommandDialog>
      </div>
  )
}
