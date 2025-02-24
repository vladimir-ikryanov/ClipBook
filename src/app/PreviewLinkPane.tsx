import '../app.css';
import React, {useEffect, useState} from "react";
import {
  Clip,
  deleteLinkPreviewDetails,
  getLinkPreviewDetails,
  LinkPreviewDetails,
  saveLinkPreviewDetails
} from "@/db";
import PreviewLinkCard from "@/app/PreviewLinkCard";
import {getClipTypeFromText} from "@/lib/utils";
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
  updateLinkPreview: boolean
  onLinkPreviewUpdated: () => void
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewLinkPane(props: PreviewLinkPaneProps) {
  const [loading, setLoading] = useState(false)
  const [content, setContent] = useState(props.linkText)
  const [title, setTitle] = useState("")
  const [description, setDescription] = useState("")
  const [imageFileName, setImageFileName] = useState("")

  function finishEditing() {
    props.onEditHistoryItem(props.item)
    props.onFinishEditing()
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      finishEditing()
    }
    e.stopPropagation()
  }

  function handleOnChange() {
    let content = (document.getElementById('preview') as HTMLTextAreaElement).value;
    setContent(content)
    props.item.content = content
    props.item.type = getClipTypeFromText(content)
  }

  function updateLinkPreviewDetails(details: LinkPreviewDetails) {
    setTitle(details.title)
    setDescription(details.description)
    setImageFileName(details.imageFileName)
    setLoading(false)
    props.onLinkPreviewUpdated()
  }

  useEffect(() => {
    if (props.editMode) {
      let textarea = document.getElementById('preview') as HTMLTextAreaElement;
      setContent(props.linkText)
      textarea.focus()
      textarea.selectionStart = textarea.selectionEnd = textarea.value.length
    }
  }, [props.editMode]);

  useEffect(() => {
    if (props.updateLinkPreview) {
      let url = props.item.content
      deleteLinkPreviewDetails(url).then(() => {
        loadLinkPreview()
      })
    }
  }, [props.updateLinkPreview]);

  useEffect(() => {
    loadLinkPreview();
  }, [props.linkText])

  function loadLinkPreview() {
    let url = props.item.content
    getLinkPreviewDetails(url).then(details => {
      if (details) {
        updateLinkPreviewDetails(details)
      } else {
        setLoading(true)
        const callbackInstance: FetchRequestCallback = {
          run: function (success: boolean, title: string, description: string, imageFileName: string, faviconFileName: string) {
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
            }
          }
        }
        fetchLinkPreviewDetails(url, callbackInstance)
      }
    })
  }

  if (props.editMode) {
    return (
        <textarea id='preview'
                  className="preview h-full px-4 py-2 m-0 bg-secondary outline-none resize-none font-mono text-sm"
                  autoFocus={true}
                  value={content}
                  onBlur={finishEditing}
                  onChange={handleOnChange}
                  onKeyDown={handleKeyDown}/>
    )
  }

  return (
      <div className="h-full overflow-auto">
        <PreviewLinkCard loading={loading}
                         url={props.linkText}
                         title={title}
                         description={description}
                         imageFileName={imageFileName}/>
      </div>
  )
}
