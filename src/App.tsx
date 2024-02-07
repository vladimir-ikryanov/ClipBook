import Sidebar from "@/components/Sidebar";
import History from "@/components/History";

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";

export default function App() {
    const [history, setHistory] = useState(getHistoryItems())

    function addClipboardData(data: string): void {
        setHistory([...addHistoryItem(data)])
    }

    function handleUpdateHistory() {
        setHistory(getHistoryItems())
    }

    // Attach the function to the window object
    (window as any).addClipboardData = addClipboardData;

    return (
        <div className="flex h-screen">
            <Sidebar/>
            <History items={history} onUpdateHistory={handleUpdateHistory}/>
        </div>
    )
}
