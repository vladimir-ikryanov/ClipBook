import '../app.css';
import {Input} from "@/components/ui/input"
import React, {useEffect, useState} from "react";
import {ListFilterIcon, PinIcon, XIcon} from "lucide-react";
import {Button} from "@/components/ui/button";
import {
  prefGetToggleFilterShortcut,
  prefGetTogglePreviewShortcut,
  prefSetAlwaysDisplay,
  prefShouldAlwaysDisplay
} from "@/pref";
import {ShowPreviewPaneIcon} from "@/app/Icons";
import {Tooltip, TooltipContent, TooltipTrigger} from "@/components/ui/tooltip";
import ShortcutLabel from "@/app/ShortcutLabel";
import Commands from "@/app/Commands";
import PasteTransformationCommands from "@/app/PasteTransformationCommands";
import {isFilterActive} from "@/data";
import FormatTextCommands from "@/app/FormatTextCommands";
import OpenWithCommands from "@/app/OpenWithCommands";
import {emitter} from "@/actions";

declare const openSettingsLicense: () => void;

type SearchBarProps = {
  searchQuery: string
  onSearchQueryChange: (searchQuery: string) => void
  isPreviewVisible: boolean
  isFilterVisible: boolean
  isTrial: boolean
  trialDaysLeft: number
  searchFieldRef?: React.Ref<HTMLInputElement>
  appName: string
  appIcon: string
}

export default function SearchBar(props: SearchBarProps) {
  const [alwaysDisplay, setAlwaysDisplay] = useState(prefShouldAlwaysDisplay())
  const [filterActive, setFilterActive] = useState(isFilterActive())

  useEffect(() => {
    function handleFilterHistoryEvent() {
      setFilterActive(isFilterActive())
    }

    emitter.on("FilterHistory", handleFilterHistoryEvent)
    return () => emitter.off("FilterHistory", handleFilterHistoryEvent);
  }, []);

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
    emitter.emit("TogglePreview")
  }

  function handleToggleFilter() {
    emitter.emit("ToggleFilter")
  }

  function handleClearSearch() {
    props.onSearchQueryChange("")
  }

  function handleClickTrial() {
    openSettingsLicense()
  }

  function handleAlwaysDisplayChange() {
    let display = !alwaysDisplay;
    setAlwaysDisplay(display)
    prefSetAlwaysDisplay(display)
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
              className={props.searchQuery.length == 0 ? "flex" : "flex-auto"}>
            <div className="flex text-primary-foreground">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button className="absolute" variant="toolbar" size="toolbar"
                          onClick={handleToggleFilter}>
                    <ListFilterIcon className={`h-5 w-5 ${filterActive ?
                        "text-toolbar-buttonSelected" :
                        (props.isFilterVisible ? "text-toolbar-buttonActive" : "")}`}/>
                  </Button>
                </TooltipTrigger>
                <TooltipContent className="flex items-center">
                  <div
                      className="select-none mr-2 ml-1">{props.isFilterVisible ? "Hide filter options" : "Show filter options"}</div>
                  <ShortcutLabel shortcut={prefGetToggleFilterShortcut()}/>
                </TooltipContent>
              </Tooltip>
            </div>
            <Input placeholder="Type to search..."
                   value={props.searchQuery}
                   className={`${props.searchQuery.length > 0 ? "w-full" : "w-48"} h-10 pl-10 text-lg placeholder:text-secondary-foreground border-none`}
                   onChange={handleOnChange}
                   onKeyDown={handleKeyDown}
                   ref={props.searchFieldRef}/>
          </div>
          <div
              className={props.searchQuery.length == 0 ? "flex-grow draggable" : "flex-none"}></div>
          <div className={props.isTrial ? "" : "hidden"}>
            <Tooltip>
              <TooltipTrigger asChild>{renderTrialBadge()}
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2 ml-1">
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
                <div className="select-none mr-2 ml-1">Clear search</div>
                <ShortcutLabel shortcut="Escape"/>
              </TooltipContent>
            </Tooltip>
          </div>
          <div>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleAlwaysDisplayChange}>
                  <PinIcon
                      className={`h-5 w-5 rotate-45 ${alwaysDisplay ? "text-toolbar-buttonSelected" : ""}`}
                      strokeWidth={2}/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center px-2.5">
                <div className="select-none">
                  {alwaysDisplay ? "Hide when not focused" : "Always display"}
                </div>
              </TooltipContent>
            </Tooltip>
          </div>
          <div>
            <Commands appName={props.appName} appIcon={props.appIcon}/>
            <PasteTransformationCommands/>
            <FormatTextCommands/>
            <OpenWithCommands/>
          </div>
          <div className={props.isPreviewVisible ? "hidden" : ""}>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="toolbar" size="toolbar" onClick={handleShowHidePreview}>
                  <ShowPreviewPaneIcon className="h-5 w-5"/>
                </Button>
              </TooltipTrigger>
              <TooltipContent className="flex items-center">
                <div className="select-none mr-2 ml-1">Show preview</div>
                <ShortcutLabel shortcut={prefGetTogglePreviewShortcut()}/>
              </TooltipContent>
            </Tooltip>
          </div>
        </div>
      </div>
  )
}
