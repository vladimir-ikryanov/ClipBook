import * as React from "react";
import {useState} from "react";
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
  allTags,
  deleteTag,
  filterByFavorites,
  filterByTag,
  filterByType,
  resetFilter
} from "@/data";
import {ClipType, Tag, getAllTags} from "@/db";
import {AppSidebarTagItem} from "@/app/AppSidebarTagItem";
import TagDialog from "@/app/TagDialog";

interface AppSidebarProps {
  visible: boolean
  selectedItemType: AppSidebarItemType
  selectedTag?: Tag | undefined
  onSelectType: (type: AppSidebarItemType) => void
  onSelectTag: (tag: Tag) => void
}

export default function AppSidebar(props: AppSidebarProps) {
  const [tags, setTags] = useState<Tag[]>(allTags())
  const [tagToEdit, setTagToEdit] = useState<Tag | undefined>(undefined)
  const [tagDialogVisible, setTagDialogVisible] = useState(false)

  function handleSelectType(type: AppSidebarItemType) {
    props.onSelectType(type)
  }

  function handleSelectTag(tag: Tag) {
    props.onSelectTag(tag)
    filterByTag(tag)
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleEditTag(tag: Tag) {
    setTagToEdit(tag)
    setTagDialogVisible(true)
  }

  function handleDeleteTag(tag: Tag) {
    deleteTag(tag)
    setTags([...allTags()])
  }

  function handleShowFavorites() {
    handleSelectType("Favorites")
    filterByFavorites()
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleShowAll() {
    handleSelectType("All")
    resetFilter()
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleShowByType(clipType: ClipType, type: AppSidebarItemType) {
    handleSelectType(type)
    filterByType(clipType)
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleNewTag() {
    setTagDialogVisible(true)
    setTagToEdit(undefined)
  }

  function handleTagDialogClose() {
    setTagDialogVisible(false)
  }

  function handleTagCreated() {
    handleTagDialogClose()
    getAllTags().then((tags) => {
      setTags(tags)
    })
  }

  function handleTagUpdated() {
    handleTagDialogClose()
    getAllTags().then((tags) => {
      setTags(tags)
    })
  }

  return (
      <Sidebar side="left"
               className={`h-screen !w-[4rem] items-center py-1 border-r ${props.visible ? "" : "hidden"}`}
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
          <div className="flex-grow"></div>
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <TagDialog visible={tagDialogVisible}
                           tag={tagToEdit}
                           onClose={handleTagDialogClose}
                           onCreateTag={handleTagCreated}
                           onUpdateTag={handleTagUpdated}/>
                <AppSidebarItem type={"New Tag"}
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
