import '../app.css';
import React from "react";

type PreviewLinkProgressBarProps = {
  visible: boolean
}

export default function PreviewLinkProgressBar(props: PreviewLinkProgressBarProps) {
  return (
      <div className={props.visible ? "loader" : "no-loader"}/>
  )
}
