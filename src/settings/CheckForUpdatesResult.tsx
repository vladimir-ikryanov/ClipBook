import * as React from "react";
import {useState} from "react";
import { Trans, useTranslation } from 'react-i18next';

declare const isUpdateAvailable: () => boolean;

export default function CheckForUpdatesResult() {
  const { t } = useTranslation();
  
  const [updateAvailable, setUpdateAvailable] = useState(isUpdateAvailable)

  function handleUpdateAvailable() {
    setUpdateAvailable(true)
  }

  (window as any).updateAvailable = handleUpdateAvailable;

  return (
      <>
        {
          updateAvailable &&
          <div>
            <p className="text-sm text-green-600 font-semibold">{t('settings.about.checkForUpdatesResult.newVersionAvailable')}</p>
            <p className="text-sm text-secondary-foreground">{t('settings.about.checkForUpdatesResult.restartClipBookToInstallUpdate')}</p>
          </div>
        }
      </>
  );
};
