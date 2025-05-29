import '../app.css';
import React, {useState} from "react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import {Button} from "@/components/ui/button";
import { useTranslation } from 'react-i18next';

type ActivationErrorMessageProps = {
  visible: boolean
  message: string
  onClose: () => void
  onHelp: () => void
}

export default function ActivationErrorMessage(props: ActivationErrorMessageProps) {
  const { t } = useTranslation();
  
  function handleHelp() {
    props.onHelp()
  }

  function handleClose() {
    props.onClose()
  }

  return (
      <AlertDialog open={props.visible}>
        <AlertDialogTrigger asChild>
          <Button className="hidden">{t('settings.license.activationErrorMessage.title')}</Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {t('settings.license.activationErrorMessage.title')}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {props.message}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={handleHelp}>{t('settings.license.activationErrorMessage.help')}</AlertDialogCancel>
            <AlertDialogCancel onClick={handleClose}>{t('settings.license.activationErrorMessage.close')}</AlertDialogCancel>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
  )
}
