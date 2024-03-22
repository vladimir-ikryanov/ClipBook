import '../App.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import HistoryItemPreview from "@/components/HistoryItemPreview"
import HistoryItemList from "@/components/HistoryItemList";
import {useRef} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
}

export default function History(props: HistoryProps) {
  const previewPanelRef = useRef<ImperativePanelHandle>(null);

  function handleShowHidePreview(): void {
    if (previewPanelRef.current) {
      let size = previewPanelRef.current.getSize()
      if (size == 0) {
        previewPanelRef.current.resize(50)
      } else {
        previewPanelRef.current.resize(0)
      }
    }
  }

  return (
      <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel defaultSize={50} className="flex flex-col">
            <HistoryItemList items={props.items} appName={props.appName}
                             onUpdateHistory={props.onUpdateHistory}
                             onFilterHistory={props.onFilterHistory}
                             onShowHidePreview={handleShowHidePreview}
            />
          </ResizablePanel>
          <ResizableHandle className="border-neutral-200"/>
          <ResizablePanel defaultSize={50} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out">
            {
              props.items.map((item, index) =>
                  <HistoryItemPreview key={index} index={index} text={item}
                                      appName={props.appName}/>)
            }
          </ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
