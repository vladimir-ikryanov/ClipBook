import '../app.css';
import * as React from "react";
import { useState, useEffect, useRef, useCallback } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getAIService } from "@/ai/ai-service";
import { 
  AIAction, 
  ACTION_CATEGORIES, 
  ACTION_METADATA,
  getOptimizedPrompt,
  getActionSettings,
} from "@/ai/prompts";
import {
  WandIcon,
  CopyIcon,
  RefreshCwIcon,
  Loader2Icon,
  Sparkles,
  RefreshCw,
  NotebookText,
  Briefcase,
  Smile,
  BugIcon,
  BookOpen,
  PencilIcon,
  Languages,
  Code,
  FileText,
  Search,
  Zap,
  CheckCircle,
  AlertCircle,
  ArrowRight,
  Clock,
  Globe,
  CheckIcon,
  Square,
  MessageSquare,
  RotateCcw,
} from "lucide-react";
import { useTranslation } from 'react-i18next';
import { VisuallyHidden } from "@radix-ui/react-visually-hidden";
import CitationsPanel, { Citation } from "./CitationsPanel";
import { PerplexityProvider } from "@/ai/perplexity-provider";
import { AIConversationContext } from "@/ai/ai-context";
import ModelSwitcher from "./ModelSwitcher";

interface AIRewriteDialogProps {
  open: boolean;
  onClose: () => void;
  originalText: string;
  onReplace: (newText: string) => void;
}

// Icon mapping with better sizes
const CATEGORY_ICONS: Record<string, React.ReactNode> = {
  'Writing': <PencilIcon className="h-4 w-4" />,
  'Summary': <NotebookText className="h-4 w-4" />,
  'Tone': <Smile className="h-4 w-4" />,
  'Code': <Code className="h-4 w-4" />,
  'Format': <FileText className="h-4 w-4" />,
  'Extract': <Search className="h-4 w-4" />,
  'Language': <Languages className="h-4 w-4" />,
  'Fix': <CheckCircle className="h-4 w-4" />,
  'Research 🌐': <Globe className="h-4 w-4 text-blue-500" />,
  'Advanced': <Zap className="h-4 w-4" />,
};

const ACTION_ICONS: Record<string, React.ReactNode> = {
  improveWriting: <Sparkles className="h-4 w-4" />,
  rewrite: <RefreshCw className="h-4 w-4" />,
  summarize: <NotebookText className="h-4 w-4" />,
  makeProfessional: <Briefcase className="h-4 w-4" />,
  makeCasual: <Smile className="h-4 w-4" />,
  fixCode: <BugIcon className="h-4 w-4" />,
  explainCode: <BookOpen className="h-4 w-4" />,
  custom: <PencilIcon className="h-4 w-4" />,
  generatePrompt: <Zap className="h-4 w-4" />,
  translate: <Languages className="h-4 w-4" />,
  research: <Globe className="h-4 w-4 text-blue-500" />,
  factCheck: <Globe className="h-4 w-4 text-blue-500" />,
};

const LANGUAGES = [
  'English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese',
  'Chinese', 'Japanese', 'Korean', 'Russian', 'Arabic', 'Hindi'
];

export default function AIRewriteDialog(props: AIRewriteDialogProps) {
  const { t } = useTranslation();

  const [action, setAction] = useState<AIAction>("improveWriting");
  const [customPrompt, setCustomPrompt] = useState("");
  const [targetLanguage, setTargetLanguage] = useState("Spanish");
  const [promptTopic, setPromptTopic] = useState("");
  const [result, setResult] = useState("");
  const [streamingText, setStreamingText] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [executionTime, setExecutionTime] = useState<number | null>(null);
  const [copied, setCopied] = useState(false);
  const [citations, setCitations] = useState<Citation[]>([]);
  
  // Conversation context - persists for follow-up questions
  const [context] = useState(() => new AIConversationContext(10));
  const [contextCount, setContextCount] = useState(0);
  
  const resultRef = useRef<HTMLTextAreaElement>(null);
  const startTimeRef = useRef<number>(0);
  const abortControllerRef = useRef<AbortController | null>(null);
  const chunkBufferRef = useRef<string>('');
  const renderTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (props.open) {
      setAction("improveWriting");
      setCustomPrompt("");
      setPromptTopic("");
      setResult("");
      setStreamingText("");
      setError("");
      setIsStreaming(false);
      setExecutionTime(null);
      setCopied(false);
      setCitations([]);
      // Clean up any previous abort controller
      abortControllerRef.current = null;
    }
    
    // Cleanup on unmount or close
    return () => {
      if (renderTimeoutRef.current) {
        clearTimeout(renderTimeoutRef.current);
      }
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [props.open]);

  useEffect(() => {
    if (isStreaming && resultRef.current) {
      resultRef.current.scrollTop = resultRef.current.scrollHeight;
    }
  }, [streamingText, isStreaming]);

  const getInstruction = useCallback(() => {
    if (action === "custom") return customPrompt;
    if (action === "translate") return getOptimizedPrompt(action, targetLanguage);
    if (action === "generatePrompt") return getOptimizedPrompt(action, promptTopic || props.originalText);
    return getOptimizedPrompt(action);
  }, [action, customPrompt, targetLanguage, promptTopic, props.originalText]);

  // Helper to get citations from Perplexity provider
  const getCitationsFromProvider = (provider: any): Citation[] => {
    if (provider instanceof PerplexityProvider) {
      return provider.getLastCitations();
    }
    return [];
  };

  const handleGenerate = async () => {
    startTimeRef.current = performance.now();
    setLoading(true);
    setIsStreaming(false);
    setError("");
    setResult("");
    setStreamingText("");
    setExecutionTime(null);
    setCitations([]);
    
    // Create new abort controller for this generation
    abortControllerRef.current = new AbortController();
    chunkBufferRef.current = '';

    try {
      const aiService = getAIService();
      const config = aiService.getConfig();
      const providerInstance = aiService.getProvider();
      
      if (!providerInstance) {
        throw new Error(`AI provider not configured. Go to Settings → AI to configure ${config.provider}`);
      }
      
      const isAvailable = await providerInstance.isAvailable();
      if (!isAvailable) {
        throw new Error(config.provider === "ollama" 
          ? "Ollama not running. Start with: ollama serve"
          : "API key missing. Check Settings → AI");
      }

      const instruction = getInstruction();
      
      // Build user message content for context
      const userMessage = `${instruction}\n\n---\nText: ${props.originalText.substring(0, 200)}${props.originalText.length > 200 ? '...' : ''}`;

      if (aiService.supportsStreaming()) {
        setIsStreaming(true);
        let fullText = '';
        
        // Smooth text batching - buffer chunks and render at intervals
        const flushBuffer = () => {
          if (chunkBufferRef.current && !abortControllerRef.current?.signal.aborted) {
            fullText += chunkBufferRef.current;
            setStreamingText(fullText);
            chunkBufferRef.current = '';
          }
        };
        
        await aiService.rewriteStream(props.originalText, instruction, {
          onChunk: (chunk) => {
            // Check if aborted
            if (abortControllerRef.current?.signal.aborted) return;
            
            chunkBufferRef.current += chunk;
            
            // Render at most every 30ms for smooth appearance
            if (!renderTimeoutRef.current) {
              renderTimeoutRef.current = setTimeout(() => {
                flushBuffer();
                renderTimeoutRef.current = null;
              }, 30);
            }
          },
          onComplete: (finalText) => {
            // Final flush of any remaining buffer
            if (renderTimeoutRef.current) {
              clearTimeout(renderTimeoutRef.current);
              renderTimeoutRef.current = null;
            }
            
            if (!abortControllerRef.current?.signal.aborted) {
              setResult(finalText);
              setStreamingText("");
              setIsStreaming(false);
              setLoading(false);
              setExecutionTime(performance.now() - startTimeRef.current);
              
              // Add to conversation context for follow-ups
              context.addUserMessage(userMessage);
              context.addAssistantMessage(finalText.substring(0, 500));
              setContextCount(context.getCount());
              
              // Capture citations from Perplexity
              const newCitations = getCitationsFromProvider(providerInstance);
              setCitations(newCitations);
            }
          },
          onError: (err) => {
            if (!abortControllerRef.current?.signal.aborted) {
              setError(err.message);
              setIsStreaming(false);
              setLoading(false);
            }
          }
        }, context);
      } else {
        const rewritten = await aiService.rewrite(props.originalText, instruction, context);
        if (!abortControllerRef.current?.signal.aborted) {
          setResult(rewritten);
          setLoading(false);
          setExecutionTime(performance.now() - startTimeRef.current);
          
          // Add to conversation context for follow-ups
          context.addUserMessage(userMessage);
          context.addAssistantMessage(rewritten.substring(0, 500));
          setContextCount(context.getCount());
          
          // Capture citations from Perplexity
          const newCitations = getCitationsFromProvider(providerInstance);
          setCitations(newCitations);
        }
      }
    } catch (err) {
      if (!abortControllerRef.current?.signal.aborted) {
        setError(err instanceof Error ? err.message : "Unknown error");
        setLoading(false);
        setIsStreaming(false);
      }
    }
  };

  const handleStop = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    // Clear any pending render timeout
    if (renderTimeoutRef.current) {
      clearTimeout(renderTimeoutRef.current);
      renderTimeoutRef.current = null;
    }
    
    // Keep whatever text we have so far as the result
    if (streamingText) {
      setResult(streamingText);
      setStreamingText("");
    }
    
    setIsStreaming(false);
    setLoading(false);
    setExecutionTime(performance.now() - startTimeRef.current);
  };

  const handleCopy = () => {
    const text = result || streamingText;
    if (text) {
      navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }
  };

  const handleClearContext = () => {
    context.clear();
    setContextCount(0);
  };

  const handleReplace = () => {
    const text = result || streamingText;
    if (text) {
      props.onReplace(text);
      props.onClose();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    e.stopPropagation();
    if (e.key === "Escape") props.onClose();
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter" && !loading && !isStreaming) handleGenerate();
  };

  const displayText = result || streamingText;
  const formatTime = (ms: number) => ms < 1000 ? `${Math.round(ms)}ms` : `${(ms / 1000).toFixed(1)}s`;

  const renderActionOptions = () => {
    return Object.entries(ACTION_CATEGORIES).map(([category, actions]) => (
      <SelectGroup key={category}>
        <SelectLabel className="flex items-center gap-2 text-xs text-muted-foreground px-2 py-1.5">
          {CATEGORY_ICONS[category]}
          {category}
        </SelectLabel>
        {actions.map((actionKey) => {
          const meta = ACTION_METADATA[actionKey];
          if (!meta) return null;
          return (
            <SelectItem key={actionKey} value={actionKey} className="text-sm py-2">
              <div className="flex items-center gap-2">
                {ACTION_ICONS[actionKey] || <ArrowRight className="h-4 w-4" />}
                <span>{meta.label}</span>
              </div>
            </SelectItem>
          );
        })}
      </SelectGroup>
    ));
  };

  return (
    <Dialog open={props.open} onOpenChange={(open) => !open && props.onClose()}>
      <DialogContent 
        onKeyDown={handleKeyDown} 
        className="max-w-5xl w-[min(1000px,calc(100vw-2rem))] p-0 gap-0 overflow-hidden rounded-2xl"
      >
        <VisuallyHidden>
          <DialogTitle>AI Rewrite</DialogTitle>
          <DialogDescription>Transform text with AI</DialogDescription>
        </VisuallyHidden>
        
        {/* Header */}
        <div className="px-5 py-4 border-b border-border flex items-center justify-between bg-secondary/30 rounded-t-2xl">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-primary/10 rounded-xl">
              <WandIcon className="h-5 w-5 text-primary" />
            </div>
            <div>
              <span className="text-base font-semibold">AI Rewrite</span>
              <div className="mt-0.5">
                <ModelSwitcher compact />
              </div>
            </div>
          </div>
          
          <div className="flex items-center gap-3">
            <Select value={action} onValueChange={(v) => setAction(v as AIAction)}>
              <SelectTrigger className="w-52 h-9 text-sm rounded-xl">
                <SelectValue>
                  <div className="flex items-center gap-2">
                    {ACTION_ICONS[action]}
                    <span>{ACTION_METADATA[action]?.label || action}</span>
                  </div>
                </SelectValue>
              </SelectTrigger>
              <SelectContent className="max-h-80 rounded-xl">
                {renderActionOptions()}
              </SelectContent>
            </Select>
            
            {action === "translate" && (
              <Select value={targetLanguage} onValueChange={setTargetLanguage}>
                <SelectTrigger className="w-32 h-9 text-sm rounded-xl">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="rounded-xl">
                  {LANGUAGES.map(lang => (
                    <SelectItem key={lang} value={lang} className="text-sm">{lang}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
            
            <kbd className="px-2.5 py-1.5 bg-secondary rounded-lg text-xs font-medium text-muted-foreground">⌘↵</kbd>
          </div>
        </div>

        {/* Main content - side by side */}
        <div className="flex min-h-[380px] max-h-[500px] h-[55vh]">
          {/* Original text */}
          <div className="flex-1 flex flex-col border-r border-border">
            <div className="px-4 py-2.5 border-b border-border bg-secondary/20 flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Original</span>
              <span className="text-xs text-muted-foreground">{props.originalText.length} chars</span>
            </div>
            <Textarea
              value={props.originalText}
              readOnly
              className="flex-1 border-0 rounded-none resize-none text-[15px] leading-relaxed font-mono focus-visible:ring-0 bg-transparent p-4"
            />
          </div>

          {/* Result */}
          <div className="flex-1 flex flex-col">
            <div className="px-4 py-2.5 border-b border-border bg-secondary/20 flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">
                {isStreaming ? "Generating..." : "Result"}
              </span>
              <div className="flex items-center gap-3">
                {executionTime !== null && (
                  <span className="text-xs text-muted-foreground flex items-center gap-1">
                    <Clock className="h-3.5 w-3.5" />
                    {formatTime(executionTime)}
                  </span>
                )}
                {displayText && (
                  <button 
                    onClick={handleCopy}
                    className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1 transition-colors"
                  >
                    {copied ? <CheckIcon className="h-3.5 w-3.5 text-green-500" /> : <CopyIcon className="h-3.5 w-3.5" />}
                    {copied ? 'Copied' : 'Copy'}
                  </button>
                )}
                <span className="text-xs text-muted-foreground">{displayText.length} chars</span>
              </div>
            </div>
            
            {loading && !isStreaming ? (
              <div className="flex-1 flex items-center justify-center">
                <div className="text-center">
                  <Loader2Icon className="h-10 w-10 animate-spin text-primary mx-auto" />
                  <p className="text-sm text-muted-foreground mt-3">Generating...</p>
                </div>
              </div>
            ) : error ? (
              <div className="flex-1 flex items-center justify-center p-6">
                <div className="text-center max-w-sm">
                  <AlertCircle className="h-10 w-10 text-destructive mx-auto" />
                  <p className="text-sm text-destructive mt-3">{error}</p>
                </div>
              </div>
            ) : isStreaming ? (
              /* Streaming text with cursor */
              <div 
                ref={resultRef as any}
                className="flex-1 overflow-y-auto p-4 text-[15px] leading-relaxed font-mono bg-transparent border-l-2 border-l-primary"
              >
                <span className="whitespace-pre-wrap break-words">{streamingText}</span>
                <span className="inline-block w-0.5 h-5 bg-primary animate-pulse ml-0.5 align-middle" />
              </div>
            ) : displayText ? (
              <Textarea
                ref={resultRef}
                value={displayText}
                onChange={(e) => setResult(e.target.value)}
                readOnly={false}
                className="flex-1 border-0 rounded-none resize-none text-[15px] leading-relaxed font-mono focus-visible:ring-0 bg-transparent p-4"
              />
            ) : (
              <div className="flex-1 flex items-center justify-center">
                <div className="text-center">
                  <WandIcon className="h-12 w-12 text-muted-foreground/30 mx-auto" />
                  <p className="text-sm text-muted-foreground mt-3">Select action & Generate</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Citations panel - only shown when citations exist */}
        {citations.length > 0 && (
          <CitationsPanel citations={citations} expanded={false} />
        )}

        {/* Custom prompt area - only when needed */}
        {(action === "custom" || action === "generatePrompt") && (
          <div className="px-5 py-3 border-t border-border bg-secondary/20">
            <Textarea
              value={action === "custom" ? customPrompt : promptTopic}
              onChange={(e) => action === "custom" ? setCustomPrompt(e.target.value) : setPromptTopic(e.target.value)}
              placeholder={action === "custom" ? "Custom instructions..." : "Topic for prompt..."}
              className="h-20 resize-none text-sm rounded-xl"
            />
          </div>
        )}

        {/* Footer */}
        <div className="px-5 py-4 border-t border-border flex items-center justify-between bg-secondary/30 rounded-b-2xl">
          <div className="text-xs text-muted-foreground flex items-center gap-3">
            {isStreaming ? (
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 bg-primary rounded-full animate-pulse" />
                Streaming...
              </span>
            ) : contextCount > 0 ? (
              <span className="flex items-center gap-3">
                <span className="flex items-center gap-1.5 text-primary">
                  <MessageSquare className="h-4 w-4" />
                  {Math.floor(contextCount / 2)} {Math.floor(contextCount / 2) === 1 ? 'exchange' : 'exchanges'}
                </span>
                <button
                  onClick={handleClearContext}
                  className="flex items-center gap-1 hover:text-foreground transition-colors"
                >
                  <RotateCcw className="h-4 w-4" />
                  New
                </button>
              </span>
            ) : null}
          </div>
          
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" onClick={props.onClose} className="h-9 px-4 text-sm rounded-xl">
              Cancel
            </Button>
            
            {isStreaming ? (
              /* Stop button during streaming */
              <Button 
                variant="destructive" 
                size="sm" 
                onClick={handleStop} 
                className="h-9 px-4 text-sm rounded-xl"
              >
                <Square className="h-4 w-4 mr-1.5 fill-current" />
                Stop
              </Button>
            ) : displayText ? (
              <>
                <Button variant="secondary" size="sm" onClick={handleGenerate} disabled={loading} className="h-9 px-4 text-sm rounded-xl">
                  <RefreshCwIcon className="h-4 w-4 mr-1.5" />
                  Redo
                </Button>
                <Button size="sm" onClick={handleReplace} className="h-9 px-5 text-sm rounded-xl">
                  Replace
                </Button>
              </>
            ) : (
              <Button 
                size="sm"
                onClick={handleGenerate} 
                disabled={loading || (action === "custom" && !customPrompt)}
                className="h-9 px-5 text-sm rounded-xl"
              >
                {loading ? (
                  <Loader2Icon className="h-4 w-4 mr-1.5 animate-spin" />
                ) : (
                  <WandIcon className="h-4 w-4 mr-1.5" />
                )}
                Generate
              </Button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
