import '../App.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import HistoryItemPreview from "@/components/HistoryItemPreview"
import HistoryItemList from "@/components/HistoryItemList";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  deleteHistoryItem,
  getActiveHistoryItem, getHistoryItems, getPreviewVisibleState,
  getVisibleActiveHistoryItemIndex,
  getVisibleHistoryItemsLength, setPreviewVisibleState,
  setVisibleActiveHistoryItemIndex, updateHistoryItem
} from "@/data";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  prefGetClearHistoryShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";

declare const pasteInFrontApp: (text: string) => void;
declare const clearEntireHistory: () => void;

export function deleteAllHistoryItems() {
  clearEntireHistory()
}

type HistoryProps = {
  items: string[]
  appName: string
  onUpdateHistory: () => void
  onFilterHistory: (searchQuery: string) => void
}

export default function History(props: HistoryProps) {
  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const moreActionsButtonRef = useRef<HTMLButtonElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState());
  const [activeTab, setActiveTab] = useState(getVisibleActiveHistoryItemIndex().toString());
  const [previewText, setPreviewText] = useState(props.items[getVisibleActiveHistoryItemIndex()]);

  const activateApp = () => {
    if (searchFieldRef.current) {
      searchFieldRef.current.focus()
    }
    if (getVisibleHistoryItemsLength() > 0) {
      let activeTabIndex = 0;
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setPreviewText(props.items[activeTabIndex])
    }
  };

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Select the previous item when the select previous item shortcut is pressed.
      if (isShortcutMatch(prefGetSelectPreviousItemShortcut(), e)) {
        selectPreviousItem()
        e.preventDefault()
      }
      // Select the next item when the select next item shortcut is pressed.
      if (isShortcutMatch(prefGetSelectNextItemShortcut(), e)) {
        selectNextItem()
        e.preventDefault()
      }
      // Paste the selected item to the active app when the paste shortcut is pressed.
      if (isShortcutMatch(prefGetPasteSelectedItemToActiveAppShortcut(), e)) {
        pasteInFrontApp(getActiveHistoryItem())
        e.preventDefault()
      }
      // Delete the active item when the delete shortcut is pressed.
      if (isShortcutMatch(prefGetDeleteHistoryItemShortcut(), e)) {
        let itemToDelete = getActiveHistoryItem();
        if (getVisibleActiveHistoryItemIndex() === getVisibleHistoryItemsLength() - 1) {
          let activeTabIndex = 0;
          if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
            setVisibleActiveHistoryItemIndex(activeTabIndex)
            setActiveTab(activeTabIndex.toString())
          }
        }
        deleteHistoryItem(itemToDelete)
        // If the history is not empty, update the preview text to the new active item.
        let items = getHistoryItems();
        if (items.length > 0) {
          setPreviewText(items[getVisibleActiveHistoryItemIndex()])
        }
        e.preventDefault()
        props.onUpdateHistory()
      }
      // Focus the search field when the search history shortcut is pressed.
      if (isShortcutMatch(prefGetSearchHistoryShortcut(), e)) {
        if (searchFieldRef.current) {
          searchFieldRef.current.focus()
        }
        e.preventDefault()
      }
      // Show or hide the preview panel when the preview shortcut is pressed.
      if (isShortcutMatch(prefGetTogglePreviewShortcut(), e)) {
        handleShowHidePreview()
        e.preventDefault()
      }
      // Clear the history when the clear history shortcut is pressed.
      if (isShortcutMatch(prefGetClearHistoryShortcut(), e)) {
        clearEntireHistory()
        e.preventDefault()
      }
      // Show more actions when the show more actions shortcut is pressed.
      if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e)) {
        if (moreActionsButtonRef.current) {
          moreActionsButtonRef.current.click()
        }
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [props.items])

  function selectNextItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
      activeTabIndex = activeTabIndex + 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setPreviewText(props.items[activeTabIndex])
      document.getElementById("tab-" + activeTabIndex)?.scrollIntoView({block: "nearest"})
    }
  }

  function selectPreviousItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex > 0) {
      activeTabIndex = activeTabIndex - 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setPreviewText(props.items[activeTabIndex])
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
    setVisibleActiveHistoryItemIndex(0)
    setActiveTab("0")
    // The props.items array won't be updated until the next render, so we need to get the updated
    // items right now to update the preview text.
    setPreviewText(getHistoryItems()[0])
  }

  function handleMouseDoubleClick(tabIndex: number) {
    pasteInFrontApp(props.items[tabIndex])
  }

  function handleFinishEditing() {
    if (searchFieldRef.current) {
      searchFieldRef.current.focus()
    }
  }

  function handleEditHistoryItem(newText: string) {
    let oldText = getActiveHistoryItem();
    updateHistoryItem(oldText, newText)
    setPreviewText(newText)
    props.onUpdateHistory()
  }

  function onTabChange(tabIndex: string): void {
    let index = parseInt(tabIndex);
    setVisibleActiveHistoryItemIndex(index)
    setActiveTab(tabIndex)
    setPreviewText(props.items[index])
  }

  (window as any).activateApp = activateApp;

  return (
      <Tabs defaultValue={activeTab} value={activeTab} onValueChange={onTabChange}
            orientation="vertical"
            className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel className="flex flex-col">
            <HistoryItemList items={props.items} appName={props.appName}
                             onFilterHistory={handleFilterHistory}
                             onShowHidePreview={handleShowHidePreview}
                             onMouseDoubleClick={handleMouseDoubleClick}
                             isPreviewVisible={previewVisible}
                             searchFieldRef={searchFieldRef}
                             moreActionsButtonRef={moreActionsButtonRef}/>
          </ResizablePanel>
          <ResizableHandle/>
          <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out bg-secondary">
            <HistoryItemPreview text={previewText}
                                onEditHistoryItem={handleEditHistoryItem}
                                onFinishEditing={handleFinishEditing}/>
          </ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
