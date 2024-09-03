import {type ClassValue, clsx} from "clsx"
import {twMerge} from "tailwind-merge"
import {ClipType} from "@/db";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function isUrl(text: string) {
  if (!text || text.length == 0) {
    return false
  }
  if (!text.startsWith("http://") && !text.startsWith("https://")) {
    return false
  }
  const urlRegex = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i
  return urlRegex.test(text)
}

export function isColor(str: string): boolean {
  return toCSSColor(str) !== ""
}

export function getClipType(str: string): ClipType {
  if (isUrl(str)) {
    return ClipType.Link
  }
  if (isColor(str)) {
    return ClipType.Color
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
