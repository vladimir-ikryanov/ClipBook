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
  StarIcon
} from "lucide-react";
import HistoryItemMenu, {HideClipDropdownMenuReason} from "@/app/HistoryItemMenu";
import ShortcutLabel from "@/app/ShortcutLabel";

type HistoryItemPaneProps = {
  item: Clip
  index: number
  historySize: number
  appName: string
  appIcon: string
  isQuickPasteModifierPressed: boolean
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onMouseDoubleClick: (tabIndex: number) => void
  onPaste: () => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
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
    if (props.item.type === ClipType.Image) {
      return <img src={"clipbook://images/" + props.item.imageThumbFileName} alt={props.item.imageThumbFileName} className="h-5 w-5"/>
    }
    return <FileIcon className="h-5 w-5"/>
  }

  function renderActionsButton() {
    if (props.isQuickPasteModifierPressed) {
      return renderQuickPasteAlias()
    }
    if (mouseOver || actionsMenuOpen) {
      return <HistoryItemMenu item={props.item}
                              appName={props.appName}
                              appIcon={props.appIcon}
                              onOpenChange={handleDropdownMenuOpenChange}
                              onHideClipDropdownMenu={props.onHideClipDropdownMenu}
                              onPaste={props.onPaste}
                              onEditHistoryItem={props.onEditHistoryItem}
                              onEditContent={props.onEditContent}
                              onCopyToClipboard={props.onCopyToClipboard}
                              onCopyTextFromImage={props.onCopyTextFromImage}
                              onOpenInBrowser={props.onOpenInBrowser}
                              onDeleteItem={props.onDeleteItem}/>
    }
    return renderStarIcon()
  }

  function renderStarIcon() {
    if (!props.item.favorite) {
      return null
    }
    return <div className="ml-4 justify-center items-center text-primary-foreground">
      <StarIcon className="h-4 w-5"/>
    </div>
  }

  function renderQuickPasteAlias() {
    if (!props.isQuickPasteModifierPressed) {
      return null
    }
    if (props.index >= 9) {
      return null
    }
    return <div className="flex flex-none ml-4">
      <ShortcutLabel shortcut={String(props.index + 1)}/>
    </div>
  }

  function escapeRegExp(string: string) {
    // Escapes special characters used in regular expressions
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function highlightAllMatches(text: string, query: string) {
    if (!query) {
      return text;
    }

    const escapedQuery = escapeRegExp(query);
    const regex = new RegExp(`(${escapedQuery})`, 'gi');
    const parts = text.split(regex);
    return <span>{
      parts.map((part, index) =>
          part.toLowerCase() === query.toLowerCase() ?
              <span key={index} className="text-searchHighlight font-bold">{part}</span> : part)
    }</span>
  }

  function getItemLabel() {
    if (props.item.type === ClipType.Image) {
      if (props.item.imageText && props.item.imageText.length > 0) {
        return props.item.imageText;
      }
      return "Image (" + props.item.imageWidth + "x" + props.item.imageHeight + ")";
    }
    return props.item.content;
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
        <div className="flex flex-none mr-3 text-primary-foreground">{renderClipIcon()}</div>
        <div
            className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">
          {
            highlightAllMatches(getItemLabel(), getFilterQuery())
          }
        </div>
        {renderActionsButton()}
      </TabsTrigger>
  )
}

export default HistoryItemPane;
