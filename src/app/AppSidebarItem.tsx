import {
  FileIcon, FilesIcon,
  HistoryIcon,
  ImageIcon,
  LinkIcon,
  MailIcon, PaletteIcon, PlusIcon,
  SettingsIcon, StarIcon
} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import React from "react";

export type AppSidebarItemType = "All" | "Text" | "Image" | "Link" | "Color" | "File" | "Email" | "Favorites" | "Settings" | "New Collection";

interface AppSidebarItemProps {
  type: AppSidebarItemType
  selectedType: AppSidebarItemType
  selectable?: boolean
  onSelect: () => void
}

export function AppSidebarItem(props: AppSidebarItemProps) {

  function renderIcon() {
    if (props.type === "All") {
      return <HistoryIcon className="h-5 w-5"/>
    }
    if (props.type === "Text") {
      return <FileIcon className="h-5 w-5"/>
    }
    if (props.type === "Image") {
      return <ImageIcon className="h-5 w-5"/>
    }
    if (props.type === "Link") {
      return <LinkIcon className="h-5 w-5"/>
    }
    if (props.type === "Color") {
      return <PaletteIcon className="h-5 w-5"/>
    }
    if (props.type === "File") {
      return <FilesIcon className="h-5 w-5"/>
    }
    if (props.type === "Email") {
      return <MailIcon className="h-5 w-5"/>
    }
    if (props.type === "Favorites") {
      return <StarIcon className="h-5 w-5"/>
    }
    if (props.type === "New Collection") {
      return <PlusIcon className="h-5 w-5"/>
    }
    if (props.type === "Settings") {
      return <SettingsIcon className="h-5 w-5"/>
    }
  }

  return (
      <SidebarMenuItem key={props.type}>
        <SidebarMenuButton onClick={props.onSelect}
                           isActive={props.type === props.selectedType}
                           variant="sidebar"
                           size="sidebar"
                           className="cursor-default"
                           tooltip={{
                             children: props.type,
                             hidden: false,
                           }}>
          {renderIcon()}
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
