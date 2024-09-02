import '../app.css';
import React from "react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";

type ShortcutLabelProps = {
  shortcut: string
  orientation?: "left" | "right"
}

export default function ShortcutLabel(props: ShortcutLabelProps) {
  return (
      <div className="flex">
        {
          props.shortcut.split(" + ").map((key, index) => (
              <div key={key + index} className={index === 0 ?
                  "flex h-6 px-2 rounded bg-card justify-center items-center" :
                  "flex h-6 px-2 rounded bg-card justify-center items-center ml-1"}>
                <span
                    className="text-sm text-card-foreground">{shortcutToDisplayShortcut(key)}</span>
              </div>
          ))
        }
      </div>
  )
}
