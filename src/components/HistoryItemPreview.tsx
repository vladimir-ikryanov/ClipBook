import '../App.css';
import React from "react";

type HistoryItemPreviewProps = {
  text: string
  onEditHistoryItem: (item: string) => void
  onFinishEditing: () => void
  previewTextareaRef?: React.Ref<HTMLTextAreaElement>
}

export default function HistoryItemPreview(props: HistoryItemPreviewProps) {
  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      props.onFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    props.onEditHistoryItem((document.getElementById('preview') as HTMLTextAreaElement).value)
  }

  return (
      <div className="flex flex-col h-screen p-0 m-0">
          <textarea id='preview'
                    ref={props.previewTextareaRef}
                    className="h-full p-2 mt-2 mb-2 ml-2 mr-1 bg-secondary border-none outline-none resize-none font-mono text-sm"
                    value={props.text} onChange={handleOnChange} onKeyDown={handleKeyDown}/>
      </div>
  )
}
