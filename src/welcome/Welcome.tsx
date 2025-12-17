import * as React from "react";
import {Button} from "@/components/ui/button";
import {useTranslation} from 'react-i18next';
import {Label} from "@/components/ui/label";
import {
  DropdownMenu,
  DropdownMenuContent, DropdownMenuRadioGroup, DropdownMenuRadioItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import {getLanguageByCode, LanguageCode} from "@/data";
import {ChevronsUpDown} from "lucide-react";
import {useState} from "react";
import {prefGetLanguage, prefSetLanguage} from "@/pref";

export default function Welcome() {
  const {t} = useTranslation()

  const [languageCode, setLanguageCode] = useState(prefGetLanguage())

  function handleLanguageCodeChange(languageCode: string) {
    setLanguageCode(languageCode as LanguageCode)
    prefSetLanguage(languageCode as LanguageCode)
  }

  return (
      <div className="flex h-screen bg-background">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo_256x256@2x.png"
               className="h-36 w-36 mt-20 mx-auto text-secondary-foreground" alt=""/>
          <p className="text-center pt-8 text-3xl font-bold text-foreground">
            {t('welcome.title')}
          </p>
          <p className="text-center pt-2 mx-16">
            {t('welcome.description')}
          </p>

          <div className="flex flex-col items-center pt-8 pb-4 space-y-4">
            <span className="font-normal">
                {t('welcome.selectLanguage')}
            </span>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" size="dropdown" className="px-10 outline-none">
                  {getLanguageByCode(languageCode)?.nativeName}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50"/>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent className="p-1.5 bg-actions-background" align="center">
                <DropdownMenuRadioGroup value={languageCode}
                                        onValueChange={handleLanguageCodeChange}>
                  <DropdownMenuRadioItem value={LanguageCode.EN_US} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.EN_US)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.EN_GB} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.EN_GB)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.DE} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.DE)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.IT} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.IT)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.ES} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.ES)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.PT_BR} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.PT_BR)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.JA} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.JA)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                  <DropdownMenuRadioItem value={LanguageCode.ZH_CN} className="py-2 pr-4 pl-10">
                    <div className="flex">
                      <span>{getLanguageByCode(LanguageCode.ZH_CN)?.nativeName}</span>
                    </div>
                  </DropdownMenuRadioItem>
                </DropdownMenuRadioGroup>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>

          <div className="items-center pt-4">
            <Button onClick={() => window.location.href = "/accessibility"}
                    className="bg-settings-primary-button text-white p-5 hover:bg-settings-primary-button-hover m-2">
              {t('welcome.getStarted')}
            </Button>
          </div>
        </div>
      </div>
  )
}
