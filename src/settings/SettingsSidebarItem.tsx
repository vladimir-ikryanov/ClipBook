import {LucideIcon} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import { useTranslation } from 'react-i18next';

export type SettingsSidebarItemType = "General" | "History" | "Storage" | "Privacy" | "Shortcuts" | "License" | "About";

interface SettingsSidebarItemProps {
  type: SettingsSidebarItemType;
  url: string;
  icon: LucideIcon;
  isSelected: boolean;
  onSelect: () => void;
}

export function SettingsSidebarItem(props: SettingsSidebarItemProps) {
  const { t } = useTranslation();

  return (
      <SidebarMenuItem key={props.type}>
        <SidebarMenuButton size="sidebar" isActive={props.isSelected} onClick={props.onSelect} asChild>
          <a href={`#${props.url}`}>
            <props.icon className="w-5 h-5"/>
            <span>{t(`settings.sidebar.${props.type.toLowerCase()}`)}</span>
          </a>
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
