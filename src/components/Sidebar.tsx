import '../App.css';
import {Button} from "@/components/ui/button"
import {File, Link} from "lucide-react"
import Preferences from "@/components/Preferences";

export default function Sidebar() {
  return (
      <div className="flex flex-col p-2 border-r border-gray-100">
        <Button variant="ghost">
          <File className="h-4 w-4"/>
        </Button>
        <Button variant="ghost">
          <Link className="h-4 w-4"/>
        </Button>
        <div className="grow draggable"></div>
        <Preferences/>
      </div>
  )
}
