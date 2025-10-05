import '../app.css';
import * as React from "react";
import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getAIService } from "@/ai/ai-service";
import { getPrompt, AIAction } from "@/ai/prompts";
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
} from "lucide-react";
import { useTranslation } from 'react-i18next';

interface AIRewriteDialogProps {
  open: boolean;
  onClose: () => void;
  originalText: string;
  onReplace: (newText: string) => void;
}

export default function AIRewriteDialog(props: AIRewriteDialogProps) {
  const { t } = useTranslation();

  const [action, setAction] = useState<AIAction>("improveWriting");
  const [customPrompt, setCustomPrompt] = useState("");
  const [result, setResult] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const actionOptions = React.useMemo(
    () => [
      { value: "improveWriting" as AIAction, icon: Sparkles, label: t("aiRewrite.actions.improveWriting", { defaultValue: "Improve Writing" }) },
      { value: "rewrite" as AIAction, icon: RefreshCw, label: t("aiRewrite.actions.rewrite", { defaultValue: "Rewrite" }) },
      { value: "summarize" as AIAction, icon: NotebookText, label: t("aiRewrite.actions.summarize", { defaultValue: "Summarize" }) },
      { value: "makeProfessional" as AIAction, icon: Briefcase, label: t("aiRewrite.actions.makeProfessional", { defaultValue: "Professional" }) },
      { value: "makeCasual" as AIAction, icon: Smile, label: t("aiRewrite.actions.makeCasual", { defaultValue: "Casual" }) },
      { value: "fixCode" as AIAction, icon: BugIcon, label: t("aiRewrite.actions.fixCode", { defaultValue: "Fix Code" }) },
      { value: "explainCode" as AIAction, icon: BookOpen, label: t("aiRewrite.actions.explainCode", { defaultValue: "Explain Code" }) },
      { value: "custom" as AIAction, icon: PencilIcon, label: t("aiRewrite.actions.custom", { defaultValue: "Custom Prompt" }) },
    ],
    [t]
  );

  useEffect(() => {
    if (props.open) {
      setAction("improveWriting");
      setCustomPrompt("");
      setResult("");
      setError("");
    }
  }, [props.open]);

  const handleGenerate = async () => {
    setLoading(true);
    setError("");
    setResult("");

    try {
      const aiService = getAIService();
      
      // Check if AI provider is available
      const config = aiService.getConfig();
      const providerInstance = (aiService as any).getProvider();
      
      if (!providerInstance) {
        throw new Error(`AI provider not configured. Please go to Settings → AI to configure ${config.provider}`);
      }
      
      const isAvailable = await providerInstance.isAvailable();
      if (!isAvailable) {
        if (config.provider === "ollama") {
          throw new Error("Ollama is not running. Please start it with: ollama serve");
        } else if (config.provider === "openai" || config.provider === "perplexity") {
          throw new Error(`${config.provider === "openai" ? "OpenAI" : "Perplexity"} API key is missing or invalid. Please check Settings → AI`);
        }
      }

      const instruction = action === "custom" 
        ? customPrompt 
        : getPrompt(action);

      const rewritten = await aiService.rewrite(props.originalText, instruction);
      setResult(rewritten);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(result);
  };

  const handleReplace = () => {
    props.onReplace(result);
    props.onClose();
  };

  function handleKeyDown(e: React.KeyboardEvent) {
    e.stopPropagation();
    if (e.key === "Escape") {
      props.onClose();
    }
  }

  return (
    <Dialog
      open={props.open}
      onOpenChange={(open) => {
        if (!open) {
          props.onClose();
        }
      }}
    >
      <DialogContent onKeyDown={handleKeyDown} className="max-w-[70vw] w-[70vw] h-[70vh] max-h-[70vh] bg-background-solid border-dialog-border shadow-lg p-0 gap-0 flex flex-col">
        <DialogHeader className="px-6 pt-2 pb-2 border-b border-border flex-shrink-0">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <WandIcon className="h-5 w-5 text-primary" />
              <DialogTitle className="text-lg font-semibold">{t("aiRewrite.title", { defaultValue: "AI Rewrite" })}</DialogTitle>
            </div>
            <div className="flex items-center gap-2">
              <Select value={action} onValueChange={(v) => setAction(v as AIAction)}>
                <SelectTrigger className="w-64 h-10 px-3 rounded-lg border border-border bg-background-solid hover:bg-secondary-solid transition-all text-sm font-medium shadow-sm [&_[data-option-icon]]:hidden">
                  <div className="flex w-full items-center justify-center gap-1.5">
                    {(() => {
                      const Icon = actionOptions.find((option) => option.value === action)?.icon;
                      return Icon ? <Icon className="h-4 w-4" aria-hidden="true" /> : null;
                    })()}
                    <SelectValue className="flex-1 text-center font-medium" />
                  </div>
                </SelectTrigger>
                <SelectContent className="w-64 bg-popover border border-border shadow-xl rounded-lg p-1">
                  {actionOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value} className="rounded-md">
                      <div className="flex w-full items-center justify-start gap-2">
                        <option.icon className="h-4 w-4" aria-hidden="true" data-option-icon />
                        <span className="font-medium flex-1 text-left">{option.label}</span>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 flex-1 overflow-hidden px-6 py-3 min-h-0">
          <div className="space-y-3 flex flex-col min-h-0">
            <Label className="text-sm font-medium text-foreground">{t("aiRewrite.originalText", { defaultValue: "Original Text" })}</Label>
            <div className="relative flex-1 min-h-0">
              <Textarea
                value={props.originalText}
                readOnly
                className="h-full w-full font-mono text-base resize-none bg-secondary-solid border-border rounded-md"
              />
              <div className="absolute bottom-3 right-3 text-xs text-muted-foreground bg-background-solid px-2.5 py-1.5 rounded border border-border shadow-sm">
                {t("aiRewrite.charCount", {
                  count: props.originalText.length,
                  defaultValue: "{{count}} chars",
                })}
              </div>
            </div>
          </div>

          <div className="space-y-3 flex flex-col min-h-0">
            <div className="flex items-center justify-between">
              <Label className="text-sm font-medium text-foreground">{t("aiRewrite.aiGenerated", { defaultValue: "AI Generated" })}</Label>
              {result && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleCopy}
                  className="h-8 px-3 text-sm"
                >
                  <CopyIcon className="mr-1.5 h-4 w-4" />
                  {t("aiRewrite.copy", { defaultValue: "Copy" })}
                </Button>
              )}
            </div>
            {loading ? (
              <div className="flex-1 min-h-0 flex items-center justify-center border border-border rounded-md bg-secondary-solid">
                <div className="text-center space-y-4">
                  <Loader2Icon className="h-12 w-12 animate-spin text-primary mx-auto" />
                  <div>
                    <p className="text-base font-medium text-foreground">{t("aiRewrite.status.generating", { defaultValue: "Generating with AI..." })}</p>
                    <p className="text-sm text-muted-foreground mt-1.5">{t("aiRewrite.status.generatingHint", { defaultValue: "This may take a moment" })}</p>
                  </div>
                </div>
              </div>
            ) : result ? (
              <div className="relative flex-1 min-h-0">
                <Textarea
                  value={result}
                  onChange={(e) => setResult(e.target.value)}
                  className="h-full w-full font-mono text-base resize-none bg-secondary-solid border-primary rounded-md"
                />
                <div className="absolute bottom-3 right-3 text-xs text-muted-foreground bg-background-solid px-2.5 py-1.5 rounded border border-border shadow-sm">
                  {t("aiRewrite.charCount", {
                    count: result.length,
                    defaultValue: "{{count}} chars",
                  })}
                </div>
              </div>
            ) : error ? (
              <div className="flex-1 min-h-0 flex items-center justify-center border border-destructive rounded-md bg-secondary-solid p-8">
                <div className="text-center space-y-4 max-w-lg">
                  <div className="p-4 rounded-full bg-destructive/10 w-fit mx-auto">
                    <p className="text-4xl">⚠️</p>
                  </div>
                  <div>
                    <p className="text-base font-semibold text-destructive">{t("aiRewrite.error.title", { defaultValue: "Error" })}</p>
                    <p className="text-sm text-muted-foreground mt-2 leading-relaxed">{error}</p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="flex-1 min-h-0 flex items-center justify-center border border-border border-dashed rounded-md bg-secondary-solid/50 text-muted-foreground">
                <div className="text-center space-y-4 px-12">
                  <div className="p-5 rounded-full bg-primary/5 w-fit mx-auto">
                    <WandIcon className="h-16 w-16 text-primary/40" />
                  </div>
                  <div>
                    <p className="text-lg font-medium text-foreground">{t("aiRewrite.state.readyTitle", { defaultValue: "Ready to Transform" })}</p>
                    <p className="text-sm text-muted-foreground mt-2">
                      {t("aiRewrite.state.readyDescription", { defaultValue: "Select an action above and click Generate" })}
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {action === "custom" && (
          <div className="space-y-2.5 px-6 py-3 border-t border-border bg-secondary-solid/30 flex-shrink-0">
            <Label className="text-sm font-medium text-foreground">{t("aiRewrite.customInstructions", { defaultValue: "Custom Instructions" })}</Label>
            <Textarea
              value={customPrompt}
              onChange={(e) => setCustomPrompt(e.target.value)}
              placeholder={t("aiRewrite.customPlaceholder", { defaultValue: "Describe what you want the AI to do with your text..." })}
              className="h-20 resize-none bg-background-solid border-border text-base rounded-md"
            />
          </div>
        )}

        <DialogFooter className="gap-3 px-6 py-2 border-t border-border flex-shrink-0">
          <Button 
            variant="secondary" 
            onClick={props.onClose}
            size="lg"
          >
            {t("aiRewrite.actions.cancel", { defaultValue: "Cancel" })}
          </Button>
          
          {result && (
            <>
              <Button 
                variant="secondary" 
                onClick={handleGenerate}
                size="lg"
              >
                <RefreshCwIcon className="mr-2 h-4 w-4" />
                {t("aiRewrite.actions.regenerate", { defaultValue: "Regenerate" })}
              </Button>
              <Button 
                variant="primary" 
                onClick={handleReplace}
                size="lg"
              >
                {t("aiRewrite.actions.replace", { defaultValue: "Replace Original" })}
              </Button>
            </>
          )}

          {!result && (
            <Button 
              variant="primary" 
              onClick={handleGenerate} 
              disabled={loading || (action === "custom" && !customPrompt)}
              size="lg"
            >
              {loading ? (
                <>
                  <Loader2Icon className="mr-2 h-5 w-5 animate-spin" />
                  {t("aiRewrite.status.generatingShort", { defaultValue: "Generating..." })}
                </>
              ) : (
                <>
                  <WandIcon className="mr-2 h-5 w-5" />
                  {t("aiRewrite.actions.generate", { defaultValue: "Generate with AI" })}
                </>
              )}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

