import {
  FileIcon, FilesIcon,
  HistoryIcon,
  ImageIcon,
  LinkIcon,
  MailIcon, PaletteIcon, PlusIcon,
  SettingsIcon, StarIcon, TagIcon
} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import React from "react";
import {Collection} from "@/db";

interface AppSidebarCollectionItemProps {
  collection: Collection
  onSelect: () => void
}

export function AppSidebarCollectionItem(props: AppSidebarCollectionItemProps) {
  return (
      <SidebarMenuItem key={props.collection.id}>
        <SidebarMenuButton onClick={props.onSelect}
                           isActive={false}
                           variant="sidebar"
                           size="sidebar"
                           className="cursor-default"
                           tooltip={{
                             children: props.collection.name,
                             hidden: false,
                           }}>
          <TagIcon className="h-5 w-5"/>
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
