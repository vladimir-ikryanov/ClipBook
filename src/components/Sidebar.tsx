import '../App.css';
import {Button} from "@/components/ui/button"
import {Home, Settings} from "lucide-react"

export default function Sidebar() {
    return (
        <div className="flex flex-col p-2 border-r border-gray-100">
            <Button variant="ghost">
                <Home className="h-4 w-4"/>
            </Button>
            <div className="grow draggable"></div>
            <Button variant="ghost">
                <Settings className="h-4 w-4"/>
            </Button>
        </div>
    )
}
