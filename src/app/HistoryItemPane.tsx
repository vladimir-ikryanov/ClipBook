import '../app.css';
import {TabsTrigger} from "@/components/ui/tabs";
import {File, Link} from "lucide-react";
import React, {CSSProperties, KeyboardEvent, MouseEvent} from 'react';
import {getFilterQuery} from "@/data";
import {Clip, ClipType} from "@/db";
import {isUrl, toCSSColor} from "@/lib/utils";

type HistoryItemPaneProps = {
  item: Clip
  index: number
  historySize: number
  onMouseDoubleClick: (tabIndex: number) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItemPane = (props: HistoryItemPaneProps) => {
  const keyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.stopPropagation()
    }
  }

  const handleMouseDoubleClick = (e: MouseEvent) => {
    props.onMouseDoubleClick(props.index)
    e.preventDefault()
  }

  function isColor(): boolean {
    return props.item.type === ClipType.Color
  }

  function isLink(): boolean {
    return props.item.type === ClipType.Link
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
            isColor() ?
                <div className="h-5 w-5 rounded-full"
                     style={{backgroundColor: toCSSColor(props.item.content)}}/> :
                isUrl(props.item.content) ? <Link className="h-5 w-5"/> :
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
