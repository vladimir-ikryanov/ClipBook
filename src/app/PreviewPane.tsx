import '../app.css';
import React from "react";
import PreviewToolBar from "@/app/PreviewToolBar";
import {Clip, ClipType} from "@/db";
import ItemInfoPane from "@/app/ItemInfoPane";
import {
  getFirstSelectedHistoryItem,
  getInfoVisibleState,
  getSelectedHistoryItems,
  setInfoVisibleState
} from "@/data";
import PreviewTextPane from "@/app/PreviewTextPane";
import PreviewImagePane from "@/app/PreviewImagePane";
import ItemsInfoPane from "@/app/ItemsInfoPane";
import PreviewItemsPane from "@/app/PreviewItemsPane";

type PreviewPaneProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  visible: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
  onPaste: () => void
  onMerge: () => void
  onHidePreview: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onOpenInBrowser: () => void
  onToggleFavorite: () => void
  onDeleteItem: () => void
  previewTextareaRef?: React.Ref<HTMLTextAreaElement>
}

export default function PreviewPane(props: PreviewPaneProps) {
  const [displayInfo, setDisplayInfo] = React.useState(getInfoVisibleState())

  function handleToggleInfo() {
    let visible = !displayInfo;
    setDisplayInfo(visible)
    setInfoVisibleState(visible)
  }

  function renderContent() {
    if (props.selectedItemIndices.length === 1) {
      let item = getFirstSelectedHistoryItem()
      return item.type === ClipType.Image ? renderImage(item) : renderText(item)
    }
    return <PreviewItemsPane items={getSelectedHistoryItems()}/>
  }

  function renderText(item: Clip) {
    return <PreviewTextPane item={item}
                            onEditHistoryItem={props.onEditHistoryItem}
                            onFinishEditing={props.onFinishEditing}
                            previewTextareaRef={props.previewTextareaRef}/>
  }

  function renderImage(item: Clip) {
    return <PreviewImagePane item={item}/>
  }

  function renderInfo() {
    if (props.selectedItemIndices.length === 1) {
      return <ItemInfoPane item={getFirstSelectedHistoryItem()} display={displayInfo}/>
    }
    return <ItemsInfoPane items={getSelectedHistoryItems()} display={displayInfo}/>
  }

  if (props.selectedItemIndices.length === 0) {
    return <div
        className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]"></div>
  }

  if (!props.visible) {
    return null
  }

  return (
      <div className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]">
        <PreviewToolBar selectedItemIndices={props.selectedItemIndices}
                        appName={props.appName}
                        appIcon={props.appIcon}
                        displayInfo={displayInfo}
                        onPaste={props.onPaste}
                        onMerge={props.onMerge}
                        onToggleInfo={handleToggleInfo}
                        onHidePreview={props.onHidePreview}
                        onEditHistoryItem={props.onEditHistoryItem}
                        onCopyToClipboard={props.onCopyToClipboard}
                        onCopyTextFromImage={props.onCopyTextFromImage}
                        onOpenInBrowser={props.onOpenInBrowser}
                        onToggleFavorite={props.onToggleFavorite}
                        onDeleteItem={props.onDeleteItem}/>
        {renderContent()}
        {renderInfo()}
      </div>
  )
}
