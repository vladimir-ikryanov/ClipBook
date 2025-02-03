import '../app.css';
import React, {CSSProperties, KeyboardEvent, MouseEvent, useEffect, useState} from 'react';
import {getFilterQuery} from "@/data";
import {Clip, ClipType, updateClip} from "@/db";
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
  selectedItemIndices: number[]
  historySize: number
  appName: string
  appIcon: string
  isQuickPasteModifierPressed: boolean
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onMouseDown(index: number, metaKeyDown: boolean, shiftKeyDown: boolean): void
  onMouseDoubleClick: (index: number) => void
  onPaste: (index: number) => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: (index: number) => void
  onCopyToClipboard: (index: number) => void
  onCopyTextFromImage: (index: number) => void
  onOpenInBrowser: (index: number) => void
  onPreviewLink: (index: number) => void
  onDeleteItem: (index: number) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItemPane = (props: HistoryItemPaneProps) => {
  const [mouseOver, setMouseOver] = useState(false)
  const [renameItemMode, setRenameItemMode] = useState(false)
  const [actionsMenuOpen, setActionsMenuOpen] = useState(false)
  const [itemName, setItemName] = useState(props.item.name ? props.item.name : "")
  const [originalItemName, setOriginalItemName] = useState(props.item.name ? props.item.name : "")

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === "renameItem" && !isMultipleItemsSelected() && isItemSelected()) {
        setRenameItemMode(true)
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [])

  function isItemSelected() {
    return props.selectedItemIndices.includes(props.index)
  }

  function isMultipleItemsSelected() {
    return props.selectedItemIndices.length > 1
  }

  async function saveItemName(name: string) {
    setItemName(name)
    props.item.name = name
    await updateClip(props.item.id!, props.item)
  }

  async function handleNameChange(event: React.ChangeEvent<HTMLInputElement>) {
    await saveItemName(event.target.value)
  }

  async function handleFinishRename() {
    setRenameItemMode(false)
    setOriginalItemName(itemName)
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "focusSearchInput"}}));
  }

  async function handleCancelRename() {
    setRenameItemMode(false)
    await saveItemName(originalItemName)
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "focusSearchInput"}}));
  }

  function handleDropdownMenuOpenChange(open: boolean) {
    setActionsMenuOpen(open)
  }

  const handleKeyDown = async (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
    if (renameItemMode) {
      if (e.key === "Enter") {
        await handleFinishRename()
      }
      if (e.key === "Escape") {
        handleCancelRename()
      }
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    if (renameItemMode) {
      return
    }
    // Check if this is e.metaKey double click event.
    if (e.detail === 2) {
      props.onMouseDoubleClick(props.index)
    } else {
      props.onMouseDown(props.index, e.metaKey, e.shiftKey)
    }
    e.preventDefault()
  }

  const handleMouseEnter = (e: MouseEvent) => {
    setMouseOver(true)
    e.preventDefault()
  }

  const handleMouseLeave = (e: MouseEvent) => {
    setMouseOver(false)
    e.preventDefault()
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
      return <img src={"clipbook://images/" + props.item.imageThumbFileName}
                  alt={props.item.imageThumbFileName} className="h-5 w-5"/>
    }
    return <FileIcon className="h-5 w-5"/>
  }

  function renderActionsButton() {
    if (props.isQuickPasteModifierPressed) {
      return renderQuickPasteAlias()
    }
    if (mouseOver || actionsMenuOpen) {
      if (props.selectedItemIndices.length === 1 ||
          (isMultipleItemsSelected() && !props.selectedItemIndices.includes(props.index))) {
        return <HistoryItemMenu item={props.item}
                                index={props.index}
                                appName={props.appName}
                                appIcon={props.appIcon}
                                open={actionsMenuOpen}
                                onOpenChange={handleDropdownMenuOpenChange}
                                onHideClipDropdownMenu={props.onHideClipDropdownMenu}
                                onPaste={props.onPaste}
                                onEditHistoryItem={props.onEditHistoryItem}
                                onEditContent={props.onEditContent}
                                onCopyToClipboard={props.onCopyToClipboard}
                                onCopyTextFromImage={props.onCopyTextFromImage}
                                onOpenInBrowser={props.onOpenInBrowser}
                                onPreviewLink={props.onPreviewLink}
                                onDeleteItem={props.onDeleteItem}/>
      }
    }
    return renderFavoriteIcon()
  }

  function renderFavoriteIcon() {
    if (props.item.favorite) {
      return (
          <div className="ml-4 justify-center items-center text-primary-foreground">
            <StarIcon className="h-4 w-5"/>
          </div>
      )
    }
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

  function highlightSearchMatches(text: string, query: string) {
    if (query.length === 0) {
      return text
    }
    const escapedQuery = escapeRegExp(query)
    const regex = new RegExp(`(${escapedQuery})`, 'gi')
    const parts = text.split(regex)
    return <span>{
      parts.map((part, index) =>
          part.toLowerCase() === query.toLowerCase() ?
              <span key={index} className="text-searchHighlight font-bold">{part}</span> : part)
    }</span>
  }

  function renderItemLabel(text: string, query: string) {
    // Replace new lines with the Return character.
    let parts = text.split("\n")
    return <div className="ml-2 space-x-1 whitespace-nowrap overflow-hidden overflow-ellipsis">{
      parts.map((line, index) => {
        return <div className="inline" key={index}>
          <span className="inline">{highlightSearchMatches(line, query)}</span>
          {
              index < parts.length - 1 &&
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
                   fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"
                   strokeLinejoin="round" className="inline lucide lucide-corner-down-left text-secondary-foreground w-4 h-4">
                <polyline points="9 10 4 15 9 20"/>
                <path d="M20 4v7a4 4 0 0 1-4 4H4"/>
              </svg>
          }
        </div>
      })
    }</div>
  }

  function renderInputField() {
    return <div className="flex flex-grow">
      <input type="text"
             className="py-0.5 px-1.5 ml-0.5 mr-0 rounded-sm border-none outline-none text-justify font-normal w-full"
             value={itemName}
             autoFocus={true}
             placeholder="Enter a name for this item"
             onChange={handleNameChange}
             onBlur={handleFinishRename}
             onKeyDown={handleKeyDown}/>
    </div>
  }

  function getItemLabel() {
    if (props.item.name && props.item.name.length > 0) {
      return props.item.name
    }
    if (props.item.type === ClipType.Image) {
      if (props.item.imageText && props.item.imageText.length > 0) {
        return props.item.imageText
      }
      return "Image (" + props.item.imageWidth + "x" + props.item.imageHeight + ")"
    }
    let content = props.item.content
    if (content.length > 256) {
      content = content.substring(0, 256)
    }
    return content
  }

  function getRoundedStyle() {
    let result = ""
    if (isMultipleItemsSelected()) {
      // Check if there's selected item before the current item.
      if (!props.selectedItemIndices.includes(props.index - 1)) {
        result += " rounded-t-md"
      }
      // Check if there's selected item after the current item.
      if (!props.selectedItemIndices.includes(props.index + 1)) {
        result += " rounded-b-md"
      }
    } else {
      result = "rounded-md"
    }
    return result
  }

  return (
      <div
          id={`tab-${props.index}`}
          style={props.style}
          className={`flex flex-row cursor-default select-none items-center ${isItemSelected() ? 'bg-accent' : 'hover:bg-popover'} py-2 px-2 whitespace-nowrap overflow-hidden overflow-ellipsis ${getRoundedStyle()}`}
          onKeyDown={handleKeyDown}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}>
        <div className="flex flex-none mr-1 text-primary-foreground">{renderClipIcon()}</div>
        <div
            className="flex-grow text-base text-justify font-normal overflow-hidden overflow-ellipsis">
          {
            renameItemMode ? renderInputField() : renderItemLabel(getItemLabel(), getFilterQuery())
          }
        </div>
        {renderActionsButton()}
      </div>
  )
}

export default HistoryItemPane;
