import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
} from "@/components/ui/sidebar";
import React, {useEffect, useState} from "react";
import {AppInfo, getSourceApps} from "@/data";
import {AppSidebarSourceItem} from "@/app/AppSidebarSourceItem";
import {AppSidebarItem, AppSidebarItemType} from "@/app/AppSidebarItem";
import {emitter} from "@/actions";

interface AppSidebarSourceItemsProps {
  selectedApp?: AppInfo | undefined
  selectedItemType: AppSidebarItemType
  onSelect: (app: AppInfo) => void
}

export function AppSidebarSourceItems(props: AppSidebarSourceItemsProps) {
  let sourceApps = getSourceApps()
  if (sourceApps.length === 0) {
    return null
  }

  const [apps, setApps] = useState<AppInfo[]>(sourceApps)
  const [expandApps, setExpandApps] = useState(false)

  useEffect(() => {
    function handleUpdateApps() {
      setApps(getSourceApps())
    }

    emitter.on("UpdateApps", handleUpdateApps)
    return () => emitter.off("UpdateApps", handleUpdateApps);
  }, [])

  function handleToggleApps() {
    setExpandApps(!expandApps)
  }

  function isHidden(app: AppInfo) {
    if (expandApps) {
      return false
    }
    if (props.selectedApp) {
      if (props.selectedApp.path === app.path) {
        return false
      }
    } else {
      if (apps[0].path === app.path) {
        return false
      }
    }

    return true
  }

  return (
      <SidebarGroup>
        <SidebarGroupContent>
          <SidebarMenu>
            {
              apps.map((app) => {
                return <AppSidebarSourceItem key={app.path}
                                             app={app}
                                             hidden={isHidden(app)}
                                             selectedApp={props.selectedApp}
                                             onSelect={() => props.onSelect(app)}/>
              })
            }
            <AppSidebarItem type={expandApps ? "HideApps" : "ShowApps"}
                            selectedType={props.selectedItemType}
                            selectable={false}
                            onSelect={handleToggleApps}/>
          </SidebarMenu>
        </SidebarGroupContent>
      </SidebarGroup>
  );
}
