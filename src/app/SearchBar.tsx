import '../app.css';
import {Input} from "@/components/ui/input"
import React from "react";
import {SearchIcon, XIcon} from "lucide-react";
import {Button} from "@/components/ui/button";
import {prefGetTogglePreviewShortcut} from "@/pref";
import {ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import Actions, {HideActionsReason} from "@/app/Actions";

declare const openSettingsLicense: () => void;

type SearchBarProps = {
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
  isPreviewVisible: boolean
  isTrial: boolean
  trialDaysLeft: number
  onShowHidePreview: () => void
  searchFieldRef?: React.Ref<HTMLInputElement>
  appName: string
  appIcon: string
  onPaste: () => void
  onPasteWithTab: () => void
  onPasteWithReturn: () => void
  onMerge: () => void
  onClose: () => void
  onHideActions: (reason: HideActionsReason) => void
  onToggleFavorite: () => void
  onTogglePreview: () => void
  onEditContent: () => void
  onRenameItem: () => void
  onCopyToClipboard: () => void
  onCopyTextFromImage: () => void
  onSaveImageAsFile: () => void
  onOpenInBrowser: () => void
  onPreviewLink: () => void
  onOpenSettings: () => void
  onDeleteItem: () => void
  onDeleteItems: () => void
  onDeleteAllItems: () => void
}

export default function SearchBar(props: SearchBarProps) {
  const handleOnChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    props.onSearchQueryChange(e.target.value)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" && props.searchQuery.length > 0) {
      handleClearSearch()
      e.stopPropagation()
    }
    if (e.code === "ArrowUp" || e.code === "ArrowDown") {
      e.preventDefault()
    }
    // Prevent clearing search query with cmd + backspace (default macOS hotkey).
    if (e.code === "Backspace" && e.metaKey) {
      e.preventDefault()
    }
  }

  const handleShowHidePreview = () => {
    props.onShowHidePreview()
  }

  function handleClearSearch() {
    props.onSearchQueryChange("")
  }

  function handleClickTrial() {
    openSettingsLicense()
  }

  function getTrialBadgeText() {
    if (props.trialDaysLeft <= 0) {
      return "Trial ended"
    }
    if (props.trialDaysLeft == 1) {
      return "Trial ends tomorrow"
    }
    return "Trial " + (props.trialDaysLeft > 0 ? `(${props.trialDaysLeft} ${props.trialDaysLeft > 1 ? "days" : "day"} left)` : " expired")
  }

  function getTrialBadgeBgColor() {
    if (props.trialDaysLeft <= 0) {
      return "bg-red-700 text-neutral-300"
    }
    if (props.trialDaysLeft == 1) {
      return "bg-orange-700 text-neutral-300"
    }
    if (props.trialDaysLeft == 2) {
      return "bg-green-700 text-neutral-300"
    }
    return "bg-accent"
  }

  function getTrialBadgeAnimation() {
    if (props.trialDaysLeft >= 1 && props.trialDaysLeft <= 2) {
      return "animate-pulse"
    }
    return ""
  }

  function renderTrialBadge() {
    return (
        <Button variant="toolbar"
                size="toolbar"
                onClick={handleClickTrial}
                className={getTrialBadgeAnimation()}>
          <span className={`rounded-sm ${getTrialBadgeBgColor()} py-1 px-2.5`}>
            {getTrialBadgeText()}
          </span>
        </Button>
    )
  }

  return (
      <div className="flex flex-col border-b-solid border-b-border border-b">
        <div className="flex m-2">
          <div
              className={props.searchQuery.length == 0 ? "flex-none relative" : "flex-auto relative"}>
            <div className="flex text-primary-foreground">
              <SearchIcon className="absolute left-2 top-2.5 h-5 w-5 text-secondary-foreground"/>
            </div>
            <Input placeholder="Type to search..."
                   value={props.searchQuery}
                   className="w-full h-10 pl-10 text-lg placeholder:text-secondary-foreground border-none"
                   onChange={handleOnChange}
                   onKeyDown={handleKeyDown}
                   ref={props.searchFieldRef}/>
          </div>
          <div
              className={props.searchQuery.length == 0 ? "flex-auto draggable" : "flex-none"}></div>
          <div className={props.isTrial ? "" : "hidden"}>
            <Tooltip>
              <TooltipTrigger asChild>{renderTrialBadge()}
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2">
                  {
                    props.trialDaysLeft > 0 ? `Trial will expire in ${props.trialDaysLeft} ${props.trialDaysLeft > 1 ? "days" : "day"}` : "Trial expired"
                  }
                </div>
              </TooltipContent>
            </Tooltip>
          </div>
          <div className={props.searchQuery.length == 0 ? "hidden" : ""}>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleClearSearch}>
                  <XIcon className="h-5 w-5"/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2">Clear search</div>
                <ShortcutLabel shortcut="Escape"/>
              </TooltipContent>
            </Tooltip>
          </div>
          <div>
            <Actions appName={props.appName}
                     appIcon={props.appIcon}
                     onHideActions={props.onHideActions}
                     onEditContent={props.onEditContent}
                     onRenameItem={props.onRenameItem}
                     onCopyToClipboard={props.onCopyToClipboard}
                     onCopyTextFromImage={props.onCopyTextFromImage}
                     onSaveImageAsFile={props.onSaveImageAsFile}
                     onOpenInBrowser={props.onOpenInBrowser}
                     onPreviewLink={props.onPreviewLink}
                     onOpenSettings={props.onOpenSettings}
                     onPaste={props.onPaste}
                     onPasteWithTab={props.onPasteWithTab}
                     onPasteWithReturn={props.onPasteWithReturn}
                     onMerge={props.onMerge}
                     onToggleFavorite={props.onToggleFavorite}
                     onTogglePreview={props.onTogglePreview}
                     onDeleteItem={props.onDeleteItem}
                     onDeleteItems={props.onDeleteItems}
                     onDeleteAllItems={props.onDeleteAllItems}/>
          </div>
          <div className={props.isPreviewVisible ? "hidden" : ""}>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleShowHidePreview}>
                  <ShowPreviewPaneIcon className="h-5 w-5"/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2">Show preview panel</div>
                <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>
  )
}
