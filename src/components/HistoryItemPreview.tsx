import '../App.css';
import { TabsContent } from "@/components/ui/tabs";

type HistoryItemPreviewProps = {
    index: number
    text: string
}

export default function HistoryItemPreview({ index, text }: HistoryItemPreviewProps) {
    return (
        <TabsContent value={index.toString()} className="m-0">
            <div className="flex flex-col h-screen m-0 p-0 ml-5 mr-5">
                <div className="mt-4">{text}</div>
                <div className="grow"></div>
                <div className="mb-5 text-gray-400">
                    <p>Press <code>Enter</code> to paste in front application</p>
                    <p>Press <code>Shift+Enter</code> to paste as plain text in front application</p>
                    <p>Press <code>Delete</code> to remove from history</p>
                </div>
            </div>
        </TabsContent>
    )
}
