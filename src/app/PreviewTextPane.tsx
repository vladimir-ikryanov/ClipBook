import '../app.css';
import React, {useEffect, useState} from "react";
import {Clip, getHTML, getRTF} from "@/db";
import {getClipTypeFromText} from "@/lib/utils";
import {isShortcutMatch} from "@/lib/shortcuts";
import {prefGetEditHistoryItemShortcut} from "@/pref";
import {ActionName} from "@/actions";
import {TextType} from "@/app/TextTypeToggle";

type PreviewTextPaneProps = {
  item: Clip
  editMode: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewTextPane(props: PreviewTextPaneProps) {
  // I need this state to keep caret position when editing the content.
  const [content, setContent] = useState(props.item.content)
  const [selectedTextType, setSelectedTextType] = useState<TextType>(TextType.Text)

  useEffect(() => {
    if (props.editMode) {
      let textarea = document.getElementById('preview') as HTMLTextAreaElement;
      textarea.focus()
      textarea.selectionStart = textarea.selectionEnd = textarea.value.length
    }
  }, [props.editMode]);

  useEffect(() => {
    setContent(props.item.content)
    setSelectedTextType(TextType.Text)
  }, [props.item]);

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      let actionName = customEvent.detail.action;
      if (actionName === ActionName.SwitchTextType) {
        const action = event as CustomEvent<{ action: string, type: TextType }>
        let type = action.detail.type
        setSelectedTextType(type)
        if (type === TextType.Text) {
          setContent(props.item.content)
        }
        if (type === TextType.HTML) {
          setContent(getHTML(props.item))
        }
        if (type === TextType.RTF) {
          setContent(getRTF(props.item))
        }
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [props.item]);

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      finishEditing()
    }
    e.stopPropagation()
  }

  function finishEditing() {
    props.onEditHistoryItem(props.item)
    props.onFinishEditing()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    setContent(content)
    if (selectedTextType === TextType.Text) {
      props.item.content = content
    }
    if (selectedTextType === TextType.HTML) {
      props.item.html = content
    }
    if (selectedTextType === TextType.RTF) {
      props.item.rtf = content
    }
    props.item.type = getClipTypeFromText(content)
  }

  return (
      <textarea id='preview'
                className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                value={content}
                onBlur={finishEditing}
                onChange={handleOnChange}
                onKeyDown={handleKeyDown}/>
  )
}
