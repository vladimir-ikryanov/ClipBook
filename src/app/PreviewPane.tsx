import '../app.css';
import React, {useEffect, useState} from "react";
import PreviewToolBar from "@/app/PreviewToolBar";
import {Clip, ClipType, getFilePath} from "@/db";
import ItemInfoPane from "@/app/ItemInfoPane";
import {
  getActiveHistoryItemIndex,
  getHistoryItem,
  getSelectedHistoryItems,
} from "@/data";
import PreviewTextPane from "@/app/PreviewTextPane";
import PreviewImagePane from "@/app/PreviewImagePane";
import ItemsInfoPane from "@/app/ItemsInfoPane";
import PreviewItemsPane from "@/app/PreviewItemsPane";
import PreviewColorPane from "@/app/PreviewColorPane";
import PreviewLinkPane from "@/app/PreviewLinkPane";
import {prefShouldShowPreviewForLinks} from "@/pref";
import PreviewFilePane from "@/app/PreviewFilePane";
import {emitter} from "@/actions";

type PreviewPaneProps = {
  selectedItemIndices: number[]
  activeItemIndex: number
  appName: string
  appIcon: string
  visible: boolean
  editMode: boolean
  detailsVisible: boolean
  onRequestEditItem: () => void
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewPane(props: PreviewPaneProps) {
  if (props.selectedItemIndices.length === 0 && props.activeItemIndex === -1) {
    return <div
        className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]"></div>
  }

  const [updateLinkPreview, setUpdateLinkPreview] = useState(false)

  useEffect(() => {
    emitter.on("UpdateLinkPreview", handleUpdateLinkPreview)
    return () => {
      emitter.off("UpdateLinkPreview", handleUpdateLinkPreview)
    };
  }, []);

  function handleUpdateLinkPreview() {
    setUpdateLinkPreview(true)
  }

  function handleLinkPreviewUpdated() {
    setUpdateLinkPreview(false)
  }

  function renderContent() {
    if (props.selectedItemIndices.length !== 0) {
      return <PreviewItemsPane items={getSelectedHistoryItems()}/>
    }
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index)
    if (!item) {
      return null
    }
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
    if (item.type === ClipType.File) {
      return <PreviewFilePane filePath={getFilePath(item)}
                              imageFileName={item.filePathFileName}
                              fileSizeInBytes={item.fileSizeInBytes}
                              isFolder={item.fileFolder}/>
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

  function renderDetails() {
    if (props.selectedItemIndices.length !== 0) {
      return <ItemsInfoPane items={getSelectedHistoryItems()} display={props.detailsVisible}/>
    }
    let index = getActiveHistoryItemIndex()
    let item = getHistoryItem(index)
    if (item) {
      return <ItemInfoPane item={item} visible={props.detailsVisible}/>
    }
  }

  return (
      <div className="flex flex-col h-screen p-0 m-0 border-l border-l-border min-w-[300px]">
        <PreviewToolBar selectedItemIndices={props.selectedItemIndices}
                        appName={props.appName}
                        appIcon={props.appIcon}
                        displayInfo={props.detailsVisible}
                        onRequestEditItem={props.onRequestEditItem}
        />
        {renderContent()}
        {renderDetails()}
      </div>
  )
}
