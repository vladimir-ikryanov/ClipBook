import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
} from "@/components/ui/sidebar";
import React, {useEffect, useState} from "react";
import {AppInfo, getSourceApps, toBase64Icon} from "@/data";
import {AppSidebarSourceItem} from "@/app/AppSidebarSourceItem";
import {AppSidebarItem, AppSidebarItemType} from "@/app/AppSidebarItem";
import {ActionName} from "@/actions";

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
    function handleAction(event: Event) {
      const customEvent = event as CustomEvent<{ action: string }>;
      if (customEvent.detail.action === ActionName.UpdateApps) {
        setApps(getSourceApps())
      }
    }

    window.addEventListener("onAction", handleAction);
    return () => window.removeEventListener("onAction", handleAction);
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
            <AppSidebarItem type={expandApps ? "Hide Apps" : "Show Apps"}
                            selectedType={props.selectedItemType}
                            selectable={false}
                            onSelect={handleToggleApps}/>
          </SidebarMenu>
        </SidebarGroupContent>
      </SidebarGroup>
  );
}
