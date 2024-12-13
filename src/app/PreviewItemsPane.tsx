import '../app.css';
import React, {useEffect} from "react";
import {Clip, ClipType} from "@/db";

type PreviewItemsPaneProps = {
  items: Clip[]
}

export default function PreviewItemsPane(props: PreviewItemsPaneProps) {
  useEffect(() => {
    let element = document.getElementById("last")
    element?.scrollIntoView({behavior: 'smooth', block: 'nearest'})
  }, [props.items])

  function renderItem(item: Clip, index: number) {
    if (item.type === ClipType.Image) {
      return renderImageItem(item, index)
    }
    return renderTextItem(item, index)
  }

  function renderTextItem(item: Clip, index: number) {
    let last = index === props.items.length - 1
    return (
        <div key={index}
             id={last ? "last" : ""}
             className={`flex-grow py-2 px-4 font-mono text-sm whitespace-pre-wrap ${last ? "" : "border-b border-b-preview-border"}`}>
          {item.content}
        </div>
    )
  }

  function renderImageItem(item: Clip, index: number) {
    let last = index === props.items.length - 1
    return (
        <div key={index}
             id={last ? "last" : ""}
             className={`flex flex-grow m-0 bg-secondary items-center justify-center outline-none resize-none overflow-hidden ${last ? "" : "border-b border-b-preview-border"}`}>
          <img src={"clipbook://images/" + item.imageFileName} alt={item.content}
               className="max-h-full max-w-full object-contain"/>
        </div>
    )
  }

  return (
      <div className="flex flex-col h-full border-t border-t-preview-border overflow-y-auto">
        {
          props.items.map((item, index) => (
              <div key={index} className="flex flex-col">
                {renderItem(item, index)}
              </div>
          ))
        }
      </div>
  )
}
