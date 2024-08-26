export type HistoryItem = {
  content: string;
  sourceApp: {
    path: string;
  };
}

let history: HistoryItem[];
let filterQuery = "";
let visibleActiveHistoryItemIndex = 0;
let visibleHistoryItemsLength = 0;
let previewVisible = true;

loadHistory()

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
function generateHistoryForTesting(size: number, wordLength: number): HistoryItem[] {
  const array: HistoryItem[] = []
  for (let i = 0; i < size; i++) {
    array.push({ content: generateRandomWord(wordLength), sourceApp: {path: ""} })
  }
  return array
}

function loadHistory() {
  // history = generateHistoryForTesting(10024, 128)
  history = []
  if (localStorage.getItem("history")) {
    history = JSON.parse(localStorage.getItem("history")!)
  } else {
    if (localStorage.getItem("historyItems")) {
      let oldFormatHistory = JSON.parse(localStorage.getItem("historyItems")!);
      // Convert old format history items to new format.
      for (let i = 0; i < oldFormatHistory.length; i++) {
        history.push({ content: oldFormatHistory[i], sourceApp: {path: ""} })
      }
      // Remove history items in the old format after migration.
      localStorage.removeItem("historyItems")
    }
  }

  if (localStorage.getItem("previewVisible")) {
    previewVisible = localStorage.getItem("previewVisible") === "true"
  }
}

function saveHistory() {
  localStorage.setItem("history", JSON.stringify(history))
}

function savePreviewVisible(visible: boolean) {
  previewVisible = visible
  localStorage.setItem("previewVisible", visible.toString())
}

function hasItem(item: HistoryItem) : number {
  for (let i = 0; i < history.length; i++) {
    if (history[i].content === item.content) {
      return i
    }
  }
  return -1
}

function deleteItem(item: HistoryItem) {
  let index = hasItem(item);
  if (index !== -1) {
    history.splice(index, 1)
  }
}

export function getHistoryItems() : HistoryItem[] {
  visibleHistoryItemsLength = history.length
  if (filterQuery.length > 0) {
    let filteredHistory = Array.from(history.filter(item => item.content.toLowerCase().includes(filterQuery.toLowerCase())));
    visibleHistoryItemsLength = filteredHistory.length
    return filteredHistory
  }
  return Array.from(history)
}

export function isHistoryEmpty() {
  return history.length === 0
}

export function addHistoryItem(item: HistoryItem) : HistoryItem[] {
  deleteItem(item)
  history.unshift(item)
  saveHistory()
  return getHistoryItems()
}

export function deleteHistoryItem(item: HistoryItem) {
  deleteItem(item)
  saveHistory()
}

export function updateHistoryItem(oldItem: HistoryItem, newItem: HistoryItem) {
  let index = hasItem(oldItem)
  if (index !== -1) {
    history[index] = newItem
    saveHistory()
  }
}

export function clear() : HistoryItem[] {
  history = []
  saveHistory()
  return getHistoryItems()
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

export function getFilterQuery() : string {
  return filterQuery
}

export function getActiveHistoryItem() : HistoryItem {
  return getHistoryItems()[visibleActiveHistoryItemIndex]
}

export function setPreviewVisibleState(visible: boolean) {
  savePreviewVisible(visible)
}

export function getPreviewVisibleState() {
  return previewVisible
}

export function isUrl(text: string) {
  const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i;
  return urlRegex.test(text);
}
