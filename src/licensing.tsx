declare const isActivated: () => boolean;
declare const isTrial: () => boolean;
declare const isTrialExpired: () => boolean;
declare const getTrialDaysLeft: () => number;

export function isLicenseActivated(): boolean {
  return isActivated()
}

export function isTrialLicense(): boolean {
  return isTrial()
}

export function isTrialLicenseExpired(): boolean {
  return isTrialExpired()
}

export function getTrialLicenseDaysLeft(): number {
  return getTrialDaysLeft()
}
