import '../App.css';
import {TabsList} from "@/components/ui/tabs";
import HistoryItem from "@/components/HistoryItem"
import React from "react";
import SearchBar from "@/components/SearchBar";
import ActionsBar from "@/components/ActionsBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";
import {HideActionsReason} from "@/components/Actions";

type HistoryItemListProps = {
  items: string[]
  appName: string
  onFilterHistory: (searchQuery: string) => void
  isPreviewVisible: boolean
  onShowHidePreview: () => void
  onPaste: () => void
  onClose: () => void
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onSearchHistory: () => void
  onEditContent: () => void
  onCopyToClipboard: () => void
  onOpenInBrowser: () => void
  onDeleteItem: () => void
  onDeleteAllItems: () => void
  onMouseDoubleClick: (tabIndex: number) => void
  searchFieldRef?: React.Ref<HTMLInputElement>
  listRef?: React.Ref<List>
}

const HistoryItemList = (props: HistoryItemListProps) => {
  function handleMouseDoubleClick(tabIndex: number) {
    props.onMouseDoubleClick(tabIndex)
  }

  return (
      <div className="flex flex-col h-screen">
        <SearchBar onFilterHistory={props.onFilterHistory}
                   onShowHidePreview={props.onShowHidePreview}
                   isPreviewVisible={props.isPreviewVisible}
                   searchFieldRef={props.searchFieldRef}
        />
        <TabsList loop={false} className="flex h-full p-2">
          <div className="grid h-full w-full">
            <AutoSizer style={{}}>
              {(sizeProps: Size) => {
                return (
                    <List
                        className=""
                        ref={props.listRef}
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
        <ActionsBar appName={props.appName}
                    onPaste={props.onPaste}
                    onClose={props.onClose}
                    onHideActions={props.onHideActions}
                    onEditContent={props.onEditContent}
                    onCopyToClipboard={props.onCopyToClipboard}
                    onOpenInBrowser={props.onOpenInBrowser}
                    onSearchHistory={props.onSearchHistory}
                    onTogglePreview={props.onTogglePreview}
                    onDeleteItem={props.onDeleteItem}
                    onDeleteAllItems={props.onDeleteAllItems}/>
      </div>
  )
}

export default HistoryItemList;
