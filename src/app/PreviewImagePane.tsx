import '../app.css';
import React from "react";
import {Clip} from "@/db";

type PreviewImagePaneProps = {
  item: Clip
}

export default function PreviewImagePane(props: PreviewImagePaneProps) {
  return (
      <div
          className="flex flex-grow m-4 mt-0.5 items-center justify-center outline-none resize-none overflow-hidden">
        <img src={"clipbook://images/" + props.item.imageFileName} alt={props.item.content}
             className="max-h-full max-w-full object-contain"/>
      </div>
  )
}
