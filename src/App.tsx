import Sidebar from "@/components/Sidebar";
import History from "@/components/History";
import {Button} from "@/components/ui/button"

import {addHistoryItem, getHistoryItems} from "@/data"
import {useState} from "react";

export default function App() {
    const [history, setHistory] = useState(getHistoryItems())

    function greet(name: string): void {
        setHistory([...addHistoryItem("New history item")])
    }

    // Attach the function to the window object
    (window as any).greet = greet;

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
