import '../App.css';
import {TabsContent} from "@/components/ui/tabs";
import {ScrollArea} from "@/components/ui/scroll-area";
import {Button} from "@/components/ui/button"
import {ArrowDown, ArrowUp, CornerDownLeft, Delete} from "lucide-react";

type HistoryItemPreviewProps = {
  index: number
  text: string
  appName: string
}

export default function HistoryItemPreview({index, text, appName}: HistoryItemPreviewProps) {
  return (
      <TabsContent value={index.toString()} className="m-0">
        <div className="flex flex-col h-screen p-0 m-0">
          <div className="draggable pt-3 pb-2"></div>
          <ScrollArea className="h-screen mt-0 mr-4 ml-3 mb-3">
            <pre className="text-wrap text-sm mt-2.5 mr-2">{text}</pre>
          </ScrollArea>
          <div className="grow"></div>
          <div className="flex flex-row justify-end m-4 mt-2 text-neutral-600 text-sm">
            <div className="flex flex-row">
              <p className="pr-2">Navigate</p>
              <Button disabled={true} className="btn p-2 mr-1 h-6 rounded-sm bg-neutral-200">
                <ArrowUp className="h-4 w-4 text-foreground"/>
              </Button>
              <Button disabled={true} className="btn p-2 mr-3 h-6 rounded-sm bg-neutral-200">
                <ArrowDown className="h-4 w-4 text-foreground"/>
              </Button>

              <p className="pr-2">Paste to {appName}</p>
              <Button disabled={true} className="btn p-2 mr-3 h-6 rounded-sm bg-neutral-200">
                <CornerDownLeft className="h-4 w-4 text-foreground"/>
              </Button>

              <p className="pr-2">Delete</p>
              <Button disabled={true} className="btn p-2 h-6 mr-3 rounded-sm bg-neutral-200">
                <Delete className="h-4 w-4 text-foreground"/>
              </Button>

              <p className="pr-2">Close window</p>
              <Button disabled={true} className="btn p-2 h-6 rounded-sm bg-neutral-200 text-foreground">
                <span className="text-xs font-mono">Escape</span>
              </Button>
            </div>
          </div>
        </div>
      </TabsContent>
  )
}
