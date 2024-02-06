import '../App.css';
import {TabsTrigger} from "@/components/ui/tabs";

type HistoryItemProps = {
    index: number
    text: string
}

export default function HistoryItem({index, text}: HistoryItemProps) {
    return (
        <TabsTrigger
            autoFocus={index == 0}
            value={index.toString()}
            className="text-base text-justify data-[state=active]:bg-accent font-normal p-2 whitespace-nowrap overflow-hidden overflow-ellipsis">
            {text}
        </TabsTrigger>
    )
}
