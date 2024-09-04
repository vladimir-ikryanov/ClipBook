import {type ClassValue, clsx} from "clsx"
import {twMerge} from "tailwind-merge"
import {ClipType} from "@/db";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function isUrl(str: string) {
  if (!str || str.length == 0) {
    return false
  }
  if (!str.startsWith("http://") && !str.startsWith("https://")) {
    return false
  }
  const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i
  return urlRegex.test(str)
}

export function isColor(str: string): boolean {
  return toCSSColor(str) !== ""
}

export function isEmail(email: string): boolean {
  if (email.length < 5 || email.length > 320) {
    return false;
  }

  let spaceIndex = email.indexOf(' ');
  if (spaceIndex !== -1) {
    return false;
  }

  const atIndex = email.indexOf('@');
  if (atIndex < 1 || atIndex === email.length - 1) {
    return false;
  }

  const dotIndex = email.indexOf('.', atIndex);
  if (dotIndex <= atIndex + 1 || dotIndex === email.length - 1) {
    return false;
  }

  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return emailRegex.test(email);
}

export function getClipType(str: string): ClipType {
  if (isUrl(str)) {
    return ClipType.Link
  }
  if (isColor(str)) {
    return ClipType.Color
  }
  if (isEmail(str)) {
    return ClipType.Email
  }
  return ClipType.Text
}

export function toCSSColor(str: string): string {
  // If the given string is longer than 20 characters, it's not a color.
  if (str.length > 20) {
    return ""
  }

  // If the string is a valid 3, 4, 6, or 8 character hex code without '#', add the '#' prefix
  if (/^[A-Fa-f0-9]{3}$/.test(str) || /^[A-Fa-f0-9]{4}$/.test(str) || /^[A-Fa-f0-9]{6}$/.test(str) || /^[A-Fa-f0-9]{8}$/.test(str)) {
    str = `#${str}`
  }

  const s = new Option().style
  s.color = str
  return s.color
}
