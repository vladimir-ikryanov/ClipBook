import * as React from "react";
import {Button} from "@/components/ui/button";
import { Trans, useTranslation } from 'react-i18next';

declare const openHistory: () => void;

export default function Enjoy() {
  const { t } = useTranslation();

  function openClipBook(): void {
    openHistory()
  }

  return (
      <div className="flex h-screen bg-background">
        <div className="flex flex-col text-center mx-auto">
          <div className="flex p-10 justify-center draggable"></div>
          <img src="assets/success.svg" className="h-24 w-24 mx-auto text-secondary-foreground"
               alt=""/>
          <p className="text-center pt-4 text-2xl font-bold text-foreground">
            {t('enjoy.ready')}
          </p>
          <p className="text-center pt-2 mx-20">
            <Trans i18nKey="enjoy.description" components={{strong: <strong/>}} />
          </p>
          <img src="assets/tray.png" alt="" className="mx-20 my-10 rounded-xl"/>
          <div className="items-center">
            <Button onClick={openClipBook}
                    className="bg-settings-primary-button text-white p-5 hover:bg-settings-primary-button-hover m-2">
              {t('enjoy.openClipBook')}
            </Button>
          </div>
        </div>
      </div>
  )
}
