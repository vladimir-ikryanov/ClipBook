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
        <div className="flex flex-col justify-center items-center">
          <img src={"clipbook://images/" + props.imageFileName} className="flex w-48 h-48"
               alt="Application icon"/>
          <div className="mt-4 text-center text-sm font-mono break-all">{props.filePath}</div>
        </div>
      </div>
  )
}
