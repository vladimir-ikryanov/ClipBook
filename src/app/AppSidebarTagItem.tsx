import {Edit3Icon, TrashIcon} from "lucide-react";
import {SidebarMenuButton, SidebarMenuItem} from "@/components/ui/sidebar";
import React from "react";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger
} from "@/components/ui/context-menu";
import TagIcon, {Tag} from "@/tags";
import { useTranslation } from 'react-i18next';

interface AppSidebarTagItemProps {
  tag: Tag
  selectedTag?: Tag | undefined
  onSelect: () => void
  onEditTag: (tag: Tag) => void
  onDeleteTag: (tag: Tag) => void
}

export function AppSidebarTagItem(props: AppSidebarTagItemProps) {
  const { t } = useTranslation();

  function handleEditTag() {
    props.onEditTag(props.tag)
  }

  function handleDeleteTag() {
    props.onDeleteTag(props.tag)
  }

  function handleSelect() {
    if (props.selectedTag) {
      if (props.tag.id != props.selectedTag.id) {
        props.onSelect()
      }
    } else {
      props.onSelect()
    }
  }

  return (
      <ContextMenu>
        <ContextMenuTrigger>
          <SidebarMenuItem key={props.tag.id}>
            <SidebarMenuButton onClick={handleSelect}
                               isActive={props.selectedTag ? props.tag.id === props.selectedTag.id : false}
                               variant="sidebar"
                               size="sidebar"
                               className="cursor-default"
                               tooltip={{
                                 children: props.tag.name,
                                 className: "px-2.5",
                                 hidden: false,
                               }}>
              <TagIcon className="h-5 w-5" style={{ color: props.tag.color }}/>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </ContextMenuTrigger>
        <ContextMenuContent>
          <ContextMenuItem onClick={handleEditTag}>
            <Edit3Icon className="mr-2 h-4 w-4"/>
            <span className="mr-4">{t('app.sidebar.tag.contextMenu.edit')}</span>
          </ContextMenuItem>
          <ContextMenuItem onClick={handleDeleteTag}>
            <TrashIcon className="mr-2 h-4 w-4"/>
            <span className="mr-4">{t('app.sidebar.tag.contextMenu.delete')}</span>
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>

  );
}
