import '../app.css';
import React from "react";
import {HistoryItem} from "@/data";
import PreviewToolBar from "@/app/PreviewToolBar";

type HistoryItemPreviewPaneProps = {
  item: HistoryItem
  appName: string
  appIcon: string
  onEditHistoryItem: (item: HistoryItem) => void
  onFinishEditing: () => void
  onHidePreview: () => void
  previewTextareaRef?: React.Ref<HTMLTextAreaElement>
}

export default function PreviewPane(props: HistoryItemPreviewPaneProps) {
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
      <div className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]">
        <PreviewToolBar appName={props.appName}
                        appIcon={props.appIcon}
                        onHidePreview={props.onHidePreview}/>
        <textarea id='preview'
                  ref={props.previewTextareaRef}
                  className="preview h-full px-4 py-2 m-0 bg-secondary border-none outline-none resize-none font-mono text-sm"
                  value={props.item?.content}
                  onChange={handleOnChange}
                  onKeyDown={handleKeyDown}/>
      </div>
  )
}
