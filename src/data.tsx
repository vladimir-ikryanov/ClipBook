let historyItems: Set<string> = new Set();

loadHistoryItems()

function loadHistoryItems() {
  if (localStorage.getItem("historyItems")) {
    historyItems = new Set(JSON.parse(localStorage.getItem("historyItems")!))
  }
}

function saveHistoryItems() {
  localStorage.setItem("historyItems", JSON.stringify(Array.from(historyItems)))
}

export function getHistoryItems() {
  return Array.from(historyItems)
}

export function addHistoryItem(item: string) {
  if (historyItems.has(item)) {
    historyItems.delete(item)
  }
  historyItems.add(item)
  saveHistoryItems()
  return getHistoryItems()
}

export function deleteHistoryItem(item: string) {
  historyItems.delete(item)
  saveHistoryItems()
  return getHistoryItems()
}
