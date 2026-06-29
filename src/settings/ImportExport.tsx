import * as React from "react";
import {useEffect, useState} from "react";
import {Label} from "@/components/ui/label";
import {Button} from "@/components/ui/button";
import {exportHistoryArchive, importHistoryArchive} from "@/archive";
import {useTranslation} from "react-i18next";

declare const closeSettingsWindow: () => void;

export default function ImportExport() {
  const {t} = useTranslation();
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow();
        e.preventDefault();
      }
    };

    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  async function handleExport() {
    setBusy(true);
    setStatus("");
    try {
      const fileName = await exportHistoryArchive();
      if (fileName) {
        setStatus(t("settings.importExport.exportSuccess", {fileName}));
      }
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  }

  async function handleImport() {
    setBusy(true);
    setStatus("");
    try {
      const result = await importHistoryArchive();
      if (result) {
        setStatus(t("settings.importExport.importSuccess", {
          itemCount: result.itemCount,
          tagCount: result.tagCount,
        }));
      }
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  }

  return (
      <div className="flex h-screen select-none">
        <div className="flex flex-col flex-grow">
          <div className="flex pt-8 px-8 border-b border-b-border draggable sticky">
            <span className="text-2xl pb-3 font-semibold">{t("settings.importExport.title")}</span>
          </div>

          <div className="flex flex-col px-8 pb-6 gap-4 flex-grow overflow-y-auto scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent">
            <p className="text-neutral-500 font-normal text-sm pt-6">
              {t("settings.importExport.description")}
            </p>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label className="flex flex-col text-base">
                <span>{t("settings.importExport.export.title")}</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  {t("settings.importExport.export.description")}
                </span>
              </Label>
              <Button onClick={handleExport} disabled={busy} variant="secondary" size="sm">
                {t("settings.importExport.export.button")}
              </Button>
            </div>

            <hr/>

            <div className="flex items-center justify-between space-x-20 py-1">
              <Label className="flex flex-col text-base">
                <span>{t("settings.importExport.import.title")}</span>
                <span className="text-neutral-500 font-normal text-sm mt-1">
                  {t("settings.importExport.import.description")}
                </span>
              </Label>
              <Button onClick={handleImport} disabled={busy} variant="secondary" size="sm">
                {t("settings.importExport.import.button")}
              </Button>
            </div>

            {status.length > 0 && (
                <p className="text-neutral-500 font-normal text-sm">{status}</p>
            )}
          </div>
        </div>
      </div>
  );
}
