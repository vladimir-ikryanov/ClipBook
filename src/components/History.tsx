import '../App.css';
import {Tabs, TabsList} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import HistoryItemPreview from "@/components/HistoryItemPreview"
import {useRef} from "react";

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
}

export default function History(props: HistoryProps) {
  let items = props.items.reverse()
  const historyItems = items.map((item, index) =>
      <HistoryItem key={index} index={index} text={item} onUpdateHistory={props.onUpdateHistory}/>
  )
  const historyItemPreviews = items.map((item, index) =>
      <HistoryItemPreview key={index} index={index} text={item} appName={props.appName}/>
  )

  const tabsListRef = useRef<HTMLInputElement>(null);

  function focusHistory(): void {
    if (tabsListRef.current) {
      tabsListRef.current.focus();
    }
  }

  (window as any).focusHistory = focusHistory;

  return (
      <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel defaultSize={40}>
            <ScrollArea className="h-full border-r border-gray-100">
              <TabsList ref={tabsListRef}
                        loop={false}
                        className="grid h-full justify-normal p-2">
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
