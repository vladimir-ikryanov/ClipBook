import '../app.css';
import React from "react";
import {Clip, ClipType, getFilePath} from "@/db";
import {toBase64Icon} from "@/data";

declare const getAppNameFromPath: (appPath: string) => string;
declare const getFileIconAsBase64: (appPath: string, large: boolean) => string;

type ItemInfoPaneProps = {
  item: Clip
  display: boolean
}

export default function ItemInfoPane(props: ItemInfoPaneProps) {
  function getSourceAppIcon(): string {
    return toBase64Icon(getFileIconAsBase64(props.item.sourceApp, false))
  }

  function getSourceAppName(): string {
    return getAppNameFromPath(props.item.sourceApp)
  }

  function getType(): string {
    if (props.item.type === ClipType.Link) {
      return "Link"
    }
    if (props.item.type === ClipType.Color) {
      return "Color"
    }
    if (props.item.type === ClipType.Email) {
      return "Email"
    }
    if (props.item.type === ClipType.Image) {
      return "Image"
    }
    if (props.item.type === ClipType.File) {
      return props.item.fileFolder ? "Folder" : "File"
    }
    return "Text"
  }

  function getTimeString(date: Date): string {
    return date.toDateString() + " at " + date.toLocaleTimeString()
  }

  function canShowImageSize() {
    return props.item.imageWidth > 0 && props.item.imageHeight > 0
  }

  function isImage() {
    return props.item.type === ClipType.Image
  }

  function isFile() {
    return props.item.type === ClipType.File
  }

  function isFolder() {
    return props.item.fileFolder
  }

  function isLink() {
    return props.item.type === ClipType.Link
  }

  function getImageDimensionsLabel() {
    return props.item.imageWidth + "x" + props.item.imageHeight
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

  if (!props.display || !props.item) {
    return <div></div>
  }

  return (
      <div
          className="flex flex-col w-full p-4 border-t-solid border-t-preview-border border-t space-y-2 text-sm">
        <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
          <div className="flex-none text-preview-infoLabel font-semibold">Application</div>
          <div className="flex-grow"></div>
          <div className="flex flex-row items-center">
            {
              props.item.sourceApp ?
                  <div className="flex">
                    <img src={getSourceAppIcon()} className="h-5 w-5 mr-2" alt="Application icon"/>
                    <span>{getSourceAppName()}</span>
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
            isLink() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">URL</div>
              <div className="flex-grow"></div>
              <div className="flex-auto text-foreground text-end break-all">{props.item.content}</div>
            </div>
        }
        {
            isFile() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold mr-4">Path</div>
              <div className="flex-grow"></div>
              <div className="flex-auto text-foreground text-end break-all">{getFilePath(props.item)}</div>
            </div>
        }
        {
            isFile() && !isFolder() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">File size</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(props.item.fileSizeInBytes)}</div>
            </div>
        }
        {
            canShowImageSize() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Image dimensions</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getImageDimensionsLabel()}</div>
            </div>
        }
        {
            isImage() &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Image size</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{getSizeLabel(props.item.imageSizeInBytes)}</div>
            </div>
        }
        {
            props.item.numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">Number of copies</div>
              <div className="flex-grow"></div>
              <div className="flex-none text-foreground">{props.item.numberOfCopies}</div>
            </div>
        }
        {
            props.item.numberOfCopies > 1 &&
            <div className="flex w-full border-b border-b-preview-infoBorder pb-1">
              <div className="flex-none text-preview-infoLabel font-semibold">First copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(props.item.firstTimeCopy)}</div>
            </div>
        }
        {
            props.item.numberOfCopies > 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">Last copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(props.item.lastTimeCopy)}</div>
            </div>
        }
        {
            props.item.numberOfCopies === 1 &&
            <div className="flex w-full">
              <div className="flex-none text-preview-infoLabel font-semibold">Copy time</div>
              <div className="flex-grow"></div>
              <div
                  className="flex-none text-foreground">{getTimeString(props.item.firstTimeCopy)}</div>
            </div>
        }
      </div>
  )
}
