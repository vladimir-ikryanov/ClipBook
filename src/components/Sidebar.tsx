import '../App.css';
import {Button} from "@/components/ui/button"
import {Code, Code2, CodeIcon, File, FileCode, Image, Link, Settings} from "lucide-react"

export default function Sidebar() {
    return (
        <div className="flex flex-col p-2 border-r border-gray-100">
            <Button variant="ghost">
                <File className="h-4 w-4"/>
            </Button>
            <Button variant="ghost">
                <Link className="h-4 w-4"/>
            </Button>
            <Button variant="ghost">
                <Code className="h-4 w-4"/>
            </Button>
            <Button variant="ghost">
                <Image className="h-4 w-4"/>
            </Button>
            <div className="grow draggable"></div>
            <Button variant="ghost">
                <Settings className="h-4 w-4"/>
            </Button>
        </div>
    )
}
