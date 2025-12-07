/**
 * QuickRewriteButton - One-click AI text improvement with streaming
 * 
 * This button provides instant text improvement without opening
 * the full AI dialog. Uses the "improveWriting" action by default.
 * Now supports streaming for real-time feedback.
 */

import React, { useState, useRef } from "react";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Sparkles, Loader2, CheckIcon, AlertCircle, Square } from "lucide-react";
import { Clip } from "@/db";
import { getAIService } from "@/ai/ai-service";
import { getOptimizedPrompt } from "@/ai/prompts";
import { useTranslation } from 'react-i18next';

interface QuickRewriteButtonProps {
  selectedItem: Clip | undefined;
  onComplete: (newText: string) => void;
  onStreamingStart?: () => void;
  onStreamingChunk?: (text: string) => void;
  onStreamingEnd?: () => void;
}

export default function QuickRewriteButton({ 
  selectedItem, 
  onComplete,
  onStreamingStart,
  onStreamingChunk,
  onStreamingEnd,
}: QuickRewriteButtonProps) {
  const { t } = useTranslation();
  
  const [isProcessing, setIsProcessing] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const abortControllerRef = useRef<AbortController | null>(null);
  const chunkBufferRef = useRef<string>('');
  const renderTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleQuickRewrite = async () => {
    if (!selectedItem?.content || isProcessing) return;
    
    setIsProcessing(true);
    setIsStreaming(false);
    setError(null);
    setShowSuccess(false);
    abortControllerRef.current = new AbortController();
    chunkBufferRef.current = '';
    
    try {
      const aiService = getAIService();
      const provider = aiService.getProvider();
      
      if (!provider) {
        throw new Error(t('preview.toolbar.quickImprove.notConfigured', { 
          defaultValue: 'AI not configured. Go to Settings → AI' 
        }));
      }
      
      const isAvailable = await provider.isAvailable();
      if (!isAvailable) {
        const config = aiService.getConfig();
        if (config.provider === "ollama") {
          throw new Error(t('preview.toolbar.quickImprove.ollamaNotRunning', { 
            defaultValue: 'Ollama not running. Start with: ollama serve' 
          }));
        } else {
          throw new Error(t('preview.toolbar.quickImprove.apiKeyMissing', { 
            defaultValue: 'API key missing. Check Settings → AI' 
          }));
        }
      }
      
      const instruction = getOptimizedPrompt('improveWriting');
      
      // Use streaming if available
      if (aiService.supportsStreaming()) {
        setIsStreaming(true);
        onStreamingStart?.();
        let fullText = '';
        
        const flushBuffer = () => {
          if (chunkBufferRef.current && !abortControllerRef.current?.signal.aborted) {
            fullText += chunkBufferRef.current;
            onStreamingChunk?.(fullText);
            chunkBufferRef.current = '';
          }
        };
        
        await aiService.rewriteStream(selectedItem.content, instruction, {
          onChunk: (chunk) => {
            if (abortControllerRef.current?.signal.aborted) return;
            
            chunkBufferRef.current += chunk;
            
            if (!renderTimeoutRef.current) {
              renderTimeoutRef.current = setTimeout(() => {
                flushBuffer();
                renderTimeoutRef.current = null;
              }, 30);
            }
          },
          onComplete: (finalText) => {
            if (renderTimeoutRef.current) {
              clearTimeout(renderTimeoutRef.current);
              renderTimeoutRef.current = null;
            }
            
            if (!abortControllerRef.current?.signal.aborted) {
              setIsStreaming(false);
              setIsProcessing(false);
              setShowSuccess(true);
              setTimeout(() => setShowSuccess(false), 1500);
              onStreamingEnd?.();
              onComplete(finalText);
            }
          },
          onError: (err) => {
            if (!abortControllerRef.current?.signal.aborted) {
              setError(err.message);
              setIsStreaming(false);
              setIsProcessing(false);
              onStreamingEnd?.();
              setTimeout(() => setError(null), 5000);
            }
          }
        });
      } else {
        // Non-streaming fallback
        const result = await aiService.rewrite(selectedItem.content, instruction);
        setShowSuccess(true);
        setTimeout(() => setShowSuccess(false), 1500);
        onComplete(result);
        setIsProcessing(false);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
      setTimeout(() => setError(null), 5000);
      setIsProcessing(false);
      setIsStreaming(false);
      onStreamingEnd?.();
    }
  };

  const handleStop = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    if (renderTimeoutRef.current) {
      clearTimeout(renderTimeoutRef.current);
      renderTimeoutRef.current = null;
    }
    setIsStreaming(false);
    setIsProcessing(false);
    onStreamingEnd?.();
  };

  // Determine button state and icon
  const getButtonContent = () => {
    if (isStreaming) {
      return <Square className="h-4 w-4 fill-current" strokeWidth={2} />;
    }
    if (isProcessing) {
      return <Loader2 className="h-5 w-5 animate-spin" strokeWidth={2} />;
    }
    if (showSuccess) {
      return <CheckIcon className="h-5 w-5 text-checked" strokeWidth={2} />;
    }
    return <Sparkles className="h-5 w-5" strokeWidth={2} />;
  };

  // Determine tooltip content
  const getTooltipContent = () => {
    if (error) {
      return (
        <div className="flex items-center gap-1.5 text-destructive">
          <AlertCircle className="h-3.5 w-3.5" />
          <span className="max-w-[200px] text-xs">{error}</span>
        </div>
      );
    }
    if (isStreaming) {
      return (
        <span className="select-none">
          {t('preview.toolbar.quickImprove.clickToStop', { defaultValue: 'Click to stop' })}
        </span>
      );
    }
    if (isProcessing) {
      return (
        <span className="select-none">
          {t('preview.toolbar.quickImprove.processing', { defaultValue: 'Improving...' })}
        </span>
      );
    }
    if (showSuccess) {
      return (
        <span className="select-none text-checked">
          {t('preview.toolbar.quickImprove.success', { defaultValue: 'Text improved!' })}
        </span>
      );
    }
    return (
      <span className="select-none">
        {t('preview.toolbar.quickImprove.tooltip', { defaultValue: 'Quick Improve' })}
      </span>
    );
  };

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          variant="toolbar"
          size="toolbar"
          onClick={isStreaming ? handleStop : handleQuickRewrite}
          disabled={isProcessing && !isStreaming || !selectedItem?.content}
          className={`relative ${showSuccess ? 'text-checked' : ''} ${error ? 'text-destructive' : ''} ${isStreaming ? 'text-destructive' : ''}`}
        >
          {getButtonContent()}
        </Button>
      </TooltipTrigger>
      <TooltipContent className="flex items-center">
        <div className="select-none ml-1 mr-2">
          {getTooltipContent()}
        </div>
      </TooltipContent>
    </Tooltip>
  );
}
