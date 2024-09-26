import '../app.css';
import React from "react";

type IconProps = {
  className?: string
}

export function HideInfoPaneIcon(props: IconProps) {
  return (
      <svg xmlns="http://www.w3.org/2000/svg"
           width="20"
           height="20"
           viewBox="0 0 24 24"
           fill="none"
           stroke="currentColor"
           strokeWidth="2"
           strokeLinecap="round"
           strokeLinejoin="round"
           className={props.className}>
        <rect x="3" y="3" width="18" height="18" rx="2"/>
        <rect fill="currentColor" x="4" y="14" width="16" height="6"/>
      </svg>
  )
}

export function ShowInfoPaneIcon(props: IconProps) {
  return (
      <svg xmlns="http://www.w3.org/2000/svg"
           width="20"
           height="20"
           viewBox="0 0 24 24"
           fill="none"
           stroke="currentColor"
           strokeWidth="2"
           strokeLinecap="round"
           strokeLinejoin="round"
           className={props.className}>
        <rect x="3" y="3" width="18" height="18" rx="2"/>
        <line x1="4" y1="14" x2="20" y2="14"/>
      </svg>
  )
}

export function HidePreviewPaneIcon(props: IconProps) {
  return (
      <svg xmlns="http://www.w3.org/2000/svg"
           width="20"
           height="20"
           viewBox="0 0 24 24"
           fill="none"
           stroke="currentColor"
           strokeWidth="2"
           strokeLinecap="round"
           strokeLinejoin="round"
           className={props.className}>
        <rect x="3" y="3" width="18" height="18" rx="2"/>
        <rect fill="currentColor" x="14" y="4" width="6" height="16"/>
      </svg>
  )
}

export function ShowPreviewPaneIcon(props: IconProps) {
  return (
      <svg xmlns="http://www.w3.org/2000/svg"
           width="20"
           height="20"
           viewBox="0 0 24 24"
           fill="none"
           stroke="currentColor"
           strokeWidth="2"
           strokeLinecap="round"
           strokeLinejoin="round"
           className={props.className}>
        <rect x="3" y="3" width="18" height="18" rx="2"/>
        <line x1="14" y1="4" x2="14" y2="20"/>
      </svg>
  )
}
