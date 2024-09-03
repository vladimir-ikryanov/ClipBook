import {addClip, Clip, deleteAllClips, deleteClip, getAllClips, updateClip} from "@/db";

export type HistoryItem = {
  content: string
  sourceApp: {
    path: string
  }
}

export enum SortHistoryType {
  TimeOfFirstCopy,
  TimeOfLastCopy,
  NumberOfCopies
}

let history: Clip[];
let filterQuery = "";
let visibleActiveHistoryItemIndex = 0;
let visibleHistoryItemsLength = 0;
let previewVisible = true;
let infoVisible = false;
let sortType = SortHistoryType.TimeOfLastCopy;

loadSettings()
await loadHistory()

// For testing purposes only!
function generateRandomWord(length: number): string {
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789'
  let result = ''
  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * characters.length)
    result += characters.charAt(randomIndex)
  }
  return result
}

// noinspection JSUnusedLocalSymbols
function generateHistoryForTesting(size: number, wordLength: number): Clip[] {
  const array: Clip[] = []
  for (let i = 0; i < size; i++) {
    array.push(new Clip(generateRandomWord(wordLength), "ClipBook"))
  }
  return array
}

async function loadHistory() {
  // history = generateHistoryForTesting(10024, 128)
  history = await getAllClips()
  if (localStorage.getItem("history")) {
    let items: HistoryItem[] = JSON.parse(localStorage.getItem("history")!)
    for (let i = 0; i < items.length; i++) {
      await addClip(new Clip(items[i].content, items[i].sourceApp.path))
    }
    localStorage.removeItem("history")
  }
  // Migrate old format history items to new format.
  if (localStorage.getItem("historyItems")) {
    let items: string[] = JSON.parse(localStorage.getItem("historyItems")!);
    // Convert old format history items to new format.
    for (let i = 0; i < items.length; i++) {
      await addClip(new Clip(items[i], ""))
    }
    history = await getAllClips()
    localStorage.removeItem("historyItems")
  }

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

function findItemByContent(content: string): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (history[i].content === content) {
      return history[i]
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
  visibleHistoryItemsLength = history.length
  if (filterQuery.length > 0) {
    let filteredHistory = Array.from(history.filter(item =>
        item.content.toLowerCase().includes(filterQuery.toLowerCase())));
    visibleHistoryItemsLength = filteredHistory.length
    sortHistory(sortType, filteredHistory)
    return filteredHistory
  }
  sortHistory(sortType, history)
  return Array.from(history)
}

export function isHistoryEmpty() {
  return history.length === 0
}

export async function addHistoryItem(content: string, sourceAppPath: string): Promise<Clip[]> {
  let item = findItemByContent(content);
  if (item) {
    item.numberOfCopies++
    item.lastTimeCopy = new Date()
    await updateClip(item.id!, item)
  } else {
    item = new Clip(content, sourceAppPath)
    await addClip(item)
    history.push(item)
  }
  return getHistoryItems()
}

export async function deleteHistoryItem(item: Clip) {
  await deleteItem(item)
}

export async function updateHistoryItem(oldItem: Clip, newItem: Clip) {
  let index = hasItem(oldItem)
  if (index !== -1) {
    history[index] = newItem
  }
  await updateClip(oldItem.id!, newItem)
}

export async function clear(): Promise<Clip[]> {
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
}

export function setVisibleActiveHistoryItemIndex(index: number) {
  visibleActiveHistoryItemIndex = index
}

export function getVisibleActiveHistoryItemIndex() {
  return visibleActiveHistoryItemIndex
}

export function getVisibleHistoryItemsLength() {
  return visibleHistoryItemsLength
}

export function setFilterQuery(query: string) {
  filterQuery = query
}

export function getFilterQuery(): string {
  return filterQuery
}

export function getActiveHistoryItem(): Clip {
  return getHistoryItems()[visibleActiveHistoryItemIndex]
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
