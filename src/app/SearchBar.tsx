import '../app.css';
import {Input} from "@/components/ui/input"
import React from "react";
import {PanelRightOpen, SearchIcon, XIcon} from "lucide-react";
import {Button} from "@/components/ui/button";
import {shortcutToDisplayShortcut} from "@/lib/shortcuts";
import {prefGetTogglePreviewShortcut} from "@/pref";

type SearchBarProps = {
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
  isPreviewVisible: boolean
  onShowHidePreview: () => void
  searchFieldRef?: React.Ref<HTMLInputElement>
}

export default function SearchBar(props: SearchBarProps) {
  const handleOnChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    props.onSearchQueryChange(e.target.value)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape" && props.searchQuery.length > 0) {
      handleClearSearch()
      e.stopPropagation()
    }
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.preventDefault()
    }
  }

  const handleShowHidePreview = () => {
    props.onShowHidePreview()
  }

  function handleClearSearch() {
    props.onSearchQueryChange("")
  }

  return (
      <div className="flex flex-col border-b-solid border-b-border border-b">
        <div className="flex m-2">
          <div
              className={props.searchQuery.length == 0 ? "flex-none relative" : "flex-auto relative"}>
            <div className="flex text-primary-foreground">
              <SearchIcon className="absolute left-2 top-2.5 h-5 w-5 text-secondary-foreground"/>
            </div>
            <Input placeholder="Type to search..."
                   value={props.searchQuery}
                   className="w-full h-10 pl-10 text-lg placeholder:text-secondary-foreground border-none"
                   onChange={handleOnChange}
                   onKeyDown={handleKeyDown}
                   ref={props.searchFieldRef}/>
          </div>
          <div className={props.searchQuery.length == 0 ? "flex-auto draggable" : "flex-none"}></div>
          <div className={props.searchQuery.length == 0 ? "hidden" : ""}>
            <Button variant="toolbar" size="toolbar" onClick={handleClearSearch}
                    title={"Clear search (Esc)"}>
              <XIcon className="h-5 w-5"/>
            </Button>
          </div>
          <div className={props.isPreviewVisible ? "hidden" : ""}>
            <Button variant="toolbar" size="toolbar" onClick={handleShowHidePreview}
                    title={"Show preview panel (" + shortcutToDisplayShortcut(prefGetTogglePreviewShortcut()) + ")"}>
              <PanelRightOpen className="h-5 w-5"/>
            </Button>
          </div>
        </div>
      </div>
  )
}
