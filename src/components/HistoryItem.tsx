import '../App.css';
import {TabsTrigger} from "@/components/ui/tabs";
import {Link, File} from "lucide-react";
import React, {KeyboardEvent, MouseEvent} from 'react';
import {deleteHistoryItem} from "@/data"

type HistoryItemProps = {
  index: number
  historySize: number
  text: string
  onDeleteHistoryItem: (isLastItem: boolean) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
}

declare const pasteInFrontApp: (text: string) => void;

export default function HistoryItem({index, historySize, text, onDeleteHistoryItem, tabsTriggerRef}: HistoryItemProps) {
  const keyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault()
      pasteInFrontApp(text)
    }
    if (e.key === "Delete" || (e.key === "Backspace" && e.metaKey)) {
      e.preventDefault()
      deleteHistoryItem(text)
      onDeleteHistoryItem(index === historySize - 1)
    }
  }

  const doubleClick = (e: MouseEvent) => {
    e.preventDefault()
    pasteInFrontApp(text)
  }

  function isUrl(url: string) {
    const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i;
    return urlRegex.test(url);
  }

  return (
      <TabsTrigger
          ref={tabsTriggerRef}
          autoFocus={index === 0}
          value={index.toString()}
          className="flex flex-row data-[state=active]:bg-accent ml-3 mr-2 py-2.5 px-3 whitespace-nowrap overflow-hidden overflow-ellipsis"
          onKeyDown={keyDown}
          onDoubleClick={doubleClick}>
        <div className="flex mr-3 text-primary-foreground">
          {
            isUrl(text) ?
                <Link className="h-5 w-5"/> :
                <File className="h-5 w-5"/>
          }
        </div>
        <div
            className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">{text}</div>
      </TabsTrigger>
  )
}
