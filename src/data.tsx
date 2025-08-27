import {
  addClip,
  Clip,
  ClipType,
  deleteAllClips,
  deleteClip,
  getAllClips,
  getFilePath, getHTML,
  getImageFileName,
  getImageText, getRTF,
  updateClip
} from "@/db";
import {prefGetClearHistoryOnMacReboot, prefGetLanguage} from "@/pref";
import {getClipType} from "@/lib/utils";
import {loadTags, Tag} from "@/tags";
import {emitter} from "@/actions";

declare const getImagesDir: () => string;
declare const isAfterSystemReboot: () => boolean;
// Returns a string that contains the app name, path, and icon separated by '|'.
declare const getAppInfo: (appPath: string) => string;
declare const getDefaultAppInfo: (filePath: string) => string;
declare const getRecommendedAppsInfo: (filePath: string) => string;
declare const getAllAppsInfo: () => string;
declare const isFileExists: (filePath: string) => boolean;

export let FinderIcon = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAAECgAwAEAAAAAQAAAEAAAAAAlNz6EQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAE7tJREFUeAHtW3+MXcV1Pve9t7tvf3vttWOv7cU2BhwMgTUBm+IAEYnSQCiISAS1xf8QRUkrov5Q1ShVEuKSpgE1IWmpRJCDKpQUCPmhVkrcJkRAkRswBbdAG0hSAoYYG9sbvOvdfb/7fd/Mue++t/sWx02rSvWs587MmTNnzvnOmblz7302O5VOIXAKgVMI/D9GIDlJ20923ElOd8LDGifMGRl/GUPIy5wbe+C5scbKte9Jij0XWyN3huUaq9C1hH0oiyh7E2vgL4j3upfoTxNp9WrZdo7O2I7VRZst16xWq6k/yeUDX6NuSSJZDZS/YL3RaBxH+Xq9Xn8J9cenp6e/Pz4+vg8D6sgE4oTACBqGaRa7wjDLL//bfed0rdn46aSneGWjYfkklzGyjnoO4jg9uVl6am+DLiOSoGPP8SnbuyUBaomVKjWDKEAH+ILRaFBASJxCCbSUJ9ar1epTBw8e3Llp06bvgqeK/KZANCUHsQtdydM1tvvAH3RtOPvxpLvnahpPxkY9Ggxj5W032ssoLaFF8CITlWaC1wJI1ar9+mDZhrq7rQoWeDT0kSeY2OSHDI8qyYPh4oEsyisUClvWrFnzbYBw18033zyAgdTdIZOc9kuMsXZy2qaA7lXfO/KXyeCSP4a8vDUSS6j8AiVtY19wbCzBJ16K1BjyeB2VUsluGa/bWE/eypWqvE9jkuj1NAo4PtrC4Uku+E6AIlJkpcY0rLu7+/zt27dvPXTo0Lf37dtX0dAOl8XQkedXfufVj+eHV3yyEcNV4UhnshellgEjoS1RMY5JYDSuYBQzirhsOL5WtzXVX9hjF/cBh5rNlavi9SjRMgEYORiriMEQLQGGvIwm4hGITNtBm546du+qVas+hGFlZGo9L4XR88gCND/65R9syw+95U9oQFKDERQRs4c1l0EwkVxQiKEewz2dEm2Nx6qUIexnvVqzq4dr1qg1rAowvI9lkBaAdeOppujsjzyueks7zj8wOHTj3r17rwJPAXm+l0BcDIDu7nUTn8QenaenlBpAPq5nKk3vyqMAgW0aLBq9HvcHp1NxAuP9lJdUSnbNWBfEYxau/QyU5G3Uw91AU8JgphYwQMvuGYEhyon86zec/mnQu5EXtHUhIpHKj37m3rOsp/9yekphTIOpSTSSpVDHRKSTRzSCwcmjsSl/9IoDkuBWtzE3Z5uGitr8CEJ7ckCc7m3Kz4LCftclSyetp6dn8+7du7eBhfsdbWtJnQAo5NddeCVcEvpjANAYz26wgyKjCQ7BiMtFNAxhSZoygSKtUrGrlwZDcPuSQfI6wWN/1DUrI3SEpUJ6O08Ww+y409affgXGLrgMSGxP1LCQDC69SJ7XRJhKioVJZTyYuPq5K8lA1H1SCYQd4gOEooPV+xNEU6NcsitWhvB377cb1KoYBHBJ+KaniErgj7AhUhsmyYCuvoGyHBrouxBdvxwAuXzXOoUvBTPcUYSdNxgCc8Nk1IlrPu740iIaTQ4LyxhknubYETw4ho35nCWDOvmF9R8ONgITSntKQQONxnkP6/RJejAiIJAf+EMUOQhd3T3jkHdCAFA+c95yhVFtfhFxgpCZXZPxzoaYxwUTEgSWJHG/iMaKgM1TmsaNLsGmetlIDH/U6UUBI2ZKgwpxzyCpBQRFYmCk8eojqJiPGijplhj7QM/n86OgYxJZQPsiY0BFY9ouGJbrr+sWRwPDSFglg2lzKoE0tDW57KB89ssMdASvKOypMXjrlTm7ZCnCF4Aw/IOBYZzkZIyXMMqD4ZSYehw0rXnw8pwABmdVyZZHAPr70CQA81KnPSDXqCW5pIBJBQJKzJxQsRjSKdoCIyifBUKbo6ZD6KPUcwLvKISuXLFLVvamR9+sVhG2LCmtUw6NTueOXic4NDabAqigMBpy+R7WYs6yLYwKOSAzr1sgZ6SHqyhhAOstGU0aW/n6Z6364U1WfeDPwyEneoy8OhO48Wiv767YSBHHC9wKU0UhR8uA45C9LjLbSHd84fP2a1vfrtI3Q+/nGM+MLKlNMS4vACA52cuCYQEGAJrvTRlphAAMAgUAOqUoAUGq/t1fWb5assp37gwE0uMBSrdGep4A4pa3ZQAKIpJ0AMooSaU9tcwHIufadfddODKX7J6v7AI+ATyOcSOlDwUgMjx5n7fbyyZnew8NkMIoUfcI0K2NfaRlj8dYHgMDeACDgerDpiheymCKY3j/P3c4rH96iilVnHUGeNNrLXXyc44KZKR8WhBxTBzr0dMOoiZru3QGgIoH/VqHREPSPm+Dq69/IBjjNB+PUidASiqVbctot7yvx9/odVeWyjO5gWqwDVCYfA5vu7HZSFC9DUgNXuDSGQBndmM8GhyYLB31/sFhW71uvfUODYfIYT+XQBzn0dBTq9hbl/WG8PcIcM/FOR0MgeAeRjkI2ZxjaHhJCpDzcGgKSqx728sovqXoDACVpxEZg9PdlyK8Dx7jGh96/8esZ3iZLbnuY2EC9teieN09QEC5rreOV0kNAZAaGr27kOeovBvwux/9fRseWWa/c/PvieZ9XnJ8jeeROIalZEb5QbHWa+u9A8sa3V3IS1ffP3uglTW00tsN7QF7+lqMQOCW40YplHkAYmKBfm5cVw0dsS9eNmLTs2WbqxClk0+cL9UHYjR7pDndeVYsW4L3lnYUmS9I4sLrfBBaeP1rJEykoUIV3uG5AG2JpFidDFEqBQOTKvgJLV54nNYfvELPMFFOUx5FBdntpe/sNNLHcDw3Rr0wke8oj3gH4ZTBlDpFrdbLQgehwNHmHD/vsxMqiMeVbKLFsAiTBiHxCpLG18q2cajQco+mYZTG7MZJ4Ri2NJZtHsJEJ0AUSzqy6xA0arbJwqSxYUQgtF0XBUBT8Z4qu4KodLwUiobF12Xk8OSKsS0TuDYrDRvtzclrnW6BPj4rK8iIsrnUJNPbESAoyecBhYA8z37kCKTLbS8XBUBhhxCTMoCYUzFFH6guWiCnfeR3XhFxURtnhOV9iAD+UR6Vy4Q8ed2raV0jg7EE1ZcOJQpkzBWh0FiqwpiiHD0jUNAiaVEAqLQLb10CnLRpdTA3csILabi2Tcy7xdLeAjZDjICCepaPHhIY4PfShzY1WKAvjiVv0CaCArpHoJcur73sCACVbU0IPZCyCnl/lpYFzfvTErt+MR+XAMXHZcR+9yZnIAhsexIoDO9swlglD3s08ASrqHdgKYE5+wSpMZlLRwD8KZC8LR7ODJ5Hxx1AkcJpM3XnoyG9XYnNlNrAhRHCQ4ZzHYclwnFK0XgBE2kEXf1xf+JyxdOBziT8pNbkJVcTzIz6qnYEgKe4sKmE+7sb4Uq5AqLHTTBhaLticVLvFwtkPn/guI0OFGxyctLK5bI2RGqCjxk2ODhoXV08hoSUKg5gPKU0EFSXYBiYiRpFDOavkwY+vy26jGzZEQB5EhugQhHzhw8jqoR12rJ5Zd7GMDQz4cvJ0m0q320f/ubP7PoNdRttHLXq7DE8O+FjCBQdGRmxs895mxWLRYFCm+XFlnkCzQ0QuBFopxEqLLLgCOHCveZkIoB2cGBGEZ+EU4SXpKGf4d6Ipz5NRS2QBJrwCArkCn22f2653fYvB81msRk2BptHCPJ/70n7j89cYaVqTh9JKUO3Sy6RKDNIolqh5iCJFzxc74oAAMdtLDgwDiZTW+oYAXx6841IxtKrNJQTB8mpqOBhTMJNTW+O4BuGn0dCnD9Juizft9ySrkE8Xlcghg8aEMszAkK5cXzSenu68KYIj7vRYsrQcEVW60YYDCUtbJwqqR/GtN6JTgIAKsWZgyKoB9NbjJKR+EQOq2mH+DUOVY+eQEcYkEXRABCKWOckZTc3KF3D+wV6MLtrh/kxB3kJMAXGOqveT8cILPIAPD8eE8d8/JBK/vbUMQKooBLn5rRSljXUYx8fhPS0CII8T3oOl9gvpcgT2yopBy8CFEm6hhq9RgOZaECkqh2JKOgIJEVHrLOZ0l0upqTKnBDz+alTY9sunQGo1RmfhXSaWEm461JPGdKw2Xuu0abTs+MbeI7EJ7gQ1fK4zhKMjmiY5uZjNhPIIcogT23QPZICJXoXfAQnQ+MboY/cdKMou+69X6UiAXwsnV/ACEwfPb+EGh1SrT7X4jkqTkOoP3M0pF6atq7J5638/Z3NdwcU6Xw+hsAwk46kV2wOBgnsQ9sfkWUQ6UiKCBoiz5vddecX7ac/+bHNzMyIRg/TWHqdJflIY9vHh9r8aycAeO8IyQ1hy41gHXS+Exy69ku29nT8TOiZ+6y850tNw91YL9vlxLbeK5KHCbQKPpmH5RaNiQbJMNQfuO9r9vX7vmr46mufuvVzKShapgQ7RpvAQt1BCxPMv3YCIHC6kgxB1H2Dc3AovDa62d6Y+CN76znnWf2xz1vpB38KoNwijIFPmDwsfWyYIHhXdc6FhN9IpUbIGBqE5cZX6Hfecbvdcfuf2VmbN9sHP/JRO3PT2Rrj3mfDI0D1GDWLgdB5D6AN6Q9oqB1NUYxRdjAMa5a3r+mVl9vBrqJt6ftre2rPLpt58RErvvc2y6+ckELk11hWMsnBodJMBHhqtmJL+6EWZUe0fvTcM/bZnZ9Q2G/d/g77wA032tZt+IGalkRzf3DRLi+0eT+Ka8EZMmVHAJJGrdaohxNeq8AwmjTtslCaExwb2WYvbl5uW4bvsdeeedT233uNFTa+y7rP32HJ2ndg01t4qhbZMHq6hFMi3q7zjPDk3ifswfu/Zv/08EO2enytXXfDb9p177/B1q3f0GISgWCEuSz3OGnhIJXMZGxuqbbDxzYP40tWf+rw00m+OEaxwdhQtoxGw9F1HgBnK4/uthUHd9t/PvuUHXh1vzWKI9az4Z2WH5uwZOlZlhsYE82KtBQyylN4WTJl9UP/br912o/t8Ms/socfedQmjx6xlWNr7NyJCbvs8ncjQ0Y+Dct2VdT2peYgkFirVo+ce+b4ZlQnkd/0nSDjpZGUS68nPT1jqKdG6r4PhXXE5W2QdfTyhMgaOnDN289H3meHhi+3FSv32CXHnrD60Rds/4tP2cv/+CDFLZruhtfWnrbeNp37NsMPG2zi/AvsgrdfaH19/L4Z58tImOcgLYsmA/UrleYOa6iUbPaxtnBcwrR6aWZ/rmv4PLHTQBjM+3p4TKat8UGJthMEJAHDFrCoJn12YOjd9vPhd1lx1WFbcvpPbKL0svVWDlp3+SjOSzOWr81qXA1f4WpJr5ULQ3b2+FK7dGKjrVw9boPDI+rn3I24u6c20AHc5cUBvdhGkkNUCTqTZ65c2Q+SNGVXNrUDIO+DoV6fPvRkrv8t7wvM9DYFNjcU3b7QGU6AVCAuAj4SEzDsHwIJ4MzlRu21Pnyi79umjU5fiuPurp3ejSlN2dYzjtn2i5fbGzMVm8U7RC2xaHxqHOb1s34aAZEn6BuAoFs45sjh159GVfcXkZwJZYAtQ4gM1eMvfPMh2IHfrWIynihQ+g+cvNQwP8ygX7z0CcfEkvVs1trkGPJEuTpUkQ+b4KuTNZ3j07UsSZQWokxzkjW2WToIrHsmn+8DTz+x52E0HQBUm6kTAJWph//ixdrU64/y1qQnQ+72yFKcJdDhBOr3kr/94VNkhs95aCzpninHeVMaVuT+SfAx0pA5Ns3RYKpOmspII47Op47IQ9rU1LFnbvnEx/8NpJbNz/k6AUC0Zqf/9W9ux3fsshtEhTU5vYXPXv51mCXpqSHRwykvjY0vQj0aJBNiXKZ4sRR+eigYxydCjwKVCHHyiI/jCEKkoZkm74+ExkP/8N3PoT6HzJNNEB47WSx6Tym99Mh075lXFvK9q/A7O1oNz+i1F4yVLChEKj0ey0hRO7IEYLgzRr7QiaurwxIZ0q00N2PXTuStrzuPD8k4CrWtbR9LDTirG+xguWbse2X/Sw/e9NvX70J1CpkRQCNa0kIRQAaqxAFTB79y6Z2VIy/cp90fBnBCGsw2xcl4lopD3BkY6m1ZG13kIb8y+UnL/MaA9Bz+u8Hzr8ziGR51ugdR4Uai1UzufW6gzEjiA53OOXrk8D9/aMcHdoJM40vImG1+WjQC4qDG9NNffrw4fmmpMDB2AZQsMPqEv8KQWDE0AQjXLqZRXYaqS3CSxiBAJ/+hZJuCOA7/AIjG1Uq2dnDGLjpjAD8lqul3RGQXn/hpbJgr0GgX4w7yBESjsf/ln33r+t94zx/iZ/OH0DmNvGD4g77oEpCa4OF+UDv+7FefbVSOPdK1bPOKXM/AODqzL27AEg1STSoGzKGrPB1eAKAR+kiWT2CU6pHO387kKm/YtRctwbtB/PaIT4eUDROZeA31oJ4MJw3GY8N7fvfff+uWD+644e65ubkjIHvoh8EgtCefu52ebRNyHo97kQeQB/s3XjXed95N7ywMbTg/1zs8jp8TLcdZv5jkC/3w7IIyg6JuRNagZh2ycdwoW3HuFfvhrWvsOH5Cf2xu/iMtzvflWq1aKpdKk7OzswcOvnbgub0/3PPYF2679UmIoNHHkHn+93X/3wIAcnRe4HJxIPpRZ+b5lP9HiHQeqmJ8ovY/l4LrQ2QytLm+aexxZIY7j5ekedh3NB48HY/C7MumsNCakxJZTsLM3+D9XwCAIND4N/U6eNK0YLimvQtX6GVGAz3uhmu/Rpt9/xvJo4COoadpNPMJeR18aToZADiY45izIX+ysijvZJKHtoORLU9Y3q9K6V+VnBNWPMPoQGRIp6onjMB/AUz+r5rlodoQAAAAAElFTkSuQmCC"

export enum TextType {
  Text = "Text",
  HTML = "HTML",
  RTF = "RTF"
}

type FilterOptions = {
  types: ClipType[]
  favorites: boolean
  tags: Tag[]
  apps: AppInfo[]
}

export enum SortHistoryType {
  TimeOfFirstCopy,
  TimeOfLastCopy,
  NumberOfCopies,
  Size
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

export type AppInfo = {
  name: string
  path: string
  icon: string
}

let unknownAppInfo: AppInfo = {
  name: "Unknown",
  path: "",
  icon: ""
}

export enum LanguageCode {
  EN_US = "en",
  EN_GB = "en-GB",
  DE = "de",
  IT = "it",
  PT_BR = "pt-BR",
}

export class Language {
  code: LanguageCode;
  name: string;
  nativeName: string;

  constructor(code: LanguageCode, name: string, nativeName: string) {
    this.code = code;
    this.name = name;
    this.nativeName = nativeName;
  }
}

export const supportedLanguages: Language[] = [
  new Language(LanguageCode.EN_US, "English (US)", "English"),
  new Language(LanguageCode.EN_GB, "English (UK)", "English (UK)"),
  new Language(LanguageCode.DE, "German", "Deutsch"),
  new Language(LanguageCode.IT, "Italian", "Italiano"),
  new Language(LanguageCode.PT_BR, "Portuguese (Brazil)", "Português (Brasil)"),
];

export type TagCheckedState = {
  tag: Tag
  checked: boolean
}

let history: Clip[] = [];
let filteredHistory: Clip[] = [];
let filterQuery = "";
let filterHistory = false;
let filterOptionsUpdated = false;
let filterOptions: FilterOptions = {
  types: [],
  favorites: false,
  tags: [],
  apps: []
};
let shouldUpdateHistory = false;
let lastSelectedItemIndex = -1;
let selectedItemIndices: number[] = [];
let visibleHistoryLength = 0;
let previewVisible = true;
let filterVisible = false;
let infoVisible = true;
let sortType = SortHistoryType.TimeOfLastCopy;
let sortOrderReverse = false;
let sourceApps: AppInfo[] = [];
let pasteNextItemIndex = -1;

function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

loadSettings()
// await loadHistory()
// await loadHistoryForPromo()

// noinspection JSUnusedLocalSymbols
async function loadHistoryForPromo() {
  await deleteAllClips()
  await addClip(new Clip(ClipType.Text, "Get it. Try it. Use it if you like it.", "/Applications/Arc.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Email, "vladimir.ikryanov@clipbook.app", "/System/Applications/Mail.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Color, "rgb(255 100 3 / 80%)", "/Applications/Sketch.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Color, "#ea3380", "/Applications/Sketch.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Link, "https://openai.com/index/sora-is-here", "/Applications/Safari.app"))
  await addClip(new Clip(ClipType.Link, "https://github.com/vladimir-ikryanov/ClipBook", "/Applications/Safari.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "🔒 All data is securely stored on your Mac and never leave it", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "✏️ Edit and preview history items", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "⭐️ Add items to favorites", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "🔎 Type to search", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "⌛️ Unlimited clipboard history", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "Keep everything you copy and quickly access your macOS clipboard history whenever you need it.\n" +
      "\n" +
      "ClipBook runs in the background and remembers everything you copy. You will never lose what you have already copied.\n" +
      "\n" +
      "Your clipboard history is always at your hands. To open your macOS clipboard history just press the following global keyboard shortcut.", "/System/Applications/Notes.app"))
  await sleep(500)
  await addClip(new Clip(ClipType.Text, "Standard clipboard stores only one entry and overwrites the previous one. It is easy to accidentally overwrite. It is inconvenient and wastes a lot of time because of such a limitation. If you copy a lot, if you are annoyed by wasting time searching for information that was copied just a couple of minutes or hours ago, if you are tired of constantly switching applications for copying and pasting, then the clipboard history app is for you. Once you try it, you will no longer be able to imagine working on a Mac without this application.", "/System/Applications/Notes.app"))
  await addClip(new Clip(ClipType.Text, "Clipboard history app for your Mac", "/System/Applications/Notes.app"))
  history = await getAllClips()
}

export async function loadHistory() {
  // Load all tags.
  loadTags()

  // Clear history on Mac reboot.
  if (prefGetClearHistoryOnMacReboot() && isAfterSystemReboot()) {
    await deleteAllClips()
    history = []
    return
  }

  // Fill the history with 10000 items.
  // for (let i = 0; i < 10000; i++) {
  //   history[i] = new Clip(ClipType.Text, "Standard clipboard stores only one entry and overwrites the previous one. It is easy to accidentally overwrite. It is inconvenient and wastes a lot of time because of such a limitation. If you copy a lot, if you are annoyed by wasting time searching for information that was copied just a couple of minutes or hours ago, if you are tired of constantly switching applications for copying and pasting, then the clipboard history app is for you. Once you try it, you will no longer be able to imagine working on a Mac without this application.", "/Applications/Safari.app")
  // }

  history = await getAllClips()
  sortHistory(sortType, history)
  requestHistoryUpdate()
}

export function requestHistoryUpdate() {
  shouldUpdateHistory = true
  loadSourceApps(history)
}

function loadSettings() {
  if (localStorage.getItem("previewVisible")) {
    previewVisible = localStorage.getItem("previewVisible") === "true"
  }
  if (localStorage.getItem("filterVisible")) {
    filterVisible = localStorage.getItem("filterVisible") === "true"
  }
  if (localStorage.getItem("infoVisible")) {
    infoVisible = localStorage.getItem("infoVisible") === "true"
  }
  if (localStorage.getItem("sortType")) {
    sortType = parseInt(localStorage.getItem("sortType")!)
  }
  if (localStorage.getItem("sortOrderReverse")) {
    sortOrderReverse = localStorage.getItem("sortOrderReverse") === "true"
  }
}

function loadSourceApps(history: Clip[]) {
  sourceApps = []
  for (let i = 0; i < history.length; i++) {
    let appPath = history[i].sourceApp
    if (appPath && appPath.length > 0) {
      let appInfo = getAppInfoByPath(appPath)
      if (!appInfo) {
        appInfo = parseAppInfo(getAppInfo(appPath))
        if (appInfo) {
          sourceApps.push(appInfo)
        }
      }
    } else {
      let appInfo = getAppInfoByPath(unknownAppInfo.path)
      if (!appInfo) {
        sourceApps.push(unknownAppInfo)
      }
    }
  }

  sortAppsAlphabetically(sourceApps)
  emitter.emit("UpdateApps")
}

function getAppInfoByPath(appPath: string): AppInfo | undefined {
  for (let i = 0; i < sourceApps.length; i++) {
    if (sourceApps[i].path === appPath) {
      return sourceApps[i]
    }
  }
  return undefined
}

export function getSourceApps(): AppInfo[] {
  return sourceApps
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
  return item && (item.type === ClipType.Text ||
      item.type === ClipType.Link ||
      item.type === ClipType.Email ||
      item.type === ClipType.Color)
}

export function isImageItem(item: Clip): boolean {
  return item && item.type === ClipType.Image
}

export function isLinkItem(item: Clip): boolean {
  return item && item.type === ClipType.Link
}

export function isFileItem(item: Clip): boolean {
  return item && item.type === ClipType.File
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
    requestHistoryUpdate()
  }
}

function hasText(searchString: string, item: Clip) {
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
  // Search in content.
  return item.content.toLowerCase().includes(searchString)
}

export function getHistoryItems(): Clip[] {
  if (filterQuery.length > 0 || filterOptionsUpdated) {
    if (!filterHistory && !shouldUpdateHistory) {
      return filteredHistory
    }
    filterHistory = false
    filteredHistory = Array.from(history.filter(item => {
      let keep = filter(item)
      if (filterQuery.length > 0 && keep) {
        return hasText(filterQuery.toLowerCase(), item)
      }
      return keep
    }));
    visibleHistoryLength = filteredHistory.length
    sortHistory(sortType, filteredHistory)
    shouldUpdateHistory = false
    return filteredHistory
  }
  if (shouldUpdateHistory) {
    sortHistory(sortType, history)
    shouldUpdateHistory = false
    visibleHistoryLength = history.length
  }
  return history
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
                                     isFolder: boolean,
                                     rtf: string,
                                     html: string): Promise<Clip> {
  let type = getClipType(content, imageFileName, filePath)
  let item = new Clip(type, content, sourceAppPath)
  item.content = content
  item.rtf = rtf
  item.html = html
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
  requestHistoryUpdate()
  return item
}

export async function deleteHistoryItem(item: Clip) {
  await deleteItem(item)
}

export async function updateHistoryItem(id: number, item: Clip) {
  await updateClip(id, item)
  requestHistoryUpdate()
}

function isFavoriteOrTagged(item: Clip) {
  return item.favorite || (item.tags && item.tags.length > 0);
}

function getFavoriteItems(): Clip[] {
  return history.filter(item => isFavoriteOrTagged(item))
}

export async function clear(keepFavorites: boolean): Promise<Clip[]> {
  if (keepFavorites) {
    let favorites = getFavoriteItems()
    if (favorites.length > 0) {
      for (const clip of history) {
        if (!isFavoriteOrTagged(clip)) {
          await deleteClip(clip.id!)
        }
      }
      history = favorites
      requestHistoryUpdate()
      return getHistoryItems()
    }
  }
  history = []
  requestHistoryUpdate()
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
    case SortHistoryType.Size:
      history.sort((a, b) => compareItemsSize(a, b))
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
  // Reverse order if needed.
  if (sortOrderReverse) {
    history.reverse()
  }
}

function itemSize(item: Clip): number {
  if (item.type === ClipType.Image) {
    return item.imageSizeInBytes
  }
  if (item.type === ClipType.File) {
    return item.fileSizeInBytes
  }
  return item.content.length
}

function compareItemsSize(a: Clip, b: Clip): number {
  return itemSize(b) - itemSize(a)
}

function filter(item: Clip) {
  if (filterOptions.favorites) {
    return item.favorite
  }
  if (filterOptions.types.length > 0) {
    return filterOptions.types.includes(item.type)
  }
  if (filterOptions.apps.length > 0) {
    if (!item.sourceApp) {
      return false
    }
    for (let i = 0; i < filterOptions.apps.length; i++) {
      if (item.sourceApp === filterOptions.apps[i].path) {
        return true
      }
    }
    return false
  }
  if (filterOptions.tags.length > 0) {
    if (!item.tags) {
      return false
    }
    for (let i = 0; i < filterOptions.tags.length; i++) {
      if (!item.tags.includes(filterOptions.tags[i].id)) {
        return false
      }
    }
  }
  return true
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
  return [...selectedItemIndices]
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
  if (filterQuery !== query) {
    filterQuery = query
    filterHistory = true
  }
}

export function getFilterQuery(): string {
  return filterQuery
}

export function getHistoryItem(index: number): Clip {
  return getHistoryItems()[index]
}

export function getHistoryItemById(id: number): Clip | undefined {
  for (let i = 0; i < history.length; i++) {
    if (history[i].id === id) {
      return history[i]
    }
  }
  return undefined
}

export function getHistoryItemIndex(item: Clip): number {
  return getHistoryItems().findIndex(i => i.id === item.id)
}

export function setPreviewVisibleState(visible: boolean) {
  previewVisible = visible
  localStorage.setItem("previewVisible", visible.toString())
}

export function getPreviewVisibleState() {
  return previewVisible
}

export function setFilterVisibleState(visible: boolean) {
  filterVisible = visible
  localStorage.setItem("filterVisible", visible.toString())
}

export function getFilterVisibleState() {
  return filterVisible
}

export function setDetailsVisibleState(visible: boolean) {
  infoVisible = visible
  localStorage.setItem("infoVisible", visible.toString())
}

export function getDetailsVisibleState() {
  return infoVisible
}

export function saveSortType(type: SortHistoryType) {
  sortType = type
  localStorage.setItem("sortType", type.toString())
}

export function getSortType(): SortHistoryType {
  return sortType
}

export function saveSortOrderReverse(reverse: boolean) {
  sortOrderReverse = reverse
  localStorage.setItem("sortOrderReverse", reverse.toString())
}

export function isSortOrderReverse(): boolean {
  return sortOrderReverse
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
  if (historyUpdated) {
    requestHistoryUpdate()
  }
  return historyUpdated
}

export function getDefaultApp(filePath: string) : AppInfo | undefined {
  return parseAppInfo(getDefaultAppInfo(filePath))
}

export function getRecommendedApps(filePath: string): AppInfo[] {
  return parseAppsInfo(getRecommendedAppsInfo(filePath))
}

function sortAppsAlphabetically(apps: AppInfo[]) : AppInfo[] {
  return apps.sort((a, b) => a.name.localeCompare(b.name))
}

function parseAppInfo(appInfo: string) {
  if (appInfo.length === 0) {
    return undefined
  }
  let parts = appInfo.split('|')
  return {
    name: parts[0],
    path: parts[1],
    icon: parts[2]
  }
}

function parseAppsInfo(appsInfo: string) {
  if (appsInfo.length === 0) {
    return []
  }
  let apps: AppInfo[] = []
  let parts = appsInfo.split('*')
  for (let i = 0; i < parts.length; i++) {
    let appInfo = parseAppInfo(parts[i]);
    if (appInfo) {
      apps.push(appInfo)
    }
  }
  return apps
}

export function getAllApps(): AppInfo[] {
  return sortAppsAlphabetically(parseAppsInfo(getAllAppsInfo()))
}

export function getFileOrImagePath(item: Clip) {
  if (item.type === ClipType.File) {
    return getFilePath(item)
  }
  if (item.type === ClipType.Image) {
    return getImagesDir() + "/" + getImageFileName(item)
  }
  return undefined
}

export function setShouldUpdateHistory() {
  shouldUpdateHistory = true
}

export function resetFilter() {
  filterOptions.types = []
  filterOptions.tags = []
  filterOptions.apps = []
  filterOptions.favorites = false
  shouldUpdateHistory = true
  filterOptionsUpdated = true
  filterHistory = true
}

export function filterByType(type: ClipType) {
  resetFilter()
  filterOptions.types = [type]
}

export function filterByTag(tag: Tag) {
  resetFilter()
  filterOptions.tags = [tag]
}

export function filterByFavorites() {
  resetFilter()
  filterOptions.favorites = true
}

export function filterByApp(app: AppInfo) {
  resetFilter()
  filterOptions.apps = [app]
}

export function isFilterActive(): boolean {
  return filterOptions.types.length > 0 || filterOptions.favorites || filterOptions.tags.length > 0 || filterOptions.apps.length > 0
}

export function getSelectedItemTextTypes(item: Clip | undefined): TextType[] {
  if (item && item.type === ClipType.Text) {
    let types: TextType[] = [TextType.Text]
    if (getHTML(item).length > 0) {
      types.push(TextType.HTML)
    }
    if (getRTF(item).length > 0) {
      types.push(TextType.RTF)
    }
    return types
  }
  return []
}

export function fileExists(filePath: string): boolean {
  return isFileExists(filePath)
}

export function getLanguageByCode(code: LanguageCode): Language | undefined {
  return supportedLanguages.find(lang => lang.code === code);
}

function toLocale(languageCode: LanguageCode): string {
  switch (languageCode) {
    case LanguageCode.EN_US:
      return "en-US";
    case LanguageCode.EN_GB:
      return "en-GB";
    case LanguageCode.DE:
      return "de-DE";
    case LanguageCode.IT:
      return "it-IT";
    case LanguageCode.PT_BR:
      return "pt-BR";
    default:
      return "en-US"; // Default to English (US)
  }
}

export function formatDateTime(date: Date): string {
  return new Intl.DateTimeFormat(toLocale(prefGetLanguage()), {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(date);
}

function getFavoriteItemsCount(): number {
  return history.filter(item => item.favorite).length;
}

export function getPasteNextItemIndex(): number {
  return pasteNextItemIndex
}

export function getNextItemIndexForPaste(): number {
  pasteNextItemIndex++
  if (pasteNextItemIndex >= history.length) {
    resetPasteNextItemIndex()
  }
  return getFavoriteItemsCount() + pasteNextItemIndex
}

export function resetPasteNextItemIndex() {
  pasteNextItemIndex = -1
}
