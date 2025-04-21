import '../app.css';
import React, {KeyboardEvent, MouseEvent, useEffect, useState} from 'react';
import {
  CopyIcon,
  Edit3Icon,
  EllipsisVerticalIcon, EyeIcon,
  GlobeIcon, PenIcon, PlusIcon, ScanTextIcon,
  StarIcon,
  StarOffIcon, TagsIcon,
  TrashIcon
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem, DropdownMenuPortal,
  DropdownMenuSeparator, DropdownMenuSub, DropdownMenuSubContent, DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
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
import {ActionName} from "@/actions";

export type HideClipDropdownMenuReason =
    "cancel"
    | "paste"
    | "pastePath"
    | "toggleFavorite"
    | "editContent"
    | "renameItem"
    | "copyToClipboard"
    | "copyPathToClipboard"
    | "copyTextFromImage"
    | "openInBrowser"
    | "previewLink"
    | "deleteItem"
    | "newTag"

type HistoryItemMenuProps = {
  item: Clip
  index: number
  appName: string
  appIcon: string
  open: boolean
  onOpenChange: (open: boolean) => void
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onPaste: (index: number) => void
  onPastePath: (index: number) => void
  onEditHistoryItem: (item: Clip) => void
  onEditContent: (index: number) => void
  onRenameItem: (index: number) => void
  onCopyToClipboard: (index: number) => void
  onCopyPathToClipboard: (index: number) => void
  onCopyTextFromImage: (index: number) => void
  onOpenInBrowser: (index: number) => void
  onPreviewLink: (index: number) => void
  onDeleteItem: (index: number) => void
}

type TagCheckedState = {
  tag: Tag
  checked: boolean
}

const HistoryItemMenu = (props: HistoryItemMenuProps) => {
  const [open, setOpen] = useState(props.open)
  const [itemTags, setItemTags] = useState<TagCheckedState[]>([])

  useEffect(() => {
    let tags: TagCheckedState[] = []
    allTags().forEach(tag => {
      const checked = !!props.item.tags?.includes(tag.id)
      tags.push({tag, checked})
    })
    setItemTags(tags)
  }, [props.item.tags])

  let closeReason: HideClipDropdownMenuReason = "cancel"

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  const handleMouseDown = (e: MouseEvent) => {
    e.stopPropagation()
  }

  function handleOpenChange(open: boolean) {
    props.onOpenChange(open)
    setOpen(open)
    if (!open) {
      props.onHideClipDropdownMenu(closeReason)
    }
  }

  function handlePaste() {
    closeReason = "paste"
    handleOpenChange(false)
    props.onPaste(props.index)
  }

  function handlePastePath() {
    closeReason = "pastePath"
    handleOpenChange(false)
    props.onPastePath(props.index)
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard(props.index)
  }

  function handleCopyPathToClipboard() {
    closeReason = "copyPathToClipboard"
    handleOpenChange(false)
    props.onCopyPathToClipboard(props.index)
  }

  function handleCopyTextFromImage() {
    closeReason = "copyTextFromImage"
    handleOpenChange(false)
    props.onCopyTextFromImage(props.index)
  }

  function handleToggleFavorite() {
    closeReason = "toggleFavorite"
    handleOpenChange(false)
    props.item.favorite = !props.item.favorite
    props.onEditHistoryItem(props.item)
  }

  function handleEditContent() {
    closeReason = "editContent"
    handleOpenChange(false)
    props.onEditContent(props.index)
  }

  function handleRename() {
    closeReason = "renameItem"
    handleOpenChange(false)
    props.onRenameItem(props.index)
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem(props.index)
  }

  function handleOpenInBrowser() {
    closeReason = "openInBrowser"
    handleOpenChange(false)
    props.onOpenInBrowser(props.index)
  }

  function handlePreviewLink() {
    closeReason = "previewLink"
    handleOpenChange(false)
    props.onPreviewLink(props.index)
  }

  function handleNewTag() {
    closeReason = "newTag"
    handleOpenChange(false)
    window.dispatchEvent(new CustomEvent("onAction", {
      detail: {
        action: ActionName.NewTag,
        itemId: props.item.id
      }
    }));
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
    window.dispatchEvent(new CustomEvent("onAction", {
      detail: {
        action: ActionName.UpdateItem,
        itemId: props.item.id
      }
    }));
  }

  function getItemLabel(): string {
    let item = getHistoryItem(props.index)
    if (item) {
      return ClipType[item.type]
    }
    return ""
  }

  return (
      <div>
        <DropdownMenu open={open} onOpenChange={handleOpenChange}>
          <DropdownMenuTrigger className="ml-2 text-primary-foreground hover:text-accent-foreground"
                               asChild>
            <EllipsisVerticalIcon className="h-5 w-5"/>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="p-1.5 bg-actions-background" align="start"
                               onKeyDown={handleKeyDown} onMouseDown={handleMouseDown}>
            <DropdownMenuItem onClick={handlePaste}>
              <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                   alt="Application icon"/>
              <span className="mr-12">Paste {getItemLabel()} to {props.appName}</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            {
                props.item.type === ClipType.File &&
                <DropdownMenuItem onClick={handlePastePath}>
                  <img src={toBase64Icon(props.appIcon)} className="mr-2 h-4 w-4"
                       alt="Application icon"/>
                  <span className="mr-12">Paste Path to {props.appName}</span>
                </DropdownMenuItem>
            }
            <DropdownMenuItem onClick={handleCopyToClipboard}>
              <CopyIcon className="mr-2 h-4 w-4"/>
              <span className="mr-12">Copy {getItemLabel()} to Clipboard</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            {
                props.item.type === ClipType.File &&
                <DropdownMenuItem onClick={handleCopyPathToClipboard}>
                  <CopyIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">Copy Path to Clipboard</span>
                </DropdownMenuItem>
            }
            <DropdownMenuSeparator/>
            {
                props.item.type === ClipType.Link &&
                <DropdownMenuItem onClick={handleOpenInBrowser}>
                  <GlobeIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">Open in Browser</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                isTextItem(props.item) &&
                <DropdownMenuItem onClick={handleEditContent}>
                  <Edit3Icon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">Edit Content...</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            {
                props.item.type === ClipType.Image && props.item.content.length > 0 &&
                <DropdownMenuItem onClick={handleCopyTextFromImage}>
                  <ScanTextIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">Copy Text from Image</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                  </CommandShortcut>
                </DropdownMenuItem>
            }
            <DropdownMenuItem onClick={handleToggleFavorite}>
              {
                props.item.favorite ? <StarOffIcon className="mr-2 h-4 w-4"/> :
                    <StarIcon className="mr-2 h-4 w-4"/>
              }
              <span>{props.item.favorite ? "Remove from Favorites" : "Add to Favorites"}</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
            <DropdownMenuSeparator/>
            <DropdownMenuSub>
              <DropdownMenuSubTrigger>
                <TagsIcon className="mr-2 h-4 w-4"/>
                <span>Tags...</span>
              </DropdownMenuSubTrigger>
              <DropdownMenuPortal>
                <DropdownMenuSubContent className="p-1.5 bg-actions-background">
                  {
                    itemTags.map((tagState: TagCheckedState) => {
                      return (
                          <DropdownMenuItem key={tagState.tag.id}>
                            <Checkbox className="mr-2 border-checkbox"
                                      checked={tagState.checked}
                                      onCheckedChange={(checked) => handleTagChecked(tagState.tag, checked)}
                                      onClick={(e) => {
                                        e.stopPropagation(); // Prevent closing the menu
                                      }}/>
                            <TagIcon className="mr-2 h-4 w-4" style={{color: tagState.tag.color}}/>
                            <span className="mr-12">{tagState.tag.name}</span>
                          </DropdownMenuItem>
                      )
                    })
                  }
                  <DropdownMenuSeparator/>
                  <DropdownMenuItem onClick={handleNewTag}>
                    <PlusIcon className="mr-2 h-4 w-4"/>
                    <span className="mr-12">New Tag...</span>
                  </DropdownMenuItem>
                </DropdownMenuSubContent>
              </DropdownMenuPortal>
            </DropdownMenuSub>
            <DropdownMenuSeparator/>
            {
              <DropdownMenuItem onClick={handleRename}>
                <PenIcon className="mr-2 h-4 w-4"/>
                <span className="mr-12">Rename...</span>
                <CommandShortcut className="flex flex-row">
                  <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                </CommandShortcut>
              </DropdownMenuItem>
            }
            {
                props.item.type === ClipType.Link && <DropdownMenuSeparator/>
            }
            {
                props.item.type === ClipType.Link &&
                <DropdownMenuItem onClick={handlePreviewLink}>
                  <EyeIcon className="mr-2 h-4 w-4"/>
                  <span className="mr-12">Preview</span>
                </DropdownMenuItem>
            }
            <DropdownMenuSeparator/>
            <DropdownMenuItem onClick={handleDeleteItem}>
              <TrashIcon className="mr-2 h-4 w-4 text-actions-danger"/>
              <span className="text-actions-danger">Delete</span>
              <CommandShortcut className="flex flex-row">
                <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
              </CommandShortcut>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
  )
}

export default HistoryItemMenu;
