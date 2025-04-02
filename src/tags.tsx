import React from "react";

let tags: Tag[] = [];
let tagIndex = 0;

export enum TagColor {
  Blue = "#3b82f6",
  Sky = "#0ea5e9",
  Lime = "#84cc16",
  Green = "#22c55e",
  Yellow = "#eab308",
  Orange = "#f97316",
  Red = "#dc2626",
  Pink = "#ec4899",
  Purple = "#a855f7",
}

const TagIcon = (props: React.SVGProps<SVGSVGElement>) => (
    <svg width="24"
         height="24"
         viewBox="-3 -2 24 24"
         version="1.1"
         xmlns="http://www.w3.org/2000/svg"
         {...props}>
      <g id="Group" fill="currentColor" fillRule="inherit">
        <path
            d="M7.80018616,0 C8.91449833,0 10.0288115,0.464576006 10.7716866,1.20789766 L19.2218895,9.6631813 C20.2433414,10.6852484 20.2433414,12.3577223 19.3147469,13.2868748 L13.371748,19.233448 C12.3502951,20.2555161 10.7716866,20.2555161 9.7502327,19.233448 L1.30003107,10.7781639 C0.464296818,10.0348425 0,8.91985989 0,7.80487728 L0,1.67247367 C0,0.743321598 0.742874861,0 1.6714685,0 L7.80018616,0 Z M4.35578396,4.32420898 C3.76142468,4.91856826 3.76142468,5.8822149 4.35578396,6.47657418 C4.95014329,7.07093351 5.91379022,7.0709338 6.5081495,6.47657452 C7.10250883,5.88221519 7.10250883,4.91856796 6.5081495,4.32420864 C5.91379022,3.72984936 4.95014329,3.72984965 4.35578396,4.32420898 Z"
            id="Combined-Shape"></path>
      </g>
    </svg>
);

export default TagIcon;

export class Tag {
  id: number = 0;
  name: string = "";
  color: string = "";

  constructor(name: string, color: string) {
    this.id = tagIndex++
    this.name = name
    this.color = color
  }
}

export function loadTags() {
  let values = localStorage.getItem("tags")
  if (values) {
    tags = JSON.parse(values)
  }
  tagIndex = parseInt(localStorage.getItem("tagIndex") || "0")
}

function saveTags() {
  localStorage.setItem("tags", JSON.stringify(tags))
  localStorage.setItem("tagIndex", tagIndex.toString())
}

export function allTags(): Tag[] {
  return tags
}

export function getTags(tagIds: number[] | undefined): Tag[] {
  if (tagIds) {
    return tags.filter((tag: Tag) => {
      return tagIds.includes(tag.id)
    })
  }
  return []
}

export function findTagById(id: number): Tag | undefined {
  for (let i = 0; i < tags.length; i++) {
    if (tags[i].id === id) {
      return tags[i]
    }
  }
  return undefined
}

export function addTag(tag: Tag) {
  tags.push(tag)
  saveTags()
}

export function removeTag(tag: Tag) {
  let index = tags.indexOf(tag);
  if (index > -1) {
    tags.splice(index, 1);
    saveTags()
  }
}

export function updateTag(id: number, name: string, color: string) {
  let tag = findTagById(id)
  if (tag) {
    tag.name = name
    tag.color = color
    saveTags()
  }
}
