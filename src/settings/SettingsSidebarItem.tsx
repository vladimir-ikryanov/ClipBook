import {LucideIcon} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";

export type SettingsSidebarItemType = "General" | "History" | "Privacy" | "Shortcuts" | "License";

interface SettingsSidebarItemProps {
  type: SettingsSidebarItemType;
  url: string;
  icon: LucideIcon;
  isSelected: boolean;
  onSelect: () => void;
}

export function SettingsSidebarItem(props: SettingsSidebarItemProps) {
  return (
      <SidebarMenuItem key={props.type}>
        <SidebarMenuButton size="default" isActive={props.isSelected} onClick={props.onSelect} asChild>
          <a href={`#${props.url}`}>
            <props.icon/>
            <span>{props.type}</span>
          </a>
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
