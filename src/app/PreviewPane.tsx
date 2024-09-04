import '../app.css';
import React from "react";
import PreviewToolBar from "@/app/PreviewToolBar";
import {HidePreviewActionsReason} from "@/app/PreviewActions";
import {Clip} from "@/db";
import {getClipType} from "@/lib/utils";
import InfoPane from "@/app/InfoPane";
import {getInfoVisibleState, setInfoVisibleState} from "@/data";

type HistoryItemPreviewPaneProps = {
  item: Clip
  appName: string
  appIcon: string
  onEditHistoryItem: (item: Clip) => void
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
  const [displayInfo, setDisplayInfo] = React.useState(getInfoVisibleState())

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      props.onFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    props.item.content = content
    props.item.type = getClipType(content)
    props.onEditHistoryItem(props.item)
  }

  function handleToggleInfo() {
    let visible = !displayInfo;
    setDisplayInfo(visible)
    setInfoVisibleState(visible)
  }

  if (!props.item) {
    return <div
        className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]"></div>
  }

  return (
      <div className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]">
        <PreviewToolBar item={props.item}
                        appName={props.appName}
                        appIcon={props.appIcon}
                        displayInfo={displayInfo}
                        onPaste={props.onPaste}
                        onToggleInfo={handleToggleInfo}
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
        <InfoPane item={props.item} display={displayInfo}/>
      </div>
  )
}
