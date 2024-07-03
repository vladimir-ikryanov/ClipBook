import '../App.css';
import {TabsList} from "@/components/ui/tabs";
import HistoryItem from "@/components/HistoryItem"
import React from "react";
import ToolBar from "@/components/ToolBar";
import StatusBar from "@/components/StatusBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";

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

const HistoryItemList = (props: HistoryItemListProps) => {
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
        <TabsList loop={false} className="flex h-full p-2">
          <div className="grid h-full w-full">
            <AutoSizer>
              {(sizeProps: Size) => {
                return (
                    <List
                        className=""
                        style={{}}
                        height={sizeProps.height}
                        itemCount={props.items.length}
                        itemSize={36}
                        layout={"vertical"}
                        width={sizeProps.width}>{
                      ({index, style}) => {
                        return (
                            <HistoryItem index={index}
                                         historySize={props.items.length}
                                         text={props.items[index]}
                                         onMouseDoubleClick={handleMouseDoubleClick}
                                         style={style}
                            />
                        )
                      }
                    }
                    </List>
                )
              }}
            </AutoSizer>
          </div>
        </TabsList>
        <div className="grow"></div>
        <StatusBar appName={props.appName}/>
      </div>
  )
}

export default HistoryItemList;
