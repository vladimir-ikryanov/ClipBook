import * as React from "react";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent, SidebarMenu,
} from "@/components/ui/sidebar";
import {SettingsSidebarItem, SettingsSidebarItemType} from "@/settings/SettingsSidebarItem";
import {useState} from "react";
import {
  KeyboardIcon,
  KeyRoundIcon,
  ListIcon,
  SettingsIcon,
  ShieldCheckIcon
} from "lucide-react";

interface SettingsSidebarProps {
  selectedItemType: SettingsSidebarItemType
  onSelect: (type: SettingsSidebarItemType) => void
}

export default function SettingsSidebar(props: SettingsSidebarProps) {
  const [selectedItemType, setSelectedItemType] = useState<SettingsSidebarItemType>(props.selectedItemType)

  function handleSelect(type: SettingsSidebarItemType) {
    setSelectedItemType(type)
    props.onSelect(type)
  }

  return (
      <Sidebar className="!h-auto" collapsible="none" side="left">
        <SidebarContent className="py-0 px-1 select-none border-r border-r-sidebar-border">
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <div className="py-4 draggable"></div>
                <SettingsSidebarItem type={"General"}
                                     url={"/"}
                                     icon={SettingsIcon}
                                     isSelected={selectedItemType === "General"}
                                     onSelect={() => handleSelect("General")}/>
                <SettingsSidebarItem type={"History"}
                                     url={"/"}
                                     icon={ListIcon}
                                     isSelected={selectedItemType === "History"}
                                     onSelect={() => handleSelect("History")}/>
                <SettingsSidebarItem type={"Shortcuts"}
                                     url={"/"}
                                     icon={KeyboardIcon}
                                     isSelected={selectedItemType === "Shortcuts"}
                                     onSelect={() => handleSelect("Shortcuts")}/>
                <SettingsSidebarItem type={"Privacy"}
                                     url={"/"}
                                     icon={ShieldCheckIcon}
                                     isSelected={selectedItemType === "Privacy"}
                                     onSelect={() => handleSelect("Privacy")}/>
                <SettingsSidebarItem type={"License"}
                                     url={"/"}
                                     icon={KeyRoundIcon}
                                     isSelected={selectedItemType === "License"}
                                     onSelect={() => handleSelect("License")}/>
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
      </Sidebar>
  )
}
