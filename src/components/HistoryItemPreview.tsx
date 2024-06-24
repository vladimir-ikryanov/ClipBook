import '../App.css';
import {TabsContent} from "@/components/ui/tabs";
import React from "react";

type HistoryItemPreviewProps = {
  index: number
  text: string
  appName: string
  onEditHistoryItem: (index: number, item: string) => void
  onFinishEditing: () => void
}

export default function HistoryItemPreview(props: HistoryItemPreviewProps) {
  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      props.onFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    props.onEditHistoryItem(props.index, (document.getElementById('preview') as HTMLTextAreaElement).value)
  }

  return (
      <TabsContent value={props.index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0">
          <textarea id='preview'
              className="h-full p-2 mt-2 mb-2 ml-2 mr-1 bg-secondary border-none outline-none resize-none font-mono text-sm"
              value={props.text} onChange={handleOnChange} onKeyDown={handleKeyDown}/>
        </div>
      </TabsContent>
  )
}
