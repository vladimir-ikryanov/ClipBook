import '../app.css';
import React from "react";
import {getDomainFromURL} from "@/lib/utils";

type PreviewLinkCardProps = {
  loading: boolean
  authorizationRequired: boolean
  url: string
  title: string
  description: string
  imageFileName: string
}

export default function PreviewLinkCard(props: PreviewLinkCardProps) {
  if (props.loading) {
    return (
        <div className="flex justify-center items-center text-secondary-foreground m-8">
          Loading...
        </div>
    )
  }
  if (props.authorizationRequired) {
    return (
        <div className="flex justify-center items-center text-secondary-foreground m-8">
          Authorization required
        </div>
    )
  }
  return (
      <div className="m-4 mt-2.5 rounded-md bg-muted overflow-clip">
        {
          props.imageFileName === "" ? null :
              <img src={"clipbook://images/links/" + props.imageFileName} alt=""
                   className="w-full"/>
        }
        <div className="p-4 space-y-1">
          <div className="font-semibold text-sm">{props.title}</div>
          <div className="text-secondary-foreground text-sm">{props.description}</div>
        </div>
      </div>
  )
}
