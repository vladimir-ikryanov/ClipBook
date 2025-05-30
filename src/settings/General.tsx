import * as React from "react";
import {useEffect, useState} from "react";
import {Label} from "@/components/ui/label";
import {Switch} from "@/components/ui/switch";
import {RadioGroup, RadioGroupItem} from "@/components/ui/radio-group";
import {
  OpenWindowStrategy,
  prefAllowCheckForUpdates,
  prefGetCheckForUpdatesAutomatically,
  prefGetLanguage,
  prefGetOpenAtLogin,
  prefGetOpenWindowStrategy,
  prefGetShowIconInMenuBar,
  prefGetTheme,
  prefIsCheckForUpdatesAutomaticallyManaged,
  prefIsOpenAtLoginManaged,
  prefIsPlaySoundOnCopyManaged,
  prefIsShowIconInMenuBarManaged,
  prefSetCheckForUpdatesAutomatically, prefSetLanguage,
  prefSetOpenAtLogin,
  prefSetOpenWindowStrategy,
  prefSetPlaySoundOnCopy,
  prefSetShowIconInMenuBar,
  prefSetTheme,
  prefShouldPlaySoundOnCopy,
} from "@/pref";
import {ChevronsUpDown, RefreshCcwIcon,} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import {Button} from "@/components/ui/button";
import CheckForUpdatesResult from "@/settings/CheckForUpdatesResult";
import {getLanguageByCode, LanguageCode} from "@/data";
import { useTranslation } from 'react-i18next';
import i18n from "i18next";
import { Trans } from 'react-i18next';
import {emitter} from "@/actions";

declare const closeSettingsWindow: () => void;
declare const checkForUpdates: () => void;

export default function General() {
  const { t } = useTranslation()

  const [languageCode, setLanguageCode] = useState(prefGetLanguage())
  const [theme, setTheme] = useState(prefGetTheme())
  const [openAtLogin, setOpenAtLogin] = useState(prefGetOpenAtLogin())
  const [checkForUpdatesAutomatically, setCheckForUpdatesAutomatically] = useState(prefGetCheckForUpdatesAutomatically())
  const [showIconInMenuBar, setShowIconInMenuBar] = useState(prefGetShowIconInMenuBar())
  const [openWindowStrategy, setOpenWindowStrategy] = useState(prefGetOpenWindowStrategy())
  const [playSoundOnCopy, setPlaySoundOnCopy] = useState(prefShouldPlaySoundOnCopy())
  const [checkingForUpdates, setCheckingForUpdates] = useState(false)

  // The map of open strategy enum values to labels.
  const openWindowStrategyLabels = {
    [OpenWindowStrategy.ACTIVE_SCREEN_LAST_POSITION]: t('settings.general.openWindow.strategies.lastLocation'),
    [OpenWindowStrategy.ACTIVE_SCREEN_CENTER]: t('settings.general.openWindow.strategies.activeScreenCenter'),
    [OpenWindowStrategy.ACTIVE_WINDOW_CENTER]: t('settings.general.openWindow.strategies.activeWindowCenter'),
    [OpenWindowStrategy.SCREEN_WITH_CURSOR]: t('settings.general.openWindow.strategies.screenWithCursor'),
    [OpenWindowStrategy.MOUSE_CURSOR]: t('settings.general.openWindow.strategies.mouseCursor'),
    [OpenWindowStrategy.INPUT_CURSOR]: t('settings.general.openWindow.strategies.inputCursor'),
  }

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

  function handleLanguageCodeChange(languageCode: string) {
    setLanguageCode(languageCode as LanguageCode)
    prefSetLanguage(languageCode as LanguageCode)
    i18n.changeLanguage(languageCode)
  }

  (window as any).setUpdateCheckInProgress = setUpdateCheckInProgress

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">{t('settings.general.title')}</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <div className="flex items-center justify-between space-x-20 pt-6 pb-1">
              <Label htmlFor="openAtLogin" className="flex flex-col text-base">
                <span className="">{t('settings.general.launchAtLogin.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.launchAtLogin.description')}
                </span>
              </Label>
              <Switch id="openAtLogin" checked={openAtLogin}
                      onCheckedChange={handleOpenAtLoginChange}
                      disabled={prefIsOpenAtLoginManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="checkForUpdates" className="flex flex-col text-base">
                <span className="">{t('settings.general.automaticUpdates.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.automaticUpdates.description')}
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
                  checkingForUpdates ? t('settings.general.automaticUpdates.checkingForUpdates') : t('settings.general.automaticUpdates.checkForUpdates')
                }
              </Button>
              <CheckForUpdatesResult/>
            </div>

            <hr/>

            <div className="flex justify-between space-x-10 py-1">
              <Label className="flex flex-col text-base">
                <span className="">{t('settings.general.appearance.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.appearance.description')}
                </span>
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
                        <span className="block w-full pt-4 text-center">
                          {t('settings.general.appearance.themes.light')}
                        </span>
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
                        <span className="block w-full pt-4 text-center">
                          {t('settings.general.appearance.themes.dark')}
                        </span>
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
                        <span className="block w-full pt-4 text-center">
                          {t('settings.general.appearance.themes.system')}
                        </span>
                      </div>
                    </Label>
                  </div>
                </div>
              </RadioGroup>
            </div>

            <div className="flex items-center justify-between space-x-10 py-1">
              <Label htmlFor="openWindowStrategy" className="flex flex-col text-base">
                <span className="">{t('settings.general.language.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.language.description')}
                </span>
              </Label>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="dropdown" className="px-4 outline-none">
                    {getLanguageByCode(languageCode)?.nativeName}
                    <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50"/>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="p-1.5 bg-actions-background" align="end">
                  <DropdownMenuRadioGroup value={languageCode}
                                          onValueChange={handleLanguageCodeChange}>
                    <DropdownMenuRadioItem value={LanguageCode.EN_US} className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{getLanguageByCode(LanguageCode.EN_US)?.nativeName}</span>
                        <span className="text-secondary-foreground">{getLanguageByCode(LanguageCode.EN_US)?.name}</span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={LanguageCode.EN_GB} className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{getLanguageByCode(LanguageCode.EN_GB)?.nativeName}</span>
                        <span className="text-secondary-foreground">{getLanguageByCode(LanguageCode.EN_GB)?.name}</span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={LanguageCode.DE} className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{getLanguageByCode(LanguageCode.DE)?.nativeName}</span>
                        <span className="text-secondary-foreground">{getLanguageByCode(LanguageCode.DE)?.name}</span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={LanguageCode.IT} className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{getLanguageByCode(LanguageCode.IT)?.nativeName}</span>
                        <span className="text-secondary-foreground">{getLanguageByCode(LanguageCode.IT)?.name}</span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={LanguageCode.PT_BR} className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{getLanguageByCode(LanguageCode.PT_BR)?.nativeName}</span>
                        <span className="text-secondary-foreground">{getLanguageByCode(LanguageCode.PT_BR)?.name}</span>
                      </div>
                    </DropdownMenuRadioItem>
                  </DropdownMenuRadioGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="showIcon" className="flex flex-col text-base">
                <span className="">{t('settings.general.playSound.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.playSound.description')}
                </span>
              </Label>
              <Switch id="showIcon" checked={playSoundOnCopy}
                      onCheckedChange={handlePlaySoundOnCopyChange}
                      disabled={prefIsPlaySoundOnCopyManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label htmlFor="showIcon" className="flex flex-col text-base">
                <span className="">{t('settings.general.showIcon.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.showIcon.description')}
                </span>
                <span
                  className={`${showIconInMenuBar ? "text-neutral-500" : ""} font-normal text-sm`}>
                  <Trans
                    i18nKey="settings.general.showIcon.hint"
                    components={{
                      strong: <strong />,
                      kbd: <kbd />
                    }}
                  />
                </span>
              </Label>
              <Switch id="showIcon" checked={showIconInMenuBar}
                      onCheckedChange={handleShowIconChange}
                      disabled={prefIsShowIconInMenuBarManaged()}/>
            </div>

            <div className="flex items-center justify-between space-x-10 py-1">
              <Label htmlFor="openWindowStrategy" className="flex flex-col text-base">
                <span className="">{t('settings.general.openWindow.title')}</span>
                <span className="text-neutral-500 font-normal text-sm">
                  {t('settings.general.openWindow.description')}
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
                          <Trans
                            i18nKey="settings.general.openWindow.descriptions.lastLocation"
                            components={{
                              br: <br />
                            }}
                          />
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.ACTIVE_SCREEN_CENTER}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.ACTIVE_SCREEN_CENTER]}</span>
                        <span className="text-secondary-foreground">
                          {t('settings.general.openWindow.descriptions.activeScreenCenter')}
                        </span>
                      </div>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value={OpenWindowStrategy.ACTIVE_WINDOW_CENTER}
                                           className="py-2 pr-4 pl-10">
                      <div className="flex flex-col">
                        <span>{openWindowStrategyLabels[OpenWindowStrategy.ACTIVE_WINDOW_CENTER]}</span>
                        <span className="text-secondary-foreground">
                          <Trans
                            i18nKey="settings.general.openWindow.descriptions.activeWindowCenter"
                            components={{
                              br: <br />
                            }}
                          />
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
                          <Trans
                            i18nKey="settings.general.openWindow.descriptions.inputCursor"
                            components={{
                              br: <br />
                            }}
                          />
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
