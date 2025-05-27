import * as React from "react";
import {useState} from "react";

declare const isUpdateAvailable: () => boolean;

export default function CheckForUpdatesResult() {
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
            <p className="text-sm text-green-600 font-semibold">New version available!</p>
            <p className="text-sm text-secondary-foreground">Restart ClipBook to install the update.</p>
          </div>
        }
      </>
  );
};
