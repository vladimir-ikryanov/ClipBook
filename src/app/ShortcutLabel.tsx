import '../app.css';
import React from "react";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";

type ShortcutLabelProps = {
  shortcut: string
  /** Size variant - compact for tighter spaces */
  size?: "default" | "compact"
}

export default function ShortcutLabel(props: ShortcutLabelProps) {
  const isCompact = props.size === "compact"
  
  return (
      <div className="flex items-center">
        {
          props.shortcut.split(" + ").map((key, index) => (
              <div key={key + index}
                   className={`flex ${isCompact ? "h-5 px-1.5 min-w-5" : "h-6 px-2 min-w-6"} rounded ${isCompact ? "rounded-[4px]" : "rounded-[5px]"} bg-shortcut-label group-hover:bg-shortcut-label-hover group-focus:bg-shortcut-label-hover group-data-[selected='true']:bg-shortcut-label-hover justify-center items-center transition-colors duration-100 ${index === 0 ? "" : "ml-0.5"}`}>
                <span
                    className={`${isCompact ? "text-xs" : "text-sm"} font-medium text-shortcut-label-text group-hover:text-shortcut-label-hover-text group-focus:text-shortcut-label-hover-text group-data-[selected='true']:text-shortcut-label-hover-text`}>{shortcutToDisplayShortcut(key)}</span>
              </div>
          ))
        }
      </div>
  )
}
