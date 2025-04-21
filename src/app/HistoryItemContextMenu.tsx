import '../app.css';
import React, {KeyboardEvent, MouseEvent, useEffect, useState} from 'react';
import {
  CopyIcon,
  Edit3Icon,
  EyeIcon,
  GlobeIcon, PenIcon, PlusIcon, ScanTextIcon,
  StarIcon,
  StarOffIcon, TagsIcon,
  TrashIcon
} from "lucide-react";
import ShortcutLabel from "@/app/ShortcutLabel";
import {
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut, prefGetRenameItemShortcut,
  prefGetToggleFavoriteShortcut,
} from "@/pref";
import {CommandShortcut} from "@/components/ui/command";
import {Clip, ClipType, updateClip} from "@/db";
import {
  getHistoryItem,
  isTextItem,
  toBase64Icon
} from "@/data";
import TagIcon, {allTags, Tag} from "@/tags";
import {Checkbox} from "@/components/ui/checkbox";
import {CheckedState} from "@radix-ui/react-checkbox";
import {emitter} from "@/actions";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuPortal,
  ContextMenuSeparator,
  ContextMenuSub,
  ContextMenuSubContent,
  ContextMenuSubTrigger,
  ContextMenuTrigger
} from "@/components/ui/context-menu";

type HistoryItemContextMenuProps = {
  item: Clip
  index: number
  appName: string
  appIcon: string
  children: React.ReactNode
}

type TagCheckedState = {
  tag: Tag
  checked: boolean
}

const HistoryItemContextMenu = (props: HistoryItemContextMenuProps) => {
  const [itemTags, setItemTags] = useState<TagCheckedState[]>([])

  useEffect(() => {
    let tags: TagCheckedState[] = []
    allTags().forEach(tag => {
      const checked = !!props.item.tags?.includes(tag.id)
      tags.push({tag, checked})
    })
    setItemTags(tags)
  }, [props.item.tags])

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
  }

  function handlePaste() {
    emitter.emit("PasteByIndex", props.index)
  }

  function handlePastePath() {
    emitter.emit("PastePathByIndex", props.index)
  }

  function handleCopyToClipboard() {
    emitter.emit("CopyToClipboardByIndex", props.index)
  }

  function handleCopyPathToClipboard() {
    emitter.emit("CopyPathToClipboardByIndex", props.index)
  }

  function handleCopyTextFromImage() {
    emitter.emit("CopyTextFromImageByIndex", props.index)
  }

  function handleToggleFavorite() {
    props.item.favorite = !props.item.favorite
    emitter.emit("EditItem", props.item)
  }

  function handleEditContent() {
    emitter.emit("EditContentByIndex", props.index)
  }

  function handleRename() {
    emitter.emit("RenameItemByIndex", props.index)
  }

  function handleDeleteItem() {
    emitter.emit("DeleteItemByIndex", props.index)
  }

  function handleOpenInBrowser() {
    emitter.emit("OpenLinkItemInBrowserByIndex", props.index)
  }

  function handlePreviewLink() {
    emitter.emit("PreviewLinkItemByIndex", props.index)
  }

  function handleNewTag() {
    emitter.emit("AddTagToItemWithId", props.item.id)
  }

  async function handleTagChecked(tag: Tag, checked: CheckedState) {
    if (checked) {
      props.item.tags = [...props.item.tags || [], tag.id]
    } else {
      props.item.tags = props.item.tags?.filter((t) => t !== tag.id)
    }
    await updateClip(props.item.id!, props.item)
    let tags = itemTags.map(tagState => {
      if (tagState.tag.id === tag.id) {
        tagState.checked = !!checked
      }
      return tagState
    })
    setItemTags([...tags])
    emitter.emit("UpdateItemById", props.item.id)
  }

  function getItemLabel(): string {
    let item = getHistoryItem(props.index)
    if (item) {
      return ClipType[item.type]
    }
    return ""
  }

  return (
      <ContextMenu>
        <ContextMenuTrigger asChild>
          {props.children}
        </ContextMenuTrigger>
        <ContextMenuContent className="p-1.5 bg-actions-background"
                            onKeyDown={handleKeyDown} onMouseDown={handleMouseDown}>
          <ContextMenuItem onClick={handlePaste}>
            <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                 alt="Application icon"/>
            <span className="mr-12">Paste {getItemLabel()} to {props.appName}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          {
              props.item.type === ClipType.File &&
              <ContextMenuItem onClick={handlePastePath}>
                <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                     alt="Application icon"/>
                <span className="mr-12">Paste Path to {props.appName}</span>
              </ContextMenuItem>
          }
          <ContextMenuItem onClick={handleCopyToClipboard}>
            <CopyIcon className="mr-2 h-4 w-4"/>
            <span className="mr-12">Copy {getItemLabel()} to Clipboard</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          {
              props.item.type === ClipType.File &&
              <ContextMenuItem onClick={handleCopyPathToClipboard}>
                <CopyIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Copy Path to Clipboard</span>
              </ContextMenuItem>
          }
          <ContextMenuSeparator/>
          {
              props.item.type === ClipType.Link &&
              <ContextMenuItem onClick={handleOpenInBrowser}>
                <GlobeIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Open in Browser</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              isTextItem(props.item) &&
              <ContextMenuItem onClick={handleEditContent}>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Edit Content...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          {
              props.item.type === ClipType.Image && props.item.content.length > 0 &&
              <ContextMenuItem onClick={handleCopyTextFromImage}>
                <ScanTextIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Copy Text from Image</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                </CommandShortcut>
              </ContextMenuItem>
          }
          <ContextMenuItem onClick={handleToggleFavorite}>
            {
              props.item.favorite ? <StarOffIcon className="mr-2 h-4 w-4"/> :
                  <StarIcon className="mr-2 h-4 w-4"/>
            }
            <span>{props.item.favorite ? "Remove from Favorites" : "Add to Favorites"}</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
          <ContextMenuSeparator/>
          <ContextMenuSub>
            <ContextMenuSubTrigger>
              <TagsIcon className="mr-2 h-4 w-4"/>
              <span>Tags...</span>
            </ContextMenuSubTrigger>
            <ContextMenuPortal>
              <ContextMenuSubContent className="p-1.5 bg-actions-background">
                {
                  itemTags.map((tagState: TagCheckedState) => {
                    return (
                        <ContextMenuItem key={tagState.tag.id}>
                          <Checkbox className="mr-2 border-checkbox"
                                    checked={tagState.checked}
                                    onCheckedChange={(checked) => handleTagChecked(tagState.tag, checked)}
                                    onClick={(e) => {
                                      e.stopPropagation(); // Prevent closing the menu
                                    }}/>
                          <TagIcon className="mr-2 h-4 w-4" style={{color: tagState.tag.color}}/>
                          <span className="mr-12">{tagState.tag.name}</span>
                        </ContextMenuItem>
                    )
                  })
                }
                <ContextMenuSeparator/>
                <ContextMenuItem onClick={handleNewTag}>
                  <PlusIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">New Tag...</span>
                </ContextMenuItem>
              </ContextMenuSubContent>
            </ContextMenuPortal>
          </ContextMenuSub>
          <ContextMenuSeparator/>
          {
            <ContextMenuItem onClick={handleRename}>
              <PenIcon className="mr-2 h-4 w-4"/>
              <span className="mr-12">Rename...</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
              </CommandShortcut>
            </ContextMenuItem>
          }
          {
              props.item.type === ClipType.Link && <ContextMenuSeparator/>
          }
          {
              props.item.type === ClipType.Link &&
              <ContextMenuItem onClick={handlePreviewLink}>
                <EyeIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Preview</span>
              </ContextMenuItem>
          }
          <ContextMenuSeparator/>
          <ContextMenuItem onClick={handleDeleteItem}>
            <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
            <span className="text-actions-danger">Delete</span>
            <CommandShortcut className="flex flex-row">
              <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
            </CommandShortcut>
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>
  )
}

export default HistoryItemContextMenu;
