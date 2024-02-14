import '../App.css';
import {TabsTrigger} from "@/components/ui/tabs";
import {Link, File} from "lucide-react";
import React, {KeyboardEvent, MouseEvent} from 'react';
import {deleteHistoryItem} from "@/data"

type HistoryItemProps = {
    index: number
    text: string
    onUpdateHistory: () => void
}

declare const pasteInFrontApp: (text: string) => void;

export default function HistoryItem({index, text, onUpdateHistory}: HistoryItemProps) {
    const keyDown = (e: KeyboardEvent) => {
        if (e.key === "Enter") {
            e.preventDefault()
            pasteInFrontApp(text)
        }
        if (e.key === "Delete" || (e.key === "Backspace" && e.metaKey)) {
            e.preventDefault()
            deleteHistoryItem(text)
            onUpdateHistory()
        }
    }
  
    const doubleClick = (e: MouseEvent) => {
        e.preventDefault()
        pasteInFrontApp(text)
    }

    function isUrl(url: string) {
        const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i;
        return urlRegex.test(url);
    }

    return (
        <TabsTrigger
            autoFocus={index === 0}
            value={index.toString()}
            className="flex flex-row data-[state=active]:bg-accent pt-2 pb-2 pl-3 pr-3 whitespace-nowrap overflow-hidden overflow-ellipsis"
            onKeyDown={keyDown}
            onDoubleClick={doubleClick}>
            <div className="flex mr-3">
                {
                    isUrl(text) ?
                        <Link className="h-4 w-4"/> :
                        <File className="h-4 w-4"/>
                }
            </div>
            <div
                className="flex-grow text-base text-justify font-normal whitespace-nowrap overflow-hidden overflow-ellipsis">{text}</div>
        </TabsTrigger>
    )
}
