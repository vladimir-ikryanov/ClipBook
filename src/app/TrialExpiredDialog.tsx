import '../app.css';
import React, {useState} from "react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import {Button} from "@/components/ui/button";
import {Checkbox} from "@/components/ui/checkbox";
import {prefIsFeedbackProvided, prefSetFeedbackProvided} from "@/pref";
import { useTranslation } from 'react-i18next';

declare const buyLicense: () => void;
declare const sendFeedback: (text: string) => void;
declare const openSettingsLicense: () => void;

type TrialExpiredDialogProps = {
  visible: boolean
}

export default function TrialExpiredDialog(props: TrialExpiredDialogProps) {
  const { t } = useTranslation()

  const [feedbackProvided, setFeedbackProvided] = useState(prefIsFeedbackProvided())
  const [feedback, setFeedback] = useState("")
  const [email, setEmail] = useState("")
  const [features, setFeatures] = useState(false)
  const [need, setNeed] = useState(false)
  const [value, setValue] = useState(false)
  const [other, setOther] = useState(true)

  function handleFeedback() {
    let reason = ""
    if (features) {
      reason += "- Missing features\n"
    }
    if (need) {
      reason += "- Don't need it right now\n"
    }
    if (value) {
      reason += "- Wasn't useful for me\n"
    }
    if (other) {
      reason += "- Other\n"
    }
    let text = ""
    if (reason.length > 0) {
      text += "Reason:\n\n" + reason + "\n"
    }
    text += "Feedback:\n\n" + feedback
    text += "\n\nEmail: " + email
    sendFeedback(text)
    setFeedbackProvided(true)
    prefSetFeedbackProvided(true)
  }

  function canSendFeedback() {
    return features || need || value || other || feedback.length > 0
  }

  function handleActivate() {
    openSettingsLicense()
  }

  function handleBuyLicense() {
    buyLicense()
  }

  function handleFeedbackChange(event: React.ChangeEvent<HTMLTextAreaElement>) {
    setFeedback(event.target.value)
  }

  function handleEmailChange(event: React.ChangeEvent<HTMLInputElement>) {
    setEmail(event.target.value)
  }

  return (
      <AlertDialog open={props.visible}>
        <AlertDialogTrigger asChild>
          <Button className="hidden">{t('trial.expiredDialog.showDialog')}</Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              <h1 className="text-xl mb-2">{t('trial.expiredDialog.title')}</h1>
            </AlertDialogTitle>
            <div className="text-[14px] text-dialog-text">
              <p>{t('trial.expiredDialog.description')}</p>
              {
                !feedbackProvided && <p className="mt-4">{t('trial.expiredDialog.feedback')}</p>
              }
              {
                  !feedbackProvided &&
                  <div className="flex space-x-4 mt-6 mb-2">
                    <div className="flex flex-col space-y-2.5 mt-2.5 mr-10">
                      <div className="flex items-center space-x-2">
                        <Checkbox id="features" checked={features}
                                  onCheckedChange={(checked) => setFeatures(!!checked)}/>
                        <label htmlFor="features"
                               className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
                          {t('trial.expiredDialog.missingFeatures')}
                        </label>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Checkbox id="need" checked={need}
                                  onCheckedChange={(checked) => setNeed(!!checked)}/>
                        <label htmlFor="need"
                               className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
                          {t('trial.expiredDialog.dontNeedItRightNow')}
                        </label>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Checkbox id="value" checked={value}
                                  onCheckedChange={(checked) => setValue(!!checked)}/>
                        <label htmlFor="value"
                               className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
                          {t('trial.expiredDialog.wasntUsefulForMe')}
                        </label>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Checkbox id="other" checked={other}
                                  onCheckedChange={(checked) => setOther(!!checked)}/>
                        <label htmlFor="other"
                               className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
                          {t('trial.expiredDialog.other')}
                        </label>
                      </div>
                    </div>
                    <div className="flex flex-col flex-grow space-y-2.5 mt-2.5">
                      <textarea id="msg" value={feedback} onChange={handleFeedbackChange}
                                className="flex h-24 p-2 bg-background border border-border rounded-md text-dialog-text text-sm outline-none"
                                placeholder={t('trial.expiredDialog.yourFeedback')}></textarea>
                      <input id="email" value={email} onChange={handleEmailChange}
                             className="flex p-2 bg-background placeholder:text-settings-inputPlaceholder border border-border rounded-md text-dialog-text text-sm outline-none"
                             type="email" placeholder={t('trial.expiredDialog.emailForResponse')}/>
                    </div>
                  </div>
              }
            </div>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <div className="flex flex-grow items-center space-x-2">
              <img src="assets/photo.png" className="w-10 h-10 rounded-full" alt="Photo"/>
              <div className="flex flex-col">
                <p className="text-sm text-secondary-foreground">Vladimir Ikryanov</p>
                <p className="text-xs text-secondary-foreground mb-1">{t('trial.expiredDialog.founder')}</p>
              </div>
            </div>
            <div className="flex space-x-3 items-center">
              {
                !feedbackProvided && <AlertDialogCancel onClick={handleFeedback} disabled={!canSendFeedback()}>{t('trial.expiredDialog.sendFeedback')}</AlertDialogCancel>
              }
              <AlertDialogCancel onClick={handleActivate}>{t('trial.expiredDialog.activateLicense')}</AlertDialogCancel>
              <AlertDialogAction onClick={handleBuyLicense}>{t('trial.expiredDialog.buyLicense')}</AlertDialogAction>
            </div>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
  )
}
