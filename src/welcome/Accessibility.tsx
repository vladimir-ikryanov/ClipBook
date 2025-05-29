import * as React from "react";
import {Button} from "@/components/ui/button";
import { useTranslation } from 'react-i18next';

declare const enableAccessibilityAccess: () => void;
declare const openUrl: (url: string) => void;

export default function Accessibility() {
  const { t } = useTranslation();

  function enableAccess(): void {
    enableAccessibilityAccess()
  }

  function handleReadMore(): void {
    openUrl("https://clipbook.app/blog/paste-to-other-applications/?utm_source=app")
  }

  return (
      <div className="flex h-screen bg-background">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/logo_256x256@2x.png" className="h-24 w-24 mx-auto text-secondary-foreground"
               alt=""/>
          <p className="text-center pt-4 text-2xl font-bold text-foreground">
            {t('accessibility.title')}
          </p>
          <p className="text-center pt-2 mx-20">
            {t('accessibility.description', {
              features: <a href="#" onClick={handleReadMore} className="text-settings-primary-button underline">{t('accessibility.readMore')}</a>
            })}
          </p>
          <img src="assets/enable-accessibility.png" alt="" className="mx-20 my-10 rounded-xl"/>
          <div className="items-center">
            <Button
                className="bg-settings-secondary-button text-settings-secondary-button-text p-5 hover:bg-settings-secondary-button-hover m-2"
                onClick={() => window.location.href = "/enjoy"}>{t('accessibility.doLater')}</Button>
            <Button onClick={enableAccess}
                    className="bg-settings-primary-button text-white p-5 hover:bg-settings-primary-button-hover m-2">
              {t('accessibility.allowAccess')}
            </Button>
          </div>
        </div>
      </div>
  )
}
