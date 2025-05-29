import {
  ChevronDownIcon,
  ChevronUpIcon,
  FileIcon, FilesIcon,
  HistoryIcon,
  ImageIcon,
  LinkIcon,
  MailIcon, 
  PaletteIcon, 
  PlusIcon,
  StarIcon
} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import { useTranslation } from 'react-i18next';

export type AppSidebarItemType = "None" | "All" | "Text" | "Image" | "Link" | "Color" | "File" | "Email" | "Favorites" | "NewTag" | "ShowApps" | "HideApps";

interface AppSidebarItemProps {
  type: AppSidebarItemType
  selectedType: AppSidebarItemType
  selectable?: boolean
  onSelect: () => void
}

export function AppSidebarItem(props: AppSidebarItemProps) {
  const { t } = useTranslation();

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
    if (props.type === "NewTag") {
      return <PlusIcon className="h-5 w-5"/>
    }
    if (props.type === "HideApps") {
      return <ChevronUpIcon className="h-5 w-5"/>
    }
    if (props.type === "ShowApps") {
      return <ChevronDownIcon className="h-5 w-5"/>
    }
  }

  function handleSelect() {
    if (props.type != props.selectedType) {
      props.onSelect()
    }
  }

  return (
      <SidebarMenuItem key={props.type}>
        <SidebarMenuButton onClick={handleSelect}
                           isActive={props.type === props.selectedType}
                           variant="sidebar"
                           size="sidebar"
                           className="cursor-default"
                           tooltip={{
                             children: t(`app.sidebar.${props.type.toLowerCase().replace(" ", "")}`),
                             className: "px-2.5",
                             hidden: false,
                           }}>
          {renderIcon()}
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
