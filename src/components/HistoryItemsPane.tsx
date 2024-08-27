import '../App.css';
import {TabsList} from "@/components/ui/tabs";
import {HistoryItem} from "@/data";
import React from "react";
import SearchBar from "@/components/SearchBar";
import ActionsBar from "@/components/ActionsBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";
import {HideActionsReason} from "@/components/Actions";
import HistoryItemPane from "@/components/HistoryItemPane";

type HistoryItemListPaneProps = {
  history: HistoryItem[]
  appName: string
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
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

const HistoryItemsPane = (props: HistoryItemListPaneProps) => {
  function handleMouseDoubleClick(tabIndex: number) {
    props.onMouseDoubleClick(tabIndex)
  }

  return (
      <div className="flex flex-col h-screen">
        <SearchBar searchQuery={props.searchQuery}
                   onSearchQueryChange={props.onSearchQueryChange}
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
                        itemCount={props.history.length}
                        itemSize={36}
                        layout={"vertical"}
                        width={sizeProps.width}>{
                      ({index, style}) => {
                        return (
                            <HistoryItemPane index={index}
                                             historySize={props.history.length}
                                             item={props.history[index]}
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

export default HistoryItemsPane;
