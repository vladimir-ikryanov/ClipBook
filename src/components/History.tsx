import '../App.css';
import {Tabs, TabsList} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import HistoryItemPreview from "@/components/HistoryItemPreview"

type HistoryProps = {
    items: string[]
    onUpdateHistory: () => void
}

export default function History(props: HistoryProps) {
    let items = props.items.toReversed();
    const historyItems = items.map((item, index) =>
        <HistoryItem key={index} index={index} text={item} onUpdateHistory={props.onUpdateHistory}/>
    );
    const historyItemPreviews = items.map((item, index) =>
        <HistoryItemPreview key={index} index={index} text={item}/>
    );
    return (
        <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
            <ResizablePanelGroup direction="horizontal">
                <ResizablePanel defaultSize={40}>
                    <ScrollArea className="h-full border-r border-gray-100">
                        <TabsList className="grid h-full grid-rows-3 justify-normal p-2">
                            {historyItems}
                        </TabsList>
                        <ScrollBar orientation="vertical" />
                    </ScrollArea>
                </ResizablePanel>
                <ResizableHandle/>
                <ResizablePanel defaultSize={60}>{historyItemPreviews}</ResizablePanel>
            </ResizablePanelGroup>
        </Tabs>
    )
}
