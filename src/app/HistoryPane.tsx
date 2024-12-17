import '../app.css';
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import PreviewPane from "@/app/PreviewPane"
import HistoryItemsPane from "@/app/HistoryItemsPane";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  addHistoryItem,
  addSelectedHistoryItemIndex,
  clear,
  clearSelection,
  deleteHistoryItem,
  findItemByImageFileName,
  getFirstSelectedHistoryItem,
  getFirstSelectedHistoryItemIndex, getHistoryItem,
  getHistoryItemIndex,
  getHistoryItems,
  getLastSelectedItemIndex,
  getPreviewVisibleState,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems,
  getVisibleHistoryLength,
  isHistoryEmpty,
  isHistoryItemSelected,
  isTextItem,
  removeSelectedHistoryItemIndex,
  setFilterQuery,
  setPreviewVisibleState,
  setSelectedHistoryItemIndex,
  updateHistoryItem
} from "@/data";
import {isQuickPasteShortcut, isShortcutMatch} from "@/lib/shortcuts";
import {
  PasteItemsSeparator,
  prefGetClearHistoryShortcut,
  prefGetCopyAndMergeSeparator,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardAfterMerge,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetKeepFavoritesOnClearHistory,
  prefGetLicenseKey,
  prefGetNavigateToFirstItemShortcut,
  prefGetNavigateToLastItemShortcut,
  prefGetNavigateToNextGroupOfItemsShortcut,
  prefGetNavigateToPrevGroupOfItemsShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteItemsSeparator,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetQuickPasteModifier,
  prefGetQuickPasteShortcuts,
  prefGetSearchHistoryShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
  prefSetDisplayThankYouDialog,
  prefShouldDisplayThankYouMessage
} from "@/pref";
import {HideActionsReason} from "@/app/Actions";
import {FixedSizeList as List} from "react-window";
import {Clip, ClipType} from "@/db";
import {isUrl} from "@/lib/utils";
import {HideClipDropdownMenuReason} from "@/app/HistoryItemMenu";
import {ClipboardIcon} from "lucide-react";
import {getTrialLicenseDaysLeft, isTrialLicense, isTrialLicenseExpired} from "@/licensing";
import TrialExpiredMessage from "@/app/TrialExpiredMessage";
import FreeLicenseMessage from "@/app/FreeLicenseMessage";

declare const pasteItemInFrontApp: (text: string, imageFileName: string, imageText: string) => void;
declare const pressReturn: () => void;
declare const pressTab: () => void;
declare const copyToClipboard: (text: string, imageFileName: string, imageText: string) => void;
declare const copyToClipboardAfterMerge: (text: string) => void;
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
  const [quickPasteModifierPressed, setQuickPasteModifierPressed] = useState(false);
  const [selectedItemIndices, setSelectedItemIndices] = useState(getSelectedHistoryItemIndices());
  const [isTrial, setIsTrial] = useState(isTrialLicense());
  const [trialDaysLeft, setTrialDaysLeft] = useState(getTrialLicenseDaysLeft());
  const [isTrialExpired, setIsTrialExpired] = useState(isTrialLicenseExpired());
  const [displayThankYouMessage, setDisplayThankYouMessage] = useState(prefShouldDisplayThankYouMessage());

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
                                  imageSizeInBytes: number,
                                  imageText: string) {
    let item = await addHistoryItem(
        content,
        sourceAppPath,
        imageFileName,
        imageThumbFileName,
        imageWidth,
        imageHeight,
        imageSizeInBytes,
        imageText)
    setHistory([...getHistoryItems()])

    let index = getHistoryItemIndex(item)
    clearSelection()
    addSelectedHistoryItemIndex(index)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  async function mergeClipboardData(content: string,
                                    sourceAppPath: string,
                                    imageFileName: string,
                                    imageThumbFileName: string,
                                    imageWidth: number,
                                    imageHeight: number,
                                    imageSizeInBytes: number,
                                    imageText: string) {
    if (history.length > 0) {
      // Find the first non-favorite item to merge with.
      let targetItem = history[0]
      for (let i = 0; i < history.length; i++) {
        const item = history[i]
        if (!item.favorite) {
          targetItem = item
          break
        }
      }

      if (isTextItem(targetItem)) {
        let item = new Clip(content, sourceAppPath, imageFileName)
        if (isTextItem(item)) {
          targetItem.content += prefGetCopyAndMergeSeparator() + content

          if (prefGetCopyToClipboardAfterMerge()) {
            copyToClipboardAfterMerge(targetItem.content)
          }

          await updateHistoryItem(targetItem.id!, targetItem)
          let items = getHistoryItems()
          setHistory([...items])
          let index = items.findIndex(i => i.id === targetItem.id)
          setSelectedHistoryItemIndex(index)
          setSelectedItemIndices(getSelectedHistoryItemIndices())
          scrollToLastSelectedItem()
          return
        }
      }
    }
    await addClipboardData(content,
        sourceAppPath,
        imageFileName,
        imageThumbFileName,
        imageWidth,
        imageHeight,
        imageSizeInBytes,
        imageText)
  }

  async function clearHistory() {
    let keepFavorites = prefGetKeepFavoritesOnClearHistory()
    let items = await clear(keepFavorites)
    setHistory(items)
    // If the history is not empty, update the preview text to the new active item.
    if (items.length > 0) {
      let activeHistoryItemIndex = getFirstSelectedHistoryItemIndex()
      if (activeHistoryItemIndex >= items.length) {
        activeHistoryItemIndex = 0
        setSelectedHistoryItemIndex(activeHistoryItemIndex)
        setSelectedItemIndices(getSelectedHistoryItemIndices())
        scrollToLastSelectedItem()
      }
    }
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
    if (getVisibleHistoryLength() > 0) {
      setSelectedHistoryItemIndex(0)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
    // Update the trial state and days left when the app is activated.
    setIsTrial(isTrialLicense())
    setTrialDaysLeft(getTrialLicenseDaysLeft())
    setIsTrialExpired(isTrialLicenseExpired())
  }

  function scrollToLastSelectedItem() {
    let selectedItemIndices = getSelectedHistoryItemIndices()
    if (selectedItemIndices.length === 0) {
      return
    }
    let index = getLastSelectedItemIndex()
    if (listRef.current && index >= 0) {
      listRef.current.scrollToItem(index, "auto")
    }
  }

  useEffect(() => {
    focusSearchField()
  }, [selectedItemIndices])

  useEffect(() => {
    const down = async (e: KeyboardEvent) => {
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
      // Add the previous item to the selected items.
      if (isShortcutMatch(prefGetSelectPreviousItemShortcut() + " + ShiftLeft", e)) {
        selectPreviousItem(e.shiftKey)
        e.preventDefault()
      }
      // Add the next item to the selected items.
      if (isShortcutMatch(prefGetSelectNextItemShortcut() + " + ShiftLeft", e)) {
        selectNextItem(e.shiftKey)
        e.preventDefault()
      }
      // Select the first item in the list.
      if (isShortcutMatch(prefGetNavigateToFirstItemShortcut(), e)) {
        selectFirstItem()
        e.preventDefault()
      }
      // Select the last item in the list.
      if (isShortcutMatch(prefGetNavigateToLastItemShortcut(), e)) {
        selectLastItem()
        e.preventDefault()
      }
      // Jump to the next fifth item in the list.
      if (isShortcutMatch(prefGetNavigateToNextGroupOfItemsShortcut(), e)) {
        jumpToNextGroupOfItems()
        e.preventDefault()
      }
      // Jump to the previous fifth item in the list.
      if (isShortcutMatch(prefGetNavigateToPrevGroupOfItemsShortcut(), e)) {
        jumpToPrevGroupOfItems()
        e.preventDefault()
      }
      // Paste the selected item to the active app when the paste shortcut is pressed.
      if (isShortcutMatch(prefGetPasteSelectedItemToActiveAppShortcut(), e)) {
        handlePaste()
        e.preventDefault()
      }
      // Delete the active item when the delete shortcut is pressed.
      if (isShortcutMatch(prefGetDeleteHistoryItemShortcut(), e)) {
        await handleDeleteItem()
        e.preventDefault()
      }
      // Focus the search field when the search history shortcut is pressed.
      if (isShortcutMatch(prefGetSearchHistoryShortcut(), e)) {
        handleSearchHistory()
        e.preventDefault()
      }
      // Toggle the favorite status of the active item when the toggle favorite shortcut is pressed.
      if (isShortcutMatch(prefGetToggleFavoriteShortcut(), e)) {
        await handleToggleFavorite()
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

      // Paste using quick paste shortcuts.
      let shortcuts = prefGetQuickPasteShortcuts();
      let quickPasteShortcut = isQuickPasteShortcut(shortcuts, e);
      if (quickPasteShortcut.match) {
        handlePasteByIndex(quickPasteShortcut.index)
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [history])

  // Listen to key down and key up events to find out when the Command key is pressed and released.
  // When the Command key is pressed set the bool property to true, when it is released set it to false.
  useEffect(() => {
    let pressTimer: NodeJS.Timeout | null = null; // To track the timer

    const down = (e: KeyboardEvent) => {
      if (e.code === prefGetQuickPasteModifier()) {
        // Start the timer when the key is pressed
        pressTimer = setTimeout(() => {
          setQuickPasteModifierPressed(true);
        }, 500); // 500ms delay
      }
    };

    const up = (e: KeyboardEvent) => {
      if (e.code === prefGetQuickPasteModifier()) {
        // Clear the timer if the key is released before 500ms
        if (pressTimer) {
          clearTimeout(pressTimer);
          pressTimer = null;
        }

        // If the state was set to true, reset it on key release
        if (quickPasteModifierPressed) {
          setQuickPasteModifierPressed(false);
        }
      }
    };

    document.addEventListener("keydown", down);
    document.addEventListener("keyup", up);

    return () => {
      document.removeEventListener("keydown", down);
      document.removeEventListener("keyup", up);
    };
  }, [quickPasteModifierPressed]);

  function selectNextItem(shiftKeyDown: boolean = false) {
    let index = getLastSelectedItemIndex()
    if (index < getVisibleHistoryLength() - 1) {
      let nextItemIndex = index + 1;
      if (shiftKeyDown) {
        if (isHistoryItemSelected(nextItemIndex)) {
          removeSelectedHistoryItemIndex(index)
        } else {
          addSelectedHistoryItemIndex(nextItemIndex)
        }
      } else {
        setSelectedHistoryItemIndex(nextItemIndex)
      }
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
  }

  function selectPreviousItem(shiftKeyDown: boolean = false) {
    let index = getLastSelectedItemIndex()
    if (index > 0) {
      let prevItemIndex = index - 1;
      if (shiftKeyDown) {
        if (isHistoryItemSelected(prevItemIndex)) {
          removeSelectedHistoryItemIndex(index)
        } else {
          addSelectedHistoryItemIndex(prevItemIndex)
        }
      } else {
        setSelectedHistoryItemIndex(prevItemIndex)
      }
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
  }

  function selectFirstItem() {
    setSelectedHistoryItemIndex(0)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  function selectLastItem() {
    setSelectedHistoryItemIndex(getVisibleHistoryLength() - 1)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  function jumpToNextGroupOfItems() {
    let index = getFirstSelectedHistoryItemIndex();
    let nextGroupIndex = index + 5;
    if (nextGroupIndex < getVisibleHistoryLength()) {
      index = nextGroupIndex;
    } else {
      index = getVisibleHistoryLength() - 1;
    }
    setSelectedHistoryItemIndex(index)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  function jumpToPrevGroupOfItems() {
    let index = getFirstSelectedHistoryItemIndex();
    let previousGroupIndex = index - 5;
    if (previousGroupIndex >= 0) {
      index = previousGroupIndex;
    } else {
      index = 0;
    }
    setSelectedHistoryItemIndex(index)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  function isPreviewVisible(): boolean {
    return previewPanelRef.current ? previewPanelRef.current.getSize() > 0 : false
  }

  function pasteItem(item: Clip) {
    let imageFileName = item.imageFileName ? item.imageFileName : "";
    let imageText = item.imageText ? item.imageText : "";
    pasteItemInFrontApp(item.content, imageFileName, imageText)
  }

  function handlePaste(): void {
    getSelectedHistoryItems().forEach(item => {
      pasteItem(item)
      let separator = prefGetPasteItemsSeparator()
      if (separator === PasteItemsSeparator.RETURN) {
        pressReturn()
      }
      if (separator === PasteItemsSeparator.TAB) {
        pressTab()
      }
    })
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  async function handleMerge() {
    let content = ""
    let indices = getSelectedHistoryItemIndices()
    for (let index of indices) {
      let item = getHistoryItem(index)
      content += item.content + "\n"
    }
    await handleDeleteItems()
    await addClipboardData(content, "ClipBook.app", "", "", 0, 0, 0, "")

  }

  function handlePasteByIndex(index: number) {
    if (index < history.length) {
      pasteItem(history[index])
      // Clear the search query in the search field after paste.
      handleSearchQueryChange("")
      // Clear the indicator after paste.
      setQuickPasteModifierPressed(false)
    }
  }

  function handleClose(): void {
    hideAppWindow()
  }

  async function handleToggleFavorite() {
    let items = getSelectedHistoryItems()
    let favorite = items.some(item => !item.favorite)
    items.forEach(item => {
      item.favorite = favorite
    })
    await handleEditHistoryItems(items)
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
    // Edit content is not available when multiple items are selected.
    if (getSelectedHistoryItemIndices().length > 1) {
      return
    }
    let item = getFirstSelectedHistoryItem()
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
    // Copy to clipboard is not available when multiple items are selected.
    if (getSelectedHistoryItemIndices().length > 1) {
      return
    }
    let item = getFirstSelectedHistoryItem()
    let imageFileName = item.imageFileName ? item.imageFileName : ""
    let imageText = item.imageText ? item.imageText : ""
    copyToClipboard(item.content, imageFileName, imageText)
    hideAppWindow()
  }

  function handleCopyTextFromImage() {
    // Copy text from image is not available when multiple items are selected.
    if (getSelectedHistoryItemIndices().length > 1) {
      return
    }
    let item = getFirstSelectedHistoryItem()
    if (item.type === ClipType.Image) {
      copyToClipboard(item.content, "", "")
    }
  }

  function handleOpenInBrowser() {
    // Open in browser is not available when multiple items are selected.
    if (getSelectedHistoryItemIndices().length > 1) {
      return
    }
    let item = getFirstSelectedHistoryItem()
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

  async function deleteItem(item: Clip) {
    await deleteHistoryItem(item)
    if (item.type === ClipType.Image) {
      deleteImage(item.imageFileName!)
      deleteImage(item.imageThumbFileName!)
    }

    // If the history is not empty, update the preview text to the new active item.
    let items = getHistoryItems()
    if (items.length > 0) {
      setSelectedItemIndices(getSelectedHistoryItemIndices())
    }
    setHistory(items)
  }

  async function handleDeleteItem() {
    await handleDeleteItems()
  }

  async function handleDeleteItems() {
    let nextSelectedItemIndex = getVisibleHistoryLength() - 1
    let items = getSelectedHistoryItems()
    clearSelection()
    for (let item of items) {
      let index = getHistoryItemIndex(item)
      nextSelectedItemIndex = Math.min(index, nextSelectedItemIndex)
      await deleteItem(item)
    }

    let lastIndex = getVisibleHistoryLength() - 1
    if (nextSelectedItemIndex >= lastIndex) {
      nextSelectedItemIndex = lastIndex
    }
    setSelectedHistoryItemIndex(nextSelectedItemIndex)
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  function handleDeleteAllItems() {
    clearEntireHistory()
  }

  function handleSearchQueryChange(searchQuery: string): void {
    setSearchQuery(searchQuery)
    setFilterQuery(searchQuery)
    setHistory(getHistoryItems())

    setSelectedHistoryItemIndex(0)
    // The props.items array won't be updated until the next render, so we need to get the updated
    // items right now to update the preview text.
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    if (searchQuery == "") {
      focusSearchField()
    }
  }

  function handleMouseDoubleClick(index: number) {
    let item = history[index];
    let imageFileName = item.imageFileName ? item.imageFileName : "";
    let imageText = item.imageText ? item.imageText : "";
    pasteItemInFrontApp(item.content, imageFileName, imageText)
  }

  function handleFinishEditing() {
    focusSearchField()
  }

  async function selectItems(items: Clip[]) {
    clearSelection()
    for (let item of items) {
      let index = getHistoryItemIndex(item)
      addSelectedHistoryItemIndex(index)
    }
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  async function handleEditHistoryItem(item: Clip) {
    await updateHistoryItem(item.id!, item)
    setHistory(getHistoryItems())
  }

  async function handleEditHistoryItems(items: Clip[]) {
    for (let item of items) {
      await updateHistoryItem(item.id!, item)
    }
    setHistory(getHistoryItems())
    await selectItems(items)
  }

  function handleSelectedItemsChange() {
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  function handleCloseThankYouMessage() {
    setDisplayThankYouMessage(false)
    prefSetDisplayThankYouDialog(false)
  }

  (window as any).addClipboardData = addClipboardData;
  (window as any).mergeClipboardData = mergeClipboardData;
  (window as any).copyToClipboardAfterMerge = copyToClipboardAfterMerge;
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
      <div className="w-full p-0 m-0">
        <TrialExpiredMessage visible={isTrialExpired}/>
        <FreeLicenseMessage visible={displayThankYouMessage} licenseKey={prefGetLicenseKey()}
                            onClose={handleCloseThankYouMessage}/>
        <ResizablePanelGroup direction="horizontal">
          <ResizablePanel className="flex flex-col">
            <HistoryItemsPane history={history}
                              appName={props.appName}
                              appIcon={props.appIcon}
                              searchQuery={searchQuery}
                              selectedItemIndices={selectedItemIndices}
                              onSelectedItemsChange={handleSelectedItemsChange}
                              onSearchQueryChange={handleSearchQueryChange}
                              onShowHidePreview={handleTogglePreview}
                              onMouseDoubleClick={handleMouseDoubleClick}
                              isPreviewVisible={previewVisible}
                              isQuickPasteModifierPressed={quickPasteModifierPressed}
                              isTrial={isTrial}
                              trialDaysLeft={trialDaysLeft}
                              searchFieldRef={searchFieldRef}
                              listRef={listRef}
                              onPaste={handlePaste}
                              onMerge={handleMerge}
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
                              onDeleteItems={handleDeleteItems}
                              onDeleteAllItems={handleDeleteAllItems}/>
          </ResizablePanel>
          <ResizableHandle/>
          <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                          className="transition-all duration-200 ease-out bg-secondary">
            <PreviewPane selectedItemIndices={selectedItemIndices}
                         appName={props.appName}
                         appIcon={props.appIcon}
                         visible={previewVisible}
                         onEditHistoryItem={handleEditHistoryItem}
                         onFinishEditing={handleFinishEditing}
                         onHidePreview={handleTogglePreview}
                         onPaste={handlePaste}
                         onMerge={handleMerge}
                         onCopyToClipboard={handleCopyToClipboard}
                         onCopyTextFromImage={handleCopyTextFromImage}
                         onOpenInBrowser={handleOpenInBrowser}
                         onDeleteItem={handleDeleteItem}
                         onToggleFavorite={handleToggleFavorite}
                         previewTextareaRef={previewTextareaRef}/>
          </ResizablePanel>
        </ResizablePanelGroup>
      </div>
  )
}
