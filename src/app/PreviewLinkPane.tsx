import '../app.css';
import React, {useEffect, useState} from "react";
import {Clip, getLinkPreviewDetails, LinkPreviewDetails, saveLinkPreviewDetails} from "@/db";
import PreviewLinkCard from "@/app/PreviewLinkCard";
import PreviewLinkProgressBar from "@/app/PreviewLinkProgressBar";
import {getClipType} from "@/lib/utils";
import {isShortcutMatch} from "@/lib/shortcuts";
import {prefGetEditHistoryItemShortcut} from "@/pref";

type FetchRequestCallback = {
  run: (success: boolean, title: string, description: string, imageFileName: string, faviconFileName: string) => void;
}

declare const fetchLinkPreviewDetails: (url: string, callback: FetchRequestCallback) => void

type PreviewLinkPaneProps = {
  item: Clip
  linkText: string
  editMode: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewLinkPane(props: PreviewLinkPaneProps) {
  const [loading, setLoading] = useState(false)
  const [authorizationRequired, setAuthorizationRequired] = useState(false)

  const [content, setContent] = useState(props.linkText)
  const [title, setTitle] = useState("")
  const [description, setDescription] = useState("")
  const [imageFileName, setImageFileName] = useState("")
  const [faviconFileName, setFaviconFileName] = useState("")

  function handleFinishEditing() {
    props.item.content = content
    props.item.type = getClipType(content)
    props.onEditHistoryItem(props.item)
    props.onFinishEditing()
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      handleFinishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    setContent(content)
    props.item.content = content
    props.item.type = getClipType(content)
  }

  function updateLinkPreviewDetails(details: LinkPreviewDetails) {
    setTitle(details.title)
    setDescription(details.description)
    setImageFileName(details.imageFileName)
    setFaviconFileName(details.faviconFileName)
    setLoading(false)
    setAuthorizationRequired(false)
  }

  useEffect(() => {
    if (props.editMode) {
      let textarea = document.getElementById('preview') as HTMLTextAreaElement;
      setContent(props.linkText)
      textarea.focus()
    }
  }, [props.editMode]);

  useEffect(() => {
    let url = props.item.content
    // getLinkPreviewDetails(url).then(details => {
    //   if (details) {
    //     updateLinkPreviewDetails(details)
    //   } else {
        setLoading(true)
        const callbackInstance: FetchRequestCallback = {
          run: function(success: boolean, title: string, description: string, imageFileName: string, faviconFileName: string) {
            if (success) {
              saveLinkPreviewDetails({
                url: url,
                title: title,
                description: description,
                imageFileName: imageFileName,
                faviconFileName: faviconFileName
              }).then(() => {
                updateLinkPreviewDetails({
                  url: url,
                  title: title,
                  description: description,
                  imageFileName: imageFileName,
                  faviconFileName: faviconFileName
                })
              });
            } else {
              setAuthorizationRequired(true)
            }
          }
        }
        console.log('Fetching link preview details for', url)
        fetchLinkPreviewDetails(url, callbackInstance)
    //   }
    // })
  }, [props.linkText])

  if (props.editMode) {
    return (
        <textarea id='preview'
                  className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                  autoFocus={true}
                  value={content}
                  onBlur={handleFinishEditing}
                  onChange={handleOnChange}
                  onKeyDown={handleKeyDown}/>
    )
  }

  return (
      <div className="h-full overflow-auto">
        <PreviewLinkProgressBar visible={loading}/>
        <PreviewLinkCard loading={loading}
                         authorizationRequired={authorizationRequired}
                         url={props.linkText}
                         title={title}
                         description={description}
                         imageFileName={imageFileName}/>
      </div>
  )
}
