export const historyItems = [
    "Create an API which would allow to access some data in table",
    "npx shadcn-ui@latest add scroll-area",
    "export default function ClipboardItems()",
    "import '../App.css';"
];

export function getHistoryItems() {
    return historyItems
}

export function addHistoryItem(item: string) {
    historyItems.push(item)
    return historyItems
}
