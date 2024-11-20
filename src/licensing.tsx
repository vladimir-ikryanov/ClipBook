declare const isActivated: () => boolean;

export function isLicenseActivated(): boolean {
  return isActivated()
}
