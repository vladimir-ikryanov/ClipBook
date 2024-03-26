import '../App.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import HistoryItemPreview from "@/components/HistoryItemPreview"
import HistoryItemList from "@/components/HistoryItemList";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  deleteHistoryItem,
  getActiveHistoryItem, getPreviewVisibleState,
  getVisibleActiveHistoryItemIndex,
  getVisibleHistoryItemsLength, setPreviewVisibleState,
  setVisibleActiveHistoryItemIndex
} from "@/data";

declare const pasteInFrontApp: (text: string) => void;

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
}

export default function History(props: HistoryProps) {
  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState());
  const [activeTab, setActiveTab] = useState(getVisibleActiveHistoryItemIndex().toString());

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "ArrowUp") {
        selectPreviousItem()
        e.preventDefault()
      }
      if (e.key === "ArrowDown") {
        selectNextItem()
        e.preventDefault()
      }
      if (e.key === "Enter") {
        pasteInFrontApp(getActiveHistoryItem())
        e.preventDefault()
      }
      if (e.key === "Delete" || (e.key === "Backspace" && e.metaKey)) {
        let itemToDelete = getActiveHistoryItem();
        if (getVisibleActiveHistoryItemIndex() === getVisibleHistoryItemsLength() - 1) {
          let activeTabIndex = 0;
          if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
            setVisibleActiveHistoryItemIndex(activeTabIndex)
            setActiveTab(activeTabIndex.toString())
          }
        }
        deleteHistoryItem(itemToDelete)
        e.preventDefault()
        props.onUpdateHistory()
      }
      if (e.key === "f" && e.metaKey) {
        if (searchFieldRef.current) {
          searchFieldRef.current.focus()
        }
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function selectNextItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
      activeTabIndex = activeTabIndex + 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      document.getElementById("tab-" + activeTabIndex)?.scrollIntoView({block: "nearest"})
    }
  }

  function selectPreviousItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex > 0) {
      activeTabIndex = activeTabIndex - 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      document.getElementById("tab-" + activeTabIndex)?.scrollIntoView({block: "nearest"})
    }
  }

  function handleShowHidePreview(): void {
    if (previewPanelRef.current) {
      let visible = previewPanelRef.current.getSize() == 0
      if (visible) {
        previewPanelRef.current.resize(50)
      } else {
        previewPanelRef.current.resize(0)
      }
      setPreviewVisible(visible)
      setPreviewVisibleState(visible)
    }
  }

  function handleFilterHistory(searchQuery: string): void {
    props.onFilterHistory(searchQuery)
    const activeTabIndex = 0
    setVisibleActiveHistoryItemIndex(activeTabIndex)
    setActiveTab(activeTabIndex.toString())
  }

  function handleMouseDoubleClick(tabIndex: number) {
    pasteInFrontApp(props.items[tabIndex])
  }

  function onTabChange(tabIndex: string): void {
    setVisibleActiveHistoryItemIndex(parseInt(tabIndex))
    setActiveTab(tabIndex)
  }

  return (
      <Tabs defaultValue={activeTab} value={activeTab} onValueChange={onTabChange}
            orientation="vertical"
            className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel className="flex flex-col">
            <HistoryItemList items={props.items} appName={props.appName}
                             onUpdateHistory={props.onUpdateHistory}
                             onFilterHistory={handleFilterHistory}
                             onShowHidePreview={handleShowHidePreview}
                             onMouseDoubleClick={handleMouseDoubleClick}
                             isPreviewVisible={previewVisible}
                             searchFieldRef={searchFieldRef}
            />
          </ResizablePanel>
          <ResizableHandle/>
          <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out border-l-border border-l-solid border-l">
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
