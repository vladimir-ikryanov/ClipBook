import '../App.css';
import React from "react";
import {HistoryItem} from "@/data";

type HistoryItemPreviewPaneProps = {
  item: HistoryItem
  onEditHistoryItem: (item: HistoryItem) => void
  onFinishEditing: () => void
  previewTextareaRef?: React.Ref<HTMLTextAreaElement>
}

export default function HistoryItemPreviewPane(props: HistoryItemPreviewPaneProps) {
  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      props.onFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    props.onEditHistoryItem({content: content, sourceApp: props.item.sourceApp})
  }

  return (
      <div className="flex flex-col h-screen p-0 m-0 border-l border-l-border">
        <textarea id='preview'
                  ref={props.previewTextareaRef}
                  className="preview h-full p-4 m-0 bg-secondary border-none outline-none resize-none font-mono text-sm"
                  value={props.item.content} onChange={handleOnChange} onKeyDown={handleKeyDown}/>
        <div>{props.item.sourceApp.id} : {props.item.sourceApp.name}</div>
      </div>
  )
}
