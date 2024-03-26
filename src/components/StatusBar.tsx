import '../App.css';
import {Button} from "@/components/ui/button";
import {
  ArrowBigDown,
  ArrowBigUp,
  ChevronDown,
  ChevronUp, Command,
  CornerDownLeft,
  Delete
} from "lucide-react";

type StatusBarProps = {
  appName: string
}

export default function StatusBar(props: StatusBarProps) {
  return (
      <div className="flex flex-row p-3 text-sm text-primary-foreground border-t-solid border-t-border border-t draggable">
        <div className="flex flex-row">
          <Button disabled={true} className="btn p-0 mr-1 h-6 w-6 rounded bg-card">
            <ChevronUp className="h-5 w-5 text-card-foreground"/>
          </Button>
          <Button disabled={true} className="btn p-0 h-6 w-6 rounded bg-card">
            <ChevronDown className="h-5 w-5 text-card-foreground"/>
          </Button>
          <div className="flex items-center">
            <p className="pl-2 pr-4">Navigate</p>
          </div>

          <Button disabled={true} className="btn p-0 h-6 w-6 rounded bg-card">
            <CornerDownLeft className="h-4 w-4 text-card-foreground"/>
          </Button>
          <div className="flex items-center">
            <p className="pl-2 pr-4">Paste to {props.appName}</p>
          </div>

          <Button disabled={true} className="btn p-0 mr-1 h-6 w-7 rounded bg-card">
            <Command className="h-4 w-6 text-card-foreground"/>
          </Button>
          <Button disabled={true} className="btn p-0 h-6 w-7 rounded bg-card">
            <Delete className="h-4 w-6 text-card-foreground"/>
          </Button>
          <div className="flex items-center">
            <p className="pl-2 pr-4">Delete</p>
          </div>

          <Button disabled={true} className="btn px-2 h-6 rounded bg-card">
            <span className="text-sm font-mono text-card-foreground">esc</span>
          </Button>
          <div className="flex items-center">
            <p className="pl-2 pr-4">Close</p>
          </div>
        </div>
      </div>
  )
}
