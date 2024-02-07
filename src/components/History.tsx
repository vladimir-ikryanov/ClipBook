import '../App.css';
import {Tabs, TabsList} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import {ScrollArea} from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import HistoryItemPreview from "@/components/HistoryItemPreview"

type HistoryProps = {
    items: string[]
}

export default function History(props: HistoryProps) {
    const items = props.items.map((item, index) =>
        <HistoryItem key={index} index={index} text={item}/>
    );
    const previews = props.items.map((item, index) =>
        <HistoryItemPreview key={index} index={index} text={item}/>
    );
    return (
        <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
            <ResizablePanelGroup direction="horizontal">
                <ResizablePanel defaultSize={40}>
                    <ScrollArea className="h-full border-r border-gray-100">
                        <TabsList className="grid h-full grid-rows-3 justify-normal p-2 pr-4 pl-4">
                            {items}
                        </TabsList>
                    </ScrollArea>
                </ResizablePanel>
                <ResizableHandle/>
                <ResizablePanel defaultSize={60}>{previews}</ResizablePanel>
            </ResizablePanelGroup>
        </Tabs>
    )
}
