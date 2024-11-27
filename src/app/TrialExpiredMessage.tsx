import '../app.css';
import React from "react";
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

declare const buyLicense: () => void;
declare const openSettingsLicense: () => void;

type TrialExpiredMessageProps = {
  visible: boolean
}

export default function TrialExpiredMessage(props: TrialExpiredMessageProps) {
  function handleActivate() {
    openSettingsLicense()
  }

  function handleBuyLicense() {
    buyLicense()
  }

  return (
      <AlertDialog open={props.visible}>
        <AlertDialogTrigger asChild>
          <Button className="hidden">Show Dialog</Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              Thank you for trying ClipBook
            </AlertDialogTitle>
            <AlertDialogDescription>
              Your trial has expired.<br/>
              To continue using ClipBook, please buy a license and activate it.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={handleActivate}>Activate</AlertDialogCancel>
            <AlertDialogAction onClick={handleBuyLicense}>Buy license</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
  )
}
