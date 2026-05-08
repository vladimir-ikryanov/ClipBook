import '../app.css';
import React, {useEffect, useRef, useState} from "react";
import {Clip, getHTML, getRTF} from "@/db";
import {getClipTypeFromText} from "@/lib/utils";
import {isShortcutMatch} from "@/lib/shortcuts";
import {prefGetEditHistoryItemShortcut} from "@/pref";
import {emitter} from "@/actions";
import {getHistoryItemById, TextType} from "@/data";

type PreviewTextPaneProps = {
  item: Clip
  editMode: boolean
  onEditHistoryItem: (item: Clip) => void
  onFinishEditing: () => void
}

export default function PreviewTextPane(props: PreviewTextPaneProps) {
  // I need this state to keep caret position when editing the content.
  const [content, setContent] = useState(props.item.content)
  const [selectedTextType, setSelectedTextType] = useState<TextType>(TextType.Text)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    if (props.editMode) {
      let textarea = textareaRef.current
      if (textarea) {
        textarea.focus()
        textarea.selectionStart = textarea.selectionEnd = textarea.value.length
      }
    }
  }, [props.editMode]);

  useEffect(() => {
    updateItem()
  }, [props.item]);

  useEffect(() => {
    function handleSwitchTextType(type: TextType) {
      if (type === TextType.Text) {
        setContent(props.item.content)
      }
      if (type === TextType.HTML) {
        setContent(getHTML(props.item))
      }
      if (type === TextType.RTF) {
        setContent(getRTF(props.item))
      }
      setSelectedTextType(type)
    }

    function handleUpdateItemByIdEvent(itemId?: number) {
      if (itemId) {
        let item = getHistoryItemById(itemId)
        if (item && item.id === props.item.id) {
          updateItem()
        }
      }
    }

    emitter.on("SwitchTextType", handleSwitchTextType)
    emitter.on("UpdateItemById", handleUpdateItemByIdEvent)
    return () => {
      emitter.off("SwitchTextType", handleSwitchTextType)
      emitter.off("UpdateItemById", handleUpdateItemByIdEvent)
    };
  }, [props.item]);

  function applyContentFromTextareaValue(newContent: string) {
    setContent(newContent)
    if (selectedTextType === TextType.Text) {
      props.item.content = newContent
    }
    if (selectedTextType === TextType.HTML) {
      props.item.html = newContent
    }
    if (selectedTextType === TextType.RTF) {
      props.item.rtf = newContent
    }
    props.item.type = getClipTypeFromText(newContent)
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.code === "Escape" || isShortcutMatch(prefGetEditHistoryItemShortcut(), e.nativeEvent)) {
      finishEditing()
      e.stopPropagation()
      return
    }

    // Frameless WebKit often skips native editing commands; mirror desktop behavior explicitly.
    const mod = e.metaKey || e.ctrlKey
    if (mod && !e.altKey && !e.shiftKey) {
      if (e.code === "KeyA") {
        e.currentTarget.select()
        e.preventDefault()
        e.stopPropagation()
        return
      }
      if (e.code === "KeyC") {
        const ta = e.currentTarget
        const text = ta.value.substring(ta.selectionStart, ta.selectionEnd)
        void navigator.clipboard.writeText(text).catch(() => {
          ta.focus()
          document.execCommand("copy")
        })
        e.preventDefault()
        e.stopPropagation()
        return
      }
      if (e.code === "KeyX") {
        const ta = e.currentTarget
        const start = ta.selectionStart
        const end = ta.selectionEnd
        e.preventDefault()
        e.stopPropagation()
        if (start === end) {
          return
        }
        const text = ta.value.substring(start, end)
        void (async () => {
          try {
            await navigator.clipboard.writeText(text)
            const newContent = ta.value.slice(0, start) + ta.value.slice(end)
            applyContentFromTextareaValue(newContent)
            setTimeout(() => {
              const el = textareaRef.current
              if (el) {
                el.selectionStart = el.selectionEnd = start
              }
            }, 0)
          } catch {
            ta.focus()
            ta.setSelectionRange(start, end)
            if (document.execCommand("cut")) {
              applyContentFromTextareaValue(ta.value)
            }
          }
        })()
        return
      }
      if (e.code === "KeyV") {
        const ta = e.currentTarget
        const start = ta.selectionStart
        const end = ta.selectionEnd
        e.preventDefault()
        e.stopPropagation()
        void navigator.clipboard.readText().then((text) => {
          const el = textareaRef.current
          if (!el) {
            return
          }
          const newContent = el.value.slice(0, start) + text + el.value.slice(end)
          applyContentFromTextareaValue(newContent)
          const caret = start + text.length
          setTimeout(() => {
            el.selectionStart = el.selectionEnd = caret
          }, 0)
        }).catch(() => {
          const el = textareaRef.current
          if (!el) {
            return
          }
          el.focus()
          if (document.execCommand("paste")) {
            setTimeout(() => {
              const t = textareaRef.current
              if (t) {
                applyContentFromTextareaValue(t.value)
              }
            }, 0)
          }
        })
        return
      }
    }

    e.stopPropagation()
  }

  function finishEditing() {
    props.onEditHistoryItem(props.item)
    props.onFinishEditing()
  }

  function handleOnChange() {
    const el = textareaRef.current
    if (!el) {
      return
    }
    applyContentFromTextareaValue(el.value)
  }

  function updateItem() {
    setContent(props.item.content)
    setSelectedTextType(TextType.Text)
  }

  return (
      <textarea id='preview'
                ref={textareaRef}
                className="preview [-webkit-app-region:no-drag] h-full px-4 py-2 m-0 outline-none resize-none font-mono text-sm scrollbar-thin scrollbar-thumb-scrollbar scrollbar-track-transparent"
                value={content}
                onBlur={finishEditing}
                onChange={handleOnChange}
                onKeyDown={handleKeyDown}/>
  )
}
