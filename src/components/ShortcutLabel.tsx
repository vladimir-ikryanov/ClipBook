import '../App.css';
import React from "react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";

type ShortcutLabelProps = {
  shortcut: string
}

export default function ShortcutLabel(props: ShortcutLabelProps) {
  return (
      <div className="flex">
        {
          props.shortcut.split(" + ").map((key, index) => (
              <div key={key + index} className="flex h-6 px-2 rounded bg-card justify-center items-center mx-0.5">
                <span
                    className="text-sm text-card-foreground">{shortcutToDisplayShortcut(key)}</span>
              </div>
          ))
        }
      </div>
  )
}
