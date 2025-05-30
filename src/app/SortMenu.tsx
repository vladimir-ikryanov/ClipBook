import '../app.css';
import React, {KeyboardEvent, useState} from "react";
import {Button} from "@/components/ui/button";
import {ArrowDownUpIcon, ArrowUpDownIcon,} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  getSortType,
  isSortOrderReverse,
  saveSortOrderReverse,
  saveSortType,
  SortHistoryType
} from "@/data";
import {emitter} from "@/actions";
import {useTranslation} from "react-i18next";

export default function SortMenu() {
  const {t} = useTranslation()
  
  const [menuOpen, setMenuOpen] = useState(false)
  const [sortType, setSortType] = useState(getSortType())
  const [sortOrderReverse, setSortOrderReverse] = useState(isSortOrderReverse())

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "ArrowUp" || e.key === "ArrowDown" || e.key === "Enter" || e.key === "Escape") {
      e.stopPropagation()
    }
  }

  function handleMenuOpenChange(open: boolean) {
    setMenuOpen(open)
  }

  function handleSortTypeChange(type: SortHistoryType) {
    if (type != sortType) {
      setSortType(type)
      saveSortType(type)
      emitter.emit("SortHistory")
    }
  }

  function handleSortOrderReverseChange() {
    let value = !sortOrderReverse
    setSortOrderReverse(value)
    saveSortOrderReverse(value)
    emitter.emit("SortHistory")
  }

  return (
      <DropdownMenu open={menuOpen} onOpenChange={handleMenuOpenChange}>
        <DropdownMenuTrigger asChild>
          <Button variant="dropdown" size="toolbar" className={menuOpen ? "bg-accent" : ""}>
            {
              sortOrderReverse ? <ArrowUpDownIcon className="h-5 w-5"/> : <ArrowDownUpIcon className="h-5 w-5"/>
            }
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent className="p-1.5 bg-actions-background" align="start"
                             onKeyDown={handleKeyDown}>
          <DropdownMenuCheckboxItem checked={sortType === SortHistoryType.TimeOfLastCopy} onCheckedChange={() => handleSortTypeChange(SortHistoryType.TimeOfLastCopy)}>
            {t('sortMenu.lastCopyTime')}
          </DropdownMenuCheckboxItem>
          <DropdownMenuCheckboxItem checked={sortType === SortHistoryType.TimeOfFirstCopy} onCheckedChange={() => handleSortTypeChange(SortHistoryType.TimeOfFirstCopy)}>
            {t('sortMenu.firstCopyTime')}
          </DropdownMenuCheckboxItem>
          <DropdownMenuCheckboxItem checked={sortType === SortHistoryType.NumberOfCopies} onCheckedChange={() => handleSortTypeChange(SortHistoryType.NumberOfCopies)}>
            {t('sortMenu.numberOfCopies')}
          </DropdownMenuCheckboxItem>
          <DropdownMenuCheckboxItem checked={sortType === SortHistoryType.Size} onCheckedChange={() => handleSortTypeChange(SortHistoryType.Size)}>
            {t('sortMenu.size')}
          </DropdownMenuCheckboxItem>
          <DropdownMenuSeparator/>
          <DropdownMenuCheckboxItem checked={sortOrderReverse} onCheckedChange={handleSortOrderReverseChange}>
            {t('sortMenu.reverseOrder')}
          </DropdownMenuCheckboxItem>
        </DropdownMenuContent>
      </DropdownMenu>
  )
}
