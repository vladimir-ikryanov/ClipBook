import '../app.css';
import React, {useEffect} from "react";
import {Clip} from "@/db";
import {getClipType} from "@/lib/utils";
import {isShortcutMatch} from "@/lib/shortcuts";
import {prefGetEditHistoryItemShortcut} from "@/pref";

type PreviewTextPaneProps = {
  item: Clip
  editMode: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewTextPane(props: PreviewTextPaneProps) {
  // I need this state to keep caret position when editing the content.
  const [content, setContent] = React.useState(props.item.content)

  useEffect(() => {
    if (props.editMode) {
      let textarea = document.getElementById('preview') as HTMLTextAreaElement;
      textarea.focus()
      textarea.selectionStart = textarea.selectionEnd = textarea.value.length
    }
  }, [props.editMode]);

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      props.onFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    setContent(content)
    props.item.content = content
    props.item.type = getClipType(content)
    props.onEditHistoryItem(props.item)
  }

  return (
      <textarea id='preview'
                className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                value={props.item.content}
                onBlur={props.onFinishEditing}
                onChange={handleOnChange}
                onKeyDown={handleKeyDown}/>
  )
}
