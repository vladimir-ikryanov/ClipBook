import './App.css';
import {Tabs, TabsContent, TabsList, TabsTrigger} from "@/components/ui/tabs";
import {ResizableHandle, ResizablePanel, ResizablePanelGroup} from "@/components/ui/resizable";
import {ScrollArea, ScrollBar} from "@/components/ui/scroll-area"

function ClipboardItems() {
    return (
        <Tabs defaultValue="tab1" orientation="vertical" className="w-full p-2">
            <ResizablePanelGroup direction="horizontal">
                <ResizablePanel defaultSize={30}>
                    <ScrollArea className="h-full">
                        <TabsList
                            className="grid h-full grid-rows-3 justify-normal">
                            <TabsTrigger value="tab1"
                                         className='justify-normal data-[state=active]:bg-accent font-normal text-base'>Create
                                an API which would allow to access...</TabsTrigger>
                            <TabsTrigger value="tab2"
                                         className='justify-normal data-[state=active]:bg-accent font-normal text-base'>Augments
                                native scroll functionality for custom, cross-browser
                                styling.</TabsTrigger>
                            <TabsTrigger value="tab3"
                                         className='justify-normal data-[state=active]:bg-accent font-normal text-base'>npx
                                shadcn-ui@latest add scroll-area</TabsTrigger>
                        </TabsList>
                    </ScrollArea>
                </ResizablePanel>
                <ResizableHandle/>
                <ResizablePanel defaultSize={70}>
                    <TabsContent value="tab1" className="m-0 p-2">Tab one content</TabsContent>
                    <TabsContent value="tab2" className="m-0 p-2">Tab two content</TabsContent>
                    <TabsContent value="tab3" className="m-0 p-2">Tab three content</TabsContent>
                </ResizablePanel>
            </ResizablePanelGroup>
        </Tabs>
    )
}

export default ClipboardItems;
