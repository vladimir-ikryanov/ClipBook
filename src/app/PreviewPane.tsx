import '../app.css';
import React from "react";
import {HistoryItem} from "@/data";
import PreviewToolBar from "@/app/PreviewToolBar";
import {HidePreviewActionsReason} from "@/app/PreviewActions";

type HistoryItemPreviewPaneProps = {
  item: HistoryItem
  appName: string
  appIcon: string
  onEditHistoryItem: (item: HistoryItem) => void
  onFinishEditing: () => void
  onPaste: () => void
  onHidePreview: () => void
  onHideActions: (reason: HidePreviewActionsReason) => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
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
                        onPaste={props.onPaste}
                        onHidePreview={props.onHidePreview}
                        onHideActions={props.onHideActions}
                        onCopyToClipboard={props.onCopyToClipboard}
                        onOpenInBrowser={props.onOpenInBrowser}
                        onDeleteItem={props.onDeleteItem}/>
        <textarea id='preview'
                  ref={props.previewTextareaRef}
                  className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                  value={props.item?.content}
                  onChange={handleOnChange}
                  onKeyDown={handleKeyDown}/>
      </div>
  )
}
