import '../app.css';
import React from "react";

type PreviewFilePaneProps = {
  filePath: string
  imageFileName: string
  fileSizeInBytes: number
  isFolder: boolean
}

export default function PreviewFilePane(props: PreviewFilePaneProps) {
  return (
      <div className="flex flex-grow mx-4 items-center justify-center overflow-auto">
          <img src={"clipbook://images/" + props.imageFileName} className="w-full h-full object-contain"
               alt="Application icon"/>
      </div>
  )
}
