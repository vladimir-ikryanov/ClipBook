/**
 * ImageAnalysisDialog - AI-powered image analysis
 * 
 * This dialog allows users to analyze images in their clipboard
 * using GPT-4o vision capabilities.
 */

import '../app.css';
import * as React from "react";
import { useState, useEffect } from "react";
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
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getAIService } from "@/ai/ai-service";
import { IMAGE_ACTIONS, getImageActionPrompt } from "@/ai/prompts/image-prompts";
import {
  ImageIcon,
  CopyIcon,
  Loader2Icon,
  AlertCircle,
  CheckIcon,
  Eye,
  FileText,
  Search,
  Table2,
  BarChart3,
} from "lucide-react";
import { useTranslation } from 'react-i18next';
import { VisuallyHidden } from "@radix-ui/react-visually-hidden";
import ModelSwitcher from "./ModelSwitcher";

interface ImageAnalysisDialogProps {
  open: boolean;
  onClose: () => void;
  imageBase64: string; // The image data URL (data:image/...)
  onInsertResult?: (text: string) => void;
}

// Icon mapping for image actions
const ACTION_ICONS: Record<string, React.ReactNode> = {
  describeImage: <Eye className="h-3.5 w-3.5" />,
  extractText: <FileText className="h-3.5 w-3.5" />,
  analyzeContent: <Search className="h-3.5 w-3.5" />,
  summarizeDocument: <FileText className="h-3.5 w-3.5" />,
  extractData: <Table2 className="h-3.5 w-3.5" />,
  explainDiagram: <BarChart3 className="h-3.5 w-3.5" />,
};

export default function ImageAnalysisDialog(props: ImageAnalysisDialogProps) {
  const { t } = useTranslation();

  const [action, setAction] = useState<string>("describeImage");
  const [result, setResult] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);
  const [currentImage, setCurrentImage] = useState<string>("");
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    if (props.open) {
      setAction("describeImage");
      setResult("");
      setError("");
      setCopied(false);
      setCurrentImage(props.imageBase64 || "");
      setIsDragging(false);
    }
  }, [props.open, props.imageBase64]);

  // Handle paste from clipboard
  const handlePaste = async (e: React.ClipboardEvent | ClipboardEvent) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    for (const item of items) {
      if (item.type.startsWith('image/')) {
        e.preventDefault();
        const blob = item.getAsFile();
        if (blob) {
          const reader = new FileReader();
          reader.onload = (event) => {
            const dataUrl = event.target?.result as string;
            setCurrentImage(dataUrl);
            setResult(""); // Clear previous result
          };
          reader.readAsDataURL(blob);
        }
        break;
      }
    }
  };

  // Handle drag and drop
  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);

    const files = e.dataTransfer.files;
    if (files.length > 0) {
      const file = files[0];
      if (file.type.startsWith('image/')) {
        const reader = new FileReader();
        reader.onload = (event) => {
          const dataUrl = event.target?.result as string;
          setCurrentImage(dataUrl);
          setResult(""); // Clear previous result
        };
        reader.readAsDataURL(file);
      }
    }
  };

  // Add global paste listener when dialog is open
  useEffect(() => {
    if (props.open) {
      const handleGlobalPaste = (e: ClipboardEvent) => handlePaste(e);
      document.addEventListener('paste', handleGlobalPaste);
      return () => document.removeEventListener('paste', handleGlobalPaste);
    }
  }, [props.open]);

  const handleAnalyze = async () => {
    if (!currentImage) {
      setError('No image to analyze. Paste or drop an image first.');
      return;
    }

    setLoading(true);
    setError("");
    setResult("");

    try {
      const aiService = getAIService();
      const provider = aiService.getProvider();
      
      if (!provider) {
        throw new Error('AI provider not configured. Go to Settings → AI');
      }
      
      if (!aiService.supportsVision()) {
        throw new Error('Current AI provider does not support image analysis. Use OpenAI with gpt-4o, gpt-4o-mini, or Perplexity with sonar-pro.');
      }
      
      const isAvailable = await provider.isAvailable();
      if (!isAvailable) {
        throw new Error('AI provider not available. Check your API key in Settings → AI');
      }

      const prompt = getImageActionPrompt(action);
      const response = await aiService.analyzeImage(currentImage, prompt);
      
      setResult(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = () => {
    if (result) {
      navigator.clipboard.writeText(result);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }
  };

  const handleInsert = () => {
    if (result && props.onInsertResult) {
      props.onInsertResult(result);
      props.onClose();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    e.stopPropagation();
    if (e.key === "Escape") props.onClose();
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter" && !loading) handleAnalyze();
  };

  const selectedAction = IMAGE_ACTIONS.find(a => a.id === action);

  return (
    <Dialog open={props.open} onOpenChange={(open) => !open && props.onClose()}>
      <DialogContent 
        onKeyDown={handleKeyDown} 
        className="max-w-3xl w-[min(750px,calc(100vw-2rem))] p-0 gap-0 overflow-hidden"
      >
        <VisuallyHidden>
          <DialogTitle>Image Analysis</DialogTitle>
          <DialogDescription>Analyze images with AI</DialogDescription>
        </VisuallyHidden>
        
        {/* Header */}
        <div className="px-3 py-2 border-b border-border flex items-center justify-between bg-secondary/30">
          <div className="flex items-center gap-2">
            <ImageIcon className="h-4 w-4 text-primary" />
            <span className="text-sm font-medium">Image Analysis</span>
            <ModelSwitcher compact showVisionOnly />
          </div>
          
          <div className="flex items-center gap-2">
            <Select value={action} onValueChange={setAction}>
              <SelectTrigger className="w-48 h-7 text-xs">
                <SelectValue>
                  <div className="flex items-center gap-1.5">
                    {ACTION_ICONS[action]}
                    <span>{selectedAction?.label || 'Select action'}</span>
                  </div>
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {IMAGE_ACTIONS.map((imageAction) => (
                  <SelectItem key={imageAction.id} value={imageAction.id} className="text-xs py-1.5">
                    <div className="flex items-center gap-1.5">
                      {ACTION_ICONS[imageAction.id]}
                      <span>{imageAction.label}</span>
                    </div>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            
            <span className="text-[10px] text-muted-foreground">
              <kbd className="px-1.5 py-0.5 bg-secondary rounded text-[10px] font-medium">⌘↵</kbd>
            </span>
          </div>
        </div>

        {/* Main content */}
        <div className="flex min-h-[280px] max-h-[380px] h-[45vh]">
          {/* Image preview / drop zone */}
          <div 
            className="w-1/2 flex flex-col border-r border-border"
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <div className="px-3 py-1.5 border-b border-border bg-secondary/20 flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">Image</span>
              <span className="text-[10px] text-muted-foreground">Paste or drop to change</span>
            </div>
            <div className={`flex-1 flex items-center justify-center p-4 overflow-hidden transition-colors ${
              isDragging ? 'bg-primary/10 border-2 border-dashed border-primary' : 'bg-secondary/10'
            }`}>
              {currentImage ? (
                <img 
                  src={currentImage} 
                  alt="Image to analyze" 
                  className="max-w-full max-h-full object-contain rounded"
                />
              ) : (
                <div className="text-center">
                  <ImageIcon className="h-12 w-12 text-muted-foreground/30 mx-auto" />
                  <p className="text-xs text-muted-foreground mt-2">
                    {isDragging ? 'Drop image here' : 'Paste (⌘V) or drop an image'}
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* Result */}
          <div className="w-1/2 flex flex-col">
            <div className="px-3 py-1.5 border-b border-border bg-secondary/20 flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">
                {loading ? "Analyzing..." : "Result"}
              </span>
              {result && (
                <button 
                  onClick={handleCopy}
                  className="text-[10px] text-muted-foreground hover:text-foreground flex items-center gap-0.5"
                >
                  {copied ? <CheckIcon className="h-3 w-3 text-green-500" /> : <CopyIcon className="h-3 w-3" />}
                  {copied ? 'Copied' : 'Copy'}
                </button>
              )}
            </div>
            
            {loading ? (
              <div className="flex-1 flex items-center justify-center">
                <div className="text-center">
                  <Loader2Icon className="h-8 w-8 animate-spin text-primary mx-auto" />
                  <p className="text-xs text-muted-foreground mt-2">Analyzing image...</p>
                </div>
              </div>
            ) : error ? (
              <div className="flex-1 flex items-center justify-center p-4">
                <div className="text-center max-w-xs">
                  <AlertCircle className="h-8 w-8 text-destructive mx-auto" />
                  <p className="text-xs text-destructive mt-2">{error}</p>
                </div>
              </div>
            ) : result ? (
              <Textarea
                value={result}
                onChange={(e) => setResult(e.target.value)}
                className="flex-1 border-0 rounded-none resize-none text-sm focus-visible:ring-0 bg-transparent"
              />
            ) : (
              <div className="flex-1 flex items-center justify-center">
                <div className="text-center">
                  <ImageIcon className="h-8 w-8 text-muted-foreground/30 mx-auto" />
                  <p className="text-xs text-muted-foreground mt-2">
                    {selectedAction?.description || 'Select action & Analyze'}
                  </p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="px-3 py-2 border-t border-border flex items-center justify-end gap-1.5 bg-secondary/30">
          <Button variant="ghost" size="sm" onClick={props.onClose} className="h-7 px-2 text-xs">
            Cancel
          </Button>
          
          {result ? (
            <>
              <Button variant="secondary" size="sm" onClick={handleAnalyze} disabled={loading} className="h-7 px-2 text-xs">
                Re-analyze
              </Button>
              {props.onInsertResult && (
                <Button size="sm" onClick={handleInsert} className="h-7 px-3 text-xs">
                  Insert Text
                </Button>
              )}
            </>
          ) : (
            <Button 
              size="sm"
              onClick={handleAnalyze} 
              disabled={loading}
              className="h-7 px-3 text-xs"
            >
              {loading ? (
                <Loader2Icon className="h-3 w-3 mr-1 animate-spin" />
              ) : (
                <Eye className="h-3 w-3 mr-1" />
              )}
              Analyze
            </Button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
