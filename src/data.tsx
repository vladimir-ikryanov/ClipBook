import {addClip, Clip, ClipType, deleteAllClips, deleteClip, getAllClips, updateClip} from "@/db";

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
let infoVisible = true;
let sortType = SortHistoryType.TimeOfLastCopy;

loadSettings()
await loadHistory()
// await loadHistoryForPromo()

function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// noinspection JSUnusedLocalSymbols
async function loadHistoryForPromo() {
  await deleteAllClips()
  await addClip(new Clip("Get it. Try it. Use it if you like it.", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip("<section class=\"section-sm text-center\">\n" +
      "  <div class=\"container\">\n" +
      "    <div class=\"row justify-center\">\n" +
      "      <div class=\"sm:col-10 md:col-8 lg:col-6\">\n" +
      "        <span\n" +
      "          class=\"text-[8rem] block font-bold text-dark dark:text-darkmode-dark\">\n" +
      "          404\n" +
      "        </span>\n" +
      "        <h1 class=\"h2 mb-4\">Page not found</h1>\n" +
      "        <div class=\"content\">\n" +
      "          <p>\n" +
      "            The page you are looking for might have been removed, had its name\n" +
      "            changed, or is temporarily unavailable.\n" +
      "          </p>\n" +
      "        </div>\n" +
      "        <a\n" +
      "          href=\"{{ site.BaseURL | relLangURL }}\"\n" +
      "          class=\"btn btn-primary mt-8\">\n" +
      "          Back to home\n" +
      "        </a>\n" +
      "      </div>\n" +
      "    </div>\n" +
      "  </div>\n" +
      "</section>", "/Applications/Visual Studio Code.app"))
  await sleep(500)
  await addClip(new Clip("john.doe@mail.com", "/System/Applications/Mail.app"))
  await sleep(500)
  await addClip(new Clip("rgb(255 100 3 / 80%)", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip("hsl(330 100% 50%)", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip("#65a30d", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip("https://clipbook.app", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip("🔒 All data is securely stored on your Mac and never leave it", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("✏️ Edit and preview history items", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("⭐️ Add items to favorites", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("🔎 Type to search", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("⌛️ Unlimited clipboard history", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("Keep everything you copy and quickly access it whenever you need it", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("Clipboard history app for your Mac", "/System/Applications/Notes.app"))
  history = await getAllClips()
}

async function loadHistory() {
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

export function findItemByImageFileName(imageFileName: string): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (history[i].imageFileName === imageFileName) {
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

export async function addHistoryItem(content: string,
                                     sourceAppPath: string,
                                     imageFileName: string,
                                     imageThumbFileName: string,
                                     imageWidth: number,
                                     imageHeight: number,
                                     imageSizeInBytes: number): Promise<Clip[]> {
  let item = imageFileName.length > 0 ?
      findItemByImageFileName(imageFileName) : findItemByContent(content)
  if (item) {
    item.numberOfCopies++
    item.lastTimeCopy = new Date()
    await updateClip(item.id!, item)
  } else {
    item = new Clip(content, sourceAppPath, imageFileName)
    item.imageWidth = imageWidth
    item.imageHeight = imageHeight
    item.imageSizeInBytes = imageSizeInBytes
    item.imageThumbFileName = imageThumbFileName
    await addClip(item)
    history.push(item)
  }
  return getHistoryItems()
}

export async function deleteHistoryItem(item: Clip) {
  await deleteItem(item)
}

export async function updateHistoryItem(id: number, item: Clip) {
  await updateClip(id, item)
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

export function getHistoryItemIndex(item: Clip): number {
  return getHistoryItems().indexOf(item)
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
