import '../App.css';
import {TabsTrigger} from "@/components/ui/tabs";
import {Link, File} from "lucide-react";
import React, {CSSProperties, KeyboardEvent, MouseEvent} from 'react';

type HistoryItemProps = {
  index: number
  historySize: number
  text: string
  onMouseDoubleClick: (tabIndex: number) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItem = (props: HistoryItemProps) => {
  const keyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.stopPropagation()
    }
  }

  const handleMouseDoubleClick = (e: MouseEvent) => {
    props.onMouseDoubleClick(props.index)
    e.preventDefault()
  }

  function isUrl(url: string) {
    const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i;
    return urlRegex.test(url);
  }

  return (
      <TabsTrigger
          id={`tab-${props.index}`}
          style={props.style}
          ref={props.tabsTriggerRef}
          value={props.index.toString()}
          className="flex flex-row data-[state=active]:bg-accent py-2 px-2 whitespace-nowrap overflow-hidden overflow-ellipsis"
          onKeyDown={keyDown}
          onDoubleClick={handleMouseDoubleClick}>
        <div className="flex mr-3 text-primary-foreground">
          {
            isUrl(props.text) ?
                <Link className="h-5 w-5"/> :
                <File className="h-5 w-5"/>
          }
        </div>
        <div
            className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">{props.text}</div>
      </TabsTrigger>
  )
}

export default HistoryItem;
