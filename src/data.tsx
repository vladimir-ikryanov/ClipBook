let historyItems: string[];

loadHistoryItems()

function loadHistoryItems() {
  if (localStorage.getItem("historyItems")) {
    historyItems = JSON.parse(localStorage.getItem("historyItems")!)
  }
}

function saveHistoryItems() {
  localStorage.setItem("historyItems", JSON.stringify(historyItems))
}

function deleteItem(item: string) {
  if (historyItems.includes(item)) {
    historyItems.splice(historyItems.indexOf(item), 1)
  }
}

export function getHistoryItems() {
  return Array.from(historyItems)
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
  return getHistoryItems()
}
