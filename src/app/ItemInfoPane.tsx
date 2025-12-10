import '../app.css';
import {useEffect, useState} from "react";
import {Clip, ClipType, getFilePath, getHTML, getRTF} from "@/db";
import {fileExists, formatDateTime, getHistoryItemById, toBase64Icon} from "@/data";
import ItemTags from "@/app/ItemTags";
import {getTags, Tag} from "@/tags";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

declare const getAppNameFromPath: (appPath: string) => string;
declare const getFileIconAsBase64: (appPath: string, large: boolean) => string;

type ItemInfoPaneProps = {
  item: Clip
  visible: boolean
}

export default function ItemInfoPane(props: ItemInfoPaneProps) {
  if (!props.visible || !props.item) {
    return null
  }
  const {t} = useTranslation()
  const [type, setType] = useState<ClipType>(props.item.type)
  const [content, setContent] = useState<string>(props.item.content)
  const [rtf, setRtf] = useState<string>(getRTF(props.item))
  const [html, setHtml] = useState<string>(getHTML(props.item))
  const [imageWidth, setImageWidth] = useState<number>(props.item.imageWidth)
  const [imageHeight, setImageHeight] = useState<number>(props.item.imageHeight)
  const [imageSizeInBytes, setImageSizeInBytes] = useState<number>(props.item.imageSizeInBytes)
  const [fileSizeInBytes, setFileSizeInBytes] = useState<number>(props.item.fileSizeInBytes)
  const [fileFolder, setFileFolder] = useState<boolean>(props.item.fileFolder)
  const [filePath, setFilePath] = useState<string>(getFilePath(props.item))
  const [sourceApp, setSourceApp] = useState<string>(props.item.sourceApp)
  const [numberOfCopies, setNumberOfCopies] = useState<number>(props.item.numberOfCopies)
  const [firstTimeCopy, setFirstTimeCopy] = useState<Date>(props.item.firstTimeCopy)
  const [lastTimeCopy, setLastTimeCopy] = useState<Date>(props.item.lastTimeCopy)
  const [tags, setTags] = useState<Tag[]>(getTags(props.item.tags))

  function updateItem(item: Clip) {
    setType(item.type)
    setContent(item.content)
    setRtf(getRTF(props.item))
    setHtml(getHTML(props.item))
    setSourceApp(item.sourceApp)
    setFileFolder(item.fileFolder)
    setImageWidth(item.imageWidth)
    setImageHeight(item.imageHeight)
    setFilePath(getFilePath(item))
    setFileSizeInBytes(item.fileSizeInBytes)
    setImageSizeInBytes(item.imageSizeInBytes)
    setNumberOfCopies(item.numberOfCopies)
    setFirstTimeCopy(item.firstTimeCopy)
    setLastTimeCopy(item.lastTimeCopy)
    setTags(getTags(item.tags))
  }

  useEffect(() => {
    function handleUpdateItemByIdEvent(itemId?: number) {
      if (itemId) {
        let item = getHistoryItemById(itemId)
        if (item && item.id === props.item.id) {
          updateItem(item)
        }
      }
    }

    updateItem(props.item)

    emitter.on("UpdateItemById", handleUpdateItemByIdEvent)
    return () => emitter.off("UpdateItemById", handleUpdateItemByIdEvent);
  }, [props.item]);

  function getTypes(): string[] {
    if (type === ClipType.Link) {
      return [t("app.itemInfoPane.link")]
    }
    if (type === ClipType.Color) {
      return [t("app.itemInfoPane.color")]
    }
    if (type === ClipType.Email) {
      return [t("app.itemInfoPane.email")]
    }
    if (type === ClipType.Image) {
      return [t("app.itemInfoPane.image")]
    }
    if (type === ClipType.File) {
      return fileFolder ? [t("app.itemInfoPane.folder")] : [t("app.itemInfoPane.file")]
    }
    if (type === ClipType.Text) {
      let result = [t("app.itemInfoPane.text")]
      if (html.length > 0) {
        result.push(t("app.itemInfoPane.html"))
      }
      if (rtf.length > 0) {
        result.push(t("app.itemInfoPane.rtf"))
      }
      return result
    }
    return [t("app.itemInfoPane.unknown")]
  }

  function canShowImageSize() {
    return imageWidth > 0 && imageHeight > 0
  }

  function isImage() {
    return type === ClipType.Image
  }

  function isFile() {
    return type === ClipType.File
  }

  function isFolder() {
    return fileFolder
  }

  function isLink() {
    return type === ClipType.Link
  }

  function getSizeLabel(sizeInBytes: number) {
    if (!sizeInBytes) {
      return t("app.itemInfoPane.unknown")
    }
    if (sizeInBytes < 1024) {
      return sizeInBytes + t("app.itemInfoPane.bytes")
    }
    if (sizeInBytes < 1024 * 1024) {
      return (sizeInBytes / 1024).toFixed(2) + t("app.itemInfoPane.kb")
    }
    return (sizeInBytes / 1024 / 1024).toFixed(2) + t("app.itemInfoPane.mb")
  }

  return (
      <div
          className="flex flex-col w-full p-4 border-t-solid border-t-preview-border border-t space-y-2 text-sm">
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.application")}</div>
          <div className="flex-grow"></div>
          <div className="flex flex-row items-center">
            {
              sourceApp.length > 0 ?
                  <div className="flex">
                    <img src={toBase64Icon(getFileIconAsBase64(sourceApp, false))}
                         className="h-5 w-5 mr-2" alt="Application icon"/>
                    <span>{getAppNameFromPath(sourceApp)}</span>
                  </div> : <span>{t("app.itemInfoPane.unknown")}</span>
            }
          </div>
        </div>
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">
            {
              getTypes().length > 1 ? t("app.itemInfoPane.types") : t("app.itemInfoPane.type")
            }
          </div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">
            {
              getTypes().map((type, index) => {
                return (
                    <span key={index}>
                      {type}
                      {index < getTypes().length - 1 ?
                          <span className="text-border px-1.5">|</span> : ""}
                    </span>
                )
              })
            }
          </div>
        </div>
        {
            tags && tags.length > 0 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1 items-center">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.tags")}</div>
              <div className="flex-grow"></div>
              <div className="flex text-foreground">
                <ItemTags tags={tags}/>
              </div>
            </div>
        }
        {
            isLink() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">{t("app.itemInfoPane.url")}</div>
              <div className="flex-grow"></div>
              <div className="flex-auto text-foreground text-end break-all">{content}</div>
            </div>
        }
        {
            isFile() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">{t("app.itemInfoPane.path")}</div>
              <div className="flex-grow"></div>
              <div className={`${fileExists(filePath) ? "text-foreground" : "text-primary-foreground"} flex-auto text-end break-all`}>{filePath}</div>
            </div>
        }
        {
            isFile() && !isFolder() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.fileSize")}</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(fileSizeInBytes)}</div>
            </div>
        }
        {
            canShowImageSize() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.imageDimensions")}</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{imageWidth + "x" + imageHeight}</div>
            </div>
        }
        {
            isImage() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.imageSize")}</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(imageSizeInBytes)}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.numberOfCopies")}</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{numberOfCopies}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.firstCopyTime")}</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{formatDateTime(firstTimeCopy)}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.lastCopyTime")}</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{formatDateTime(lastTimeCopy)}</div>
            </div>
        }
        {
            numberOfCopies === 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">{t("app.itemInfoPane.copyTime")}</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{formatDateTime(firstTimeCopy)}</div>
            </div>
        }
      </div>
  )
}
