import {useEffect, useState} from "react";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarHeader,
  SidebarMenu,
} from "@/components/ui/sidebar";
import {AppSidebarItem, AppSidebarItemType} from "@/app/AppSidebarItem";
import {
  AppInfo,
  filterByApp,
  filterByFavorites,
  filterByTag,
  filterByType,
  getHistoryItemById,
  resetFilter
} from "@/data";
import {Clip, ClipType} from "@/db";
import {AppSidebarTagItem} from "@/app/AppSidebarTagItem";
import TagDialog from "@/app/TagDialog";
import {allTags, removeTag, Tag} from "@/tags";
import {emitter} from "@/actions";
import {AppSidebarSourceItems} from "@/app/AppSidebarSourceItems";

interface AppSidebarProps {
  visible: boolean
  selectedItemType: AppSidebarItemType
  selectedTag?: Tag | undefined
  selectedApp?: AppInfo | undefined
  onSelectType: (type: AppSidebarItemType) => void
  onSelectTag: (tag: Tag) => void
  onSelectApp: (app: AppInfo) => void
}

export default function AppSidebar(props: AppSidebarProps) {
  const [tags, setTags] = useState<Tag[]>(allTags())
  const [tagToEdit, setTagToEdit] = useState<Tag | undefined>(undefined)
  const [itemForTag, setItemForTag] = useState<Clip | undefined>(undefined)
  const [tagDialogVisible, setTagDialogVisible] = useState(false)

  useEffect(() => {
    function handleAddTagToItemWithIdEvent(itemId?: number) {
      if (itemId) {
        handleNewTagForItem(itemId)
      }
    }

    function handleUpdateTagsEvent() {
      setTags([...allTags()])
    }

    emitter.on("UpdateTags", handleUpdateTagsEvent)
    emitter.on("AddTagToItemWithId", handleAddTagToItemWithIdEvent)
    return () => {
      emitter.off("UpdateTags", handleUpdateTagsEvent)
      emitter.off("AddTagToItemWithId", handleAddTagToItemWithIdEvent)
    };
  }, [])

  function handleSelectType(type: AppSidebarItemType) {
    props.onSelectType(type)
  }

  function handleSelectTag(tag: Tag) {
    props.onSelectTag(tag)
    filterByTag(tag)
    emitter.emit("FilterHistory")
  }

  function handleSelectApp(app: AppInfo) {
    props.onSelectApp(app)
    filterByApp(app)
    emitter.emit("FilterHistory")
  }

  function handleEditTag(tag: Tag) {
    setTagToEdit(tag)
    setItemForTag(undefined)
    setTagDialogVisible(true)
  }

  function handleDeleteTag(tag: Tag) {
    if (tag.id === props.selectedTag?.id) {
      handleShowAll()
    }
    removeTag(tag)
    emitter.emit("DeleteTagById", tag.id)
    emitter.emit("UpdateTags")
  }

  function handleShowFavorites() {
    handleSelectType("Favorites")
    filterByFavorites()
    emitter.emit("FilterHistory")
  }

  function handleShowAll() {
    handleSelectType("All")
    resetFilter()
    emitter.emit("FilterHistory")
  }

  function handleShowByType(clipType: ClipType, type: AppSidebarItemType) {
    handleSelectType(type)
    filterByType(clipType)
    emitter.emit("FilterHistory")
  }

  function handleNewTag() {
    setTagToEdit(undefined)
    setItemForTag(undefined)
    setTagDialogVisible(true)
  }

  function handleNewTagForItem(itemId: number) {
    setTagToEdit(undefined)
    setItemForTag(getHistoryItemById(itemId))
    setTagDialogVisible(true)
  }

  function handleTagDialogClose() {
    setTagDialogVisible(false)
  }

  return (
      <Sidebar side="left"
               className={`h-screen !w-[4rem] bg-secondary items-center py-1 border-r ${props.visible ? "" : "hidden"}`}
               collapsible="none">
        <SidebarHeader>
          <SidebarMenu>
            <AppSidebarItem type={"All"}
                            selectedType={props.selectedItemType}
                            onSelect={() => handleShowAll()}/>
          </SidebarMenu>
        </SidebarHeader>
        <SidebarContent className="select-none overflow-scroll no-scrollbars mt-2">
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <AppSidebarItem type={"Favorites"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowFavorites()}/>
                <AppSidebarItem type={"Text"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Text, "Text")}/>
                <AppSidebarItem type={"Image"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Image, "Image")}/>
                <AppSidebarItem type={"Link"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Link, "Link")}/>
                <AppSidebarItem type={"File"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.File, "File")}/>
                <AppSidebarItem type={"Color"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Color, "Color")}/>
                <AppSidebarItem type={"Email"}
                                selectedType={props.selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Email, "Email")}/>

              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
          <AppSidebarSourceItems selectedApp={props.selectedApp} selectedItemType={props.selectedItemType} onSelect={handleSelectApp}/>
          <div className="flex-grow"></div>
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <TagDialog visible={tagDialogVisible}
                           tag={tagToEdit}
                           item={itemForTag}
                           onClose={handleTagDialogClose}/>
                <AppSidebarItem type={"NewTag"}
                                selectedType={props.selectedItemType}
                                selectable={false}
                                onSelect={handleNewTag}/>
                {
                  tags.map((tag) => {
                    return <AppSidebarTagItem key={tag.id}
                                              tag={tag}
                                              selectedTag={props.selectedTag}
                                              onSelect={() => handleSelectTag(tag)}
                                              onEditTag={() => handleEditTag(tag)}
                                              onDeleteTag={() => handleDeleteTag(tag)}/>
                  })
                }
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
      </Sidebar>
  )
}
