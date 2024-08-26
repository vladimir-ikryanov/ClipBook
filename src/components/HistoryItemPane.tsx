import '../App.css';
import {TabsTrigger} from "@/components/ui/tabs";
import {Link, File} from "lucide-react";
import React, {CSSProperties, KeyboardEvent, MouseEvent} from 'react';
import {getFilterQuery, HistoryItem, isUrl, toCSSColor} from "@/data";

type HistoryItemPaneProps = {
  index: number
  historySize: number
  item: HistoryItem
  onMouseDoubleClick: (tabIndex: number) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItemPane = (props: HistoryItemPaneProps) => {
  const cssColor = toCSSColor(props.item.content)

  const keyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.stopPropagation()
    }
  }

  const handleMouseDoubleClick = (e: MouseEvent) => {
    props.onMouseDoubleClick(props.index)
    e.preventDefault()
  }

  function highlightAllMatches(text: string, query: string) {
    if (!query) {
      return text;
    }

    const regex = new RegExp(`(${query})`, 'gi');
    const parts = text.split(regex);

    return (
        <span>
      {
        parts.map((part, index) =>
            part.toLowerCase() === query.toLowerCase() ? (
                <span key={index} className="text-searchHighlight font-bold">{part}</span>) : (part)
        )
      }
    </span>
    );
  }

  return (
      <TabsTrigger
          id={`tab-${props.index}`}
          style={props.style}
          ref={props.tabsTriggerRef}
          value={props.index.toString()}
          className="flex flex-row cursor-default data-[state=active]:bg-accent py-2 px-2 whitespace-nowrap overflow-hidden overflow-ellipsis hover:bg-popover"
          onKeyDown={keyDown}
          onDoubleClick={handleMouseDoubleClick}>
        <div className="flex mr-3 text-primary-foreground">
          {
            cssColor !== '' ?
                <div className="h-5 w-5 rounded-full" style={{backgroundColor: cssColor}}/> :
                isUrl(props.item.content) ?
                    <Link className="h-5 w-5"/> :
                    <File className="h-5 w-5"/>
          }
        </div>
        <div
            className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">
          {
            highlightAllMatches(props.item.content, getFilterQuery())
          }
        </div>
      </TabsTrigger>
  )
}

export default HistoryItemPane;
