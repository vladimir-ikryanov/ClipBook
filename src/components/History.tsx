import '../App.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import HistoryItemPreview from "@/components/HistoryItemPreview"
import HistoryItemList from "@/components/HistoryItemList";

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
}

export default function History(props: HistoryProps) {
  return (
      <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel defaultSize={50} className="flex flex-col transition-all duration-100 ease-in-out">
            <HistoryItemList items={props.items} appName={props.appName}
                             onUpdateHistory={props.onUpdateHistory}
                             onFilterHistory={props.onFilterHistory}/>
          </ResizablePanel>
          <ResizableHandle className="border-neutral-200"/>
          <ResizablePanel defaultSize={50}>{
            props.items.map((item, index) =>
                <HistoryItemPreview key={index} index={index} text={item} appName={props.appName}/>
            )
          }</ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
