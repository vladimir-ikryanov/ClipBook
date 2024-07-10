import '../App.css';
import {Button} from "@/components/ui/button";

import * as React from "react"
import {
  DeleteIcon,
  Edit2Icon,
  Edit3Icon,
  EditIcon,
  MoreHorizontal,
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

type ActionsProps = {}

export default function Actions(props: ActionsProps) {
  const [open, setOpen] = React.useState(false)

  return (
      <DropdownMenu open={open} onOpenChange={setOpen}>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm">
            <MoreHorizontal/>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-[300px]">
          <Command>
            <CommandList>
              <CommandItem>
                <Edit3Icon className="mr-2 h-4 w-4"/>
                <span>Edit content...</span>
                <CommandShortcut>⌘E</CommandShortcut>
              </CommandItem>
              <CommandItem>
                <SearchIcon className="mr-2 h-4 w-4"/>
                <span>Search...</span>
                <CommandShortcut>⌘F</CommandShortcut>
              </CommandItem>
              <CommandItem>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete</span>
                <CommandShortcut>⌘⌫</CommandShortcut>
              </CommandItem>
              <CommandItem>
                <TrashIcon className="mr-2 h-4 w-4"/>
                <span>Delete all...</span>
                <CommandShortcut>⌘⌫</CommandShortcut>
              </CommandItem>
              <CommandEmpty>No results found.</CommandEmpty>
            </CommandList>
            <CommandInput placeholder="Type a command or search..." autoFocus={true}/>
          </Command>
        </DropdownMenuContent>
      </DropdownMenu>
  )
}
