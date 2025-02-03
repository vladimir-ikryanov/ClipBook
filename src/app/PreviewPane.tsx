import '../app.css';
import React, {useState} from "react";
import PreviewToolBar, {HideDropdownReason} from "@/app/PreviewToolBar";
import {Clip, ClipType} from "@/db";
import ItemInfoPane from "@/app/ItemInfoPane";
import {
  getFirstSelectedHistoryItem, getHistoryItem,
  getInfoVisibleState,
  getSelectedHistoryItems,
  setInfoVisibleState
} from "@/data";
import PreviewTextPane from "@/app/PreviewTextPane";
import PreviewImagePane from "@/app/PreviewImagePane";
import ItemsInfoPane from "@/app/ItemsInfoPane";
import PreviewItemsPane from "@/app/PreviewItemsPane";
import PreviewColorPane from "@/app/PreviewColorPane";
import PreviewLinkPane from "@/app/PreviewLinkPane";
import {prefShouldShowPreviewForLinks} from "@/pref";

type PreviewPaneProps = {
  selectedItemIndices: number[]
  appName: string
  appIcon: string
  visible: boolean
  editMode: boolean
  onHideDropdown: (reason: HideDropdownReason) => void
  onRequestEditItem: () => void
  onSaveImageAsFile: () => void
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
  onPaste: () => void
  onPasteWithReturn: () => void
  onPasteWithTab: () => void
  onMerge: () => void
  onHidePreview: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onOpenInBrowser: () => void
  onPreviewLink: () => void
  onToggleFavorite: () => void
  onDeleteItem: () => void
}

export default function PreviewPane(props: PreviewPaneProps) {
  const [displayInfo, setDisplayInfo] = useState(getInfoVisibleState())
  const [updateLinkPreview, setUpdateLinkPreview] = useState(false)

  function handleToggleInfo() {
    let visible = !displayInfo;
    setDisplayInfo(visible)
    setInfoVisibleState(visible)
  }

  function handleUpdateLinkPreview() {
    setUpdateLinkPreview(true)
  }

  function handleLinkPreviewUpdated() {
    setUpdateLinkPreview(false)
  }

  function renderContent() {
    if (props.selectedItemIndices.length === 1) {
      let item = getHistoryItem(props.selectedItemIndices[0])
      if (item.type === ClipType.Color) {
        return <PreviewColorPane item={item}
                                 colorText={item.content}
                                 editMode={props.editMode}
                                 onEditHistoryItem={props.onEditHistoryItem}
                                 onFinishEditing={props.onFinishEditing}/>
      }
      if (item.type === ClipType.Image) {
        return <PreviewImagePane item={item}/>
      }
      if (item.type === ClipType.Link && prefShouldShowPreviewForLinks()) {
        return <PreviewLinkPane item={item}
                                linkText={item.content}
                                editMode={props.editMode}
                                updateLinkPreview={updateLinkPreview}
                                onLinkPreviewUpdated={handleLinkPreviewUpdated}
                                onEditHistoryItem={props.onEditHistoryItem}
                                onFinishEditing={props.onFinishEditing}/>
      }
      return <PreviewTextPane item={item}
                              editMode={props.editMode}
                              onEditHistoryItem={props.onEditHistoryItem}
                              onFinishEditing={props.onFinishEditing}/>
    }
    return <PreviewItemsPane items={getSelectedHistoryItems()}/>
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
                        onPasteWithReturn={props.onPasteWithReturn}
                        onPasteWithTab={props.onPasteWithTab}
                        onMerge={props.onMerge}
                        onToggleInfo={handleToggleInfo}
                        onHidePreview={props.onHidePreview}
                        onSaveImageAsFile={props.onSaveImageAsFile}
                        onRequestEditItem={props.onRequestEditItem}
                        onDeleteItem={props.onDeleteItem}
                        onCopyToClipboard={props.onCopyToClipboard}
                        onCopyTextFromImage={props.onCopyTextFromImage}
                        onOpenInBrowser={props.onOpenInBrowser}
                        onToggleFavorite={props.onToggleFavorite}
                        onPreviewLink={props.onPreviewLink}
                        onUpdateLinkPreview={handleUpdateLinkPreview}
                        onHideDropdown={props.onHideDropdown}/>
        {renderContent()}
        {renderInfo()}
      </div>
  )
}
