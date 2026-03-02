import '../app.css';
import { shortcutToDisplayShortcut } from "@/lib/shortcuts";

type QuickPasteLabelProps = {
  index: number
}

export default function QuickPasteLabel(props: QuickPasteLabelProps) {
  return (
    <div className="flex text-sm text-quick-paste-label space-x-0.5">
      <span>⌘</span>
      <span className="tabular-nums">{props.index}</span>
    </div>
  )
}
