import * as React from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";
import {useEffect, useState} from "react";
import {
  OpenWindowStrategy, prefAllowCheckForUpdates,
  prefGetCheckForUpdatesAutomatically,
  prefGetOpenAtLogin,
  prefGetOpenWindowStrategy,
  prefGetShowIconInMenuBar,
  prefGetTheme,
  prefIsCheckForUpdatesAutomaticallyManaged,
  prefIsOpenAtLoginManaged,
  prefIsPlaySoundOnCopyManaged, prefIsShowIconInMenuBarManaged,
  prefSetCheckForUpdatesAutomatically,
  prefSetOpenAtLogin,
  prefSetOpenWindowStrategy,
  prefSetPlaySoundOnCopy,
  prefSetShowIconInMenuBar,
  prefSetTheme,
  prefShouldPlaySoundOnCopy,
} from "@/pref";
import {
  ChevronsUpDown,
  RefreshCcwIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import {Button} from "@/components/ui/button";
import CheckForUpdatesResult from "@/settings/CheckForUpdatesResult";

declare const closeSettingsWindow: () => void;
declare const checkForUpdates: () => void;

// The map of open strategy enum values to labels.
const openWindowStrategyLabels = {
  [OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION]: "Last location on active screen",
  [OpenWindowStrategy.ACTIVE_SCREEN_CENTER]: "Center of the active screen",
  [OpenWindowStrategy.ACTIVE_WINDOW_CENTER]: "Center of the active window",
  [OpenWindowStrategy.SCREEN_WITH_CURSOR]: "Screen with mouse pointer",
  [OpenWindowStrategy.MOUSE_CURSOR]: "Mouse pointer location",
  [OpenWindowStrategy.INPUT_CURSOR]: "Text caret location",
}

export default function General() {
  const [theme, setTheme] = useState(prefGetTheme())
  const [openAtLogin, setOpenAtLogin] = useState(prefGetOpenAtLogin())
  const [checkForUpdatesAutomatically, setCheckForUpdatesAutomatically] = useState(prefGetCheckForUpdatesAutomatically())
  const [showIconInMenuBar, setShowIconInMenuBar] = useState(prefGetShowIconInMenuBar())
  const [openWindowStrategy, setOpenWindowStrategy] = useState(prefGetOpenWindowStrategy())
  const [playSoundOnCopy, setPlaySoundOnCopy] = useState(prefShouldPlaySoundOnCopy())
  const [checkingForUpdates, setCheckingForUpdates] = useState(false)

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow()
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  function handleThemeChange(theme: string) {
    setTheme(theme)
    prefSetTheme(theme)
  }

  function handleOpenAtLoginChange(openAtLogin: boolean) {
    setOpenAtLogin(openAtLogin)
    prefSetOpenAtLogin(openAtLogin)
  }

  function handleCheckForUpdatesAutomaticallyChange(checkForUpdatesAutomatically: boolean) {
    setCheckForUpdatesAutomatically(checkForUpdatesAutomatically)
    prefSetCheckForUpdatesAutomatically(checkForUpdatesAutomatically)
  }

  function handleShowIconChange(showIcon: boolean) {
    setShowIconInMenuBar(showIcon)
    prefSetShowIconInMenuBar(showIcon)
  }

  function handleOpenWindowStrategyChange(value: string) {
    setOpenWindowStrategy(value as OpenWindowStrategy)
    prefSetOpenWindowStrategy(value as OpenWindowStrategy)
  }

  function handlePlaySoundOnCopyChange(play: boolean) {
    setPlaySoundOnCopy(play)
    prefSetPlaySoundOnCopy(play)
  }

  function handleCheckForUpdates() {
    checkForUpdates()
  }

  function setUpdateCheckInProgress(inProgress: boolean) {
    setCheckingForUpdates(inProgress)
  }

  (window as any).setUpdateCheckInProgress = setUpdateCheckInProgress

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">General</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="openAtLogin" className="flex flex-col text-base">
                <span className="">Launch at login</span>
                <span className="text-neutral-500 font-normal text-sm">
Launch ClipBook automatically at&nbsp;login.
            </span>
              </Label>
              <Switch id="openAtLogin" checked={openAtLogin}
                      onCheckedChange={handleOpenAtLoginChange}
                      disabled={prefIsOpenAtLoginManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="checkForUpdates" className="flex flex-col text-base">
                <span className="">Automatic updates</span>
                <span className="text-neutral-500 font-normal text-sm">
Download and install new updates when&nbsp;available.
            </span>
              </Label>
              <Switch id="checkForUpdates" checked={checkForUpdatesAutomatically}
                      onCheckedChange={handleCheckForUpdatesAutomaticallyChange}
                      disabled={prefIsCheckForUpdatesAutomaticallyManaged()}/>
            </div>

            <div className="flex items-center py-1 space-x-4">
              <Button variant="secondary" size="md" className="px-4"
                      onClick={handleCheckForUpdates} disabled={checkingForUpdates || !prefAllowCheckForUpdates()}>
                {
                  checkingForUpdates ? <RefreshCcwIcon className="animate-spin h-4 w-4 mr-2"/> : null
                }
                {
                  checkingForUpdates ? "Checking for updates..." : "Check for Updates..."
                }
              </Button>
              <CheckForUpdatesResult/>
            </div>

            <hr/>

            <div className="flex justify-between space-x-10 py-1">
              <Label className="flex flex-col text-base">
                <span className="">Appearance</span>
                <span className="text-neutral-500 font-normal text-sm">Change how ClipBook looks on your&nbsp;device.</span>
              </Label>

              <RadioGroup value={theme} onValueChange={handleThemeChange}>
                <div className="flex flex-row gap-x-6">
                  <div className="">
                    <Label htmlFor="r1" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="light" id="r1" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="/assets/theme-light.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Light</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r2" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="dark" id="r2" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="/assets/theme-dark.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">Dark</span>
                      </div>
                    </Label>
                  </div>
                  <div className="">
                    <Label htmlFor="r3" className="[&:has([data-state=checked])>div>img]:outline">
                      <RadioGroupItem value="system" id="r3" className="sr-only"/>
                      <div className="items-center content-center">
                        <img src="/assets/theme-system.svg"
                             className="mx-auto rounded-sm outline-neutral-400 outline-4"
                             alt=""/>
                        <span className="block w-full pt-4 text-center">System</span>
                      </div>
                    </Label>
                  </div>
                </div>
              </RadioGroup>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="showIcon" className="flex flex-col text-base">
                <span className="">Play sound</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Play a sound when an item is added to the&nbsp;history.
                </span>
              </Label>
              <Switch id="showIcon" checked={playSoundOnCopy}
                      onCheckedChange={handlePlaySoundOnCopyChange}
                      disabled={prefIsPlaySoundOnCopyManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="showIcon" className="flex flex-col text-base">
                <span className="">Show icon in menu bar</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Display the ClipBook app icon in the menu&nbsp;bar.
                </span>
                <span
                    className={`${showIconInMenuBar ? "text-neutral-500" : ""} font-normal text-sm`}>
                  You can always open <strong>Settings</strong> by pressing <kbd>⌘</kbd><kbd>,</kbd> inside the ClipBook window.
                </span>
              </Label>
              <Switch id="showIcon" checked={showIconInMenuBar}
                      onCheckedChange={handleShowIconChange}
                      disabled={prefIsShowIconInMenuBarManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-10 py-1">
              <Label htmlFor="openWindowStrategy" className="flex flex-col text-base">
                <span className="">Open window at</span>
                <span className="text-neutral-500 font-normal text-sm">
                  Select where the ClipBook window should be opened if it's possible.
                </span>
              </Label>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="dropdown" className="px-4 outline-none">
                    {openWindowStrategyLabels[openWindowStrategy]}
                    <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50"/>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="p-1.5 bg-actions-background" align="end">
                  <DropdownMenuRadioGroup value={openWindowStrategy}
                                          onValueChange={handleOpenWindowStrategyChange}>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION]}</span>
                        <span className="text-secondary-foreground">
                          ClipBook window remembers its position on each screen and opens at<br/>the last position on the active screen.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.ACTIVE_SCREEN_CENTER}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.ACTIVE_SCREEN_CENTER]}</span>
                        <span className="text-secondary-foreground">
                          Open at the center of the active screen.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.ACTIVE_WINDOW_CENTER}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.ACTIVE_WINDOW_CENTER]}</span>
                        <span className="text-secondary-foreground">
                          Open at the center of the active window. If there is no active window,<br/>then open at the center of the active screen.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.SCREEN_WITH_CURSOR}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.SCREEN_WITH_CURSOR]}</span>
                        <span className="text-secondary-foreground">
                          Open at the center of the screen where the mouse pointer is located.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.MOUSE_CURSOR}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.MOUSE_CURSOR]}</span>
                        <span className="text-secondary-foreground">
                          Open near the mouse pointer location.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.INPUT_CURSOR}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.INPUT_CURSOR]}</span>
                        <span className="text-secondary-foreground">
                          Open near the current text caret location. If the caret location cannot<br/>be determined, then open at the center of the active window.
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                  </DropdownMenuRadioGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>
        </div>
      </div>
  )
}
