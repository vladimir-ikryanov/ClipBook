import '../App.css';
import {TabsContent} from "@/components/ui/tabs";
import {ScrollArea} from "@/components/ui/scroll-area";
import {Button} from "@/components/ui/button"
import {ArrowBigDown, ArrowBigUp, ArrowDown, ArrowUp, CornerDownLeft, Delete} from "lucide-react";

type HistoryItemPreviewProps = {
  index: number
  text: string
  appName: string
}

export default function HistoryItemPreview({index, text, appName}: HistoryItemPreviewProps) {
  return (
      <TabsContent value={index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0 border-l-neutral-200 border-l-solid border-l">
          <ScrollArea className="h-screen m-2">
            <pre className="text-wrap text-sm m-4">{text}</pre>
          </ScrollArea>
        </div>
      </TabsContent>
  )
}
