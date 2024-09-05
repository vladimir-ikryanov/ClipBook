import '../app.css';
import {TabsList} from "@/components/ui/tabs";
import React from "react";
import SearchBar from "@/app/SearchBar";
import ActionsBar from "@/app/ActionsBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";
import {HideActionsReason} from "@/app/Actions";
import HistoryItemPane from "@/app/HistoryItemPane";
import {Clip} from "@/db";
import {SearchIcon} from "lucide-react";

type HistoryItemListPaneProps = {
  history: Clip[]
  appName: string
  appIcon: string
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

  function renderTabsList() {
    return <TabsList loop={false} className="flex h-full p-2">
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
  }

  function renderNoSearchResults() {
    return <div className="flex flex-col items-center justify-center h-full">
      <div>
        <SearchIcon className="h-16 w-16 m-auto text-secondary-foreground"/>
        <p className="text-center pt-4 text-2xl font-semibold text-primary-foreground">
          No results
        </p>
      </div>
    </div>
  }

  function renderHistoryItems() {
    if (props.history.length === 0 && props.searchQuery !== "") {
      return renderNoSearchResults()
    }

    return <div className="flex flex-col h-screen">
      {renderTabsList()}
      <div className="grow"></div>
      <ActionsBar appName={props.appName}
                  appIcon={props.appIcon}
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
  }

  return (
      <div className="flex flex-col h-screen">
        <SearchBar searchQuery={props.searchQuery}
                   onSearchQueryChange={props.onSearchQueryChange}
                   onShowHidePreview={props.onShowHidePreview}
                   isPreviewVisible={props.isPreviewVisible}
                   searchFieldRef={props.searchFieldRef}/>
        {renderHistoryItems()}
      </div>
  )
}

export default HistoryItemsPane;