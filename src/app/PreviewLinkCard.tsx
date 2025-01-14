import '../app.css';
import React from "react";
import { Skeleton } from "@/components/ui/skeleton"

type PreviewLinkCardProps = {
  loading: boolean
  url: string
  title: string
  description: string
  imageFileName: string
}

export default function PreviewLinkCard(props: PreviewLinkCardProps) {
  if (props.loading) {
    return (
        <div className="flex flex-col m-3 mt-0.5 rounded-md bg-skeleton-background overflow-clip">
          <Skeleton className="flex h-52 w-full items-center justify-center rounded-none bg-skeleton-foreground">
            <span className="text-skeleton-text">Loading preview...</span>
          </Skeleton>
          <div className="p-4">
            <Skeleton className="h-4 w-[50%] mt-2 rounded bg-skeleton-foreground"/>
            <Skeleton className="h-4 w-[90%] mt-2 rounded mr-12 bg-skeleton-foreground"/>
            <Skeleton className="h-4 w-[80%] mt-2 rounded mr-12 bg-skeleton-foreground"/>
          </div>
        </div>
    )
  }
  return (
      <div className="m-3 mt-0.5 rounded-md bg-muted overflow-clip">
        {
          props.imageFileName === "" ?
              <div className="flex h-52 w-full bg-skeleton-foreground items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
                     fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"
                     strokeLinejoin="round" className="lucide lucide-image-off text-skeleton-text">
                  <line x1="2" x2="22" y1="2" y2="22"/>
                  <path d="M10.41 10.41a2 2 0 1 1-2.83-2.83"/>
                  <line x1="13.5" x2="6" y1="13.5" y2="21"/>
                  <line x1="18" x2="21" y1="12" y2="15"/>
                  <path
                      d="M3.59 3.59A1.99 1.99 0 0 0 3 5v14a2 2 0 0 0 2 2h14c.55 0 1.052-.22 1.41-.59"/>
                  <path d="M21 15V5a2 2 0 0 0-2-2H9"/>
                </svg>
              </div> :
              <div className="flex h-52 items-center justify-center">
                <img src={"clipbook://images/links/" + props.imageFileName} alt="" className="w-full h-full object-cover max-h-52"/>
              </div>
        }
        <div className="p-4 space-y-1">
          <div className="font-semibold text-sm">{props.title}</div>
          <div className="text-secondary-foreground text-sm">{props.description}</div>
        </div>
      </div>
  )
}
