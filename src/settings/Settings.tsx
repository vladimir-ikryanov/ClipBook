import * as React from "react";
import {SidebarProvider} from "@/components/ui/sidebar";
import History from "@/settings/History";
import Privacy from "@/settings/Privacy";
import Shortcuts from "@/settings/Shortcuts";
import License from "@/settings/License";
import General from "@/settings/General";
import AISettings from "@/settings/AISettings";
import SettingsSidebar from "@/settings/SettingsSidebar";
import {SettingsSidebarItemType} from "@/settings/SettingsSidebarItem";
import {useState} from "react";
import About from "@/settings/About";

interface SettingsProps {
  selectedItemType: SettingsSidebarItemType
}

export default function Settings(props: SettingsProps) {
  const [selectedItemType, setSelectedItemType] = useState<SettingsSidebarItemType>(props.selectedItemType)

  function handleSidebarItemSelect(type: SettingsSidebarItemType) {
    setSelectedItemType(type)
  }

  return (
      <SidebarProvider className="">
        <SettingsSidebar onSelect={handleSidebarItemSelect} selectedItemType={selectedItemType}/>
        <div className="w-full bg-background-solid">
          {
              selectedItemType === "General" && <General/>
          }
          {
              selectedItemType === "History" && <History/>
          }
          {
              selectedItemType === "Shortcuts" && <Shortcuts/>
          }
          {
              selectedItemType === "Privacy" && <Privacy/>
          }
          {
              selectedItemType === "AI" && <AISettings/>
          }
          {
              selectedItemType === "License" && <License/>
          }
          {
              selectedItemType === "About" && <About/>
          }
        </div>
      </SidebarProvider>
  )
}
