import '../App.css';
import {TabsContent} from "@/components/ui/tabs";
import {ScrollArea} from "@/components/ui/scroll-area";
import {Button} from "@/components/ui/button"
import {CornerDownLeft, Delete} from "lucide-react";

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
          <div className="grow"></div>
          <div className="">
            <div className="flex flex-row justify-end m-2 mt-0 text-neutral-600 text-sm">
              <div className="flex flex-row">
                <p className="pr-2">Paste to Clion</p>
                <Button disabled={true} className="btn p-2 mr-3 h-6 rounded-sm bg-neutral-200">
                  <CornerDownLeft className="h-4 w-4 text-foreground"/>
                </Button>
                <p className="pr-2">Delete</p>
                <Button disabled={true} className="btn p-2 h-6 rounded-sm bg-neutral-200">
                  <Delete className="h-4 w-4 text-foreground"/>
                </Button>
              </div>
            </div>
          </div>
        </div>
      </TabsContent>
  )
}
