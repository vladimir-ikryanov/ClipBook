import {addClip, Clip, ClipType, deleteAllClips, deleteClip, getAllClips, updateClip} from "@/db";
import {prefGetClearHistoryOnMacReboot} from "@/pref";

declare const isAfterSystemReboot: () => boolean;

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
let selectedItemIndices: number[] = [];
let visibleHistoryLength = 0;
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
  await addClip(new Clip("rgb(255 100 3 / 80%)", "/Applications/Safari.app"))
  await sleep(500)
  await addClip(new Clip("hsl(330 100% 50%)", "/Applications/Safari.app"))
  await sleep(500)
  await addClip(new Clip("#65a30d", "/Applications/Safari.app"))
  await sleep(500)
  await addClip(new Clip("https://clipbook.app", "/Applications/Safari.app"))
  await addClip(new Clip("https://github.com/vladimir-ikryanov/ClipBook", "/Applications/Safari.app"))
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
  await addClip(new Clip("Keep everything you copy and quickly access your macOS clipboard history whenever you need it.\n" +
      "\n" +
      "ClipBook runs in background and remembers everything you copy. You will never loose what you have already copied.\n" +
      "\n" +
      "Your clipboard history is always at your hands. To open your macOS clipboard history just press the following global keyboard shortcut.", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip("Standard clipboard stores only one entry and overwrites the previous one. It is easy to accidentally overwrite. It is inconvenient and wastes a lot of time because of such a limitation. If you copy a lot, if you are annoyed by wasting time searching for information that was copied just a couple of minutes or hours ago, if you are tired of constantly switching applications for copying and pasting, then the clipboard history app is for you. Once you try it, you will no longer be able to imagine working on a Mac without this application.", "/System/Applications/Notes.app"))
  await addClip(new Clip("Clipboard history app for your Mac", "/System/Applications/Notes.app"))
  history = await getAllClips()
}

async function loadHistory() {
  // Clear history on Mac reboot.
  if (prefGetClearHistoryOnMacReboot() && isAfterSystemReboot()) {
    await deleteAllClips()
    history = []
    return
  }

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

export function isTextItem(item: Clip): boolean {
  return item.type === ClipType.Text ||
      item.type === ClipType.Link ||
      item.type === ClipType.Email ||
      item.type === ClipType.Color
}

function findItem(content: string, imageFileName: string): Clip | undefined {
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
      let contentHasText = item.content.toLowerCase().includes(filterQuery.toLowerCase());
      if (!contentHasText && item.type === ClipType.Image) {
        let imageTitle = "Image (" + item.imageWidth + "x" + item.imageHeight + ")";
        if (item.imageText && item.imageText.length > 0) {
          imageTitle = item.imageText;
        }
        contentHasText = imageTitle.toLowerCase().includes(filterQuery.toLowerCase());
      }
      return contentHasText
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
                                     imageText: string): Promise<Clip[]> {
  let item = findItem(content, imageFileName)
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
    item.imageText = imageText
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

export function setSelectedHistoryItemIndex(index: number) {
  selectedItemIndices = []
  selectedItemIndices.push(index)
}

export function getSelectedHistoryItemIndex(): number {
  return selectedItemIndices.length > 0 ? selectedItemIndices[0] : 0
}

export function getSelectedHistoryItem(): Clip {
  return getHistoryItems()[getSelectedHistoryItemIndex()]
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
