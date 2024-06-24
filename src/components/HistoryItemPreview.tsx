import '../App.css';
import {TabsContent} from "@/components/ui/tabs";

type HistoryItemPreviewProps = {
  index: number
  text: string
  appName: string
}

export default function HistoryItemPreview(props: HistoryItemPreviewProps) {
  return (
      <TabsContent value={props.index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0">
          <textarea
              className="h-full p-2 mt-2 mb-2 ml-2 mr-1 bg-secondary border-none outline-none resize-none font-mono text-sm"
              value={props.text} readOnly={true}/>
        </div>
      </TabsContent>
  )
}
