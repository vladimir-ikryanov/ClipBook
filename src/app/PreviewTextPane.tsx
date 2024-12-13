import '../app.css';
import React from "react";
import {Clip} from "@/db";
import {getClipType} from "@/lib/utils";

type PreviewTextPaneProps = {
  item: Clip
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
  previewTextareaRef?: React.Ref<HTMLTextAreaElement>
}

export default function PreviewTextPane(props: PreviewTextPaneProps) {
  // I need this state to keep caret position when editing the content.
  const [content, setContent] = React.useState(props.item.content)

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape") {
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
                ref={props.previewTextareaRef}
                className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                value={props.item.content}
                onChange={handleOnChange}
                onKeyDown={handleKeyDown}/>
  )
}
