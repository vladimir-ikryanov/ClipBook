import * as React from "react";
import {
  Sidebar,
  SidebarContent, SidebarFooter,
  SidebarGroup,
  SidebarGroupContent, SidebarMenu,
} from "@/components/ui/sidebar";
import {SettingsSidebarItem, SettingsSidebarItemType} from "@/settings/SettingsSidebarItem";
import {useState} from "react";
import {
  CogIcon,
  InfoIcon,
  KeyboardIcon,
  KeyRoundIcon,
  ListIcon,
  SettingsIcon,
  ShieldCheckIcon
} from "lucide-react";
import {prefIsDeviceManaged} from "@/pref";

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
                <SettingsSidebarItem type={"About"}
                                     url={"/"}
                                     icon={InfoIcon}
                                     isSelected={selectedItemType === "About"}
                                     onSelect={() => handleSelect("About")}/>
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
        {
            !prefIsDeviceManaged() &&
            <SidebarFooter className="border-r border-r-sidebar-border select-none">
              <div
                  className="flex flex-col items-center justify-center text-center px-2 py-4 w-full rounded-md bg-sidebar-background-secondary text-secondary-foreground space-y-2">
                <CogIcon className="h-8 w-10 mt-1 text-sidebar-foreground-secondary" strokeWidth={1.5}/>
                <span className="text-sm">Some settings are managed by your organization.</span>
              </div>
            </SidebarFooter>
        }
      </Sidebar>
  )
}
