import {
  addClip,
  Clip,
  ClipType,
  deleteAllClips,
  deleteClip,
  getAllClips,
  getFilePath, getImageFileName, getImageText,
  updateClip
} from "@/db";
import {prefGetClearHistoryOnMacReboot} from "@/pref";
import {getClipType} from "@/lib/utils";

declare const isAfterSystemReboot: () => boolean;

export enum SortHistoryType {
  TimeOfFirstCopy,
  TimeOfLastCopy,
  NumberOfCopies
}

export enum TextFormatOperation {
  ToLowerCase,
  ToUpperCase,
  CapitalizeWords,
  ToSentenceCase,
  RemoveEmptyLines,
  StripAllWhitespaces,
  TrimSurroundingWhitespaces
}

let history: Clip[];
let filterQuery = "";
let lastSelectedItemIndex = -1;
let selectedItemIndices: number[] = [];
let visibleHistoryLength = 0;
let previewVisible = true;
let infoVisible = true;
let sortType = SortHistoryType.TimeOfLastCopy;

loadSettings()
await loadHistory()

async function loadHistory() {
  // Clear history on Mac reboot.
  if (prefGetClearHistoryOnMacReboot() && isAfterSystemReboot()) {
    await deleteAllClips()
    history = []
    return
  }

  history = await getAllClips()
  sortHistory(sortType, history)
}

function loadSettings() {
  if (localStorage.getItem("previewVisible")) {
    previewVisible = localStorage.getItem("previewVisible") === "true"
  }
  if (localStorage.getItem("infoVisible")) {
    infoVisible = localStorage.getItem("infoVisible") === "true"
  }
  if (localStorage.getItem("sortType")) {
    sortType = parseInt(localStorage.getItem("sortType")!)
  }
}

function savePreviewVisible(visible: boolean) {
  previewVisible = visible
  localStorage.setItem("previewVisible", visible.toString())
}

function saveInfoVisible(visible: boolean) {
  infoVisible = visible
  localStorage.setItem("infoVisible", visible.toString())
}

function hasItem(item: Clip): number {
  for (let i = 0; i < history.length; i++) {
    if (history[i].id === item.id) {
      return i
    }
  }
  return -1;
}

export function isTextItem(item: Clip): boolean {
  return item.type === ClipType.Text ||
      item.type === ClipType.Link ||
      item.type === ClipType.Email ||
      item.type === ClipType.Color
}

export function findItem(content: string, imageFileName: string, fileName: string): Clip | undefined {
  if (fileName.length > 0) {
    // Content is a file path in this case.
    return findItemByFilePath(content)
  }
  if (imageFileName.length > 0) {
    return findItemByImageFileName(imageFileName)
  }
  return findItemByContent(content)
}

function findItemByContent(content: string): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (isTextItem(history[i])) {
      if (history[i].content === content) {
        return history[i]
      }
    }
  }
  return undefined
}

export function findItemByFilePath(filePath: string): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (history[i].type === ClipType.File) {
      if (history[i].content === filePath) {
        return history[i]
      }
    }
  }
  return undefined
}

export function findItemByImageFileName(imageFileName: string): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (history[i].type === ClipType.Image) {
      if (history[i].imageFileName === imageFileName) {
        return history[i]
      }
    }
  }
  return undefined
}

async function deleteItem(item: Clip) {
  let index = hasItem(item);
  if (index !== -1) {
    history.splice(index, 1)
    await deleteClip(item.id!)
  }
}

export function getHistoryItems(): Clip[] {
  visibleHistoryLength = history.length
  if (filterQuery.length > 0) {
    let filteredHistory = Array.from(history.filter(item => {
      let searchString = filterQuery.toLowerCase();
      // Search in content.
      let contentHasText = item.content.toLowerCase().includes(searchString);
      if (contentHasText) {
        return true
      }
      // Search in name.
      if (item.name && item.name.toLowerCase().includes(searchString)) {
        return true
      }
      // Search in image title.
      if (item.type === ClipType.Image) {
        let imageTitle = "Image (" + item.imageWidth + "x" + item.imageHeight + ")";
        if (imageTitle.toLowerCase().includes(searchString)) {
          return true;
        }
      }
      // Search in text from image.
      if (getImageText(item).toLowerCase().includes(searchString)) {
        return true
      }
      // Search in file path.
      if (item.type === ClipType.File) {
        if (item.filePathFileName.toLowerCase().includes(searchString)) {
          return true
        }
      }
      return false
    }));
    visibleHistoryLength = filteredHistory.length
    sortHistory(sortType, filteredHistory)
    return filteredHistory
  }
  sortHistory(sortType, history)
  return Array.from(history)
}

export function isHistoryEmpty() {
  return history.length === 0
}

export async function addHistoryItem(content: string,
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
                                     isFolder: boolean): Promise<Clip> {
  let type = getClipType(content, imageFileName, filePath)
  let item = new Clip(type, content, sourceAppPath)
  item.content = content
  item.imageFileName = imageFileName
  item.filePath = filePath
  item.filePathFileName = filePathFileName
  item.filePathThumbFileName = filePathThumbFileName
  item.fileSizeInBytes = fileSizeInBytes
  item.imageWidth = imageWidth
  item.imageHeight = imageHeight
  item.imageSizeInBytes = imageSizeInBytes
  item.imageThumbFileName = imageThumbFileName
  item.imageText = imageText
  item.fileFolder = isFolder
  await addClip(item)
  history.push(item)
  return item
}

export async function deleteHistoryItem(item: Clip) {
  await deleteItem(item)
}

export async function updateHistoryItem(id: number, item: Clip) {
  await updateClip(id, item)
}

function getFavorites(): Clip[] {
  return history.filter(item => item.favorite)
}

export async function clear(keepFavorites: boolean): Promise<Clip[]> {
  if (keepFavorites) {
    let favorites = getFavorites()
    if (favorites.length > 0) {
      for (const clip of history) {
        if (!clip.favorite) {
          await deleteClip(clip.id!)
        }
      }
      history = favorites
      return getHistoryItems()
    }
  }
  history = []
  await deleteAllClips()
  return getHistoryItems()
}

export function sortHistory(type: SortHistoryType, history: Clip[]) {
  switch (type) {
    case SortHistoryType.TimeOfFirstCopy:
      history.sort((a, b) => b.firstTimeCopy.getTime() - a.firstTimeCopy.getTime())
      break
    case SortHistoryType.TimeOfLastCopy:
      history.sort((a, b) => b.lastTimeCopy.getTime() - a.lastTimeCopy.getTime())
      break
    case SortHistoryType.NumberOfCopies:
      history.sort((a, b) => b.numberOfCopies - a.numberOfCopies)
      break
  }
  // Move pinned items to the top.
  history.sort((a, b) => {
    if (a.favorite && !b.favorite) {
      return -1
    }
    if (!a.favorite && b.favorite) {
      return 1
    }
    return 0
  })
}

export function getLastSelectedItemIndex(): number {
  return lastSelectedItemIndex
}

export function setSelectedHistoryItemIndex(index: number) {
  clearSelection()
  addSelectedHistoryItemIndex(index)
}

export function getFirstSelectedHistoryItemIndex(): number {
  return selectedItemIndices.length > 0 ? selectedItemIndices[0] : 0
}

export function clearSelection() {
  selectedItemIndices = []
  lastSelectedItemIndex = -1
}

export function addSelectedHistoryItemIndex(index: number) {
  if (!selectedItemIndices.includes(index)) {
    selectedItemIndices.push(index)
  }
  lastSelectedItemIndex = index
}

export function removeSelectedHistoryItemIndex(index: number) {
  let i = selectedItemIndices.indexOf(index)
  if (i !== -1) {
    selectedItemIndices.splice(i, 1)
    // Make the last selected item from the list the last selected item.
    lastSelectedItemIndex = selectedItemIndices.length > 0 ? selectedItemIndices[selectedItemIndices.length - 1] : -1
  }
}

export function getSelectedHistoryItemIndices(): number[] {
  return Array.from(selectedItemIndices)
}

export function getFirstSelectedHistoryItem(): Clip {
  return getHistoryItems()[getFirstSelectedHistoryItemIndex()]
}

export function isHistoryItemSelected(index: number): boolean {
  return selectedItemIndices.includes(index)
}

export function getSelectedHistoryItems(): Clip[] {
  let items = getHistoryItems()
  return selectedItemIndices.map(index => items[index])
}

export function getVisibleHistoryLength() {
  return visibleHistoryLength
}

export function setFilterQuery(query: string) {
  filterQuery = query
}

export function getFilterQuery(): string {
  return filterQuery
}

export function getHistoryItem(index: number): Clip {
  return getHistoryItems()[index]
}

export function getHistoryItemIndex(item: Clip): number {
  return getHistoryItems().findIndex(i => i.id === item.id)
}

export function setPreviewVisibleState(visible: boolean) {
  savePreviewVisible(visible)
}

export function getPreviewVisibleState() {
  return previewVisible
}

export function setInfoVisibleState(visible: boolean) {
  saveInfoVisible(visible)
}

export function getInfoVisibleState() {
  return infoVisible
}

export function toBase64Icon(base64IconData: string): string {
  if (!base64IconData) {
    return '';
  }
  return "data:image/png;base64," + base64IconData;
}

export async function updateHistoryItemTypes(): Promise<boolean> {
  let historyUpdated = false
  for (let i = 0; i < history.length; i++) {
    let clip = history[i];
    let oldType = clip.type;
    let newType = getClipType(clip.content, getImageFileName(clip), getFilePath(clip))
    clip.type = newType
    await updateClip(clip.id!, clip)
    if (oldType !== newType) {
      historyUpdated = true
    }
  }
  return historyUpdated
}
