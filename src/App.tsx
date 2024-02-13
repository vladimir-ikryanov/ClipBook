import Sidebar from "@/components/Sidebar";
import History from "@/components/History";

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";
import * as React from "react";

declare const hideAppWindow: () => void;

export default function App() {
    const [history, setHistory] = useState(getHistoryItems())

    React.useEffect(() => {
        const down = (e: KeyboardEvent) => {
            if (e.key === "Escape") {
                e.preventDefault()
                hideAppWindow()
            }
        }

        document.addEventListener("keydown", down)
        return () => document.removeEventListener("keydown", down)
    }, [])

    function addClipboardData(data: string): void {
        setHistory([...addHistoryItem(data)])
    }

    function handleUpdateHistory() : void {
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
