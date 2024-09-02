import '../app.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import HistoryItemPreviewPane from "@/app/HistoryItemPreviewPane"
import HistoryItemsPane from "@/app/HistoryItemsPane";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  deleteHistoryItem,
  getActiveHistoryItem,
  getHistoryItems,
  getPreviewVisibleState,
  getVisibleActiveHistoryItemIndex,
  getVisibleHistoryItemsLength,
  HistoryItem,
  isUrl,
  setPreviewVisibleState,
  setVisibleActiveHistoryItemIndex,
  updateHistoryItem
} from "@/data";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  prefGetClearHistoryShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import {HideActionsReason} from "@/app/Actions";
import {FixedSizeList as List} from "react-window";

declare const pasteInFrontApp: (text: string) => void;
declare const copyToClipboard: (text: string) => void;
declare const clearEntireHistory: () => void;
declare const hideAppWindow: () => void;
declare const openInBrowser: (url: string) => void;

type HistoryPaneProps = {
  history: HistoryItem[]
  appName: string
  appIcon: string
  onUpdateHistory: () => void
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
}

export default function HistoryPane(props: HistoryPaneProps) {
  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const previewTextareaRef = useRef<HTMLTextAreaElement>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<List>(null);
  const moreActionsButtonRef = useRef<HTMLButtonElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState());
  const [activeTab, setActiveTab] = useState(getVisibleActiveHistoryItemIndex().toString());
  const [historyItem, setHistoryItem] = useState(props.history[getVisibleActiveHistoryItemIndex()]);

  function focusSearchField() {
    if (searchFieldRef.current) {
      searchFieldRef.current.focus()
    }
  }

  function activateApp() {
    focusSearchField()
    if (getVisibleHistoryItemsLength() > 0) {
      let activeTabIndex = 0;
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(props.history[activeTabIndex])
      if (listRef.current) {
        listRef.current.scrollToItem(activeTabIndex, "start")
      }
    }
  }

  useEffect(() => {
    setTimeout(() => {
      focusSearchField()
    }, 0);
  }, [activeTab])

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
        handlePaste()
        e.preventDefault()
      }
      // Delete the active item when the delete shortcut is pressed.
      if (isShortcutMatch(prefGetDeleteHistoryItemShortcut(), e)) {
        handleDeleteItem()
        e.preventDefault()
      }
      // Focus the search field when the search history shortcut is pressed.
      if (isShortcutMatch(prefGetSearchHistoryShortcut(), e)) {
        handleSearchHistory()
        e.preventDefault()
      }
      // Show or hide the preview panel when the preview shortcut is pressed.
      if (isShortcutMatch(prefGetTogglePreviewShortcut(), e)) {
        handleTogglePreview()
        e.preventDefault()
      }
      // Edit the active item when the edit history item shortcut is pressed.
      if (isShortcutMatch(prefGetEditHistoryItemShortcut(), e)) {
        handleEditContent()
        e.preventDefault()
      }
      // Open the active item in the browser when the open in browser shortcut is pressed.
      if (isShortcutMatch(prefGetOpenInBrowserShortcut(), e)) {
        handleOpenInBrowser()
        e.preventDefault()
      }
      // Copy the active item to the clipboard when the copy to clipboard shortcut is pressed.
      if (isShortcutMatch(prefGetCopyToClipboardShortcut(), e)) {
        handleCopyToClipboard()
        e.preventDefault()
      }
      // Clear the history when the clear history shortcut is pressed.
      if (isShortcutMatch(prefGetClearHistoryShortcut(), e)) {
        handleDeleteAllItems()
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
  }, [props.history])

  function selectNextItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
      activeTabIndex = activeTabIndex + 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(props.history[activeTabIndex])
      if (listRef.current) {
        listRef.current.scrollToItem(activeTabIndex, "auto")
      }
    }
  }

  function selectPreviousItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex > 0) {
      activeTabIndex = activeTabIndex - 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(props.history[activeTabIndex])
      if (listRef.current) {
        listRef.current.scrollToItem(activeTabIndex, "auto")
      }
    }
  }

  function isPreviewVisible(): boolean {
    return previewPanelRef.current ? previewPanelRef.current.getSize() > 0 : false
  }

  function handlePaste(): void {
    pasteInFrontApp(getActiveHistoryItem().content)
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  function handleClose(): void {
    hideAppWindow()
  }

  function handleTogglePreview(): void {
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
    focusSearchField()
  }

  function handleHideActions(reason: HideActionsReason) {
    if (reason !== "editContent") {
      handleSearchHistory()
    }
  }

  function handleEditContent() {
    if (!isPreviewVisible()) {
      handleTogglePreview()
    }
    if (previewTextareaRef.current) {
      previewTextareaRef.current.focus()
    }
  }

  function handleCopyToClipboard() {
    copyToClipboard(getActiveHistoryItem().content)
    hideAppWindow()
  }

  function handleOpenInBrowser() {
    let item = getActiveHistoryItem()
    if (isUrl(item.content)) {
      openInBrowser(item.content)
    }
  }

  function handleSearchHistory() {
    if (searchFieldRef.current) {
      searchFieldRef.current.focus()
    }
  }

  function handleDeleteItem() {
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
      setHistoryItem(items[getVisibleActiveHistoryItemIndex()])
    }
    props.onUpdateHistory()
  }

  function handleDeleteAllItems() {
    clearEntireHistory()
  }

  function handleSearchQueryChange(searchQuery: string): void {
    props.onSearchQueryChange(searchQuery)
    setVisibleActiveHistoryItemIndex(0)
    setActiveTab("0")
    // The props.items array won't be updated until the next render, so we need to get the updated
    // items right now to update the preview text.
    setHistoryItem(getHistoryItems()[0])
    if (searchQuery == "") {
      focusSearchField()
    }
  }

  function handleMouseDoubleClick(tabIndex: number) {
    pasteInFrontApp(props.history[tabIndex].content)
  }

  function handleFinishEditing() {
    if (searchFieldRef.current) {
      searchFieldRef.current.focus()
    }
  }

  function handleEditHistoryItem(newText: HistoryItem) {
    let oldText = getActiveHistoryItem();
    updateHistoryItem(oldText, newText)
    setHistoryItem(newText)
    props.onUpdateHistory()
  }

  function onTabChange(tabIndex: string): void {
    let index = parseInt(tabIndex);
    setVisibleActiveHistoryItemIndex(index)
    setActiveTab(tabIndex)
    setHistoryItem(props.history[index])
  }

  (window as any).activateApp = activateApp;

  return (
      <Tabs defaultValue={activeTab} value={activeTab} onValueChange={onTabChange}
            orientation="vertical"
            className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel className="flex flex-col">
            <HistoryItemsPane history={props.history}
                              appName={props.appName}
                              appIcon={props.appIcon}
                              searchQuery={props.searchQuery}
                              onSearchQueryChange={handleSearchQueryChange}
                              onShowHidePreview={handleTogglePreview}
                              onMouseDoubleClick={handleMouseDoubleClick}
                              isPreviewVisible={previewVisible}
                              searchFieldRef={searchFieldRef}
                              listRef={listRef}
                              onPaste={handlePaste}
                              onClose={handleClose}
                              onHideActions={handleHideActions}
                              onEditContent={handleEditContent}
                              onCopyToClipboard={handleCopyToClipboard}
                              onOpenInBrowser={handleOpenInBrowser}
                              onSearchHistory={handleSearchHistory}
                              onTogglePreview={handleTogglePreview}
                              onDeleteItem={handleDeleteItem}
                              onDeleteAllItems={handleDeleteAllItems}
            />
          </ResizablePanel>
          <ResizableHandle/>
          <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out bg-secondary">
            <HistoryItemPreviewPane item={historyItem}
                                    onEditHistoryItem={handleEditHistoryItem}
                                    onFinishEditing={handleFinishEditing}
                                    previewTextareaRef={previewTextareaRef}/>
          </ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
