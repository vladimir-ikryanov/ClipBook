import '../app.css';
import React, {useEffect, useState} from "react";
import {Clip, ClipType, getFilePath} from "@/db";
import {getHistoryItemById, toBase64Icon} from "@/data";
import ItemTags from "@/app/ItemTags";
import {getTags, Tag} from "@/tags";
import {ActionName} from "@/actions";

declare const getAppNameFromPath: (appPath: string) => string;
declare const getFileIconAsBase64: (appPath: string, large: boolean) => string;

type ItemInfoPaneProps = {
  item: Clip
  display: boolean
}

export default function ItemInfoPane(props: ItemInfoPaneProps) {
  if (!props.display || !props.item) {
    return null
  }

  const [type, setType] = useState<ClipType>(props.item.type)
  const [content, setContent] = useState<string>(props.item.content)
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
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      let actionName = customEvent.detail.action;
      if (actionName === ActionName.UpdateItem) {
        const updateItemAction = event as CustomEvent<{ action: string, itemId: number }>
        let updatedItem = getHistoryItemById(updateItemAction.detail.itemId)
        if (updatedItem && updatedItem.id === props.item.id) {
          updateItem(updatedItem)
        }
      }
    }

    updateItem(props.item)

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
  }, [props.item]);

  function getType(): string {
    if (type === ClipType.Link) {
      return "Link"
    }
    if (type === ClipType.Color) {
      return "Color"
    }
    if (type === ClipType.Email) {
      return "Email"
    }
    if (type === ClipType.Image) {
      return "Image"
    }
    if (type === ClipType.File) {
      return fileFolder ? "Folder" : "File"
    }
    return "Text"
  }

  function getTimeString(date: Date): string {
    return date.toDateString() + " at " + date.toLocaleTimeString()
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
      return "Unknown"
    }
    if (sizeInBytes < 1024) {
      return sizeInBytes + " bytes"
    }
    if (sizeInBytes < 1024 * 1024) {
      return (sizeInBytes / 1024).toFixed(2) + " KB"
    }
    return (sizeInBytes / 1024 / 1024).toFixed(2) + " MB"
  }

  return (
      <div
          className="flex flex-col w-full p-4 border-t-solid border-t-preview-border border-t space-y-2 text-sm">
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">Application</div>
          <div className="flex-grow"></div>
          <div className="flex flex-row items-center">
            {
              sourceApp.length > 0 ?
                  <div className="flex">
                    <img src={toBase64Icon(getFileIconAsBase64(sourceApp, false))} className="h-5 w-5 mr-2" alt="Application icon"/>
                    <span>{getAppNameFromPath(sourceApp)}</span>
                  </div> : <span>Unknown</span>
            }
          </div>
        </div>
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">Type</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{getType()}</div>
        </div>
        {
            tags && tags.length > 0 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1 items-center">
              <div className="flex-none text-preview-infoLabel font-semibold">Tags</div>
              <div className="flex-grow"></div>
              <div className="flex text-foreground">
                <ItemTags tags={tags}/>
              </div>
            </div>
        }
        {
            isLink() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">URL</div>
              <div className="flex-grow"></div>
              <div className="flex-auto text-foreground text-end break-all">{content}</div>
            </div>
        }
        {
            isFile() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">Path</div>
              <div className="flex-grow"></div>
              <div className="flex-auto text-foreground text-end break-all">{filePath}</div>
            </div>
        }
        {
            isFile() && !isFolder() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">File size</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(fileSizeInBytes)}</div>
            </div>
        }
        {
            canShowImageSize() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Image dimensions</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{imageWidth + "x" + imageHeight}</div>
            </div>
        }
        {
            isImage() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Image size</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(imageSizeInBytes)}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Number of copies</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{numberOfCopies}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">First copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(firstTimeCopy)}</div>
            </div>
        }
        {
            numberOfCopies > 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">Last copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(lastTimeCopy)}</div>
            </div>
        }
        {
            numberOfCopies === 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">Copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(firstTimeCopy)}</div>
            </div>
        }
      </div>
  )
}
