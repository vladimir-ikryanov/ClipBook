import '../App.css';
import {TabsList} from "@/components/ui/tabs";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import {useRef} from "react";
import ToolBar from "@/components/ToolBar";
import StatusBar from "@/components/StatusBar";

type HistoryItemListProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
  isPreviewVisible: boolean
  onShowHidePreview: () => void
}

export default function HistoryItemList(props: HistoryItemListProps) {
  const firstItemRef = useRef<HTMLButtonElement>(null);

  function focusHistory(): void {
    if (firstItemRef.current) {
      firstItemRef.current.focus();
    }
  }

  (window as any).focusHistory = focusHistory;

  function handleDeleteHistoryItem(lastItem: boolean): void {
    props.onUpdateHistory()
    if (lastItem) {
      focusHistory()
    }
  }

  return (
      <div className="flex flex-col h-screen">
        <ToolBar onFilterHistory={props.onFilterHistory}
                 onShowHidePreview={props.onShowHidePreview}
                 isPreviewVisible={props.isPreviewVisible}
        />
        <ScrollArea className="my-2">
          <TabsList loop={false}
                    className="grid h-full justify-normal py-1 px-0">{
            props.items.map((item, index) => {
              return <HistoryItem key={index} index={index} historySize={props.items.length}
                                  text={item}
                                  onDeleteHistoryItem={handleDeleteHistoryItem}
                                  tabsTriggerRef={index == 0 ? firstItemRef : null}/>
            })
          }
          </TabsList>
          <ScrollBar orientation="vertical"/>
        </ScrollArea>
        <div className="grow"></div>
        <StatusBar appName={props.appName}/>
      </div>
  )
}
