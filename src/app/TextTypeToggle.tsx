import '../app.css';
import React, {useEffect, useState} from "react";
import {Clip, ClipType, getHTML, getRTF} from "@/db";
import {ToggleGroup, ToggleGroupItem} from "@/components/ui/toggle-group";
import {emitter} from "@/actions";

export enum TextType {
  Text = "Text",
  HTML = "HTML",
  RTF = "RTF"
}

type TextTypeToggleProps = {
  item: Clip | undefined
}

export default function TextTypeToggle(props: TextTypeToggleProps) {
  let textItemTypes = getSelectedItemTextTypes(props.item)
  if (textItemTypes.length <= 1) {
    return null
  }

  const [types, setTypes] = useState<TextType[]>(textItemTypes)
  const [selectedType, setSelectedType] = useState<TextType>(textItemTypes[0])

  useEffect(() => {
    if (props.item) {
      setTypes(getSelectedItemTextTypes(props.item))
      setSelectedType(TextType.Text)
    }
  }, [props.item]);

  function getSelectedItemTextTypes(item: Clip | undefined): TextType[] {
    if (item && item.type === ClipType.Text) {
      let types: TextType[] = [TextType.Text]
      if (getHTML(item).length > 0) {
        types.push(TextType.HTML)
      }
      if (getRTF(item).length > 0) {
        types.push(TextType.RTF)
      }
      return types
    }
    return []
  }

  function handleSelectTextType(value: TextType) {
    // Do not allow clear selection as we need to have at least one selected type.
    if (!value) {
      return
    }
    setSelectedType(value)
    emitter.emit("SwitchTextType", value)
  }

  return (
      <div className="content-center">
        <ToggleGroup type="single" value={selectedType} onValueChange={handleSelectTextType}
                     className="p-1 content-center items-center rounded-lg">
          {
            types.map((type, index) => {
              return <ToggleGroupItem value={type} key={index} variant="toolbar" size="toolbar"
                                      aria-label={`Toggle ${type}`}>
                {type}
              </ToggleGroupItem>
            })
          }
        </ToggleGroup>
      </div>
  )
}
