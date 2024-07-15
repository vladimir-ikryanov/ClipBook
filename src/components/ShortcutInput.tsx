import '../App.css';
import React, {useState} from "react";
import {Input} from "@/components/ui/input";
import {keysToDisplayShortcut, shortcutToDisplayShortcut} from "@/lib/shortcuts";

type ShortcutProps = {
  shortcut: string
  onSave: (shortcut: string) => void
}

export default function ShortcutInput(props: ShortcutProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [currentKeys, setCurrentKeys] = useState<string[]>([]);
  const [shortcut, setShortcut] = useState(props.shortcut);

  function handleClick() {
    setShortcut('')
    setIsEditing(true);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    console.log(e.key)
    if (isEditing) {
      e.preventDefault();
      const key = e.key === ' ' ? 'Space' : e.key;

      // Add the key to the current keys if it's not already there
      if (!currentKeys.includes(key)) {
        setCurrentKeys([...currentKeys, key]);
      }
    }
  }

  function handleKeyUp(e: React.KeyboardEvent<HTMLInputElement>) {
    console.log(e.key)
    if (isEditing) {
      // Save the new shortcut when the user stops typing
      const newShortcut = currentKeys.join(' + ');
      setShortcut(newShortcut);
      setCurrentKeys([]);
      setIsEditing(false);
      props.onSave(newShortcut);
    }
  }

  return (
      <Input
          className={isEditing ? "w-40 h-8 text-base text-center caret-transparent focus:border-neutral-500" : "w-40 h-8 text-base text-center caret-transparent"}
          readOnly={true}
          value={isEditing ? keysToDisplayShortcut(currentKeys) : shortcutToDisplayShortcut(shortcut)}
          onClick={handleClick}
          onKeyDown={handleKeyDown}
          onKeyUp={handleKeyUp}/>
  )
}
