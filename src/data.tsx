let historyItems: string[];
let filterQuery = "";
let visibleActiveHistoryItemIndex = 0;
let visibleHistoryItemsLength = 0;
let previewVisible = true;

loadHistoryItems()

addHistoryItem("Hello, world 1!")
addHistoryItem("Hello, world 2!")
addHistoryItem("Hello, world 3!")
addHistoryItem("Hello, world 4!")
addHistoryItem("Hello, world 5!")
addHistoryItem("Hello, world 6!")
addHistoryItem("Hello, world 7!")
addHistoryItem("John Doe")
addHistoryItem("John Doe 2")
addHistoryItem("John Doe 3")

function loadHistoryItems() {
  historyItems = []
  if (localStorage.getItem("historyItems")) {
    historyItems = JSON.parse(localStorage.getItem("historyItems")!)
  }
  if (localStorage.getItem("previewVisible")) {
    previewVisible = localStorage.getItem("previewVisible") === "true"
  }
}

function saveHistoryItems() {
  localStorage.setItem("historyItems", JSON.stringify(historyItems))
}

function savePreviewVisible(visible: boolean) {
  previewVisible = visible
  localStorage.setItem("previewVisible", visible.toString())
}

function deleteItem(item: string) {
  if (historyItems.includes(item)) {
    historyItems.splice(historyItems.indexOf(item), 1)
  }
}

export function getHistoryItems() {
  visibleHistoryItemsLength = historyItems.length
  if (filterQuery.length > 0) {
    let result = Array.from(historyItems.filter(item => item.toLowerCase().includes(filterQuery.toLowerCase())));
    visibleHistoryItemsLength = result.length
    return result
  }
  return Array.from(historyItems)
}

export function isHistoryEmpty() {
  return historyItems.length === 0
}

export function addHistoryItem(item: string) {
  if (historyItems.includes(item)) {
    deleteItem(item)
  }
  historyItems.unshift(item)
  saveHistoryItems()
  return getHistoryItems()
}

export function deleteHistoryItem(item: string) {
  deleteItem(item)
  saveHistoryItems()
}

export function clear() {
  historyItems = []
  saveHistoryItems()
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

export function getActiveHistoryItem() {
  return getHistoryItems()[visibleActiveHistoryItemIndex]
}

export function setPreviewVisibleState(visible: boolean) {
  savePreviewVisible(visible)
}

export function getPreviewVisibleState() {
  return previewVisible
}
