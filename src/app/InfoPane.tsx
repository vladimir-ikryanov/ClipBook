import '../app.css';
import React from "react";
import {Clip, ClipType} from "@/db";
import {toBase64Icon} from "@/data";

declare const getAppNameFromPath: (appPath: string) => string;
declare const getAppIconAsBase64: (appPath: string) => string;

type InfoPaneProps = {
  item: Clip
  display: boolean
}

export default function InfoPane(props: InfoPaneProps) {
  function getSourceAppIcon(): string {
    return toBase64Icon(getAppIconAsBase64(props.item.sourceApp))
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
    return "Text"
  }

  function getTimeString(date: Date): string {
    return date.toDateString() + " at " + date.toLocaleTimeString()
  }

  if (!props.display || !props.item) {
    return <div></div>
  }

  return (
      <div className="flex flex-col w-full p-4 border-t-solid border-t-border border-t space-y-2 text-sm">
        <div className="flex w-full border-b border-b-neutral-800 pb-1">
          <div className="flex-none text-primary-foreground font-semibold">Application</div>
          <div className="flex-grow"></div>
          <div className="flex flex-row items-center">
            <img src={getSourceAppIcon()} className="h-5 w-5 mr-2" alt="Application icon"/> {getSourceAppName()}
          </div>
        </div>
        <div className="flex w-full border-b border-b-neutral-800 pb-1">
          <div className="flex-none text-primary-foreground font-semibold">Type</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{getType()}</div>
        </div>
        <div className="flex w-full border-b border-b-neutral-800 pb-1">
          <div className="flex-none text-primary-foreground font-semibold">Number of copies</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{props.item.numberOfCopies}</div>
        </div>
        <div className="flex w-full border-b border-b-neutral-800 pb-1">
          <div className="flex-none text-primary-foreground font-semibold">First copy time</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{getTimeString(props.item.firstTimeCopy)}</div>
        </div>
        <div className="flex w-full">
          <div className="flex-none text-primary-foreground font-semibold">Last copy time</div>
          <div className="flex-grow"></div>
          <div className="flex-none text-foreground">{getTimeString(props.item.lastTimeCopy)}</div>
        </div>
      </div>
  )
}
