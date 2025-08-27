import '../app.css';
import React, {CSSProperties, KeyboardEvent, MouseEvent, useEffect, useState} from 'react';
import {
  fileExists,
  getFilterQuery,
  getFilterVisibleState,
  getPasteNextItemIndex,
  updateHistoryItem
} from "@/data";
import {Clip, ClipType, getFilePath} from "@/db";
import {getFileNameFromPath, hasModifiers, toCSSColor} from "@/lib/utils";
import {
  FileIcon,
  LinkIcon,
  MailIcon, PenLineIcon,
  StarIcon
} from "lucide-react";
import HistoryItemContextMenu from "@/app/HistoryItemContextMenu";
import ShortcutLabel from "@/app/ShortcutLabel";
import {prefShouldPasteOnClick} from "@/pref";
import TagIcon, {getTags} from "@/tags";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

type HistoryItemPaneProps = {
  item: Clip
  index: number
  selectedItemIndices: number[]
  historySize: number
  appName: string
  appIcon: string
  isQuickPasteModifierPressed: boolean
  onItemSelected(index: number, metaKeyDown: boolean, shiftKeyDown: boolean): void
  onMouseDoubleClick: (index: number) => void
  tabsTriggerRef?: React.Ref<HTMLButtonElement>
  style: CSSProperties
}

const HistoryItemPane = (props: HistoryItemPaneProps) => {
  const {t} = useTranslation()

  const [renameItemMode, setRenameItemMode] = useState(false)
  const [itemName, setItemName] = useState(props.item.name ? props.item.name : "")
  const [itemTags, setItemTags] = useState(getTags(props.item.tags))
  const [originalItemName, setOriginalItemName] = useState(props.item.name ? props.item.name : "")
  const [pasteOnClick, setPasteOnClick] = useState(prefShouldPasteOnClick())

  useEffect(() => {
    function handleUpdateItemByIdEvent(itemId?: number) {
      if (itemId === props.item.id) {
        setItemTags(getTags(props.item.tags))
      }
    }

    function handleRenameSelectedItemEvent() {
      if (!isMultipleItemsSelected() && isItemSelected()) {
        setRenameItemMode(true)
      }
    }

    emitter.on("UpdateItemById", handleUpdateItemByIdEvent)
    emitter.on("RenameSelectedItem", handleRenameSelectedItemEvent)
    return () => {
      emitter.off("UpdateItemById", handleUpdateItemByIdEvent)
      emitter.off("RenameSelectedItem", handleRenameSelectedItemEvent)
    };
  }, [])

  function isItemSelected() {
    return props.selectedItemIndices.includes(props.index)
  }

  function isPointer() {
    return props.index == getPasteNextItemIndex() + 1
  }

  function isFilterPaneVisible() {
    return getFilterVisibleState()
  }

  function isMultipleItemsSelected() {
    return props.selectedItemIndices.length > 1
  }

  async function saveItemName(name: string) {
    setItemName(name)
    props.item.name = name
    await updateHistoryItem(props.item.id!, props.item)
  }

  async function handleNameChange(event: React.ChangeEvent<HTMLInputElement>) {
    await saveItemName(event.target.value)
  }

  async function handleFinishRename() {
    setRenameItemMode(false)
    setOriginalItemName(itemName)
    emitter.emit("FocusSearchInput")
  }

  async function handleCancelRename() {
    setRenameItemMode(false)
    await saveItemName(originalItemName)
    emitter.emit("FocusSearchInput")
  }

  function handleFocus(event: React.FocusEvent<HTMLInputElement>) {
    if (props.item.name && props.item.name.length > 0) {
      document.getElementById("animated-input")?.classList.add("animate-text");
      setTimeout(() => {
        document.getElementById("animated-input")?.classList.remove("animate-text");
      }, 300);
    }
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
        await handleCancelRename()
      }
    }
  }

  const handleMouseUp = (e: MouseEvent) => {
    if (renameItemMode) {
      return
    }
    if (pasteOnClick) {
      if (e.metaKey || e.shiftKey) {
        props.onItemSelected(props.index, e.metaKey, e.shiftKey)
      } else {
        if (props.selectedItemIndices.length >= 1) {
          emitter.emit("Paste")
        } else {
          emitter.emit("PasteByIndex", props.index)
        }
      }
    }
    e.preventDefault()
  }

  const handleMouseDown = (e: MouseEvent) => {
    if (renameItemMode || pasteOnClick || e.button !== 0) {
      return
    }
    // Check if this is e.metaKey double click event.
    if (e.detail === 2) {
      props.onMouseDoubleClick(props.index)
    } else {
      props.onItemSelected(props.index, e.metaKey, e.shiftKey)
    }
    e.preventDefault()
  }

  const handleMouseEnter = (e: MouseEvent) => {
    if (pasteOnClick) {
      if (!hasModifiers(e) && !props.selectedItemIndices.includes(props.index)) {
        if (e.relatedTarget !== window) {
          props.onItemSelected(props.index, e.metaKey, e.shiftKey)
        }
      }
    }
    e.preventDefault()
  }

  const handleMouseLeave = (e: MouseEvent) => {
    e.preventDefault()
  }

  function renderClipIcon() {
    if (renameItemMode) {
      return <PenLineIcon className="h-5 w-5 animate-pulse"/>
    }
    if (props.item.type === ClipType.Color) {
      return <div className="h-5 w-5 rounded-full"
                  style={{backgroundColor: toCSSColor(props.item.content)}}/>
    }
    if (props.item.type === ClipType.Link) {
      return <LinkIcon className="h-5 w-5 text-primary-foreground"/>
    }
    if (props.item.type === ClipType.Email) {
      return <MailIcon className="h-5 w-5 text-primary-foreground"/>
    }
    if (props.item.type === ClipType.File) {
      return <img src={"clipbook://images/" + props.item.filePathThumbFileName}
                  alt={props.item.filePathThumbFileName} className="h-5 w-5 object-contain"/>
    }
    if (props.item.type === ClipType.Image) {
      return <img src={"clipbook://images/" + props.item.imageThumbFileName}
                  alt={props.item.imageThumbFileName} className="h-5 w-5 object-contain"/>
    }
    return <FileIcon className="h-5 w-5 text-primary-foreground"/>
  }

  function renderFavoriteIcon() {
    if (props.item.favorite) {
      return (
          <div className="ml-2 justify-center items-center text-primary-foreground">
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

  function renderTags() {
    if (itemTags.length > 0) {
      return <div className="flex space-x-1 ml-1">
        {
          itemTags.map((tag, index) => {
            return <TagIcon key={index} id={"_" + tag.id} className="w-5 h-5"
                            style={{color: tag.color}}/>
          })
        }
      </div>
    }
    return null
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
                   strokeLinejoin="round"
                   className="inline lucide lucide-corner-down-left text-secondary-foreground w-4 h-4">
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
             id="animated-input"
             className="py-0.5 px-1.5 ml-0.5 mr-0 bg-transparent outline-none text-justify font-normal w-full placeholder:text-secondary-foreground"
             value={itemName}
             autoFocus={true}
             placeholder={t("app.history.renamePlaceholder")}
             onChange={handleNameChange}
             onFocus={handleFocus}
             onBlur={handleFinishRename}
             onKeyDown={handleKeyDown}/>
    </div>
  }

  function getItemLabel() {
    if (props.item.name && props.item.name.length > 0) {
      return props.item.name
    }
    if (props.item.type === ClipType.Image) {
      return "Image (" + props.item.imageWidth + "x" + props.item.imageHeight + ")"
    }
    if (props.item.type === ClipType.File) {
      return getFileNameFromPath(getFilePath(props.item))
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

  function isDisabled(): boolean {
    if (props.item && props.item.type === ClipType.File) {
      return fileExists(props.item.filePath)
    }
    return true
  }

  function renderItemPane() {
    return (
        <div id={`tab-${props.index}`}
             style={props.style}
             className={`flex flex-row pr-2 ${isPointer() ? '' : 'pl-2'}`}>
          {
            isPointer() && <div className={`flex flex-none w-[3px] h-8 ${isFilterPaneVisible() ? 'mr-1' : 'ml-[1px] mr-[4px]'} rounded my-auto bg-switch-checked`}></div>
          }
          <div
              className={`flex flex-grow cursor-default select-none items-center ${isItemSelected() ? 'bg-accent' : 'hover:bg-accent-hover'} py-2 px-2 whitespace-nowrap overflow-hidden overflow-ellipsis ${getRoundedStyle()}`}
              onKeyDown={handleKeyDown}
              onMouseUp={handleMouseUp}
              onMouseDown={handleMouseDown}
              onMouseEnter={handleMouseEnter}
              onMouseLeave={handleMouseLeave}>
            <div className="flex flex-none mr-1">{renderClipIcon()}</div>
            <div
                className={`flex-grow text-base text-justify font-normal overflow-hidden overflow-ellipsis ${isDisabled() ? "" : "text-primary-foreground"}`}>
              {
                renameItemMode ? renderInputField() : renderItemLabel(getItemLabel(), getFilterQuery())
              }
            </div>
            {renderTags()}
            {renderFavoriteIcon()}
            {renderQuickPasteAlias()}
          </div>
        </div>
    )
  }

  return (
      <HistoryItemContextMenu item={props.item}
                              index={props.index}
                              appName={props.appName}
                              appIcon={props.appIcon}
                              children={renderItemPane()}
      />
  )
}

export default HistoryItemPane;
