import '../App.css';
import {Input} from "@/components/ui/input"
import React, {useState} from "react";
import {PanelRightClose, PanelRightOpen} from "lucide-react";
import {Button} from "@/components/ui/button";

type ToolbarProps = {
  onFilterHistory: (searchQuery: string) => void
  isPreviewVisible: boolean
  onShowHidePreview: () => void
  searchFieldRef?: React.Ref<HTMLInputElement>
}

export default function ToolBar(props: ToolbarProps) {
  const [searchQuery, setSearchQuery] = useState("");

  const handleOnChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value)
    props.onFilterHistory(e.target.value)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape" && searchQuery.length > 0) {
      setSearchQuery("")
      props.onFilterHistory("")
      e.stopPropagation()
    }
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.preventDefault()
    }
  }

  const handleShowHidePreview = () => {
    props.onShowHidePreview()
  }

  return (
      <div className="flex flex-col border-b-solid border-b-border border-b">
        <div className="flex-auto draggable p-1"></div>
        <div className="flex ml-2 mr-2 mb-2">
          <div className="flex-auto relative">
            <div className="flex text-primary-foreground">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
                   fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"
                   strokeLinejoin="round"
                   className="lucide lucide-search absolute left-3 top-2.5 h-5 w-5 text-secondary-foreground">
                <circle cx="11" cy="11" r="8"/>
                <path d="m21 21-4.3-4.3"/>
              </svg>
            </div>
            <Input placeholder="Type to search"
                   value={searchQuery}
                   className="w-full pl-11 text-lg placeholder:text-secondary-foreground border-none"
                   onChange={handleOnChange}
                   onKeyDown={handleKeyDown}
                   ref={props.searchFieldRef}
            />
          </div>
          <div className="ml-3">
            <Button variant="ghost" className="p-2" onClick={handleShowHidePreview}
                    title={props.isPreviewVisible ? "Hide preview panel" : "Show preview panel"}>
              {props.isPreviewVisible ?
                  <PanelRightClose className="h-5 w-5 text-primary-foreground"/> :
                  <PanelRightOpen className="h-5 w-5 text-primary-foreground"/>}
            </Button>
          </div>
        </div>
      </div>
  )
}
