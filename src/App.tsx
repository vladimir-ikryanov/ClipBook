import Sidebar from "@/components/Sidebar";
import History from "@/components/History";
import {Button} from "@/components/ui/button"

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";

export default function App() {
    const [history, setHistory] = useState(getHistoryItems())
    return (
        <div className="flex h-screen">
            <Sidebar/>
            <History items={history}/>
            <Button onClick={() => {
                setHistory([...addHistoryItem("Test item")])
            }}>Add</Button>
        </div>
    )
}
