let historyItems: string[];

loadHistoryItems()

addHistoryItem("Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world! Hello, world!")
addHistoryItem("Hello, world 2!")
addHistoryItem("Hello, world 3!")
addHistoryItem("Hello, world 4!")
addHistoryItem("Hello, world 5!")
addHistoryItem("Hello, world 6!")
addHistoryItem("Hello, world 7!")

function loadHistoryItems() {
  historyItems = []
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

export function clear() {
  historyItems = []
  saveHistoryItems()
  return getHistoryItems()
}
