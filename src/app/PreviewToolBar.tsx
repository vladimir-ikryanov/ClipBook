import '../app.css';
import React from "react";
import {Input} from "@/components/ui/input";
import {Button} from "@/components/ui/button";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {prefGetTogglePreviewShortcut} from "@/pref";
import {
  CircleEllipsisIcon,
  ClipboardIcon,
  ClipboardPasteIcon,
  CopyIcon, Globe2Icon, GlobeIcon, InfoIcon,
  PanelRightClose,
  PanelRightOpen, ShieldEllipsisIcon,
  StarIcon
} from "lucide-react";

type PreviewToolBarProps = {}

export default function PreviewToolBar(props: PreviewToolBarProps) {
  return (
      <div className="flex flex-col">
        <div className="flex m-2">
          <div className="">
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <ClipboardIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <CopyIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
          </div>
          <div className="flex-auto draggable"></div>
          <div className="">
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <StarIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <InfoIcon className="h-5 w-5 text-primary-foreground"/>
            </Button>
            <Button variant="ghost" className="p-2" title={"Clear search (Esc)"}>
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
                   fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"
                   stroke-linejoin="round" className="h-5 w-5 text-primary-foreground lucide lucide-ellipsis-vertical">
                <circle cx="12" cy="12" r="1"/>
                <circle cx="12" cy="5" r="1"/>
                <circle cx="12" cy="19" r="1"/>
              </svg>
            </Button>
            <Button variant="ghost" className="p-2">
              <PanelRightClose className="h-5 w-5 text-primary-foreground"/>
            </Button>
          </div>
        </div>
      </div>
  )
}
