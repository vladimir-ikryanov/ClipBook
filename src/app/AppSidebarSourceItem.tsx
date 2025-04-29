import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import React from "react";
import {AppInfo, toBase64Icon} from "@/data";

interface AppSidebarSourceItemProps {
  app: AppInfo
  selectedApp?: AppInfo | undefined
  hidden?: boolean
  onSelect: () => void
}

export function AppSidebarSourceItem(props: AppSidebarSourceItemProps) {
  return (
      <SidebarMenuItem key={props.app.path} hidden={props.hidden}>
        <SidebarMenuButton onClick={props.onSelect}
                           isActive={props.selectedApp ? props.app.path === props.selectedApp.path : false}
                           variant="sidebar"
                           size="sidebar"
                           className="cursor-default justify-center"
                           tooltip={{
                             children: props.app.name,
                             className: "px-2.5",
                             hidden: false,
                           }}>
          <div className="flex h-5 w-5">
            <img src={toBase64Icon(props.app.icon)} className="" alt="Application icon"/>
          </div>
        </SidebarMenuButton>
      </SidebarMenuItem>
  );
}
