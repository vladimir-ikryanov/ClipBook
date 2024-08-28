import React, {useState, useEffect, useRef} from 'react';
import {Button} from "@/components/ui/button";
import {MinusIcon, PlusIcon} from "lucide-react";
import {toBase64Icon} from "@/data";

interface IgnoreAppsPaneProps {
  apps: string[];
  onSelectApps: () => void;
  onRemoveApps: (apps: string[]) => void;
}

declare const getAppNameFromPath: (appPath: string) => string;
declare const getAppIconAsBase64: (appPath: string) => string;

export default function IgnoreAppsPane(props: IgnoreAppsPaneProps) {
  const [selectedIndices, setSelectedIndices] = useState<number[]>([]);
  const [lastSelectedIndex, setLastSelectedIndex] = useState<number | null>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (lastSelectedIndex === null) {
      return;
    }
    let newIndex: number | null = null;
    if (e.key === 'ArrowDown') {
      newIndex =
          lastSelectedIndex < props.apps.length - 1 ? lastSelectedIndex + 1 : lastSelectedIndex;
    } else if (e.key === 'ArrowUp') {
      newIndex = lastSelectedIndex > 0 ? lastSelectedIndex - 1 : lastSelectedIndex;
    }

    if (newIndex !== null) {
      e.preventDefault();
      if (e.shiftKey) {
        handleShiftSelection(newIndex);
      } else {
        setSelectedIndices([newIndex]);
      }
      setLastSelectedIndex(newIndex);
    }
  };

  const handleItemClick = (index: number, e: React.MouseEvent<HTMLDivElement>) => {
    if (e.shiftKey && lastSelectedIndex !== null) {
      handleShiftSelection(index);
    } else if (e.ctrlKey || e.metaKey) {
      handleCtrlSelection(index);
    } else {
      setSelectedIndices([index]);
    }
    setLastSelectedIndex(index);
  };

  const handleShiftSelection = (newIndex: number) => {
    if (lastSelectedIndex === null) {
      return;
    }

    const rangeStart = Math.min(lastSelectedIndex, newIndex);
    const rangeEnd = Math.max(lastSelectedIndex, newIndex);

    const newSelectedIndices = Array.from(
        new Set([
          ...selectedIndices,
          ...Array(rangeEnd - rangeStart + 1)
              .fill(null)
              .map((_, i) => rangeStart + i),
        ])
    );

    setSelectedIndices(newSelectedIndices);
  };

  const handleCtrlSelection = (index: number) => {
    if (selectedIndices.includes(index)) {
      setSelectedIndices(selectedIndices.filter((i) => i !== index));
    } else {
      setSelectedIndices([...selectedIndices, index]);
    }
  };

  useEffect(() => {
    if (props.apps.length > 0 && lastSelectedIndex !== null && listRef.current) {
      const selectedElement = listRef.current.children[lastSelectedIndex] as HTMLElement;
      selectedElement.scrollIntoView({block: 'nearest'});
    }
  }, [lastSelectedIndex]);

  function handleRemoveApps(): void {
    props.onRemoveApps(selectedIndices.map((i) => props.apps[i]))
    setSelectedIndices([])
    setLastSelectedIndex(null)
  }

  function handleAddApps(): void {
    props.onSelectApps();
  }

  function getAppIcon(appPath: string): string {
    return toBase64Icon(getAppIconAsBase64(appPath))
  }

  function getAppName(appPath: string): string {
    return getAppNameFromPath(appPath)
  }

  return (
      <div>
        <div
            ref={listRef}
            tabIndex={0}
            onKeyDown={handleKeyDown}
            className="flex flex-col mt-2 border border-settings-border rounded-md overflow-auto focus:outline-none"
        >
          {props.apps.length === 0 && (
              <div className="p-4 bg-secondary text-secondary-foreground text-center">No applications</div>
          )}
          {props.apps.map((item, index) => (
              <div
                  key={index}
                  className={`flex flex-row p-2 items-center ${
                      selectedIndices.includes(index) ? 'bg-settings-selection text-white' : index % 2 === 0 ? 'bg-settings-tableRow' : 'bg-settings-tableRow2'
                  }`}
                  onClick={(e) => handleItemClick(index, e)}
                  title={item}
              >
                <img src={getAppIcon(item)} className="h-8 w-8 mr-2" alt="Application icon"/>
                {getAppName(item)}
              </div>
          ))}
          <div className="flex flex-row bg-secondary border-t border-t-settings-border">
            <Button variant="tool" size="tool" onClick={handleAddApps}>
              <PlusIcon className="h-4 w-4"></PlusIcon>
            </Button>
            <div className="border-l border-l-settings-border my-1.5"></div>
            <Button variant="tool" size="tool" disabled={selectedIndices.length == 0}
                    onClick={handleRemoveApps}>
              <MinusIcon className="h-4 w-4"></MinusIcon>
            </Button>
          </div>
        </div>
      </div>
  );
};
