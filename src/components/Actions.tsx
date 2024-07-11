import '../App.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {
  ArrowBigUp,
  CommandIcon,
  DeleteIcon,
  Edit2Icon,
  Edit3Icon,
  EditIcon,
  MoreHorizontal, PanelRightClose, PanelRightOpen,
  SearchIcon,
  TrashIcon
} from "lucide-react"

import {
  Command,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList, CommandSeparator, CommandShortcut,
} from "@/components/ui/command"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {KeyboardEvent} from "react";

type ActionsProps = {}

export default function Actions(props: ActionsProps) {
  const [open, setOpen] = React.useState(false)

  const handleKeyDown = (e: KeyboardEvent) => {
    // Prevent leaving the keyboard event from the Actions menu.
    e.stopPropagation()
  }

  return (
      <DropdownMenu open={open} onOpenChange={setOpen}>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="p-1 h-8">
            <p className="px-2">Actions</p>
            <div className="flex h-6 w-6 p-1.5 rounded bg-card">
              <CommandIcon className="h-3 w-3 text-card-foreground"/>
            </div>
            <div className="flex h-6 w-6 ml-1 rounded bg-card justify-center items-center">
              <span className="font-mono text-sm text-card-foreground">K</span>
            </div>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-[300px]" onKeyDown={handleKeyDown}>
          <Command>
            <CommandList>
              <CommandItem>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span>Edit content...</span>
                <CommandShortcut className="flex flex-row">
                  <div className="flex h-6 w-6 p-1.5 rounded bg-card">
                    <CommandIcon className="h-3 w-3 text-card-foreground"/>
                  </div>
                  <div className="flex h-6 w-6 ml-1 rounded bg-card justify-center items-center">
                    <span className="font-mono text-sm text-card-foreground">E</span>
                  </div>
                </CommandShortcut>
              </CommandItem>
              <CommandItem>
                <SearchIcon className="mr-2 h-4 w-4"/>
                <span>Search...</span>
                <CommandShortcut className="flex flex-row">
                  <div className="flex h-6 w-6 p-1.5 rounded bg-card">
                    <CommandIcon className="h-3 w-3 text-card-foreground"/>
                  </div>
                  <div className="flex h-6 w-6 ml-1 rounded bg-card justify-center items-center">
                    <span className="font-mono text-sm text-card-foreground">F</span>
                  </div>
                </CommandShortcut>
              </CommandItem>
              <CommandItem>
                <PanelRightClose className="mr-2 h-4 w-4"/>
                <span>Hide Preview panel</span>
                <CommandShortcut className="flex flex-row">
                  <div className="flex h-6 w-6 p-1.5 rounded bg-card">
                    <CommandIcon className="h-3 w-3 text-card-foreground"/>
                  </div>
                  <div className="flex h-6 w-6 ml-1 rounded bg-card justify-center items-center">
                    <span className="font-mono text-sm text-card-foreground">P</span>
                  </div>
                </CommandShortcut>
              </CommandItem>
              <CommandItem>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete</span>
                <CommandShortcut className="flex flex-row">
                  <div className="flex h-6 w-6 p-1.5 rounded bg-card">
                    <CommandIcon className="h-3 w-3 text-card-foreground"/>
                  </div>
                  <div className="flex h-6 w-6 pt-0.5 ml-1 rounded bg-card justify-center items-center">
                    <DeleteIcon className="h-4 w-4 text-card-foreground"/>
                  </div>
                </CommandShortcut>
              </CommandItem>
              <CommandItem>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete all...</span>
                <CommandShortcut className="flex flex-row">
                  <div className="flex h-6 w-6 p-1.5 rounded bg-card">
                    <CommandIcon className="h-3 w-3 text-card-foreground"/>
                  </div>
                  <div
                      className="flex h-6 w-6 pt-0.5 ml-1 rounded bg-card justify-center items-center">
                    <ArrowBigUp className="h-4 w-4 text-card-foreground"/>
                  </div>
                  <div
                      className="flex h-6 w-6 pt-0.5 ml-1 rounded bg-card justify-center items-center">
                    <DeleteIcon className="h-4 w-4 text-card-foreground"/>
                  </div>
                </CommandShortcut>
              </CommandItem>
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
          </Command>
        </DropdownMenuContent>
      </DropdownMenu>
  )
}
