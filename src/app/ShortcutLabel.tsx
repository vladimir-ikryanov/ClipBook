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
              <div key={key + index}
                   className={`flex h-6 px-2 rounded bg-shortcut-label group-hover:bg-shortcut-label-hover group-focus:bg-shortcut-label-hover group-data-[selected='true']:bg-shortcut-label-hover justify-center items-center ${index === 0 ? "" : "ml-1"}`}>
                <span
                    className="text-sm text-shortcut-label-text group-hover:text-shortcut-label-hover-text group-focus:text-shortcut-label-hover-text group-data-[selected='true']:text-shortcut-label-hover-text">{shortcutToDisplayShortcut(key)}</span>
              </div>
          ))
        }
      </div>
  )
}
