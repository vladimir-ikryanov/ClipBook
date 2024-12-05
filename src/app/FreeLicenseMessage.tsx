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

type FreeLicenseMessageProps = {
  visible: boolean,
  licenseKey: string,
  onClose: () => void
}

export default function FreeLicenseMessage(props: FreeLicenseMessageProps) {
  function handleClose() {
    props.onClose()
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    e.stopPropagation()
  }

  return (
      <AlertDialog open={props.visible}>
        <AlertDialogTrigger asChild>
          <Button className="hidden">Show Dialog</Button>
        </AlertDialogTrigger>
        <AlertDialogContent className="flex flex-col p-8" onKeyDown={handleKeyDown}>
          <h2 className="font-semibold text-2xl text-accent-foreground">Thank you for using ClipBook!</h2>
          <p className="">
            ClipBook was free for a long time, but I had to make it a paid app to keep it alive. The monthly expenses are getting higher and higher, and I need to cover them.
          </p>
          <p className="">
            Since you used ClipBook before it became a paid app, I'm giving you a free lifetime license key as my thank you.
          </p>
          <div
              className="text-lg font-mono bg-secondary py-3 px-4 rounded-md">{props.licenseKey}</div>
          <p className="">
            This license grants you free lifetime updates. Enjoy!
          </p>
          <p className="text-primary-foreground">Vladimir Ikryanov<br/>Founder of ClipBook</p>
          <Button className="mt-4" onClick={handleClose} variant="buy">Close</Button>
        </AlertDialogContent>
      </AlertDialog>
  )
}
