import HistoryPane from "@/app/HistoryPane";
import {ThemeProvider} from "@/app/ThemeProvider"

import {useEffect, useState} from "react";
import {
  prefGetCloseAppShortcut,
  prefGetCloseAppShortcut2,
  prefGetCloseAppShortcut3, prefGetLanguage,
  prefGetZoomUIInShortcut,
  prefGetZoomUIOutShortcut, prefGetZoomUIResetShortcut
} from "@/pref";
import {isShortcutMatch} from "@/lib/shortcuts";
import {TooltipProvider} from "@/components/ui/tooltip";
import {emitter} from "@/actions";
import {getAIService, AIProviderType} from "@/ai/ai-service";
import {OllamaProvider} from "@/ai/ollama-provider";
import {OpenAIProvider} from "@/ai/openai-provider";
import {PerplexityProvider} from "@/ai/perplexity-provider";
import {prefGetAIProvider, prefGetAIAPIKey, prefGetAIModel} from "@/pref";

declare const hideAppWindow: () => void;
declare const zoomIn: () => void;
declare const zoomOut: () => void;
declare const resetZoom: () => void;

export default function App() {
  const [appName, setAppName] = useState("")
  const [appIcon, setAppIcon] = useState("")

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      // Prevent leaving the history items with the tab key.
      if (e.code === "Tab") {
        e.preventDefault()
      }
      // Close the app window with the close app shortcut.
      if (isShortcutMatch(prefGetCloseAppShortcut(), e)
          || isShortcutMatch(prefGetCloseAppShortcut2(), e)
          || isShortcutMatch(prefGetCloseAppShortcut3(), e)) {
        hideAppWindow()
        e.preventDefault()
      }
      // Zoom in the UI with the zoom in shortcut.
      if (isShortcutMatch(prefGetZoomUIInShortcut(), e)) {
        handleZoomIn()
        e.preventDefault()
      }
      // Zoom out the UI with the zoom out shortcut.
      if (isShortcutMatch(prefGetZoomUIOutShortcut(), e)) {
        handleZoomOut()
        e.preventDefault()
      }
      // Reset zoom.
      if (isShortcutMatch(prefGetZoomUIResetShortcut(), e)) {
        handleResetZoom()
        e.preventDefault()
      }
    }

    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  useEffect(() => {
    emitter.on("ZoomIn", handleZoomIn)
    emitter.on("ZoomOut", handleZoomOut)
    emitter.on("ResetZoom", handleResetZoom)
    return () => {
      emitter.off("ZoomIn", handleZoomIn)
      emitter.off("ZoomOut", handleZoomOut)
      emitter.off("ResetZoom", handleResetZoom)
    };
  }, []);

  function setActiveAppInfo(appName: string, appIcon: string): void {
    setAppName(appName)
    setAppIcon(appIcon)
  }

  function onDidAppWindowHide() {
    emitter.emit("NotifyAppWindowDidHide")
  }

  function handleZoomIn() {
    zoomIn()
    emitter.emit("FocusSearchInput")
  }

  function handleZoomOut() {
    zoomOut()
    emitter.emit("FocusSearchInput")
  }

  function handleResetZoom() {
    resetZoom()
    emitter.emit("FocusSearchInput")
  }

  // Initialize AI service
  useEffect(() => {
    const aiService = getAIService();
    const provider = (prefGetAIProvider() as AIProviderType) || AIProviderType.Ollama;
    const apiKey = prefGetAIAPIKey() || "";
    const model = prefGetAIModel() || (
      provider === AIProviderType.Ollama ? "llama3.2" : 
      provider === AIProviderType.Perplexity ? "sonar" : 
      "gpt-3.5-turbo"
    );

    if (provider === AIProviderType.Ollama) {
      aiService.setProvider(AIProviderType.Ollama, new OllamaProvider(model));
    } else if (provider === AIProviderType.OpenAI && apiKey) {
      aiService.setProvider(AIProviderType.OpenAI, new OpenAIProvider(apiKey, model));
    } else if (provider === AIProviderType.Perplexity && apiKey) {
      aiService.setProvider(AIProviderType.Perplexity, new PerplexityProvider(apiKey, model));
    }

    aiService.updateConfig({ provider, apiKey, model });
  }, []);

  // Attach the function to the window object
  (window as any).setActiveAppInfo = setActiveAppInfo;
  (window as any).onDidAppWindowHide = onDidAppWindowHide;

  return (
      <ThemeProvider defaultTheme="system">
        <TooltipProvider delayDuration={250}>
          <HistoryPane appName={appName} appIcon={appIcon}/>
        </TooltipProvider>
      </ThemeProvider>
  )
}
