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
import {filterByFavorites, filterByType, resetFilter} from "@/data";
import {ClipType, Collection, getAllCollections} from "@/db";
import {AppSidebarCollectionItem} from "@/app/AppSidebarCollectionItem";

interface AppSidebarProps {
  selectedItemType: AppSidebarItemType
  visible: boolean
  onSelect: (type: AppSidebarItemType) => void
}

export default function AppSidebar(props: AppSidebarProps) {
  const [selectedItemType, setSelectedItemType] = useState<AppSidebarItemType>(props.selectedItemType)

  function handleSelect(type: AppSidebarItemType) {
    setSelectedItemType(type)
    props.onSelect(type)
  }

  function handleCollectionSelect(collection: Collection) {

  }

  function handleShowFavorites() {
    handleSelect("Favorites")
    filterByFavorites()
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleShowAll() {
    handleSelect("All")
    resetFilter()
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleShowByType(clipType: ClipType, type: AppSidebarItemType) {
    handleSelect(type)
    filterByType(clipType)
    window.dispatchEvent(new CustomEvent("onAction", {detail: {action: "filterHistory"}}));
  }

  function handleNewCollection() {
    console.log("New Collection")
  }

  return (
      <Sidebar side="left"
               className={`h-screen !w-[4rem] items-center py-1 border-r ${props.visible ? "" : "hidden"}`}
               collapsible="none">
        <SidebarHeader>
          <SidebarMenu>
            <AppSidebarItem type={"All"}
                            selectedType={selectedItemType}
                            onSelect={() => handleShowAll()}/>
            <AppSidebarItem type={"Favorites"}
                            selectedType={selectedItemType}
                            onSelect={() => handleShowFavorites()}/>
          </SidebarMenu>
        </SidebarHeader>
        <SidebarContent className="select-none bg-secondary overflow-scroll no-scrollbars mt-2">
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <AppSidebarItem type={"Text"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Text, "Text")}/>
                <AppSidebarItem type={"Image"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Image, "Image")}/>
                <AppSidebarItem type={"Link"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Link, "Link")}/>
                <AppSidebarItem type={"File"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.File, "File")}/>
                <AppSidebarItem type={"Color"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Color, "Color")}/>
                <AppSidebarItem type={"Email"}
                                selectedType={selectedItemType}
                                onSelect={() => handleShowByType(ClipType.Email, "Email")}/>

              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
          <div className="flex-grow"></div>
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                <AppSidebarItem type={"New Collection"}
                                selectedType={selectedItemType}
                                selectable={false}
                                onSelect={handleNewCollection}/>
                {
                  getAllCollections().map(collection => {
                    return <AppSidebarCollectionItem
                        collection={collection}
                        onSelect={() => handleCollectionSelect(collection)}/>
                  })
                }

              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
      </Sidebar>
  )
}
