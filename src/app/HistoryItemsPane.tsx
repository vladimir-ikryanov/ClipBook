import '../app.css';
import React from "react";
import SearchBar from "@/app/SearchBar";
import ActionsBar from "@/app/ActionsBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";
import {HideActionsReason} from "@/app/Actions";
import HistoryItemPane from "@/app/HistoryItemPane";
import {Clip} from "@/db";
import {SearchIcon} from "lucide-react";
import {HideClipDropdownMenuReason} from "@/app/HistoryItemMenu";
import {
  addSelectedHistoryItemIndex,
  getSelectedHistoryItemIndices,
  removeSelectedHistoryItemIndex,
  setSelectedHistoryItemIndex
} from "@/data";

type HistoryItemsPaneProps = {
  history: Clip[]
  appName: string
  appIcon: string
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
  isPreviewVisible: boolean
  isQuickPasteModifierPressed: boolean
  isTrial: boolean
  trialDaysLeft: number
  selectedItemIndices: number[]
  onSelectedItemsChange: () => void
  onShowHidePreview: () => void
  onPaste: () => void
  onMerge: () => void
  onClose: () => void
  onEditHistoryItem: (item: Clip) => void
  onHideActions: (reason: HideActionsReason) => void
  onHideClipDropdownMenu: (reason: HideClipDropdownMenuReason) => void
  onTogglePreview: () => void
  onToggleFavorite: () => void
  onSearchHistory: () => void
  onEditContent: () => void
  onEditContentByIndex: (index: number) => void
  onCopyToClipboard: () => void
  onCopyToClipboardByIndex: (index: number) => void
  onCopyTextFromImage: () => void
  onOpenInBrowser: () => void
  onOpenSettings: () => void
  onDeleteItem: () => void
  onDeleteItemByIndex: (index: number) => void
  onDeleteItems: () => void
  onDeleteAllItems: () => void
  onMouseDoubleClick: (index: number) => void
  searchFieldRef?: React.Ref<HTMLInputElement>
  listRef?: React.Ref<List>
}

const HistoryItemsPane = (props: HistoryItemsPaneProps) => {
  function handleMouseDown(index: number, metaKeyDown: boolean, shiftKeyDown: boolean) {
    // Handle click without modifier keys: select a single item.
    if (!metaKeyDown && !shiftKeyDown) {
      setSelectedHistoryItemIndex(index)
    }
    // Handle click with meta key: toggle selection of an item.
    if (metaKeyDown) {
      let selectedIndices = getSelectedHistoryItemIndices()
      if (selectedIndices.includes(index)) {
        if (selectedIndices.length > 1) {
          removeSelectedHistoryItemIndex(index)
        }
      } else {
        addSelectedHistoryItemIndex(index)
      }
    }
    // Handle click with shift key: select a range of items.
    if (shiftKeyDown) {
      let selectedIndices = getSelectedHistoryItemIndices()
      if (selectedIndices.length === 0) {
        setSelectedHistoryItemIndex(index)
      } else {
        // Sort selected indices.
        selectedIndices.sort((a, b) => a - b)
        let firstIndex = selectedIndices[0]
        let lastIndex = selectedIndices[selectedIndices.length - 1]
        if (index < firstIndex) {
          for (let i = index; i <= firstIndex; i++) {
            addSelectedHistoryItemIndex(i)
          }
        } else if (index > lastIndex) {
          for (let i = lastIndex; i <= index; i++) {
            addSelectedHistoryItemIndex(i)
          }
        }
      }
    }
    props.onSelectedItemsChange()
  }

  function handleMouseDoubleClick(index: number) {
    props.onMouseDoubleClick(index)
  }

  function renderItems() {
    return <div className="flex h-full p-2">
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
                        <HistoryItemPane style={style}
                                         index={index}
                                         selectedItemIndices={props.selectedItemIndices}
                                         item={props.history[index]}
                                         historySize={props.history.length}
                                         appName={props.appName}
                                         appIcon={props.appIcon}
                                         isQuickPasteModifierPressed={props.isQuickPasteModifierPressed}
                                         onHideClipDropdownMenu={props.onHideClipDropdownMenu}
                                         onPaste={props.onPaste}
                                         onEditHistoryItem={props.onEditHistoryItem}
                                         onMouseDown={handleMouseDown}
                                         onMouseDoubleClick={handleMouseDoubleClick}
                                         onEditContent={props.onEditContentByIndex}
                                         onCopyToClipboard={props.onCopyToClipboardByIndex}
                                         onCopyTextFromImage={props.onCopyTextFromImage}
                                         onOpenInBrowser={props.onOpenInBrowser}
                                         onDeleteItem={props.onDeleteItemByIndex}/>
                    )
                  }
                }
                </List>
            )
          }}
        </AutoSizer>
      </div>
    </div>
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
      {renderItems()}
      <div className="grow"></div>
      <ActionsBar appName={props.appName}
                  appIcon={props.appIcon}
                  onPaste={props.onPaste}
                  onMerge={props.onMerge}
                  onClose={props.onClose}
                  onHideActions={props.onHideActions}
                  onEditContent={props.onEditContent}
                  onCopyToClipboard={props.onCopyToClipboard}
                  onCopyTextFromImage={props.onCopyTextFromImage}
                  onOpenInBrowser={props.onOpenInBrowser}
                  onOpenSettings={props.onOpenSettings}
                  onSearchHistory={props.onSearchHistory}
                  onToggleFavorite={props.onToggleFavorite}
                  onTogglePreview={props.onTogglePreview}
                  onDeleteItem={props.onDeleteItem}
                  onDeleteItems={props.onDeleteItems}
                  onDeleteAllItems={props.onDeleteAllItems}/>
    </div>
  }

  return (
      <div className="flex flex-col h-screen">
        <SearchBar searchQuery={props.searchQuery}
                   onSearchQueryChange={props.onSearchQueryChange}
                   onShowHidePreview={props.onShowHidePreview}
                   isPreviewVisible={props.isPreviewVisible}
                   isTrial={props.isTrial}
                   trialDaysLeft={props.trialDaysLeft}
                   searchFieldRef={props.searchFieldRef}/>
        {renderHistoryItems()}
      </div>
  )
}

export default HistoryItemsPane;
