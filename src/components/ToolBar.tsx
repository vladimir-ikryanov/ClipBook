import '../App.css';
import {Input} from "@/components/ui/input"
import {Toggle} from "@/components/ui/toggle"
import React from "react";
import {PanelRightClose} from "lucide-react";
import {Button} from "@/components/ui/button";

type ToolbarProps = {
  onFilterHistory: (searchQuery: string) => void
}

export default function ToolBar(props: ToolbarProps) {
  const handleOnChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    props.onFilterHistory(e.target.value)
  }

  return (
      <div className="flex flex-row p-2 border-b-solid border-b-neutral-200 border-b">
        <div className="flex-auto relative">
          <div className="flex text-primary-foreground">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
                 fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"
                 strokeLinejoin="round"
                 className="lucide lucide-search absolute left-3 top-2.5 h-5 w-5 text-neutral-400">
              <circle cx="11" cy="11" r="8"/>
              <path d="m21 21-4.3-4.3"/>
            </svg>
          </div>
          <Input placeholder="Type to search" className="w-full pl-11 text-lg placeholder:text-neutral-400"
                 onChange={handleOnChange}/>
        </div>
        <div className="ml-3">
          <Button variant="ghost" className="p-2">
            <PanelRightClose className="h-5 w-5 text-neutral-600"/>
          </Button>
        </div>
      </div>
  )
}
