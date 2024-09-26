import '../app.css';
import {Tabs} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import PreviewPane from "@/app/PreviewPane"
import HistoryItemsPane from "@/app/HistoryItemsPane";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  addHistoryItem,
  clear,
  deleteHistoryItem,
  findItemByImageFileName,
  getActiveHistoryItem,
  getHistoryItemIndex,
  getHistoryItems,
  getPreviewVisibleState,
  getVisibleActiveHistoryItemIndex,
  getVisibleHistoryItemsLength,
  isHistoryEmpty, isTextItem,
  setFilterQuery,
  setPreviewVisibleState,
  setVisibleActiveHistoryItemIndex,
  updateHistoryItem
} from "@/data";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  prefGetClearHistoryShortcut, prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut
} from "@/pref";
import {HideActionsReason} from "@/app/Actions";
import {FixedSizeList as List} from "react-window";
import {Clip, ClipType} from "@/db";
import {isUrl} from "@/lib/utils";
import {HideClipDropdownMenuReason} from "@/app/HistoryItemMenu";
import {ClipboardIcon} from "lucide-react";

declare const pasteInFrontApp: (text: string) => void;
declare const copyToClipboard: (text: string) => void;
declare const deleteImage: (imageFileName: string) => void;
declare const clearEntireHistory: () => void;
declare const hideAppWindow: () => void;
declare const openInBrowser: (url: string) => void;
declare const openSettingsWindow: () => void;

type HistoryPaneProps = {
  appName: string
  appIcon: string
}

export default function HistoryPane(props: HistoryPaneProps) {
  const [history, setHistory] = useState(getHistoryItems())
  const [searchQuery, setSearchQuery] = useState("")

  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const previewTextareaRef = useRef<HTMLTextAreaElement>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<List>(null);
  const moreActionsButtonRef = useRef<HTMLButtonElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState());
  const [activeTab, setActiveTab] = useState(getVisibleActiveHistoryItemIndex().toString());
  const [historyItem, setHistoryItem] = useState(history[getVisibleActiveHistoryItemIndex()]);

  async function setTextFromImage(imageFileName: string, text: string) {
    let clip = findItemByImageFileName(imageFileName)
    if (clip) {
      clip.content = text
      await updateHistoryItem(clip.id!, clip)
    }
  }

  async function addClipboardData(content: string,
                                  sourceAppPath: string,
                                  imageFileName: string,
                                  imageThumbFileName: string,
                                  imageWidth: number,
                                  imageHeight: number,
                                  imageSizeInBytes: number) {
    let selectedItem = getActiveHistoryItem();

    let clips = await addHistoryItem(
        content, sourceAppPath, imageFileName, imageThumbFileName, imageWidth, imageHeight, imageSizeInBytes)
    setHistory([...clips])

    let selectedItemIndex = getHistoryItemIndex(selectedItem);
    setVisibleActiveHistoryItemIndex(selectedItemIndex)
    setActiveTab(selectedItemIndex.toString())
    setHistoryItem(selectedItem)
    scrollToActiveTab()
  }

  async function clearHistory() {
    setHistory(await clear())
  }

  function focusSearchField() {
    setTimeout(() => {
      if (searchFieldRef.current) {
        searchFieldRef.current.focus()
      }
    }, 0);
  }

  function activateApp() {
    focusSearchField()
    if (getVisibleHistoryItemsLength() > 0) {
      let activeTabIndex = 0;
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(history[activeTabIndex])
      scrollToActiveTab()
    }
  }

  function scrollToActiveTab() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (listRef.current) {
      listRef.current.scrollToItem(activeTabIndex, "auto")
    }
  }

  useEffect(() => {
    focusSearchField()
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
      // Toggle the favorite status of the active item when the toggle favorite shortcut is pressed.
      if (isShortcutMatch(prefGetToggleFavoriteShortcut(), e)) {
        handleToggleFavorite()
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
      // Copy text from the active item (image) when the copy text from image shortcut is pressed.
      if (isShortcutMatch(prefGetCopyTextFromImageShortcut(), e)) {
        handleCopyTextFromImage()
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
      // Open the settings window with the settings shortcut.
      if (isShortcutMatch(prefGetOpenSettingsShortcut(), e)) {
        openSettingsWindow()
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [history])

  function selectNextItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
      activeTabIndex = activeTabIndex + 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(history[activeTabIndex])
      scrollToActiveTab()
    }
  }

  function selectPreviousItem() {
    let activeTabIndex = getVisibleActiveHistoryItemIndex();
    if (activeTabIndex > 0) {
      activeTabIndex = activeTabIndex - 1
      setVisibleActiveHistoryItemIndex(activeTabIndex)
      setActiveTab(activeTabIndex.toString())
      setHistoryItem(history[activeTabIndex])
      scrollToActiveTab()
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

  async function handleToggleFavorite() {
    let item = getActiveHistoryItem()
    item.favorite = !item.favorite
    await handleEditHistoryItem(item)
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
      focusSearchField()
    }
  }

  function handleHideClipDropdownMenu(reason: HideClipDropdownMenuReason) {
    if (reason !== "editContent") {
      focusSearchField()
    }
  }

  function handleEditContent() {
    let item = getActiveHistoryItem()
    if (!isTextItem(item)) {
      return
    }
    if (!isPreviewVisible()) {
      handleTogglePreview()
    }
    setTimeout(() => {
      if (previewTextareaRef.current) {
        previewTextareaRef.current.focus()
      }
    }, 0);
  }

  function handleCopyToClipboard() {
    copyToClipboard(getActiveHistoryItem().content)
    hideAppWindow()
  }

  function handleCopyTextFromImage() {
    let item = getActiveHistoryItem()
    if (item.type === ClipType.Image) {
      copyToClipboard(item.content)
    }
  }

  function handleOpenInBrowser() {
    let item = getActiveHistoryItem()
    if (isUrl(item.content)) {
      openInBrowser(item.content)
    }
  }

  function handleOpenSettings() {
    openSettingsWindow()
  }

  function handleSearchHistory() {
    focusSearchField()
  }

  async function handleDeleteItem() {
    let itemToDelete = getActiveHistoryItem();
    if (getVisibleActiveHistoryItemIndex() === getVisibleHistoryItemsLength() - 1) {
      let activeTabIndex = 0;
      if (activeTabIndex < getVisibleHistoryItemsLength() - 1) {
        setVisibleActiveHistoryItemIndex(activeTabIndex)
        setActiveTab(activeTabIndex.toString())
      }
    }
    await deleteHistoryItem(itemToDelete)
    if (itemToDelete.type === ClipType.Image) {
      deleteImage(itemToDelete.imageFileName!)
      deleteImage(itemToDelete.imageThumbFileName!)
    }
    // If the history is not empty, update the preview text to the new active item.
    let items = getHistoryItems();
    if (items.length > 0) {
      setHistoryItem(items[getVisibleActiveHistoryItemIndex()])
    }
    setHistory(getHistoryItems())
  }

  function handleDeleteAllItems() {
    clearEntireHistory()
  }

  function handleSearchQueryChange(searchQuery: string): void {
    setSearchQuery(searchQuery)
    setFilterQuery(searchQuery)
    setHistory(getHistoryItems())

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
    pasteInFrontApp(history[tabIndex].content)
  }

  function handleFinishEditing() {
    focusSearchField()
  }

  async function handleEditHistoryItem(item: Clip) {
    await updateHistoryItem(item.id!, item)
    setHistoryItem(item)
    setHistory(getHistoryItems())
    let index = getHistoryItems().findIndex(i => i.id === item.id)
    setVisibleActiveHistoryItemIndex(index)
    setActiveTab(index.toString())
    scrollToActiveTab()
  }

  function onTabChange(tabIndex: string): void {
    let index = parseInt(tabIndex);
    setVisibleActiveHistoryItemIndex(index)
    setActiveTab(tabIndex)
    setHistoryItem(history[index])
  }

  (window as any).addClipboardData = addClipboardData;
  (window as any).setTextFromImage = setTextFromImage;
  (window as any).clearHistory = clearHistory;
  (window as any).activateApp = activateApp;

  if (isHistoryEmpty()) {
    return (
        <div className="flex h-screen draggable">
          <div className="flex flex-col text-center m-auto">
            <ClipboardIcon className="h-24 w-24 m-auto text-secondary-foreground"/>
            <p className="text-center pt-8 text-2xl font-semibold text-foreground">
              Your clipboard is empty
            </p>
            <p className="text-center pt-2">
              Start copying text or links to build your history.
            </p>
          </div>
        </div>
    )
  }

  return (
      <Tabs defaultValue={activeTab}
            value={activeTab}
            onValueChange={onTabChange}
            orientation="vertical"
            className="w-full p-0 m-0">
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel className="flex flex-col">
            <HistoryItemsPane history={history}
                              appName={props.appName}
                              appIcon={props.appIcon}
                              searchQuery={searchQuery}
                              onSearchQueryChange={handleSearchQueryChange}
                              onShowHidePreview={handleTogglePreview}
                              onMouseDoubleClick={handleMouseDoubleClick}
                              isPreviewVisible={previewVisible}
                              searchFieldRef={searchFieldRef}
                              listRef={listRef}
                              onPaste={handlePaste}
                              onClose={handleClose}
                              onHideActions={handleHideActions}
                              onHideClipDropdownMenu={handleHideClipDropdownMenu}
                              onEditContent={handleEditContent}
                              onCopyToClipboard={handleCopyToClipboard}
                              onCopyTextFromImage={handleCopyTextFromImage}
                              onOpenInBrowser={handleOpenInBrowser}
                              onOpenSettings={handleOpenSettings}
                              onSearchHistory={handleSearchHistory}
                              onToggleFavorite={handleToggleFavorite}
                              onTogglePreview={handleTogglePreview}
                              onEditHistoryItem={handleEditHistoryItem}
                              onDeleteItem={handleDeleteItem}
                              onDeleteAllItems={handleDeleteAllItems}/>
          </ResizablePanel>
          <ResizableHandle/>
          <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out bg-secondary">
            <PreviewPane item={historyItem}
                         appName={props.appName}
                         appIcon={props.appIcon}
                         visible={previewVisible}
                         onEditHistoryItem={handleEditHistoryItem}
                         onFinishEditing={handleFinishEditing}
                         onHidePreview={handleTogglePreview}
                         onPaste={handlePaste}
                         onCopyToClipboard={handleCopyToClipboard}
                         onCopyTextFromImage={handleCopyTextFromImage}
                         onOpenInBrowser={handleOpenInBrowser}
                         onDeleteItem={handleDeleteItem}
                         previewTextareaRef={previewTextareaRef}/>
          </ResizablePanel>
        </ResizablePanelGroup>
      </Tabs>
  )
}
