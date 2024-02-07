import Sidebar from "@/components/Sidebar";
import History from "@/components/History";
import {Button} from "@/components/ui/button"

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";

export default function App() {
    const [history, setHistory] = useState(getHistoryItems())

    function addClipboardData(data: string): void {
        setHistory([...addHistoryItem(data)])
    }

    // Attach the function to the window object
    (window as any).addClipboardData = addClipboardData;

    let sumOfNumbers = (
        firstnum : number,
        secondnum : number
    ) : number => {
        return firstnum + secondnum;
    }

    return (
        <div className="flex h-screen">
            <Sidebar/>
            <History items={history}/>
        </div>
    )
}
