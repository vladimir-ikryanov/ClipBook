import '../app.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {useEffect, useState} from "react"
import {
  CommandIcon,
  CopyIcon, DownloadIcon,
  Edit3Icon, EyeIcon,
  GlobeIcon, PenIcon,
  ScanTextIcon,
  SettingsIcon,
  StarIcon,
  StarOffIcon,
  TrashIcon, TypeIcon, Undo2Icon, UploadIcon, ZoomIn, ZoomOut
} from "lucide-react"

import { VisuallyHidden } from "@radix-ui/react-visually-hidden";

import {
  CommandDialog,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command"
import {
  prefGetClearHistoryShortcut,
  prefGetCopyTextFromImageShortcut,
  prefGetCopyToClipboardShortcut,
  prefGetDeleteHistoryItemShortcut,
  prefGetEditHistoryItemShortcut,
  prefGetOpenInBrowserShortcut, prefGetOpenInDefaultAppShortcut,
  prefGetOpenSettingsShortcut,
  prefGetPasteSelectedItemToActiveAppShortcut,
  prefGetRenameItemShortcut,
  prefGetSaveImageAsFileShortcut, prefGetShowInFinderShortcut,
  prefGetShowMoreActionsShortcut,
  prefGetToggleFavoriteShortcut,
  prefGetTogglePreviewShortcut,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut,
  prefGetZoomUIResetShortcut
} from "@/pref";
import ShortcutLabel from "@/app/ShortcutLabel";
import {isShortcutMatch} from "@/lib/shortcuts";
import {
  getFirstSelectedHistoryItem,
  getPreviewVisibleState,
  toBase64Icon,
  getSelectedHistoryItemIndices, getSelectedHistoryItems, isTextItem, AppInfo, getDefaultApp
} from "@/data";
import {ClipType, getImageText} from "@/db";
import {HidePreviewPaneIcon, ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import {DialogTitle} from "@/components/ui/dialog";

declare const canZoomIn: () => boolean;
declare const canZoomOut: () => boolean;
declare const canResetZoom: () => boolean;

export type HideActionsReason =
    "cancel"
    | "togglePreview"
    | "toggleFavorite"
    | "paste"
    | "pasteWithTab"
    | "pasteWithReturn"
    | "pasteWithTransformation"
    | "pastePath"
    | "merge"
    | "editContent"
    | "renameItem"
    | "formatText"
    | "copyToClipboard"
    | "copyPathToClipboard"
    | "copyTextFromImage"
    | "saveImageAsFile"
    | "openInBrowser"
    | "showInFinder"
    | "openInDefaultApp"
    | "openWith"
    | "preview"
    | "zoomIn"
    | "zoomOut"
    | "resetZoom"
    | "openSettings"
    | "deleteItem"
    | "deleteItems"
    | "deleteAllItems"

type CommandsProps = {
  appName: string
  appIcon: string
  onHideActions: (reason: HideActionsReason) => void
  onTogglePreview: () => void
  onToggleFavorite: () => void
  onPaste: () => void
  onPasteWithTab: () => void
  onPasteWithReturn: () => void
  onPasteWithTransformation: () => void
  onPastePath: () => void
  onMerge: () => void
  onEditContent: () => void
  onRenameItem: () => void
  onFormatText: () => void
  onCopyToClipboard: () => void
  onCopyPathToClipboard: () => void
  onCopyTextFromImage: () => void
  onSaveImageAsFile: () => void
  onOpenInBrowser: () => void
  onShowInFinder: () => void
  onOpenInApp: (app: AppInfo | undefined) => void
  onOpenWith: () => void
  onPreviewLink: () => void
  onZoomIn: () => void
  onZoomOut: () => void
  onResetZoom: () => void
  onOpenSettings: () => void
  onDeleteItem: () => void
  onDeleteItems: () => void
  onDeleteAllItems: () => void
}

let finderIcon = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAAECgAwAEAAAAAQAAAEAAAAAAlNz6EQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAE7tJREFUeAHtW3+MXcV1Pve9t7tvf3vttWOv7cU2BhwMgTUBm+IAEYnSQCiISAS1xf8QRUkrov5Q1ShVEuKSpgE1IWmpRJCDKpQUCPmhVkrcJkRAkRswBbdAG0hSAoYYG9sbvOvdfb/7fd/Mue++t/sWx02rSvWs587MmTNnzvnOmblz7302O5VOIXAKgVMI/D9GIDlJ20923ElOd8LDGifMGRl/GUPIy5wbe+C5scbKte9Jij0XWyN3huUaq9C1hH0oiyh7E2vgL4j3upfoTxNp9WrZdo7O2I7VRZst16xWq6k/yeUDX6NuSSJZDZS/YL3RaBxH+Xq9Xn8J9cenp6e/Pz4+vg8D6sgE4oTACBqGaRa7wjDLL//bfed0rdn46aSneGWjYfkklzGyjnoO4jg9uVl6am+DLiOSoGPP8SnbuyUBaomVKjWDKEAH+ILRaFBASJxCCbSUJ9ar1epTBw8e3Llp06bvgqeK/KZANCUHsQtdydM1tvvAH3RtOPvxpLvnahpPxkY9Ggxj5W032ssoLaFF8CITlWaC1wJI1ar9+mDZhrq7rQoWeDT0kSeY2OSHDI8qyYPh4oEsyisUClvWrFnzbYBw18033zyAgdTdIZOc9kuMsXZy2qaA7lXfO/KXyeCSP4a8vDUSS6j8AiVtY19wbCzBJ16K1BjyeB2VUsluGa/bWE/eypWqvE9jkuj1NAo4PtrC4Uku+E6AIlJkpcY0rLu7+/zt27dvPXTo0Lf37dtX0dAOl8XQkedXfufVj+eHV3yyEcNV4UhnshellgEjoS1RMY5JYDSuYBQzirhsOL5WtzXVX9hjF/cBh5rNlavi9SjRMgEYORiriMEQLQGGvIwm4hGITNtBm546du+qVas+hGFlZGo9L4XR88gCND/65R9syw+95U9oQFKDERQRs4c1l0EwkVxQiKEewz2dEm2Nx6qUIexnvVqzq4dr1qg1rAowvI9lkBaAdeOppujsjzyueks7zj8wOHTj3r17rwJPAXm+l0BcDIDu7nUTn8QenaenlBpAPq5nKk3vyqMAgW0aLBq9HvcHp1NxAuP9lJdUSnbNWBfEYxau/QyU5G3Uw91AU8JgphYwQMvuGYEhyon86zec/mnQu5EXtHUhIpHKj37m3rOsp/9yekphTIOpSTSSpVDHRKSTRzSCwcmjsSl/9IoDkuBWtzE3Z5uGitr8CEJ7ckCc7m3Kz4LCftclSyetp6dn8+7du7eBhfsdbWtJnQAo5NddeCVcEvpjANAYz26wgyKjCQ7BiMtFNAxhSZoygSKtUrGrlwZDcPuSQfI6wWN/1DUrI3SEpUJ6O08Ww+y409affgXGLrgMSGxP1LCQDC69SJ7XRJhKioVJZTyYuPq5K8lA1H1SCYQd4gOEooPV+xNEU6NcsitWhvB377cb1KoYBHBJ+KaniErgj7AhUhsmyYCuvoGyHBrouxBdvxwAuXzXOoUvBTPcUYSdNxgCc8Nk1IlrPu740iIaTQ4LyxhknubYETw4ho35nCWDOvmF9R8ONgITSntKQQONxnkP6/RJejAiIJAf+EMUOQhd3T3jkHdCAFA+c95yhVFtfhFxgpCZXZPxzoaYxwUTEgSWJHG/iMaKgM1TmsaNLsGmetlIDH/U6UUBI2ZKgwpxzyCpBQRFYmCk8eojqJiPGijplhj7QM/n86OgYxJZQPsiY0BFY9ouGJbrr+sWRwPDSFglg2lzKoE0tDW57KB89ssMdASvKOypMXjrlTm7ZCnCF4Aw/IOBYZzkZIyXMMqD4ZSYehw0rXnw8pwABmdVyZZHAPr70CQA81KnPSDXqCW5pIBJBQJKzJxQsRjSKdoCIyifBUKbo6ZD6KPUcwLvKISuXLFLVvamR9+sVhG2LCmtUw6NTueOXic4NDabAqigMBpy+R7WYs6yLYwKOSAzr1sgZ6SHqyhhAOstGU0aW/n6Z6364U1WfeDPwyEneoy8OhO48Wiv767YSBHHC9wKU0UhR8uA45C9LjLbSHd84fP2a1vfrtI3Q+/nGM+MLKlNMS4vACA52cuCYQEGAJrvTRlphAAMAgUAOqUoAUGq/t1fWb5assp37gwE0uMBSrdGep4A4pa3ZQAKIpJ0AMooSaU9tcwHIufadfddODKX7J6v7AI+ATyOcSOlDwUgMjx5n7fbyyZnew8NkMIoUfcI0K2NfaRlj8dYHgMDeACDgerDpiheymCKY3j/P3c4rH96iilVnHUGeNNrLXXyc44KZKR8WhBxTBzr0dMOoiZru3QGgIoH/VqHREPSPm+Dq69/IBjjNB+PUidASiqVbctot7yvx9/odVeWyjO5gWqwDVCYfA5vu7HZSFC9DUgNXuDSGQBndmM8GhyYLB31/sFhW71uvfUODYfIYT+XQBzn0dBTq9hbl/WG8PcIcM/FOR0MgeAeRjkI2ZxjaHhJCpDzcGgKSqx728sovqXoDACVpxEZg9PdlyK8Dx7jGh96/8esZ3iZLbnuY2EC9teieN09QEC5rreOV0kNAZAaGr27kOeovBvwux/9fRseWWa/c/PvieZ9XnJ8jeeROIalZEb5QbHWa+u9A8sa3V3IS1ffP3uglTW00tsN7QF7+lqMQOCW40YplHkAYmKBfm5cVw0dsS9eNmLTs2WbqxClk0+cL9UHYjR7pDndeVYsW4L3lnYUmS9I4sLrfBBaeP1rJEykoUIV3uG5AG2JpFidDFEqBQOTKvgJLV54nNYfvELPMFFOUx5FBdntpe/sNNLHcDw3Rr0wke8oj3gH4ZTBlDpFrdbLQgehwNHmHD/vsxMqiMeVbKLFsAiTBiHxCpLG18q2cajQco+mYZTG7MZJ4Ri2NJZtHsJEJ0AUSzqy6xA0arbJwqSxYUQgtF0XBUBT8Z4qu4KodLwUiobF12Xk8OSKsS0TuDYrDRvtzclrnW6BPj4rK8iIsrnUJNPbESAoyecBhYA8z37kCKTLbS8XBUBhhxCTMoCYUzFFH6guWiCnfeR3XhFxURtnhOV9iAD+UR6Vy4Q8ed2raV0jg7EE1ZcOJQpkzBWh0FiqwpiiHD0jUNAiaVEAqLQLb10CnLRpdTA3csILabi2Tcy7xdLeAjZDjICCepaPHhIY4PfShzY1WKAvjiVv0CaCArpHoJcur73sCACVbU0IPZCyCnl/lpYFzfvTErt+MR+XAMXHZcR+9yZnIAhsexIoDO9swlglD3s08ASrqHdgKYE5+wSpMZlLRwD8KZC8LR7ODJ5Hxx1AkcJpM3XnoyG9XYnNlNrAhRHCQ4ZzHYclwnFK0XgBE2kEXf1xf+JyxdOBziT8pNbkJVcTzIz6qnYEgKe4sKmE+7sb4Uq5AqLHTTBhaLticVLvFwtkPn/guI0OFGxyctLK5bI2RGqCjxk2ODhoXV08hoSUKg5gPKU0EFSXYBiYiRpFDOavkwY+vy26jGzZEQB5EhugQhHzhw8jqoR12rJ5Zd7GMDQz4cvJ0m0q320f/ubP7PoNdRttHLXq7DE8O+FjCBQdGRmxs895mxWLRYFCm+XFlnkCzQ0QuBFopxEqLLLgCOHCveZkIoB2cGBGEZ+EU4SXpKGf4d6Ipz5NRS2QBJrwCArkCn22f2653fYvB81msRk2BptHCPJ/70n7j89cYaVqTh9JKUO3Sy6RKDNIolqh5iCJFzxc74oAAMdtLDgwDiZTW+oYAXx6841IxtKrNJQTB8mpqOBhTMJNTW+O4BuGn0dCnD9Juizft9ySrkE8Xlcghg8aEMszAkK5cXzSenu68KYIj7vRYsrQcEVW60YYDCUtbJwqqR/GtN6JTgIAKsWZgyKoB9NbjJKR+EQOq2mH+DUOVY+eQEcYkEXRABCKWOckZTc3KF3D+wV6MLtrh/kxB3kJMAXGOqveT8cILPIAPD8eE8d8/JBK/vbUMQKooBLn5rRSljXUYx8fhPS0CII8T3oOl9gvpcgT2yopBy8CFEm6hhq9RgOZaECkqh2JKOgIJEVHrLOZ0l0upqTKnBDz+alTY9sunQGo1RmfhXSaWEm461JPGdKw2Xuu0abTs+MbeI7EJ7gQ1fK4zhKMjmiY5uZjNhPIIcogT23QPZICJXoXfAQnQ+MboY/cdKMou+69X6UiAXwsnV/ACEwfPb+EGh1SrT7X4jkqTkOoP3M0pF6atq7J5638/Z3NdwcU6Xw+hsAwk46kV2wOBgnsQ9sfkWUQ6UiKCBoiz5vddecX7ac/+bHNzMyIRg/TWHqdJflIY9vHh9r8aycAeO8IyQ1hy41gHXS+Exy69ku29nT8TOiZ+6y850tNw91YL9vlxLbeK5KHCbQKPpmH5RaNiQbJMNQfuO9r9vX7vmr46mufuvVzKShapgQ7RpvAQt1BCxPMv3YCIHC6kgxB1H2Dc3AovDa62d6Y+CN76znnWf2xz1vpB38KoNwijIFPmDwsfWyYIHhXdc6FhN9IpUbIGBqE5cZX6Hfecbvdcfuf2VmbN9sHP/JRO3PT2Rrj3mfDI0D1GDWLgdB5D6AN6Q9oqB1NUYxRdjAMa5a3r+mVl9vBrqJt6ftre2rPLpt58RErvvc2y6+ckELk11hWMsnBodJMBHhqtmJL+6EWZUe0fvTcM/bZnZ9Q2G/d/g77wA032tZt+IGalkRzf3DRLi+0eT+Ka8EZMmVHAJJGrdaohxNeq8AwmjTtslCaExwb2WYvbl5uW4bvsdeeedT233uNFTa+y7rP32HJ2ndg01t4qhbZMHq6hFMi3q7zjPDk3ifswfu/Zv/08EO2enytXXfDb9p177/B1q3f0GISgWCEuSz3OGnhIJXMZGxuqbbDxzYP40tWf+rw00m+OEaxwdhQtoxGw9F1HgBnK4/uthUHd9t/PvuUHXh1vzWKI9az4Z2WH5uwZOlZlhsYE82KtBQyylN4WTJl9UP/br912o/t8Ms/socfedQmjx6xlWNr7NyJCbvs8ncjQ0Y+Dct2VdT2peYgkFirVo+ce+b4ZlQnkd/0nSDjpZGUS68nPT1jqKdG6r4PhXXE5W2QdfTyhMgaOnDN289H3meHhi+3FSv32CXHnrD60Rds/4tP2cv/+CDFLZruhtfWnrbeNp37NsMPG2zi/AvsgrdfaH19/L4Z58tImOcgLYsmA/UrleYOa6iUbPaxtnBcwrR6aWZ/rmv4PLHTQBjM+3p4TKat8UGJthMEJAHDFrCoJn12YOjd9vPhd1lx1WFbcvpPbKL0svVWDlp3+SjOSzOWr81qXA1f4WpJr5ULQ3b2+FK7dGKjrVw9boPDI+rn3I24u6c20AHc5cUBvdhGkkNUCTqTZ65c2Q+SNGVXNrUDIO+DoV6fPvRkrv8t7wvM9DYFNjcU3b7QGU6AVCAuAj4SEzDsHwIJ4MzlRu21Pnyi79umjU5fiuPurp3ejSlN2dYzjtn2i5fbGzMVm8U7RC2xaHxqHOb1s34aAZEn6BuAoFs45sjh159GVfcXkZwJZYAtQ4gM1eMvfPMh2IHfrWIynihQ+g+cvNQwP8ygX7z0CcfEkvVs1trkGPJEuTpUkQ+b4KuTNZ3j07UsSZQWokxzkjW2WToIrHsmn+8DTz+x52E0HQBUm6kTAJWph//ixdrU64/y1qQnQ+72yFKcJdDhBOr3kr/94VNkhs95aCzpninHeVMaVuT+SfAx0pA5Ns3RYKpOmspII47Op47IQ9rU1LFnbvnEx/8NpJbNz/k6AUC0Zqf/9W9ux3fsshtEhTU5vYXPXv51mCXpqSHRwykvjY0vQj0aJBNiXKZ4sRR+eigYxydCjwKVCHHyiI/jCEKkoZkm74+ExkP/8N3PoT6HzJNNEB47WSx6Tym99Mh075lXFvK9q/A7O1oNz+i1F4yVLChEKj0ey0hRO7IEYLgzRr7QiaurwxIZ0q00N2PXTuStrzuPD8k4CrWtbR9LDTirG+xguWbse2X/Sw/e9NvX70J1CpkRQCNa0kIRQAaqxAFTB79y6Z2VIy/cp90fBnBCGsw2xcl4lopD3BkY6m1ZG13kIb8y+UnL/MaA9Bz+u8Hzr8ziGR51ugdR4Uai1UzufW6gzEjiA53OOXrk8D9/aMcHdoJM40vImG1+WjQC4qDG9NNffrw4fmmpMDB2AZQsMPqEv8KQWDE0AQjXLqZRXYaqS3CSxiBAJ/+hZJuCOA7/AIjG1Uq2dnDGLjpjAD8lqul3RGQXn/hpbJgr0GgX4w7yBESjsf/ln33r+t94zx/iZ/OH0DmNvGD4g77oEpCa4OF+UDv+7FefbVSOPdK1bPOKXM/AODqzL27AEg1STSoGzKGrPB1eAKAR+kiWT2CU6pHO387kKm/YtRctwbtB/PaIT4eUDROZeA31oJ4MJw3GY8N7fvfff+uWD+644e65ubkjIHvoh8EgtCefu52ebRNyHo97kQeQB/s3XjXed95N7ywMbTg/1zs8jp8TLcdZv5jkC/3w7IIyg6JuRNagZh2ycdwoW3HuFfvhrWvsOH5Cf2xu/iMtzvflWq1aKpdKk7OzswcOvnbgub0/3PPYF2679UmIoNHHkHn+93X/3wIAcnRe4HJxIPpRZ+b5lP9HiHQeqmJ8ovY/l4LrQ2QytLm+aexxZIY7j5ekedh3NB48HY/C7MumsNCakxJZTsLM3+D9XwCAIND4N/U6eNK0YLimvQtX6GVGAz3uhmu/Rpt9/xvJo4COoadpNPMJeR18aToZADiY45izIX+ysijvZJKHtoORLU9Y3q9K6V+VnBNWPMPoQGRIp6onjMB/AUz+r5rlodoQAAAAAElFTkSuQmCC"

export default function Commands(props: CommandsProps) {
  const [open, setOpen] = useState(false)
  const [defaultApp, setDefaultApp] = useState<AppInfo | undefined>(undefined)

  function closeCommandsPopup() {
    handleOpenChange(false)
  }

  (window as any).closeCommandsPopup = closeCommandsPopup

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e)) {
        e.preventDefault()
        handleOpenChange(true)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function handleKeyDown(e: React.KeyboardEvent) {
    // Close the app window with the close app shortcut.
    if (isShortcutMatch(prefGetShowMoreActionsShortcut(), e.nativeEvent)) {
      e.preventDefault()
      handleOpenChange(false)
    }
    e.stopPropagation()
  }

  function handleClick() {
    handleOpenChange(true)
  }

  let closeReason: HideActionsReason = "cancel"

  function handleOpenChange(open: boolean) {
    setDefaultApp(undefined)
    if (open) {
      if (isFile()) {
        let item = getFirstSelectedHistoryItem()
        if (!item.fileFolder) {
          setDefaultApp(getDefaultAppInfo())
        }
      }
    }
    setOpen(open)
    if (!open) {
      props.onHideActions(closeReason)
    }
  }

  function handleEditContent() {
    closeReason = "editContent"
    handleOpenChange(false)
    props.onEditContent()
  }

  function handleRenameItem() {
    closeReason = "renameItem"
    handleOpenChange(false)
    props.onRenameItem()
  }

  function handleFormatText() {
    closeReason = "formatText"
    handleOpenChange(false)
    props.onFormatText()
  }

  function handleCopyToClipboard() {
    closeReason = "copyToClipboard"
    handleOpenChange(false)
    props.onCopyToClipboard()
  }

  function handlePaste() {
    closeReason = "paste"
    handleOpenChange(false)
    props.onPaste()
  }

  function handlePasteWithTab() {
    closeReason = "pasteWithTab"
    handleOpenChange(false)
    props.onPasteWithTab()
  }

  function handlePasteWithReturn() {
    closeReason = "pasteWithReturn"
    handleOpenChange(false)
    props.onPasteWithReturn()
  }

  function handleMerge() {
    closeReason = "merge"
    handleOpenChange(false)
    props.onMerge()
  }

  function handleToggleFavorite() {
    closeReason = "toggleFavorite"
    handleOpenChange(false)
    props.onToggleFavorite()
  }

  function handleTogglePreview() {
    closeReason = "togglePreview"
    handleOpenChange(false)
    props.onTogglePreview()
  }

  function handleOpenSettings() {
    closeReason = "openSettings"
    handleOpenChange(false)
    props.onOpenSettings()
  }

  function handleZoomIn() {
    closeReason = "zoomIn"
    handleOpenChange(false)
    props.onZoomIn()
  }

  function handleZoomOut() {
    closeReason = "zoomOut"
    handleOpenChange(false)
    props.onZoomOut()
  }

  function handleResetZoom() {
    closeReason = "resetZoom"
    handleOpenChange(false)
    props.onResetZoom()
  }

  function handleDeleteItem() {
    closeReason = "deleteItem"
    handleOpenChange(false)
    props.onDeleteItem()
  }

  function handleDeleteItems() {
    closeReason = "deleteItems"
    handleOpenChange(false)
    props.onDeleteItems()
  }

  function handleDeleteAllItems() {
    closeReason = "deleteAllItems"
    handleOpenChange(false)
    props.onDeleteAllItems()
  }

  function handleOpenInBrowser() {
    closeReason = "openInBrowser"
    handleOpenChange(false)
    props.onOpenInBrowser()
  }

  function handleShowInFinder() {
    closeReason = "showInFinder"
    handleOpenChange(false)
    props.onShowInFinder()
  }

  function handleOpenInDefaultApp() {
    closeReason = "openInDefaultApp"
    handleOpenChange(false)
    props.onOpenInApp(defaultApp)
  }

  function handleOpenWith() {
    closeReason = "openWith"
    handleOpenChange(false)
    props.onOpenWith()
  }

  function handlePreviewLink() {
    closeReason = "preview"
    handleOpenChange(false)
    props.onPreviewLink()
  }

  function handleCopyTextFromImage() {
    closeReason = "copyTextFromImage"
    handleOpenChange(false)
    props.onCopyTextFromImage()
  }

  function handleSaveImageAsFile() {
    closeReason = "saveImageAsFile"
    handleOpenChange(false)
    props.onSaveImageAsFile()
  }

  function handlePasteWithTransformation() {
    closeReason = "pasteWithTransformation"
    handleOpenChange(false)
    props.onPasteWithTransformation()
  }

  function handlePastePath() {
    closeReason = "pastePath"
    handleOpenChange(false)
    props.onPastePath()
  }

  function handleCopyPathToClipboard() {
    closeReason = "copyPathToClipboard"
    handleOpenChange(false)
    props.onCopyPathToClipboard()
  }

  function canShowCopyToClipboard() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowMultiplePaste() {
    return getSelectedHistoryItemIndices().length > 1
  }

  function canShowInFinder() {
    return isFile()
  }

  function canOpenInDefaultApp() {
    return defaultApp !== undefined
  }

  function canShowCopyPath() {
    return isFile()
  }

  function canShowPastePath() {
    return isFile()
  }

  function isFile() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      return item && item.type === ClipType.File
    }
    return false
  }

  function getDefaultAppInfo() : AppInfo | undefined {
    if (isFile()) {
      let item = getFirstSelectedHistoryItem()
      return getDefaultApp(item.filePath)
    }
    return undefined
  }

  function canPasteWithTransformation() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item) {
        return isTextItem(item)
      }
    }
    return false
  }

  function canShowMergeItems() {
    if (getSelectedHistoryItemIndices().length > 1) {
      return getSelectedHistoryItems().every(item => isTextItem(item) || item.type === ClipType.File)
    }
    return false
  }

  function canShowOpenInBrowser() {
    if (getSelectedHistoryItemIndices().length === 1) {
      return getFirstSelectedHistoryItem()?.type === ClipType.Link
    }
    return false
  }

  function canShowPreview() {
    return canShowOpenInBrowser()
  }

  function canShowRenameItem() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowFormatText() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      if (item) {
        return isTextItem(item)
      }
    }
    return false
  }

  function canShowCopyTextFromImage() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem()
      if (item) {
        if (item.type === ClipType.Image && item.content.length > 0) {
          return true
        }
        if (getImageText(item).length > 0) {
          return true
        }
      }
    }
    return false
  }

  function canShowSaveImageAsFile() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      return item?.type === ClipType.Image
    }
    return false
  }

  function canShowEditContent() {
    if (getSelectedHistoryItemIndices().length === 1) {
      let item = getFirstSelectedHistoryItem();
      let type = item?.type;
      return type === ClipType.Text ||
          type === ClipType.Link ||
          type === ClipType.Email ||
          type === ClipType.Color
    }
    return false
  }

  function canAddToFavorites() {
    return getSelectedHistoryItems().some(item => !item.favorite)
  }

  function canShowDeleteItem() {
    return getSelectedHistoryItemIndices().length === 1
  }

  function canShowDeleteItems() {
    return getSelectedHistoryItemIndices().length > 1
  }

  function getMultipleItemsIndicator(): string {
    let indices = getSelectedHistoryItemIndices().length
    if (indices > 1) {
      return indices + " Items"
    }
    return ""
  }

  return (
      <>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="toolbar" size="toolbar" onClick={handleClick}>
              <CommandIcon className="h-5 w-5"/>
            </Button>
          </TooltipTrigger>
          <TooltipContent className="flex items-center">
            <div className="select-none mr-2">Show more actions</div>
            <ShortcutLabel shortcut={prefGetShowMoreActionsShortcut()}/>
          </TooltipContent>
        </Tooltip>
        <div className="" onKeyDown={handleKeyDown}>
          <CommandDialog open={open} onOpenChange={handleOpenChange}>
            <VisuallyHidden>
              <DialogTitle></DialogTitle>
            </VisuallyHidden>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
            <div className="max-h-[70vh] overflow-y-auto mb-1.5">
              <CommandList>
                <CommandItem onSelect={handlePaste}>
                  <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                       alt="Application icon"/>
                  <span>Paste {getMultipleItemsIndicator()} to {props.appName}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetPasteSelectedItemToActiveAppShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                {
                    canPasteWithTransformation() &&
                    <CommandItem onSelect={handlePasteWithTransformation}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>
                    Paste {getMultipleItemsIndicator()} to {props.appName} with Formatting...
                  </span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithReturn}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste {getMultipleItemsIndicator()} to {props.appName} with Return</span>
                    </CommandItem>
                }
                {
                    canShowMultiplePaste() &&
                    <CommandItem onSelect={handlePasteWithTab}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste {getMultipleItemsIndicator()} to {props.appName} with Tab</span>
                    </CommandItem>
                }
                {
                    canShowPastePath() &&
                    <CommandItem onSelect={handlePastePath}>
                      <img src={toBase64Icon(props.appIcon)} className="mr-2 h-5 w-5"
                           alt="Application icon"/>
                      <span>Paste Path to {props.appName}</span>
                    </CommandItem>
                }
                {
                    canShowMergeItems() &&
                    <CommandItem onSelect={handleMerge}>
                      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
                           viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
                           strokeLinecap="round" strokeLinejoin="round"
                           className="lucide lucide-unfold-vertical mr-2 h-5 w-5">
                        <path d="M12 22v-6"/>
                        <path d="M12 8V2"/>
                        <path d="M4 12H2"/>
                        <path d="M10 12H8"/>
                        <path d="M16 12h-2"/>
                        <path d="M22 12h-2"/>
                        <path d="m15 5-3 3-3-3"/>
                        <path d="m15 19-3-3-3 3"/>
                      </svg>
                      <span>Merge {getMultipleItemsIndicator()}</span>
                    </CommandItem>
                }
                {
                    canShowCopyToClipboard() &&
                    <CommandItem onSelect={handleCopyToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>Copy to Clipboard</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyToClipboardShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowCopyPath() &&
                    <CommandItem onSelect={handleCopyPathToClipboard}>
                      <CopyIcon className="mr-2 h-5 w-5"/>
                      <span>Copy Path to Clipboard</span>
                    </CommandItem>
                }
                <CommandSeparator/>
                {
                    canShowOpenInBrowser() &&
                    <CommandItem onSelect={handleOpenInBrowser}>
                      <GlobeIcon className="mr-2 h-5 w-5"/>
                      <span>Open in Browser</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetOpenInBrowserShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowInFinder() &&
                    <CommandItem onSelect={handleShowInFinder}>
                      <img src={toBase64Icon(finderIcon)} className="mr-2 h-5 w-5"
                           alt="App icon"/>
                      <span>Show in Finder</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetShowInFinderShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canOpenInDefaultApp() &&
                    <CommandItem onSelect={handleOpenInDefaultApp}>
                      {
                        defaultApp ? <img src={toBase64Icon(defaultApp.icon)} className="mr-2 h-5 w-5"
                                          alt="App icon"/> : null
                      }
                      <span>Open in {defaultApp?.name}</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetOpenInDefaultAppShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canOpenInDefaultApp() &&
                    <CommandItem onSelect={handleOpenWith}>
                      <UploadIcon className="mr-2 h-5 w-5"/>
                      <span>Open With...</span>
                    </CommandItem>
                }
                {
                    canShowCopyTextFromImage() &&
                    <CommandItem onSelect={handleCopyTextFromImage}>
                      <ScanTextIcon className="mr-2 h-5 w-5"/>
                      <span>Copy Text from Image</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetCopyTextFromImageShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowSaveImageAsFile() &&
                    <CommandItem onSelect={handleSaveImageAsFile}>
                      <DownloadIcon className="mr-2 h-5 w-5"/>
                      <span>Save as File...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetSaveImageAsFileShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowEditContent() &&
                    <CommandItem onSelect={handleEditContent}>
                      <Edit3Icon className="mr-2 h-5 w-5"/>
                      <span>Edit Content...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetEditHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandItem onSelect={handleToggleFavorite}>
                  {
                    canAddToFavorites() ?
                        <StarIcon className="mr-2 h-5 w-5"/> :
                        <StarOffIcon className="mr-2 h-5 w-5"/>
                  }
                  <span>{canAddToFavorites() ?
                      `Add ${getMultipleItemsIndicator()} to Favorites` :
                      `Remove ${getMultipleItemsIndicator()} from Favorites`}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetToggleFavoriteShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                {
                    canShowPreview() && <CommandSeparator/>
                }
                {
                    canShowPreview() &&
                    <CommandItem onSelect={handlePreviewLink}>
                      <EyeIcon className="mr-2 h-5 w-5"/>
                      <span>Preview Link</span>
                    </CommandItem>
                }
                {
                    canShowRenameItem() &&
                    <CommandItem onSelect={handleRenameItem}>
                      <PenIcon className="mr-2 h-5 w-5"/>
                      <span>Rename...</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetRenameItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowFormatText() &&
                    <CommandItem onSelect={handleFormatText}>
                      <TypeIcon className="mr-2 h-5 w-5"/>
                      <span>Format Text...</span>
                    </CommandItem>
                }
                <CommandSeparator/>
                <CommandItem onSelect={handleTogglePreview}>
                  {
                    getPreviewVisibleState() ?
                        <HidePreviewPaneIcon className="mr-2 h-5 w-5"/> :
                        <ShowPreviewPaneIcon className="mr-2 h-5 w-5"/>
                  }
                  <span>{getPreviewVisibleState() ? "Hide Preview" : "Show Preview"}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomIn} disabled={!canZoomIn()}>
                  <ZoomIn className="mr-2 h-5 w-5"/>
                  <span>Zoom In</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIInShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleZoomOut} disabled={!canZoomOut()}>
                  <ZoomOut className="mr-2 h-5 w-5"/>
                  <span>Zoom Out</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIOutShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandItem onSelect={handleResetZoom} disabled={!canResetZoom()}>
                  <Undo2Icon className="mr-2 h-5 w-5"/>
                  <span>Reset Zoom</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetZoomUIResetShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                <CommandItem onSelect={handleOpenSettings}>
                  <SettingsIcon className="mr-2 h-5 w-5"/>
                  <span>{"Settings..."}</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetOpenSettingsShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandSeparator/>
                {
                    canShowDeleteItem() &&
                    <CommandItem onSelect={handleDeleteItem}>
                      <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                      <span className="text-actions-danger">Delete</span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                {
                    canShowDeleteItems() &&
                    <CommandItem onSelect={handleDeleteItems}>
                      <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                      <span className="text-actions-danger">
                      Delete {getMultipleItemsIndicator()}
                    </span>
                      <CommandShortcut className="flex flex-row">
                        <ShortcutLabel shortcut={prefGetDeleteHistoryItemShortcut()}/>
                      </CommandShortcut>
                    </CommandItem>
                }
                <CommandItem onSelect={handleDeleteAllItems}>
                  <TrashIcon className="mr-2 h-5 w-5 text-actions-danger"/>
                  <span className="text-actions-danger">Delete All...</span>
                  <CommandShortcut className="flex flex-row">
                    <ShortcutLabel shortcut={prefGetClearHistoryShortcut()}/>
                  </CommandShortcut>
                </CommandItem>
                <CommandEmpty>No results found.</CommandEmpty>
              </CommandList>
            </div>
          </CommandDialog>
        </div>
      </>
  )
}
