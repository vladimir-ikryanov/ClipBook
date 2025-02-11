import {type ClassValue, clsx} from "clsx"
import {twMerge} from "tailwind-merge"
import {ClipType} from "@/db";
import {prefShouldTreatDigitNumbersAsColor} from "@/pref";
import {MouseEvent} from "react";
import {TextFormatOperation} from "@/data";

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

export function getDomainFromURL(url: string): string {
  const domainRegex = /^(?:https?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:/\n?]+)/
  const match = url.match(domainRegex)
  return match ? match[1] : ""
}

export function isDigit(str: string) {
  return /^\d+$/.test(str)
}

export function isColor(str: string): boolean {
  if (str.length === 3 || str.length === 4 || str.length === 6 || str.length === 8) {
    if (isDigit(str) && !prefShouldTreatDigitNumbersAsColor()) {
      return false;
    }
  }
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

function getCSSColor(str: string): string {
  const s = new Option().style
  s.color = str
  return s.color
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

  const hexRegex = /^#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{4}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$/
  if (hexRegex.test(str)) {
    return getCSSColor(str)
  }

  const rgbRegex = /^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$/
  if (rgbRegex.test(str)) {
    return getCSSColor(str)
  }

  const hslRegex = /^hsl\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*\)$/
  if (hslRegex.test(str)) {
    return getCSSColor(str)
  }

  // Check if the string represents a single word with only letters.
  // If it does, try to get the standard color by name from the string.
  const wordRegex = /^[a-zA-Z]+$/
  if (wordRegex.test(str)) {
    return getCSSColor(str)
  }

  return ""
}

export function hasModifiers(e: MouseEvent) :boolean {
  return e.metaKey || e.ctrlKey || e.shiftKey || e.altKey
}

export function formatText(text: string, operation: TextFormatOperation) {
  switch (operation) {
    case TextFormatOperation.ToUpperCase:
      return text.toUpperCase()
    case TextFormatOperation.ToLowerCase:
      return text.toLowerCase()
    case TextFormatOperation.CapitalizeWords:
      return text.replace(/\b\w/g, l => l.toUpperCase())
    case TextFormatOperation.ToSentenceCase:
      return text.replace(/(^\w{1}|\.\s+\w{1})/gi, l => l.toUpperCase())
    case TextFormatOperation.RemoveEmptyLines:
      return text.replace(/^\s*\n/gm, "")
    case TextFormatOperation.StripAllWhitespaces:
      return text.replace(/\s/g, "")
    case TextFormatOperation.TrimSurroundingWhitespaces:
      return text.trim()
    default:
      return text
  }
}
