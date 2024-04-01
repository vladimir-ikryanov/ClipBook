import '../App.css';
import {TabsList} from "@/components/ui/tabs";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import React, {useRef} from "react";
import ToolBar from "@/components/ToolBar";
import StatusBar from "@/components/StatusBar";

type HistoryItemListProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
  isPreviewVisible: boolean
  onShowHidePreview: () => void
  onMouseDoubleClick: (tabIndex: number) => void
  searchFieldRef?: React.Ref<HTMLInputElement>
}

export default function HistoryItemList(props: HistoryItemListProps) {
  function handleMouseDoubleClick(tabIndex: number) {
    props.onMouseDoubleClick(tabIndex)
  }

  return (
      <div className="flex flex-col h-screen">
        <ToolBar onFilterHistory={props.onFilterHistory}
                 onShowHidePreview={props.onShowHidePreview}
                 isPreviewVisible={props.isPreviewVisible}
                 searchFieldRef={props.searchFieldRef}
        />
        <ScrollArea className="my-2">
          <TabsList loop={false}
                    className="grid h-full justify-normal py-1 px-0">{
            props.items.map((item, index) => {
              return <HistoryItem key={index}
                                  index={index}
                                  text={item}
                                  historySize={props.items.length}
                                  onMouseDoubleClick={handleMouseDoubleClick}
              />
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
