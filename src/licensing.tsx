declare const isActivated: () => boolean;
declare const isTrial: () => boolean;
declare const getTrialDaysLeft: () => number;

export function isLicenseActivated(): boolean {
  return isActivated()
}

export function isTrialLicense(): boolean {
  return isTrial()
}

export function isTrialLicenseExpired(): boolean {
  return isTrial() && getTrialLicenseDaysLeft() <= 0
}

export function getTrialLicenseDaysLeft(): number {
  return getTrialDaysLeft()
}
