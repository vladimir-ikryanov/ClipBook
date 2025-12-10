import '../app.css';
import {Clip, ClipType} from "@/db";
import {useTranslation} from "react-i18next";

type ItemsInfoPaneProps = {
  items: Clip[]
  display: boolean
}

export default function ItemsInfoPane(props: ItemsInfoPaneProps) {
  if (!props.display || (props.items && props.items.length === 0)) {
    return <div></div>
  }

  const {t} = useTranslation()

  function getCopyTimeRange(): string {
    let earliestCopyTime = new Date();
    let latestCopyTime = new Date();
    // Find the earliest copy time and the latest copy time.
    props.items.forEach(item => {
      if (item.firstTimeCopy < earliestCopyTime) {
        earliestCopyTime = item.firstTimeCopy
      }
      if (item.lastTimeCopy > latestCopyTime) {
        latestCopyTime = item.lastTimeCopy
      }
    })
    let earliestCopyTimeStr = earliestCopyTime.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    let latestCopyTimeStr = latestCopyTime.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    return earliestCopyTimeStr + " — " + latestCopyTimeStr
  }

  function getSelectedTypes(): string {
    let result = ""
    let textItems = getTextItems()
    if (textItems.length > 0) {
      result += textItems
    }
    let imageItems = getImageItems()
    if (imageItems.length > 0) {
      if (result.length > 0) {
        result += ", "
      }
      result += imageItems
    }
    let linkItems = getLinkItems()
    if (linkItems.length > 0) {
      if (result.length > 0) {
        result += ", "
      }
      result += linkItems
    }
    let colorItems = getColorItems()
    if (colorItems.length > 0) {
      if (result.length > 0) {
        result += ", "
      }
      result += colorItems
    }
    let emailItems = getEmailItems()
    if (emailItems.length > 0) {
      if (result.length > 0) {
        result += ", "
      }
      result += emailItems
    }
    let fileItems = getFileItems()
    if (fileItems.length > 0) {
      if (result.length > 0) {
        result += ", "
      }
      result += fileItems
    }
    return result
  }

  function getItems(type: ClipType, singular: string, plural: string): string {
    let items = props.items.filter(item => item.type === type);
    if (items.length === 0) {
      return ""
    }
    if (items.length === 1) {
      return "1 " + singular
    }
    return items.length + " " + plural
  }

  function getTextItems(): string {
    return getItems(ClipType.Text, t("app.itemsInfoPane.text"), t("app.itemsInfoPane.texts"))
  }

  function getImageItems(): string {
    return getItems(ClipType.Image, t("app.itemsInfoPane.image"), t("app.itemsInfoPane.images"))
  }

  function getLinkItems(): string {
    return getItems(ClipType.Link, t("app.itemsInfoPane.link"), t("app.itemsInfoPane.links"))
  }

  function getColorItems(): string {
    return getItems(ClipType.Color, t("app.itemsInfoPane.color"), t("app.itemsInfoPane.colors"))
  }

  function getEmailItems(): string {
    return getItems(ClipType.Email, t("app.itemsInfoPane.email"), t("app.itemsInfoPane.emails"))
  }

  function getFileItems(): string {
    return getItems(ClipType.File, t("app.itemsInfoPane.file"), t("app.itemsInfoPane.files"))
  }

  return (
      <div
          className="flex flex-col w-full p-4 border-t-solid border-t-preview-border border-t space-y-2 text-sm">
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemsInfoPane.items")}</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{getSelectedTypes()}</div>
        </div>
        {
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemsInfoPane.copyTime")}</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getCopyTimeRange()}</div>
            </div>
        }
      </div>
  )
}
