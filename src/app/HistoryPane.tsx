import '../app.css';
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import PreviewPane from "@/app/PreviewPane"
import HistoryItemsPane from "@/app/HistoryItemsPane";
import {useEffect, useRef, useState} from "react";
import {ImperativePanelHandle} from "react-resizable-panels";
import {
  addHistoryItem,
  addSelectedHistoryItemIndex,
  AppInfo,
  clear,
  clearSelection,
  deleteHistoryItem,
  findItem,
  getDefaultApp,
  getFileOrImagePath,
  getFirstSelectedHistoryItem,
  getFirstSelectedHistoryItemIndex,
  getHistoryItem,
  getHistoryItemIndex,
  getHistoryItems,
  getLastSelectedItemIndex,
  getPreviewVisibleState,
  getSelectedHistoryItemIndices,
  getSelectedHistoryItems,
  getFilterVisibleState,
  getVisibleHistoryLength,
  isHistoryEmpty,
  isHistoryItemSelected,
  isTextItem,
  loadHistory,
  removeSelectedHistoryItemIndex,
  setFilterQuery,
  setPreviewVisibleState,
  setSelectedHistoryItemIndex,
  TextFormatOperation,
  updateHistoryItem,
  updateHistoryItemTypes,
  setFilterVisibleState,
  getDetailsVisibleState,
  setDetailsVisibleState,
  getFilterQuery,
  isFilterActive,
  resetFilter,
  setShouldUpdateHistory,
  fileExists,
  getNextItemIndexForPaste, resetPasteNextItemIndex
} from "@/data";
import {isQuickPasteShortcut, isShortcutMatch} from "@/lib/shortcuts";
import {
  prefGetCapitalizeShortcut,
  prefGetClearHistoryShortcut,
  prefGetCopyAndMergeSeparator,
  prefGetCopyObjectToClipboardShortcut,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardAfterMerge,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetKeepFavoritesOnClearHistory,
  prefGetMakeLowerCaseShortcut,
  prefGetMakeUpperCaseShortcut,
  prefGetNavigateToFirstItemShortcut,
  prefGetNavigateToLastItemShortcut,
  prefGetNavigateToNextGroupOfItemsShortcut,
  prefGetNavigateToPrevGroupOfItemsShortcut,
  prefGetOpenInBrowserShortcut,
  prefGetOpenInDefaultAppShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetPasteSelectedObjectToActiveAppShortcut,
  prefGetQuickLookShortcut,
  prefGetQuickPasteModifier,
  prefGetQuickPasteShortcuts,
  prefGetRemoveEmptyLinesShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut, prefGetSelectAllShortcut,
  prefGetSelectNextItemShortcut,
  prefGetSelectPreviousItemShortcut,
  prefGetSentenceCaseShortcut,
  prefGetShowInFinderShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetStripAllWhitespacesShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetToggleFilterShortcut,
  prefGetTogglePreviewShortcut,
  prefGetTrimSurroundingWhitespacesShortcut,
  prefShouldAlwaysDisplay,
  prefShouldCopyOnDoubleClick,
  prefShouldTreatDigitNumbersAsColor,
  prefShouldUpdateHistoryAfterAction
} from "@/pref";
import {FixedSizeList as List} from "react-window";
import {Clip, ClipType, getFilePath, getHTML, getImageFileName, getImageText, getRTF} from "@/db";
import {formatText, getClipType, isUrl} from "@/lib/utils";
import {ClipboardIcon} from "lucide-react";
import {getTrialLicenseDaysLeft, isTrialLicense, isTrialLicenseExpired} from "@/licensing";
import TrialExpiredDialog from "@/app/TrialExpiredDialog";
import {SidebarProvider} from "@/components/ui/sidebar";
import * as React from "react";
import AppSidebar from "@/app/AppSidebar";
import {AppSidebarItemType} from "@/app/AppSidebarItem";
import {Tag} from "@/tags";
import {
  emitter,
  FormatTextByIndexArgs,
  OpenFileItemWithAppByIndexArgs,
  OpenInAppByIndexArgs
} from "@/actions";

declare const pasteItemInFrontApp: (text: string, rtf: string, html: string, imageFileName: string, filePath: string) => void;
declare const pasteFilesInFrontApp: (filePaths: string) => void;
declare const pressReturn: () => void;
declare const pressTab: () => void;
declare const copyToClipboard: (text: string, rtf: string, html: string, imageFileName: string, filePath: string, ghost: boolean) => void;
declare const copyToClipboardAfterMerge: (text: string) => void;
declare const deleteImage: (imageFileName: string) => void;
declare const clearEntireHistory: () => void;
declare const openInBrowser: (url: string) => void;
declare const showInFinder: (filePath: string) => void;
declare const previewLink: (url: string) => void;
declare const previewFile: (filePath: string) => void;
declare const openSettingsWindow: () => void;
declare const saveImageAsFile: (imageFilePath: string, imageWidth: number, imageHeight: number) => void;
declare const hideAppWindow: () => void;
declare const openInApp: (filePath: string, appPath: string) => void;

type HistoryPaneProps = {
  appName: string
  appIcon: string
}

let treatDigitNumbersAsColor = prefShouldTreatDigitNumbersAsColor()
let renameItemMode = false

export default function HistoryPane(props: HistoryPaneProps) {
  const [history, setHistory] = useState<Clip[]>([])
  const [searchQuery, setSearchQuery] = useState("")

  const previewPanelRef = useRef<ImperativePanelHandle>(null);
  const searchFieldRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<List>(null);
  const moreActionsButtonRef = useRef<HTMLButtonElement>(null);
  const [previewVisible, setPreviewVisible] = useState(getPreviewVisibleState())
  const [detailsVisible, setDetailsVisible] = useState(getDetailsVisibleState())
  const [filterVisible, setFilterVisible] = useState(getFilterVisibleState())
  const [quickPasteModifierPressed, setQuickPasteModifierPressed] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [hidePreviewOnEditFinish, setHidePreviewOnEditFinish] = useState(false);
  const [selectedItemIndices, setSelectedItemIndices] = useState(getSelectedHistoryItemIndices());
  const [isTrial, setIsTrial] = useState(isTrialLicense());
  const [trialDaysLeft, setTrialDaysLeft] = useState(getTrialLicenseDaysLeft());
  const [isTrialExpired, setIsTrialExpired] = useState(isTrialLicenseExpired());
  const [selectedItemType, setSelectedItemType] = useState<AppSidebarItemType>("All")
  const [selectedTag, setSelectedTag] = useState<Tag | undefined>(undefined)
  const [selectedApp, setSelectedApp] = useState<AppInfo | undefined>(undefined)

  useEffect(() => {
    loadHistory().then(() => {
      setHistory(getHistoryItems())
    })
  }, []);

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
                                  isFolder: boolean,
                                  rtf: string,
                                  html: string) {
    let item = findItem(content, imageFileName, filePath)
    if (item) {
      item.numberOfCopies++
      item.lastTimeCopy = new Date()
      await updateHistoryItem(item.id!, item)
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
          isFolder,
          rtf,
          html)
    }
    setHistory([...getHistoryItems()])

    // When the history is changed, we need to reset the next item index for paste.
    resetPasteNextItemIndex()

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
          resetPasteNextItemIndex()
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
        isFolder,
        "",
        "")
  }

  async function clearHistory() {
    let keepFavorites = prefGetKeepFavoritesOnClearHistory()
    let items = await clear(keepFavorites)
    setHistory(items)
    resetPasteNextItemIndex()
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
    resetPasteNextItemIndex()
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

  async function pasteNextItemToActiveApp() {
    let index = getNextItemIndexForPaste()
    if (index >= 0) {
      let item = getHistoryItem(index)
      if (item) {
        await pasteItem(item, true)
      }
    } else {
      console.log("No next item to paste")
    }
  }

  function scrollToLastSelectedItem() {
    let selectedItemIndices = getSelectedHistoryItemIndices()
    if (selectedItemIndices.length === 0) {
      return
    }
    scrollToIndex(getLastSelectedItemIndex())
  }

  function scrollToIndex(index: number) {
    setTimeout(() => {
      if (listRef.current && index >= 0) {
        listRef.current.scrollToItem(index, "auto")
      }
    }, 50);
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
      // Paste the selected object to the active app when the paste shortcut is pressed.
      if (isShortcutMatch(prefGetPasteSelectedObjectToActiveAppShortcut(), e)) {
        await handlePasteObject()
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
      if (isShortcutMatch(prefGetOpenInDefaultAppShortcut(), e)) {
        handleOpenInDefaultApp()
        e.preventDefault()
      }
      // Copy the active item to the clipboard when the copy to clipboard shortcut is pressed.
      if (isShortcutMatch(prefGetCopyToClipboardShortcut(), e)) {
        await handleCopyToClipboard()
        e.preventDefault()
      }
      // Copy the active object item to the clipboard when the copy to clipboard shortcut is pressed.
      if (isShortcutMatch(prefGetCopyObjectToClipboardShortcut(), e)) {
        await handleCopyObjectToClipboard()
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
      // Toggle the filter when the corresponding shortcut is pressed.
      if (isShortcutMatch(prefGetToggleFilterShortcut(), e)) {
        handleToggleFilter()
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
        await handleFormatTextAndSave({
          operation: TextFormatOperation.ToLowerCase,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetMakeUpperCaseShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.ToUpperCase,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetCapitalizeShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.CapitalizeWords,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetSentenceCaseShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.ToSentenceCase,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetRemoveEmptyLinesShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.RemoveEmptyLines,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetStripAllWhitespacesShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.StripAllWhitespaces,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetTrimSurroundingWhitespacesShortcut(), e)) {
        await handleFormatTextAndSave({
          operation: TextFormatOperation.TrimSurroundingWhitespaces,
          index: -1
        })
        e.preventDefault()
      }
      if (isShortcutMatch(prefGetQuickLookShortcut(), e)) {
        handleQuickLook()
        e.preventDefault()
      }

      // Handle select all (Cmd+A) shortcut.
      if (isShortcutMatch(prefGetSelectAllShortcut(), e)) {
        if (handleSelectAll()) {
          e.preventDefault()
        }
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
    function handleFilterHistory() {
      updateHistory()
      focusSearchField()
    }

    function handleSortHistory() {
      setShouldUpdateHistory()
      updateHistory()
      focusSearchField()
    }

    emitter.on("ToggleFilter", handleToggleFilter)
    emitter.on("ToggleFavorite", handleToggleFavorite)
    emitter.on("TogglePreview", handleTogglePreview)
    emitter.on("ToggleDetails", handleToggleDetails)
    emitter.on("FocusSearchInput", focusSearchField)
    emitter.on("DeleteTagById", handleDeleteTag)
    emitter.on("UpdateTagById", handleUpdateTag)
    emitter.on("DeleteItem", handleDeleteItem)
    emitter.on("DeleteItemByIndex", handleDeleteItemByIndex)
    emitter.on("DeleteItems", handleDeleteItems)
    emitter.on("DeleteAllItems", handleDeleteAllItems)
    emitter.on("RenameItem", handleRenameItem)
    emitter.on("RenameItemByIndex", handleRenameItemByIndex)
    emitter.on("FilterHistory", handleFilterHistory)
    emitter.on("SortHistory", handleSortHistory)
    emitter.on("PasteWithTransformation", handlePasteWithTransformation)
    emitter.on("FormatText", handleFormatTextAndSave)
    emitter.on("OpenInApp", handleOpenInApp)
    emitter.on("OpenInAppByIndex", handleOpenInAppByIndex)
    emitter.on("OpenInBrowser", handleOpenInBrowser)
    emitter.on("OpenInBrowserByIndex", handleOpenInBrowserByIndex)
    emitter.on("PreviewLinkItem", handlePreviewLink)
    emitter.on("PreviewLinkItemByIndex", handlePreviewLinkByIndex)
    emitter.on("QuickLookItem", handleQuickLook)
    emitter.on("QuickLookItemByIndex", handleQuickLookByIndex)
    emitter.on("CopyTextFromImage", handleCopyTextFromImage)
    emitter.on("CopyTextFromImageByIndex", handleCopyTextFromImageByIndex)
    emitter.on("CopyPathToClipboard", handleCopyPathToClipboard)
    emitter.on("CopyPathToClipboardByIndex", handleCopyPathToClipboardByIndex)
    emitter.on("CopyToClipboard", handleCopyToClipboard)
    emitter.on("CopyToClipboardByIndex", handleCopyToClipboardByIndex)
    emitter.on("CopyObjectToClipboard", handleCopyObjectToClipboard)
    emitter.on("Paste", handlePaste)
    emitter.on("PastePath", handlePastePath)
    emitter.on("PasteWithReturn", handlePasteWithReturn)
    emitter.on("PasteWithTab", handlePasteWithTab)
    emitter.on("PasteByIndex", handlePasteByIndex)
    emitter.on("PastePathByIndex", handlePastePathByIndex)
    emitter.on("PasteObject", handlePasteObject)
    emitter.on("PasteObjectByIndex", handlePasteObjectByIndex)
    emitter.on("EditContent", handleEditContent)
    emitter.on("EditContentByIndex", handleEditContentByIndex)
    emitter.on("EditItem", handleEditHistoryItem)
    emitter.on("OpenFileItemWithApp", handleOpenWithApp)
    emitter.on("OpenFileItemWithAppByIndex", handleOpenWithAppByIndex)
    emitter.on("OpenSettings", handleOpenSettings)
    emitter.on("SaveImageAsFile", handleSaveImageAsFile)
    emitter.on("ShowInFinder", handleShowInFinder)
    emitter.on("ShowInFinderByIndex", handleShowInFinderByIndex)
    emitter.on("ShowInHistory", handleShowInHistory)
    emitter.on("Split", handleSplit)
    emitter.on("Merge", handleMerge)
    emitter.on("RenameItemModeEnabled", handleRenameItemModeEnabled)
    return () => {
      emitter.off("ToggleFilter", handleToggleFilter)
      emitter.off("ToggleFavorite", handleToggleFavorite)
      emitter.off("TogglePreview", handleTogglePreview)
      emitter.off("ToggleDetails", handleToggleDetails)
      emitter.off("FocusSearchInput", focusSearchField)
      emitter.off("DeleteTagById", handleDeleteTag)
      emitter.off("UpdateTagById", handleUpdateTag)
      emitter.off("DeleteItem", handleDeleteItem)
      emitter.off("DeleteItemByIndex", handleDeleteItemByIndex)
      emitter.off("DeleteItems", handleDeleteItems)
      emitter.off("DeleteAllItems", handleDeleteAllItems)
      emitter.off("RenameItem", handleRenameItem)
      emitter.off("RenameItemByIndex", handleRenameItemByIndex)
      emitter.off("FilterHistory", handleFilterHistory)
      emitter.off("SortHistory", handleSortHistory)
      emitter.off("PasteWithTransformation", handlePasteWithTransformation)
      emitter.off("FormatText", handleFormatTextAndSave)
      emitter.off("OpenInApp", handleOpenInApp)
      emitter.off("OpenInAppByIndex", handleOpenInAppByIndex)
      emitter.off("OpenInBrowser", handleOpenInBrowser)
      emitter.off("OpenInBrowserByIndex", handleOpenInBrowserByIndex)
      emitter.off("PreviewLinkItem", handlePreviewLink)
      emitter.off("PreviewLinkItemByIndex", handlePreviewLinkByIndex)
      emitter.off("QuickLookItem", handleQuickLook)
      emitter.off("QuickLookItemByIndex", handleQuickLookByIndex)
      emitter.off("CopyTextFromImage", handleCopyTextFromImage)
      emitter.off("CopyTextFromImageByIndex", handleCopyTextFromImageByIndex)
      emitter.off("CopyPathToClipboard", handleCopyPathToClipboard)
      emitter.off("CopyPathToClipboardByIndex", handleCopyPathToClipboardByIndex)
      emitter.off("CopyToClipboard", handleCopyToClipboard)
      emitter.off("CopyToClipboardByIndex", handleCopyToClipboardByIndex)
      emitter.off("CopyObjectToClipboard", handleCopyObjectToClipboard)
      emitter.off("Paste", handlePaste)
      emitter.off("PastePath", handlePastePath)
      emitter.off("PasteWithReturn", handlePasteWithReturn)
      emitter.off("PasteWithTab", handlePasteWithTab)
      emitter.off("PasteByIndex", handlePasteByIndex)
      emitter.off("PastePathByIndex", handlePastePathByIndex)
      emitter.off("PasteObject", handlePasteObject)
      emitter.off("PasteObjectByIndex", handlePasteObjectByIndex)
      emitter.off("EditContent", handleEditContent)
      emitter.off("EditContentByIndex", handleEditContentByIndex)
      emitter.off("EditItem", handleEditHistoryItem)
      emitter.off("OpenFileItemWithApp", handleOpenWithApp)
      emitter.off("OpenFileItemWithAppByIndex", handleOpenWithAppByIndex)
      emitter.off("OpenSettings", handleOpenSettings)
      emitter.off("SaveImageAsFile", handleSaveImageAsFile)
      emitter.off("ShowInFinder", handleShowInFinder)
      emitter.off("ShowInFinderByIndex", handleShowInFinderByIndex)
      emitter.off("ShowInHistory", handleShowInHistory)
      emitter.off("Split", handleSplit)
      emitter.off("Merge", handleMerge)
      emitter.off("RenameItemModeEnabled", handleRenameItemModeEnabled)
    };
  }, []);

  async function handleDeleteTag(tagId: number) {
    getHistoryItems().forEach((item) => {
      if (item.tags && item.tags.includes(tagId)) {
        item.tags = item.tags.filter((id) => id !== tagId)
        updateHistoryItem(item.id!, item)
        emitter.emit("UpdateItemById", item.id)
      }
    })
  }

  async function handleUpdateTag(tagId: number) {
    getHistoryItems().forEach((item) => {
      if (item.tags && item.tags.includes(tagId)) {
        emitter.emit("UpdateItemById", item.id)
      }
    })
  }

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

  async function pasteItem(item: Clip, keepHistory: boolean = false, pasteObject: boolean = false) {
    item.numberOfCopies++
    if (prefShouldUpdateHistoryAfterAction() && !keepHistory) {
      item.lastTimeCopy = new Date()
    }
    await updateHistoryItem(item.id!, item)

    let rtf = pasteObject ? getRTF(item) : ""
    let html = pasteObject ? getHTML(item) : ""
    pasteItemInFrontApp(item.content, rtf, html, getImageFileName(item), getFilePath(item))

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

  async function pasteFileItems(items: Clip[], keepHistory: boolean = false) {
    let filePaths = []
    for (const item of items) {
      item.numberOfCopies++
      if (prefShouldUpdateHistoryAfterAction() && !keepHistory) {
        item.lastTimeCopy = new Date()
      }
      await updateHistoryItem(item.id!, item)
      filePaths.push(getFilePath(item))
    }
    setHistory([...getHistoryItems()])

    pasteFilesInFrontApp(filePaths.join(":"))

    clearSelection()
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    scrollToLastSelectedItem()
  }

  async function handlePaste() {
    let items = getSelectedHistoryItems()

    let filePaths = []
    for (const item of items) {
      if (item.type === ClipType.File) {
        filePaths.push(getFilePath(item))
      }
    }

    if (filePaths.length === items.length) {
      await pasteFileItems(items)
      // Clear the search query in the search field after paste.
      handleSearchQueryChange("")
      return
    }

    for (const item of items) {
      await pasteItem(item)
    }
    // Clear the search query in the search field after paste.
    handleSearchQueryChange("")
  }

  async function handlePasteObject() {
    let items = getSelectedHistoryItems()
    for (const item of items) {
      if (item.type === ClipType.Text) {
        await pasteItem(item, false, true)
      }
    }
    handleSearchQueryChange("")
  }

  async function handlePasteObjectByIndex(index: number) {
    let item = getHistoryItem(index)
    if (item.type === ClipType.Text) {
      await pasteItem(item, false, true)
    }
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
        await pasteItem(item, false)
        item.content = originalContent
        await updateHistoryItem(item.id!, item)
      }
    }
  }

  async function handlePastePath() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File) {
        pasteItemInFrontApp(getFilePath(item), "", "", "", "")
      }
    }
    focusSearchField()
  }

  async function handlePastePathByIndex(index: number) {
    if (index < history.length) {
      let item = history[index]
      if (item.type === ClipType.File) {
        pasteItemInFrontApp(getFilePath(item), "", "", "", "")
      }
    }
  }

  async function handleCopyPathToClipboard() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File) {
        copyToClipboard(item.filePath, "", "", "", "", false)
      }
    }
    focusSearchField()
  }

  async function handleCopyPathToClipboardByIndex(index: number) {
    let item = getHistoryItem(index)
    if (item.type === ClipType.File) {
      copyToClipboard(item.filePath, "", "", "", "", false)
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
    await addClipboardData(content, "ClipBook.app", "", "", 0, 0, 0, "", "", "", "", 0, false, "", "")
    focusSearchField()
  }

  async function handlePasteByIndex(index: number) {
    if (index < history.length) {
      let item = history[index]
      if (prefShouldCopyOnDoubleClick()) {
        await copyItemToClipboard(item)
        if (!prefShouldAlwaysDisplay()) {
          hideAppWindow()
        }
      } else {
        await pasteItem(item)
      }
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
    focusSearchField()
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

  function handleToggleDetails() {
    let visible = !getDetailsVisibleState()
    setDetailsVisible(visible)
    setDetailsVisibleState(visible)
  }

  function handleRenameItem() {
    setTimeout(() => {
      scrollToLastSelectedItem()
      setTimeout(() => {
        emitter.emit("RenameSelectedItem")
      }, 100);
    }, 100);
  }

  async function handleSplit() {
    let selectedItem = getFirstSelectedHistoryItem()
    if (isTextItem(selectedItem)) {
      // Check if the item content has text with line breaks and has at least two lines.
      let text = selectedItem.content
      let lines = text.split(/\r?\n/).filter(line => line.trim() !== "")
      if (lines.length > 1) {
        let items = []
        for (let i = 0; i < lines.length; i++) {
          // Create a new item for each line.
          let item = await addHistoryItem(lines[i], selectedItem.sourceApp, "", "", 0, 0, 0, "", "", "", "", 0, false, "", "")
          let now = new Date()
          // Add one millisecond to the time to make sure the items are not identical.
          now.setMilliseconds(now.getMilliseconds() - (i * 100))
          item.firstTimeCopy = now
          item.lastTimeCopy = now
          items.push(item)
        }
        setHistory([...getHistoryItems()])

        clearSelection()
        for (let i = 0; i < items.length; i++) {
          let item = items[i]
          let index = getHistoryItemIndex(item)
          addSelectedHistoryItemIndex(index)
        }
        setSelectedItemIndices(getSelectedHistoryItemIndices())
        scrollToIndex(getHistoryItemIndex(items[0]))
      }
      focusSearchField()
    }
  }

  async function handleFormatTextAndSave(args: FormatTextByIndexArgs) {
    let items: Clip[] = []
    if (args.index >= 0) {
      let item = getHistoryItem(args.index)
      if (item) {
        items.push(item)
      }
    } else {
      items = getSelectedHistoryItems()
    }
    items.forEach(item => {
      item.content = formatText(item.content, args.operation)
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

  async function copyItemToClipboard(item: Clip, pasteObject: boolean = false) {
    item.numberOfCopies++
    if (prefShouldUpdateHistoryAfterAction()) {
      item.lastTimeCopy = new Date()
    }
    await updateHistoryItem(item.id!, item)

    let rtf = pasteObject ? getRTF(item) : ""
    let html = pasteObject ? getHTML(item) : ""
    copyToClipboard(item.content, rtf, html, getImageFileName(item), getFilePath(item), true)

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

  async function handleCopyObjectToClipboard() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      await copyItemToClipboard(item, true)
    }
    focusSearchField()
  }

  async function handleCopyToClipboardByIndex(index: number) {
    await copyItemToClipboard(getHistoryItem(index))
  }

  function copyTextFromImage(item: Clip) {
    if (item.type === ClipType.Image || item.type === ClipType.File) {
      let imageText = getImageText(item)
      copyToClipboard(imageText.length > 0 ? imageText : item.content, "", "", "", "", false)
    }
  }

  function handleCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      copyTextFromImage(getFirstSelectedHistoryItem())
    }
    focusSearchField()
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
    focusSearchField()
  }

  function handleShowInFinder() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File) {
        showInFinder(getFilePath(item))
      }
    }
    focusSearchField()
  }

  function handleShowInFinderByIndex(index: number) {
    let item = getHistoryItem(index)
    if (item && item.type === ClipType.File) {
      showInFinder(getFilePath(item))
    }
  }

  function handleShowInHistory(item: Clip) {
    if (getFilterQuery().length > 0) {
      // Clear the search query in the search field.
      handleSearchQueryChange("", true)
    }
    if (isFilterActive()) {
      handleSidebarTypeSelect("All")
      resetFilter()
      emitter.emit("FilterHistory")
    }
    let index = getHistoryItemIndex(item)
    if (index >= 0) {
      setSelectedHistoryItemIndex(index)
      setSelectedItemIndices(getSelectedHistoryItemIndices())
      scrollToLastSelectedItem()
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
    focusSearchField()
  }

  function quickLook(item: Clip) {
    if (item.type === ClipType.Image || (item.type === ClipType.File && fileExists(item.filePath))) {
      let filePath = getFileOrImagePath(item)
      if (filePath) {
        previewFile(filePath)
      }
    }
  }

  function handleQuickLook() {
    if (getSelectedHistoryItemIndices().length === 1) {
      quickLook(getFirstSelectedHistoryItem())
    }
  }

  function handleOpenInDefaultApp() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if ((item.type === ClipType.File && !item.fileFolder) || item.type === ClipType.Image) {
        let filePath = getFileOrImagePath(item)
        if (filePath) {
          let defaultApp = getDefaultApp(filePath)
          if (defaultApp) {
            openInApp(filePath, defaultApp.path)
          }
        }
      }
    }
  }

  function handleOpenInApp(appInfo: AppInfo | undefined) {
    if (appInfo) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File || item.type === ClipType.Image) {
        let filePath = getFileOrImagePath(item)
        if (filePath) {
          openInApp(filePath, appInfo.path)
        }
      }
    }
    focusSearchField()
  }

  function handleOpenInAppByIndex(args: OpenInAppByIndexArgs) {
    if (args.app) {
      let item = getHistoryItem(args.index)
      if (item.type === ClipType.File || item.type === ClipType.Image) {
        let filePath = getFileOrImagePath(item)
        if (filePath) {
          openInApp(filePath, args.app.path)
        }
      }
    }
    focusSearchField()
  }

  function handleOpenWithApp(appPath: string) {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item.type === ClipType.File || item.type === ClipType.Image) {
        let filePath = getFileOrImagePath(item);
        if (filePath) {
          openInApp(filePath, appPath)
        }
      }
    }
  }

  function handleOpenWithAppByIndex(args: OpenFileItemWithAppByIndexArgs) {
    let item = getHistoryItem(args.index)
    if (item.type === ClipType.File || item.type === ClipType.Image) {
      let filePath = getFileOrImagePath(item);
      if (filePath) {
        openInApp(filePath, args.appPath)
      }
    }
  }

  function handleOpenInBrowserByIndex(index: number) {
    openItemInBrowser(getHistoryItem(index))
  }

  function handlePreviewLinkByIndex(index: number) {
    previewLinkInApp(getHistoryItem(index))
  }

  function handleQuickLookByIndex(index: number) {
    quickLook(getHistoryItem(index))
  }

  function handleOpenSettings() {
    openSettingsWindow()
    focusSearchField()
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
    if (items.length > 0) {
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
    focusSearchField()
  }

  function handleDeleteAllItems() {
    clearEntireHistory()
  }

  function handleSearchQueryChange(searchQuery: string, skipSelection: boolean = false): void {
    setSearchQuery(searchQuery)
    setFilterQuery(searchQuery)
    let items = getHistoryItems();
    setHistory(items)

    if (!skipSelection) {
      if (items.length === 0) {
        clearSelection()
      } else {
        setSelectedHistoryItemIndex(0)
      }
      // The props.items array won't be updated until the next render, so we need to get the updated
      // items right now to update the preview text.
      setSelectedItemIndices(getSelectedHistoryItemIndices())
    }
    if (searchQuery == "") {
      focusSearchField()
    }
  }

  async function handleMouseDoubleClick(index: number) {
    let item = getHistoryItem(index)
    if (prefShouldCopyOnDoubleClick()) {
      await copyItemToClipboard(item)
      if (!prefShouldAlwaysDisplay()) {
        hideAppWindow()
      }
    } else {
      pasteItemInFrontApp(item.content, "", "", getImageFileName(item), getFilePath(item))
    }
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
    focusSearchField()
  }

  async function handleEditHistoryItem(item: Clip) {
    await updateHistoryItem(item.id!, item)
    setHistory([...getHistoryItems()])
  }

  async function handleEditHistoryItems(items: Clip[]) {
    for (let item of items) {
      await updateHistoryItem(item.id!, item)
      emitter.emit("UpdateItemById", item.id)
    }
    setHistory(getHistoryItems())
    await selectItems(items)
  }

  function handleSelectedItemsChange() {
    focusSearchField()
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  function handleToggleFilter() {
    let visible = !getFilterVisibleState()
    setFilterVisibleState(visible)
    setFilterVisible(visible)
  }

  function handleSelectAll(): boolean {
    if (editMode || searchQuery !== "" || renameItemMode) {
      return false
    }
    clearSelection()
    for (let i = 0; i < getVisibleHistoryLength(); i++) {
      addSelectedHistoryItemIndex(i)
    }
    setSelectedItemIndices(getSelectedHistoryItemIndices())
    return true
  }

  function handleRenameItemModeEnabled(enabled: boolean) {
    renameItemMode = enabled
  }

  function updateHistory() {
    let history = getHistoryItems()
    setHistory([...history])
    if (history.length > 0) {
      setSelectedHistoryItemIndex(0)
    } else {
      clearSelection()
    }
    setSelectedItemIndices(getSelectedHistoryItemIndices())
  }

  (window as any).addClipboardData = addClipboardData;
  (window as any).mergeClipboardData = mergeClipboardData;
  (window as any).copyToClipboardAfterMerge = copyToClipboardAfterMerge;
  (window as any).clearHistory = clearHistory;
  (window as any).activateApp = activateApp;
  (window as any).pasteNextItemToActiveApp = pasteNextItemToActiveApp;

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

  function handleSidebarTypeSelect(type: AppSidebarItemType) {
    setSelectedItemType(type)
    setSelectedTag(undefined)
    setSelectedApp(undefined)
  }

  function handleSidebarTagSelect(tag: Tag) {
    setSelectedItemType("None")
    setSelectedTag(tag)
    setSelectedApp(undefined)
  }

  function handleSidebarAppSelect(app: AppInfo) {
    setSelectedItemType("None")
    setSelectedTag(undefined)
    setSelectedApp(app)
  }

  return (
      <div className="w-full p-0 m-0">
        <TrialExpiredDialog visible={isTrialExpired}/>
        <SidebarProvider className="">
          <AppSidebar visible={filterVisible}
                      onSelectType={handleSidebarTypeSelect}
                      onSelectTag={handleSidebarTagSelect}
                      onSelectApp={handleSidebarAppSelect}
                      selectedTag={selectedTag}
                      selectedApp={selectedApp}
                      selectedItemType={selectedItemType}/>
          <div className="w-full">
            <ResizablePanelGroup direction="horizontal">
              <ResizablePanel className="flex flex-col">
                <HistoryItemsPane history={history}
                                  appName={props.appName}
                                  appIcon={props.appIcon}
                                  searchQuery={searchQuery}
                                  selectedItemIndices={selectedItemIndices}
                                  onSelectedItemsChange={handleSelectedItemsChange}
                                  onSearchQueryChange={handleSearchQueryChange}
                                  onMouseDoubleClick={handleMouseDoubleClick}
                                  isPreviewVisible={previewVisible}
                                  isFilterVisible={filterVisible}
                                  isQuickPasteModifierPressed={quickPasteModifierPressed}
                                  isTrial={isTrial}
                                  trialDaysLeft={trialDaysLeft}
                                  searchFieldRef={searchFieldRef}
                                  listRef={listRef}
                />
              </ResizablePanel>
              <ResizableHandle/>
              <ResizablePanel defaultSize={previewVisible ? 50 : 0} ref={previewPanelRef}
                              className="transition-all duration-200 ease-out bg-secondary">
                <PreviewPane selectedItemIndices={selectedItemIndices}
                             appName={props.appName}
                             appIcon={props.appIcon}
                             visible={previewVisible}
                             editMode={editMode}
                             detailsVisible={detailsVisible}
                             onRequestEditItem={handleRequestEditItem}
                             onEditHistoryItem={handleEditHistoryItem}
                             onFinishEditing={handleFinishEditing}
                />
              </ResizablePanel>
            </ResizablePanelGroup>
          </div>
        </SidebarProvider>
      </div>
  )
}
