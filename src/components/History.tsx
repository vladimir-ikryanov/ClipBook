import '../App.css';
import {Tabs, TabsList} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import HistoryItemPreview from "@/components/HistoryItemPreview"
import {useRef} from "react";
import {Clipboard} from "lucide-react";

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
}

export default function History(props: HistoryProps) {
  const firstItemRef = useRef<HTMLButtonElement>(null);

  let items = props.items.reverse()
  const historyItems = items.map((item, index) => {
    return <HistoryItem key={index} index={index} text={item}
                        onUpdateHistory={props.onUpdateHistory}
                        tabsTriggerRef={index == 0 ? firstItemRef : null}/>
  })
  const historyItemPreviews = items.map((item, index) =>
      <HistoryItemPreview key={index} index={index} text={item} appName={props.appName}/>
  )

  function focusHistory(): void {
    if (firstItemRef.current) {
      firstItemRef.current.focus();
    }
  }

  (window as any).focusHistory = focusHistory;

  if (historyItems.length === 0) {
    return (
        <div className="flex flex-col w-full">
          <div className="draggable"></div>
          <div className="flex flex-col w-full text-center m-auto">
            <Clipboard className="h-24 w-24 m-auto text-neutral-500"/>
            <p className="text-center pt-8 text-2xl font-semibold text-neutral-700">Your clipboard
              is empty</p>
            <p className="text-center pt-2">Start copying items to build your history.</p>
          </div>
        </div>
    )
  }
  return (
      <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel defaultSize={40} className="flex flex-col">
            <div className="draggable pt-3 pb-2"></div>
            <ScrollArea className="h-full mt-0 ml-4 mr-3 mb-5">
              <TabsList loop={false}
                        className="grid h-full justify-normal pr-3 pt-0 pb-0 pl-1">
                {historyItems}
              </TabsList>
              <ScrollBar orientation="vertical"/>
            </ScrollArea>
          </ResizablePanel>
          <ResizableHandle className="border-neutral-200"/>
          <ResizablePanel defaultSize={60}>{historyItemPreviews}</ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
