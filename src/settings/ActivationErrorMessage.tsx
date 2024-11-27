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

type ActivationErrorMessageProps = {
  visible: boolean
  message: string
  onClose: () => void
  onHelp: () => void
}

export default function ActivationErrorMessage(props: ActivationErrorMessageProps) {
  function handleHelp() {
    props.onHelp()
  }

  function handleClose() {
    props.onClose()
  }

  return (
      <AlertDialog open={props.visible}>
        <AlertDialogTrigger asChild>
          <Button className="hidden">Show Dialog</Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              The license cannot be activated :(
            </AlertDialogTitle>
            <AlertDialogDescription>
              {props.message}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={handleHelp}>Help me</AlertDialogCancel>
            <AlertDialogCancel onClick={handleClose}>Close</AlertDialogCancel>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
  )
}
