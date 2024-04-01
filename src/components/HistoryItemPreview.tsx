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

export default function HistoryItemPreview(props: HistoryItemPreviewProps) {
  return (
      <TabsContent value={props.index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0">
          <ScrollArea className="h-screen m-2">
            <pre className="text-wrap text-sm m-4">{props.text}</pre>
          </ScrollArea>
        </div>
      </TabsContent>
  )
}
