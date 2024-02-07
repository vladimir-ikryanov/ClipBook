let historyItems: Set<string> = new Set();

// Add elements to the Set
historyItems.add("Create an API which would allow to access some data in table");
historyItems.add("npx shadcn-ui@latest add scroll-area");
historyItems.add("export default function ClipboardItems()");

export function getHistoryItems() {
    return Array.from(historyItems)
}

export function addHistoryItem(item: string) {
    if (historyItems.has(item)) {
        historyItems.delete(item)
    }
    historyItems.add(item)
    return getHistoryItems()
}
