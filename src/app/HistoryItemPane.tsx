import '../app.css';
import {TabsTrigger} from "@/components/ui/tabs";
import React, {CSSProperties, KeyboardEvent, MouseEvent, useState} from 'react';
import {getFilterQuery} from "@/data";
import {Clip, ClipType} from "@/db";
import {toCSSColor} from "@/lib/utils";
import {
  FileIcon,
  LinkIcon,
  MailIcon,
  PinIcon
} from "lucide-react";
import ClipDropdownMenu, {HideClipDropdownMenuReason} from "@/app/ClipDropdownMenu";

type HistoryItemPaneProps = {
  item: Clip
  index: number
  historySize: number
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onMouseDoubleClick: (tabIndex: number) => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItemPane = (props: HistoryItemPaneProps) => {
  const [mouseOver, setMouseOver] = useState(false)
  const [actionsMenuOpen, setActionsMenuOpen] = useState(false)

  function handleDropdownMenuOpenChange(open: boolean) {
    setActionsMenuOpen(open)
  }

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDoubleClick = (e: MouseEvent) => {
    props.onMouseDoubleClick(props.index)
    e.preventDefault()
  }

  function handleMouseEnter() {
    setMouseOver(true)
  }

  function handleMouseLeave() {
    setMouseOver(false)
  }

  function renderClipIcon() {
    if (props.item.type === ClipType.Color) {
      return <div className="h-5 w-5 rounded-full"
                  style={{backgroundColor: toCSSColor(props.item.content)}}/>
    }
    if (props.item.type === ClipType.Link) {
      return <LinkIcon className="h-5 w-5"/>
    }
    if (props.item.type === ClipType.Email) {
      return <MailIcon className="h-5 w-5"/>
    }
    return <FileIcon className="h-5 w-5"/>
  }

  function renderActionsButton() {
    if (mouseOver || actionsMenuOpen) {
      return <ClipDropdownMenu item={props.item}
                               onOpenChange={handleDropdownMenuOpenChange}
                               onHideClipDropdownMenu={props.onHideClipDropdownMenu}
                               onEditHistoryItem={props.onEditHistoryItem}
                               onEditContent={props.onEditContent}
                               onCopyToClipboard={props.onCopyToClipboard}
                               onOpenInBrowser={props.onOpenInBrowser}
                               onDeleteItem={props.onDeleteItem}/>
    }
    return renderPinIcon()
  }

  function renderPinIcon() {
    if (!props.item.pinned) {
      return null
    }
    return <div className="ml-4 justify-center items-center text-primary-foreground">
      <PinIcon className="h-4 w-5"/>
    </div>
  }

  function highlightAllMatches(text: string, query: string) {
    if (!query) {
      return text;
    }

    const regex = new RegExp(`(${query})`, 'gi');
    const parts = text.split(regex);
    return <span>{
      parts.map((part, index) =>
          part.toLowerCase() === query.toLowerCase() ?
              <span key={index} className="text-searchHighlight font-bold">{part}</span> : part)
    }</span>
  }

  return (
      <TabsTrigger
          id={`tab-${props.index}`}
          style={props.style}
          ref={props.tabsTriggerRef}
          value={props.index.toString()}
          className="flex flex-row cursor-default data-[state=active]:bg-accent py-2 px-2 whitespace-nowrap overflow-hidden overflow-ellipsis hover:bg-popover"
          onKeyDown={handleKeyDown}
          onDoubleClick={handleMouseDoubleClick}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}>
        <div className="flex mr-3 text-primary-foreground">{renderClipIcon()}</div>
        <div
            className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">
          {
            highlightAllMatches(props.item.content, getFilterQuery())
          }
        </div>
        {renderActionsButton()}
      </TabsTrigger>
  )
}

export default HistoryItemPane;
