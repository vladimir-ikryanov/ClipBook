import '../app.css';
import React, {useEffect, useState} from "react";
import {
  Dialog,
  DialogContent, DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {Button} from "@/components/ui/button";
import TagIcon, {addTag, Tag, TagColor, updateTag} from "@/tags";
import {Input} from "@/components/ui/input";
import {RadioGroup, RadioGroupColorItem} from "@/components/ui/radio-group";
import {emitter} from "@/actions";
import {Clip} from "@/db";
import {updateHistoryItem} from "@/data";

type TagDialogProps = {
  tag?: Tag
  item?: Clip
  visible: boolean
  onClose: () => void
}

export default function TagDialog(props: TagDialogProps) {
  const [visible, setVisible] = useState<boolean>(props.visible)
  const [tagName, setTagName] = useState<string>(props.tag ? props.tag.name : "")
  const [tagColor, setTagColor] = useState<TagColor>(props.tag ? props.tag.color as TagColor : TagColor.Blue)

  useEffect(() => {
    if (props.visible) {
      setTagName(props.tag ? props.tag.name : "")
      setTagColor(props.tag ? props.tag.color as TagColor : TagColor.Blue)
      // Find the input element by ID, focus it and select its content.
      setTimeout(() => {
        let input = document.getElementById("tagName") as HTMLInputElement
        if (input) {
          input.focus()
          input.select()
        }
      }, 250)
    }
    setVisible(props.visible)
  }, [props.visible, props.tag])

  function handleCancel() {
    props.onClose()
  }

  async function handleSave() {
    if (props.tag) {
      updateTag(props.tag.id, tagName, tagColor)
      emitter.emit("UpdateTagById", props.tag.id)
    } else {
      let tag = new Tag(tagName, tagColor)
      addTag(tag)
      if (props.item) {
        if (props.item.tags) {
          props.item.tags = [...props.item.tags, tag.id]
        } else {
          props.item.tags = [tag.id]
        }
        await updateHistoryItem(props.item.id!, props.item)
        emitter.emit("UpdateItemById", props.item.id)
      }
    }
    emitter.emit("UpdateTags")
    props.onClose()
  }

  function handleValueChange(e: React.ChangeEvent<HTMLInputElement>) {
    setTagName(e.target.value)
  }

  async function handleKeyDown(e: React.KeyboardEvent) {
    e.stopPropagation()
    if (e.key === "Enter" && tagName.length > 0) {
      await handleSave()
    }
    if (e.key === "Escape") {
      handleCancel()
    }
  }

  function handleColorChange(value: TagColor) {
    setTagColor(value)
  }

  return (
      <Dialog open={visible}>
        <DialogContent onKeyDown={handleKeyDown} className="w-fit">
          <DialogHeader>
            <DialogTitle className="mx-auto">{props.tag ? "Edit tag" : "New tag"}</DialogTitle>
            <DialogDescription className="mx-auto"></DialogDescription>
          </DialogHeader>
          <div className="flex items-center bg-secondary rounded-lg">
            <TagIcon className="p-0.5 mt-0.5 ml-3 mr-1" style={{color: tagColor}}/>
            <Input id="tagName"
                   autoFocus={true}
                   value={tagName}
                   onChange={handleValueChange}
                   onKeyDown={handleKeyDown}
                   placeholder="Tag name"
                   className="text-base placeholder:text-settings-inputPlaceholder border-none bg-secondary px-1"/>
          </div>
          <RadioGroup value={tagColor}
                      onValueChange={handleColorChange}
                      className="flex w-full items-center space-x-2 mt-1 mb-4 px-3">
            <RadioGroupColorItem value={TagColor.Blue} id="r1" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Blue}}/>
            <RadioGroupColorItem value={TagColor.Sky} id="r2" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Sky}}/>
            <RadioGroupColorItem value={TagColor.Lime} id="r3" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Lime}}/>
            <RadioGroupColorItem value={TagColor.Green} id="r4" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Green}}/>
            <RadioGroupColorItem value={TagColor.Yellow} id="r5" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Yellow}}/>
            <RadioGroupColorItem value={TagColor.Orange} id="r6" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Orange}}/>
            <RadioGroupColorItem value={TagColor.Red} id="r7" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Red}}/>
            <RadioGroupColorItem value={TagColor.Pink} id="r8" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Pink}}/>
            <RadioGroupColorItem value={TagColor.Purple} id="r9" className="w-5 h-5 rounded-full"
                                 style={{backgroundColor: TagColor.Purple}}/>
          </RadioGroup>
          <DialogFooter className="mx-auto">
            <Button variant="secondary" onClick={handleCancel}>Cancel</Button>
            <Button variant="primary" onClick={handleSave} disabled={tagName.length === 0}>
              {
                props.tag ? "Save" : "Create"
              }
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
  )
}
