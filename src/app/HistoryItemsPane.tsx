import '../app.css';
import React from "react";
import SearchBar from "@/app/SearchBar";
import StatusBar from "@/app/StatusBar";
import {FixedSizeList as List} from "react-window";
import AutoSizer, {Size} from "react-virtualized-auto-sizer";
import HistoryItemPane from "@/app/HistoryItemPane";
import {Clip} from "@/db";
import {SearchIcon} from "lucide-react";
import {
  addSelectedHistoryItemIndex,
  getSelectedHistoryItemIndices,
  removeSelectedHistoryItemIndex,
  setSelectedHistoryItemIndex,
} from "@/data";
import {useTranslation} from "react-i18next";

type HistoryItemsPaneProps = {
  history: Clip[]
  appName: string
  appIcon: string
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
  isPreviewVisible: boolean
  isFilterVisible: boolean
  isQuickPasteModifierPressed: boolean
  isTrial: boolean
  trialDaysLeft: number
  selectedItemIndices: number[]
  onSelectedItemsChange: () => void
  onMouseDoubleClick: (index: number) => void
  searchFieldRef?: React.Ref<HTMLInputElement>
  listRef?: React.Ref<List>
}

const HistoryItemsPane = (props: HistoryItemsPaneProps) => {
  const {t} = useTranslation()

  function handleItemSelected(index: number, metaKeyDown: boolean, shiftKeyDown: boolean) {
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
    if (props.history.length === 0) {
      return <div className="flex h-screen">
          <div className="flex flex-col text-center m-auto">
            <p className="text-center text-xl font-semibold text-foreground">
              {t("app.history.noItems")}
            </p>
          </div>
        </div>
    }

    return <div className="flex h-full py-2">
      <div className="grid h-full w-full">
        <AutoSizer style={{}}>
          {(sizeProps: Size) => {
            return (
                <List
                    className="scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent"
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
                                         onItemSelected={handleItemSelected}
                                         onMouseDoubleClick={handleMouseDoubleClick}/>
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
          {t("app.history.noResults")}
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
      <StatusBar appName={props.appName}/>
    </div>
  }

  return (
      <div className="flex flex-col h-screen bg-background">
        <SearchBar searchQuery={props.searchQuery}
                   onSearchQueryChange={props.onSearchQueryChange}
                   isPreviewVisible={props.isPreviewVisible}
                   isFilterVisible={props.isFilterVisible}
                   isTrial={props.isTrial}
                   trialDaysLeft={props.trialDaysLeft}
                   searchFieldRef={props.searchFieldRef}
                   appName={props.appName}
                   appIcon={props.appIcon}
        />
        {renderHistoryItems()}
      </div>
  )
}

export default HistoryItemsPane;
