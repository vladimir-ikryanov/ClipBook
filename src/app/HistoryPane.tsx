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
  findItem,
  getFirstSelectedHistoryItem,
  getFirstSelectedHistoryItemIndex,
  getHistoryItem,
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
  TextFormatOperation,
  updateHistoryItem,
  updateHistoryItemTypes
} from "@/data";
import {isQuickPasteShortcut, isShortcutMatch} from "@/lib/shortcuts";
import {
  prefGetCapitalizeShortcut,
  prefGetClearHistoryShortcut,
  prefGetCopyAndMergeSeparator,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardAfterMerge,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetKeepFavoritesOnClearHistory,
  prefGetLicenseKey,
  prefGetMakeLowerCaseShortcut, prefGetMakeUpperCaseShortcut,
  prefGetNavigateToFirstItemShortcut,
  prefGetNavigateToLastItemShortcut,
  prefGetNavigateToNextGroupOfItemsShortcut,
  prefGetNavigateToPrevGroupOfItemsShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetQuickPasteModifier,
  prefGetQuickPasteShortcuts, prefGetRemoveEmptyLinesShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut, prefGetSentenceCaseShortcut, prefGetShowInFinderShortcut,
  prefGetShowMoreActionsShortcut, prefGetStripAllWhitespacesShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut, prefGetTrimSurroundingWhitespacesShortcut,
  prefSetDisplayThankYouDialog,
  prefShouldDisplayThankYouMessage,
  prefShouldTreatDigitNumbersAsColor,
  prefShouldUpdateHistoryAfterAction
} from "@/pref";
import {HideActionsReason} from "@/app/Commands";
import {FixedSizeList as List} from "react-window";
import {Clip, ClipType, updateClip} from "@/db";
import {formatText, getClipType, isUrl} from "@/lib/utils";
import {HideClipDropdownMenuReason} from "@/app/HistoryItemMenu";
import {ClipboardIcon} from "lucide-react";
import {getTrialLicenseDaysLeft, isTrialLicense, isTrialLicenseExpired} from "@/licensing";
import TrialExpiredMessage from "@/app/TrialExpiredMessage";
import FreeLicenseMessage from "@/app/FreeLicenseMessage";
import {HideDropdownReason} from "@/app/PreviewToolBarMenu";

declare const pasteItemInFrontApp: (text: string, imageFileName: string, imageText: string, filePath: string) => void;
declare const pressReturn: () => void;
declare const pressTab: () => void;
declare const copyToClipboard: (text: string, imageFileName: string, imageText: string, filePath: string, ghost: boolean) => void;
declare const copyToClipboardAfterMerge: (text: string) => void;
declare const deleteImage: (imageFileName: string) => void;
declare const clearEntireHistory: () => void;
declare const openInBrowser: (url: string) => void;
declare const showInFinder: (filePath: string) => void;
declare const previewLink: (url: string) => void;
declare const openSettingsWindow: () => void;
declare const saveImageAsFile: (imageFilePath: string, imageWidth: number, imageHeight: number) => void;

type HistoryPaneProps = {
  appName: string
  appIcon: string
  onZoomIn: () => void
  onZoomOut: () => void
  onResetZoom: () => void
}

let treatDigitNumbersAsColor = prefShouldTreatDigitNumbersAsColor()

export default function HistoryPane(props: HistoryPaneProps) {
  const [history, setHistory] = useState(getHistoryItems())
  const [searchQuery, setSearchQuery] = useState("")

  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<List>(null);
  const moreActionsButtonRef = useRef<HTMLButtonElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState());
  const [quickPasteModifierPressed, setQuickPasteModifierPressed] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [hidePreviewOnEditFinish, setHidePreviewOnEditFinish] = useState(false);
  const [selectedItemIndices, setSelectedItemIndices] = useState(getSelectedHistoryItemIndices());
  const [isTrial, setIsTrial] = useState(isTrialLicense());
  const [trialDaysLeft, setTrialDaysLeft] = useState(getTrialLicenseDaysLeft());
  const [isTrialExpired, setIsTrialExpired] = useState(isTrialLicenseExpired());
  const [displayThankYouMessage, setDisplayThankYouMessage] = useState(prefShouldDisplayThankYouMessage());

  async function addClipboardData(content: string,
                                  sourceAppPath: string,
                                  imageFileName: string,
                                  imageThumbFileName: string,
                                  imageWidth: number,
                                  imageHeight: number,
                                  imageSizeInBytes: number,
                                  imageText: string,
                                  filePath: string,
                                  filePathFileName: string,
                                  filePathThumbFileName: string,
                                  fileSizeInBytes: number,
                                  isFolder: boolean) {
    let item = findItem(content, imageFileName, filePath)
    if (item) {
      item.numberOfCopies++
      item.lastTimeCopy = new Date()
      await updateClip(item.id!, item)
    } else {
      item = await addHistoryItem(
          content,
          sourceAppPath,
          imageFileName,
          imageThumbFileName,
          imageWidth,
          imageHeight,
          imageSizeInBytes,
          imageText,
          filePath,
          filePathFileName,
          filePathThumbFileName,
          fileSizeInBytes,
          isFolder)
    }
    setHistory([...getHistoryItems()])

    // The added item might not be in the visible history list if it doesn't match the search query.
    let index = getHistoryItemIndex(item)
    if (index >= 0) {
      clearSelection()
      addSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
  }

  async function mergeClipboardData(content: string,
                                    sourceAppPath: string,
                                    imageFileName: string,
                                    imageThumbFileName: string,
                                    imageWidth: number,
                                    imageHeight: number,
                                    imageSizeInBytes: number,
                                    imageText: string,
                                    filePath: string,
                                    filePathFileName: string,
                                    filePathThumbFileName: string,
                                    fileSizeInBytes: number,
                                    isFolder: boolean) {
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
        let type = getClipType(content, imageFileName, filePath);
        let item = new Clip(type, content, sourceAppPath)
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
        imageText,
        filePath,
        filePathFileName,
        filePathThumbFileName,
        fileSizeInBytes,
        isFolder)
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
    }, 250);
  }

  async function updateHistoryItemsIfNecessary() {
    let newValue = prefShouldTreatDigitNumbersAsColor()
    if (treatDigitNumbersAsColor !== newValue) {
      if (await updateHistoryItemTypes()) {
        setHistory([...getHistoryItems()])
      }
      treatDigitNumbersAsColor = newValue
    }
  }

  async function activateApp(clearSearch: boolean) {
    if (clearSearch && searchQuery.length > 0) {
      handleSearchQueryChange("")
    }
    await updateHistoryItemsIfNecessary()
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
    const down = async (e: KeyboardEvent) => {
      if (isTrialExpired) {
        return
      }
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
        await handlePaste()
        e.preventDefault()
      }
      // Delete the active item when the delete shortcut is pressed.
      if (isShortcutMatch(prefGetDeleteHistoryItemShortcut(), e)) {
        await handleDeleteItems()
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
      if (isShortcutMatch(prefGetShowInFinderShortcut(), e)) {
        handleShowInFinder()
        e.preventDefault()
      }
      // Copy the active item to the clipboard when the copy to clipboard shortcut is pressed.
      if (isShortcutMatch(prefGetCopyToClipboardShortcut(), e)) {
        await handleCopyToClipboard()
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
      // Save image as file when the corresponding shortcut is pressed.
      if (isShortcutMatch(prefGetSaveImageAsFileShortcut(), e)) {
        handleSaveImageAsFile()
        e.preventDefault()
      }

      // Paste using quick paste shortcuts.
      let shortcuts = prefGetQuickPasteShortcuts();
      let quickPasteShortcut = isQuickPasteShortcut(shortcuts, e);
      if (quickPasteShortcut.match) {
        await handlePasteByIndex(quickPasteShortcut.index)
        e.preventDefault()
      }

      // Dispatch the rename item request.
      if (isShortcutMatch(prefGetRenameItemShortcut(), e)) {
        handleRenameItem()
        e.preventDefault()
      }

      if (isShortcutMatch(prefGetMakeLowerCaseShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.ToLowerCase)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetMakeUpperCaseShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.ToUpperCase)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetCapitalizeShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.CapitalizeWords)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetSentenceCaseShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.ToSentenceCase)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetRemoveEmptyLinesShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.RemoveEmptyLines)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetStripAllWhitespacesShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.StripAllWhitespaces)
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetTrimSurroundingWhitespacesShortcut(), e)) {
        await handleFormatTextAndSave(TextFormatOperation.TrimSurroundingWhitespaces)
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

    function startShowQuickPasteModifiersRequest() {
      pressTimer = setTimeout(() => {
        setQuickPasteModifierPressed(true)
      }, 500); // 500ms delay
    }

    function cancelShowQuickPasteModifiersRequest() {
      // Clear the timer if the key is released before 500ms
      if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
      }
      // If the state was set to true, reset it on key release
      if (quickPasteModifierPressed) {
        setQuickPasteModifierPressed(false)
      }
    }

    const down = (e: KeyboardEvent) => {
      if (e.code === prefGetQuickPasteModifier() && !e.shiftKey && !e.altKey && !e.ctrlKey) {
        startShowQuickPasteModifiersRequest()
      } else {
        cancelShowQuickPasteModifiersRequest()
      }
    };

    const up = (e: KeyboardEvent) => {
      if (e.code === prefGetQuickPasteModifier()) {
        cancelShowQuickPasteModifiersRequest()
      }
    };

    document.addEventListener("keydown", down);
    document.addEventListener("keyup", up);

    return () => {
      document.removeEventListener("keydown", down);
      document.removeEventListener("keyup", up);
    };
  }, [quickPasteModifierPressed]);

  useEffect(() => {
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === "focusSearchInput") {
        focusSearchField()
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, []);

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

  async function pasteItem(item: Clip, keepHistory: boolean = false) {
    item.numberOfCopies++
    if (prefShouldUpdateHistoryAfterAction() && !keepHistory) {
      item.lastTimeCopy = new Date()
    }
    await updateClip(item.id!, item)

    pasteItemInFrontApp(item.content, item.imageFileName, item.imageText, item.filePath)

    setHistory([...getHistoryItems()])

    // The added item might not be in the visible history list if it doesn't match the search query.
    let index = getHistoryItemIndex(item)
    if (index >= 0) {
      clearSelection()
      addSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
  }

  async function handlePaste() {
    let items = getSelectedHistoryItems()
    for (const item of items) {
      await pasteItem(item)
    }
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  async function handlePasteWithTab() {
    let items = getSelectedHistoryItems()
    for (const item of items) {
      await pasteItem(item)
      if (items.length > 1) {
        pressTab()
      }
    }
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  async function handlePasteWithReturn() {
    let items = getSelectedHistoryItems()
    for (const item of items) {
      await pasteItem(item)
      if (items.length > 1) {
        pressReturn()
      }
    }
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  async function handlePasteWithTransformation(operation: TextFormatOperation) {
    let items = getSelectedHistoryItems()
    for (const item of items) {
      if (isTextItem(item)) {
        let originalContent = item.content
        item.content = formatText(originalContent, operation)
        await pasteItem(item, true)
        item.content = originalContent
      }
    }
  }

  async function handleMerge() {
    let content = ""
    let indices = getSelectedHistoryItemIndices()
    for (let index of indices) {
      let item = getHistoryItem(index)
      content += item.content + "\n"
    }
    await handleDeleteItems()
    await addClipboardData(content, "ClipBook.app", "", "", 0, 0, 0, "", "", "", "", 0, false)
  }

  async function handlePasteByIndex(index: number) {
    if (index < history.length) {
      await pasteItem(history[index])
      handleSearchQueryChange("")
      setQuickPasteModifierPressed(false)
    }
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
    if (reason !== "editContent" && reason !== "renameItem" && reason !== "pasteWithTransformation") {
      focusSearchField()
    }
  }

  function handleHideClipDropdownMenu(reason: HideClipDropdownMenuReason) {
    if (reason !== "editContent" && reason !== "renameItem") {
      focusSearchField()
    }
  }

  function handleHideDropdown(reason: HideDropdownReason) {
    if (reason !== "editContent") {
      focusSearchField()
    }
  }

  function handleRenameItem() {
    setTimeout(() => {
      scrollToLastSelectedItem()
      setTimeout(() => {
        window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "renameItem"}}));
      }, 100);
    }, 100);
  }

  async function handleFormatTextAndSave(operation: TextFormatOperation) {
    let items = getSelectedHistoryItems()
    items.forEach(item => {
      item.content = formatText(item.content, operation)
    })
    await handleEditHistoryItems(items)
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
      setHidePreviewOnEditFinish(true)
      handleTogglePreview()
    }
    setTimeout(() => {
      setEditMode(true)
    }, 50);
  }

  function handleEditContentByIndex(index: number) {
    if (getLastSelectedItemIndex() !== index) {
      setSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
    }
    handleEditContent()
  }

  function handleRenameItemByIndex(index: number) {
    if (getLastSelectedItemIndex() !== index) {
      setSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
    }
    handleRenameItem()
  }

  async function copyItemToClipboard(item: Clip) {
    item.numberOfCopies++
    if (prefShouldUpdateHistoryAfterAction()) {
      item.lastTimeCopy = new Date()
    }
    await updateClip(item.id!, item)

    let imageFileName = item.imageFileName ? item.imageFileName : ""
    let imageText = item.imageText ? item.imageText : ""
    copyToClipboard(item.content, imageFileName, imageText, item.filePath, true)

    setHistory([...getHistoryItems()])

    // The added item might not be in the visible history list if it doesn't match the search query.
    let index = getHistoryItemIndex(item)
    if (index >= 0) {
      clearSelection()
      addSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
    }
  }

  async function handleCopyToClipboard() {
    if (getSelectedHistoryItemIndices().length === 1) {
      await copyItemToClipboard(getFirstSelectedHistoryItem())
    }
    focusSearchField()
  }

  async function handleCopyToClipboardByIndex(index: number) {
    await copyItemToClipboard(getHistoryItem(index))
  }

  function copyTextFromImage(item: Clip) {
    if (item.type === ClipType.Image || (item.imageText && item.imageText.length > 0)) {
      copyToClipboard(item.content, "", item.imageText, "", false)
    }
  }

  function handleCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      copyTextFromImage(getFirstSelectedHistoryItem())
    }
  }

  function handleCopyTextFromImageByIndex(index: number) {
    copyTextFromImage(getHistoryItem(index))
  }

  function openItemInBrowser(item: Clip) {
    if (isUrl(item.content)) {
      openInBrowser(item.content)
    }
  }

  function handleOpenInBrowser() {
    if (getSelectedHistoryItemIndices().length === 1) {
      openItemInBrowser(getFirstSelectedHistoryItem())
    }
  }

  function handleShowInFinder() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File) {
        showInFinder(item.filePath)
      }
    }
  }

  function previewLinkInApp(item: Clip) {
    if (isUrl(item.content)) {
      previewLink(item.content)
    }
  }

  function handlePreviewLink() {
    if (getSelectedHistoryItemIndices().length === 1) {
      previewLinkInApp(getFirstSelectedHistoryItem())
    }
  }

  function handleOpenInBrowserByIndex(index: number) {
    openItemInBrowser(getHistoryItem(index))
  }

  function handlePreviewLinkByIndex(index: number) {
    previewLinkInApp(getHistoryItem(index))
  }

  function handleOpenSettings() {
    openSettingsWindow()
  }

  async function deleteItem(item: Clip) {
    await deleteHistoryItem(item)
    if (item.type === ClipType.Image) {
      deleteImage(item.imageFileName)
      deleteImage(item.imageThumbFileName)
    }
    if (item.type === ClipType.File) {
      deleteImage(item.filePathFileName)
      deleteImage(item.filePathThumbFileName)
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

  async function handleDeleteItemByIndex(index: number) {
    let item = getHistoryItem(index)
    let indices = getSelectedHistoryItemIndices()
    // If the item is selected, and it's the only selected item,
    // then delete it and select the first item.
    if (getLastSelectedItemIndex() === index) {
      await deleteItem(item)
      if (getVisibleHistoryLength() > 0) {
        setSelectedHistoryItemIndex(0)
        setSelectedItemIndices(getSelectedHistoryItemIndices())
        scrollToLastSelectedItem()
      } else {
        clearSelection()
        setSelectedItemIndices(getSelectedHistoryItemIndices())
      }
    } else {
      await deleteItem(item)
      // Get all the selected indices that are more than the current index.
      let indicesToShift = indices.filter(i => i > index)
      // Decrement the indices that are more than the current index.
      for (let i of indicesToShift) {
        removeSelectedHistoryItemIndex(i)
        addSelectedHistoryItemIndex(i - 1)
      }
      setSelectedItemIndices(getSelectedHistoryItemIndices())
    }
  }

  async function handleDeleteItems() {
    let items = getSelectedHistoryItems()
    if (items.length === 0) {
      return
    }
    let nextSelectedItemIndex = getVisibleHistoryLength() - 1
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
    if (nextSelectedItemIndex >= 0) {
      setSelectedHistoryItemIndex(nextSelectedItemIndex)
    }
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  function handleDeleteAllItems() {
    clearEntireHistory()
  }

  function handleSearchQueryChange(searchQuery: string): void {
    setSearchQuery(searchQuery)
    setFilterQuery(searchQuery)
    let items = getHistoryItems();
    setHistory(items)

    if (items.length === 0) {
      clearSelection()
    } else {
      setSelectedHistoryItemIndex(0)
    }
    // The props.items array won't be updated until the next render, so we need to get the updated
    // items right now to update the preview text.
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    if (searchQuery == "") {
      focusSearchField()
    }
  }

  function handleMouseDoubleClick(index: number) {
    let item = getHistoryItem(index)
    pasteItemInFrontApp(item.content, item.imageFileName, item.imageText, item.filePath)
  }

  function handleFinishEditing() {
    if (hidePreviewOnEditFinish) {
      handleTogglePreview()
      setHidePreviewOnEditFinish(false)
    }
    setEditMode(false)
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

  async function handleRequestEditItem() {
    handleEditContent()
  }

  function handleSaveImageAsFile() {
    let item = getFirstSelectedHistoryItem()
    if (item.type === ClipType.Image) {
      saveImageAsFile(item.imageFileName!, item.imageWidth!, item.imageHeight!)
    }
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
    focusSearchField()
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  function handleCloseThankYouMessage() {
    setDisplayThankYouMessage(false)
    prefSetDisplayThankYouDialog(false)
  }

  (window as any).addClipboardData = addClipboardData;
  (window as any).mergeClipboardData = mergeClipboardData;
  (window as any).copyToClipboardAfterMerge = copyToClipboardAfterMerge;
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
                              onPasteWithTab={handlePasteWithTab}
                              onPasteWithReturn={handlePasteWithReturn}
                              onPasteWithTransformation={handlePasteWithTransformation}
                              onPasteByIndex={handlePasteByIndex}
                              onMerge={handleMerge}
                              onHideActions={handleHideActions}
                              onHideClipDropdownMenu={handleHideClipDropdownMenu}
                              onEditContent={handleEditContent}
                              onEditContentByIndex={handleEditContentByIndex}
                              onRenameItem={handleRenameItem}
                              onRenameItemByIndex={handleRenameItemByIndex}
                              onCopyToClipboard={handleCopyToClipboard}
                              onCopyToClipboardByIndex={handleCopyToClipboardByIndex}
                              onCopyTextFromImage={handleCopyTextFromImage}
                              onCopyTextFromImageByIndex={handleCopyTextFromImageByIndex}
                              onSaveImageAsFile={handleSaveImageAsFile}
                              onOpenInBrowser={handleOpenInBrowser}
                              onShowInFinder={handleShowInFinder}
                              onPreviewLink={handlePreviewLink}
                              onZoomIn={props.onZoomIn}
                              onZoomOut={props.onZoomOut}
                              onResetZoom={props.onResetZoom}
                              onOpenInBrowserByIndex={handleOpenInBrowserByIndex}
                              onPreviewLinkByIndex={handlePreviewLinkByIndex}
                              onOpenSettings={handleOpenSettings}
                              onToggleFavorite={handleToggleFavorite}
                              onTogglePreview={handleTogglePreview}
                              onEditHistoryItem={handleEditHistoryItem}
                              onDeleteItem={handleDeleteItem}
                              onDeleteItemByIndex={handleDeleteItemByIndex}
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
                         editMode={editMode}
                         onHideDropdown={handleHideDropdown}
                         onRequestEditItem={handleRequestEditItem}
                         onSaveImageAsFile={handleSaveImageAsFile}
                         onEditHistoryItem={handleEditHistoryItem}
                         onFinishEditing={handleFinishEditing}
                         onHidePreview={handleTogglePreview}
                         onPaste={handlePaste}
                         onPasteWithTab={handlePasteWithTab}
                         onPasteWithReturn={handlePasteWithReturn}
                         onMerge={handleMerge}
                         onCopyToClipboard={handleCopyToClipboard}
                         onCopyTextFromImage={handleCopyTextFromImage}
                         onOpenInBrowser={handleOpenInBrowser}
                         onPreviewLink={handlePreviewLink}
                         onDeleteItem={handleDeleteItem}
                         onRenameItem={handleRenameItem}
                         onFormatText={handleFormatTextAndSave}
                         onToggleFavorite={handleToggleFavorite}/>
          </ResizablePanel>
        </ResizablePanelGroup>
      </div>
  )
}
