import '../app.css';
import {useEffect, useState} from "react";
import {Clip} from "@/db";
import {ToggleGroup, ToggleGroupItem} from "@/components/ui/toggle-group";
import {emitter} from "@/actions";
import {TextType} from "@/data";

type TextTypeToggleProps = {
  item: Clip | undefined
  types: TextType[]
}

export default function TextTypeToggle(props: TextTypeToggleProps) {
  const [types, setTypes] = useState<TextType[]>(props.types)
  const [selectedType, setSelectedType] = useState<TextType>(props.types.length >= 1 ? props.types[0] : TextType.Text)

  useEffect(() => {
    if (props.item) {
      setTypes(props.types)
      setSelectedType(TextType.Text)
    }
  }, [props.item]);

  function handleSelectTextType(value: TextType) {
    // Do not allow clear selection as we need to have at least one selected type.
    if (!value) {
      return
    }
    setSelectedType(value)
    emitter.emit("SwitchTextType", value)
  }

  return (
      <div className="content-center" hidden={types.length <= 1}>
        <ToggleGroup type="single" value={selectedType} onValueChange={handleSelectTextType}
                     className="p-1 content-center items-center rounded-lg hover:bg-secondary">
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
