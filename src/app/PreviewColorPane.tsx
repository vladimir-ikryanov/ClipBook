import '../app.css';
import React, {useEffect, useState} from "react";
import {getClipTypeFromText, toCSSColor} from "@/lib/utils";
import namer from 'color-namer';
import {Clip} from "@/db";
import {isShortcutMatch} from "@/lib/shortcuts";
import {prefGetEditHistoryItemShortcut} from "@/pref";

type PreviewColorPaneProps = {
  item: Clip
  colorText: string
  editMode: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewColorPane(props: PreviewColorPaneProps) {
  const [content, setContent] = useState(props.item.content)
  const [cssColor, setCssColor] = useState("")
  const [colorName, setColorName] = useState("")

  useEffect(() => {
    if (props.editMode) {
      let textarea = document.getElementById('preview') as HTMLTextAreaElement;
      textarea.focus()
      textarea.selectionStart = textarea.selectionEnd = textarea.value.length
    }
  }, [props.editMode]);

  useEffect(() => {
    let cssColorName = ""
    let cssColorValue = toCSSColor(props.colorText)
    if (cssColorValue.length > 0) {
      if (cssColorValue.startsWith("#") || cssColorValue.startsWith("rgb") || cssColorValue.startsWith("hsl")) {
        cssColorName = namer(cssColorValue, { pick: ['ntc'] }).ntc[0].name
      }
    }
    setCssColor(cssColorValue)
    setColorName(cssColorName)
    setContent(props.item.content)
  }, [props.colorText])

  function handleFinishEditing() {
    props.item.content = content
    props.item.type = getClipTypeFromText(content)
    props.onEditHistoryItem(props.item)
    props.onFinishEditing()
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      handleFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    setContent(content)
    props.item.content = content
    props.item.type = getClipTypeFromText(content)
  }

  if (props.editMode) {
    return (
        <textarea id='preview'
                  className="preview h-full px-4 py-2 m-0 outline-none resize-none font-mono text-sm"
                  value={content}
                  onBlur={handleFinishEditing}
                  onChange={handleOnChange}
                  onKeyDown={handleKeyDown}/>
    )
  }

  return (
      <div className="flex flex-grow m-0 items-center justify-center outline-none resize-none overflow-hidden">
        <div className="flex flex-col justify-center items-center">
          <div className={`h-48 w-48 rounded-full border-[6px] border-accent`} style={{backgroundColor: cssColor}}></div>
          <div className="mt-6 font-mono">{props.colorText}</div>
          <div className="mt-2 text-secondary-foreground">{colorName}</div>
        </div>
      </div>
  )
}
