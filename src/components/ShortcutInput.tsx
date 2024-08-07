import '../App.css';
import React, {useState} from "react";
import {Input} from "@/components/ui/input";
import {isModifierKey, keysToDisplayShortcut, shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {Button} from "@/components/ui/button";
import {Undo2Icon} from "lucide-react";

declare const enableOpenAppShortcut: () => void;
declare const disableOpenAppShortcut: () => void;

type ShortcutProps = {
  shortcut: string
  defaultShortcut?: string
  onSave: (shortcut: string) => void
}

export default function ShortcutInput(props: ShortcutProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [currentKeys, setCurrentKeys] = useState<string[]>([]);
  const [shortcut, setShortcut] = useState(props.shortcut);

  function startEditing() {
    setIsEditing(true)
    disableOpenAppShortcut()
  }

  function stopEditing() {
    setIsEditing(false)
    enableOpenAppShortcut()
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
      const key = e.key === ' ' ? 'Space' : e.key;
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
    if (props.defaultShortcut) {
      setShortcut(props.defaultShortcut)
      props.onSave(props.defaultShortcut)
    }
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

  let style: string = "w-40 h-8 pl-10 text-base text-center caret-transparent border-none bg-neutral-100 dark:bg-neutral-700";

  return (
      <div className="flex flex-row bg-neutral-100 dark:bg-neutral-700 shadow hover:shadow-md rounded-md">
        <Input
            className={isEditing ? style + " text-neutral-400" : style}
            title="Click to edit shortcut"
            readOnly={true}
            value={getInputValue()}
            onBlur={handleBlur}
            onClick={handleClick}
            onKeyDown={handleKeyDown}
            onKeyUp={handleKeyUp}/>
        <Button variant="ghost" onClick={handleReset}
                className="text-xs my-auto h-5 w-5 p-0 mr-2 text-neutral-400"
                title="Reset to default" disabled={props.shortcut === props.defaultShortcut}>
          <Undo2Icon
              className={props.shortcut !== props.defaultShortcut ? "w-4 h-4" : "invisible"}/>
        </Button>
      </div>
  )
}
