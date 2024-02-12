import '../App.css';
import {TabsContent} from "@/components/ui/tabs";
import {ScrollArea} from "@/components/ui/scroll-area";

type HistoryItemPreviewProps = {
  index: number
  text: string
}

export default function HistoryItemPreview({index, text}: HistoryItemPreviewProps) {
  return (
      <TabsContent value={index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0">
          <ScrollArea className="h-screen mt-4 mb-4 ml-4 mr-1">
            <div className="m-0">
              <pre className="text-wrap text-sm">{text}</pre>
            </div>
          </ScrollArea>
        </div>
      </TabsContent>
  )
}
