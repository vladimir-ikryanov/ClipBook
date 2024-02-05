import '../App.css';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from "@/components/ui/resizable";
import { ScrollArea } from "@/components/ui/scroll-area"
import HistoryItem from "@/components/HistoryItem"
import HistoryItemPreview from "@/components/HistoryItemPreview"

const historyItems = [
    { value: "Create an API which would allow to access some data in table" },
    { value: "npx shadcn-ui@latest add scroll-area" },
    { value: "export default function ClipboardItems()" },
    { value: "import '../App.css';" },
];

export default function History() {
    const tabs = historyItems.map((item, index) =>
        <HistoryItem key={index} index={index} text={item.value} />
    );
    const previews = historyItems.map((item, index) =>
        <HistoryItemPreview key={index} index={index} text={item.value} />
    );
    return (
        <Tabs defaultValue="0" orientation="vertical" className="w-full p-0 m-0">
            <ResizablePanelGroup direction="horizontal">
                <ResizablePanel defaultSize={30}>
                    <ScrollArea className="h-full">
                        <TabsList className="grid h-full grid-rows-3 justify-normal p-2">
                            {tabs}
                        </TabsList>
                    </ScrollArea>
                </ResizablePanel>
                <ResizableHandle />
                <ResizablePanel defaultSize={70}>{previews}</ResizablePanel>
            </ResizablePanelGroup>
        </Tabs>
    )
}
