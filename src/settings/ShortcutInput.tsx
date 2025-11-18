import '../app.css';
import React, { useState } from "react";
import { Input } from "@/components/ui/input";
import { isModifierKey, keysToDisplayShortcut, shortcutToDisplayShortcut } from "@/lib/shortcuts";
import { Button } from "@/components/ui/button";
import { Undo2Icon, CircleXIcon } from "lucide-react";
import { useTranslation } from 'react-i18next';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';

declare const enableOpenAppShortcut: () => void;
declare const disableOpenAppShortcut: () => void;
declare const enablePauseResumeShortcut: () => void;
declare const disablePauseResumeShortcut: () => void;
declare const enablePasteNextItemShortcut: () => void;
declare const disablePasteNextItemShortcut: () => void;

type ShortcutProps = {
  shortcut: string
  defaultShortcut?: string
  onSave: (shortcut: string) => void
}

export default function ShortcutInput(props: ShortcutProps) {
  const { t } = useTranslation();

  const [isEditing, setIsEditing] = useState(false);
  const [currentKeys, setCurrentKeys] = useState<string[]>([]);
  const [shortcut, setShortcut] = useState(props.shortcut);
  const [isHovered, setIsHovered] = useState(false);

  function startEditing() {
    setIsEditing(true)
    disableOpenAppShortcut()
    disablePauseResumeShortcut()
    disablePasteNextItemShortcut()
  }

  function stopEditing() {
    setIsEditing(false)
    enableOpenAppShortcut()
    enablePauseResumeShortcut()
    enablePasteNextItemShortcut()
  }

  function handleClick() {
    setShortcut('')
    startEditing()
  }

  function handleBlur() {
    if (!isEditing) {
      return
    }
    stopEditing()
    if (currentKeys.length == 0) {
      setShortcut('')
      setCurrentKeys([])
      props.onSave('')
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (isEditing) {
      e.preventDefault()
      e.stopPropagation()
      const key = e.code
      let keys: string[] = currentKeys;
      // Add the key to the current keys if it's not already there
      if (!currentKeys.includes(key)) {
        keys = [...currentKeys, key]
        setCurrentKeys(keys)
      }

      if (!isModifierKey(key)) {
        const newShortcut = keys.join(' + ')
        setShortcut(newShortcut)
        setCurrentKeys([])
        stopEditing()
        props.onSave(newShortcut)
      }
    }
  }

  function handleKeyUp(e: React.KeyboardEvent<HTMLInputElement>) {
    if (isEditing) {
      // Save the new shortcut when the user stops typing
      setCurrentKeys([])
      e.preventDefault()
      e.stopPropagation()
    }
  }

  function handleReset() {
    if (props.defaultShortcut !== undefined) {
      setShortcut(props.defaultShortcut)
      props.onSave(props.defaultShortcut)
    }
  }

  function handleClear() {
    setShortcut('')
    props.onSave('')
  }

  function getInputValue() {
    if (isEditing) {
      if (currentKeys.length === 0) {
        return 'Recording...'
      }
      return keysToDisplayShortcut(currentKeys)
    }
    return shortcutToDisplayShortcut(shortcut)
  }

  const showRevertButton = props.shortcut !== props.defaultShortcut;
  const showClearButton = !showRevertButton && shortcut !== '' && isHovered;

  return (
    <div
      className="flex flex-row bg-shortcut shadow hover:shadow-md rounded-md"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}>
      <Tooltip>
        <TooltipTrigger asChild>
          <Input
            className={`w-40 h-8 pl-10 text-base text-center caret-transparent border-none bg-shortcut ${isEditing ? "text-neutral-400" : ""}`}
            readOnly={true}
            value={getInputValue()}
            onBlur={handleBlur}
            onClick={handleClick}
            onKeyDown={handleKeyDown}
            onKeyUp={handleKeyUp} />
        </TooltipTrigger>
        <TooltipContent className="flex items-center">
          <div className="select-none mr-2 ml-1">{t('settings.shortcuts.clickToEditShortcut')}</div>
        </TooltipContent>
      </Tooltip>
      {showRevertButton ? (
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" onClick={handleReset}
              className="text-xs my-auto h-5 w-5 p-0 mr-2 text-neutral-400">
              <Undo2Icon className="w-4 h-4" />
            </Button>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div
              className="select-none mr-2 ml-1">{t('settings.shortcuts.resetToDefault')}</div>
          </TooltipContent>
        </Tooltip>

      ) : showClearButton ? (
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" onClick={handleClear}
              className="text-xs my-auto h-5 w-5 p-0 mr-2 text-neutral-400">
              <CircleXIcon className="w-4 h-4" />
            </Button>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div
              className="select-none mr-2 ml-1">{t('settings.shortcuts.clearShortcut')}</div>
          </TooltipContent>
        </Tooltip>
      ) : (
        <div className="h-5 w-5 mr-2 my-auto" />
      )}
    </div>
  )
}
