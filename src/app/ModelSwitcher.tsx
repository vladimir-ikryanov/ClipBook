/**
 * ModelSwitcher - Quick model selection in AI dialogs
 * 
 * Shows only models for the currently configured provider.
 * Allows quick switching without going to settings.
 */

import React from "react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { AIProviderType, getAIService } from "@/ai/ai-service";
import { OLLAMA_MODELS, OllamaProvider } from "@/ai/ollama-provider";
import { OPENAI_MODELS, OpenAIProvider } from "@/ai/openai-provider";
import { PERPLEXITY_MODELS, PerplexityProvider } from "@/ai/perplexity-provider";
import { prefGetAIProvider, prefGetAIModel, prefSetAIModel, prefGetAIAPIKey } from "@/pref";
import { Cpu, Sparkles, Search, Eye } from "lucide-react";

interface ModelSwitcherProps {
  onModelChange?: (model: string) => void;
  showVisionOnly?: boolean; // Only show models that support vision
  compact?: boolean;
}

export default function ModelSwitcher({ onModelChange, showVisionOnly = false, compact = true }: ModelSwitcherProps) {
  const [currentModel, setCurrentModel] = React.useState(prefGetAIModel());
  const [provider] = React.useState(prefGetAIProvider() as AIProviderType);

  const handleModelChange = (model: string) => {
    setCurrentModel(model);
    prefSetAIModel(model);
    
    // Update the AI service with new model
    const aiService = getAIService();
    const apiKey = prefGetAIAPIKey();
    
    if (provider === AIProviderType.Ollama) {
      aiService.setProvider(AIProviderType.Ollama, new OllamaProvider({ model }));
    } else if (provider === AIProviderType.OpenAI) {
      aiService.setProvider(AIProviderType.OpenAI, new OpenAIProvider({ apiKey, model }));
    } else if (provider === AIProviderType.Perplexity) {
      aiService.setProvider(AIProviderType.Perplexity, new PerplexityProvider({ apiKey, model }));
    }
    
    aiService.updateConfig({ model });
    onModelChange?.(model);
  };

  const getProviderIcon = () => {
    switch (provider) {
      case AIProviderType.Ollama:
        return <Cpu className="h-3 w-3" />;
      case AIProviderType.OpenAI:
        return <Sparkles className="h-3 w-3" />;
      case AIProviderType.Perplexity:
        return <Search className="h-3 w-3" />;
      default:
        return null;
    }
  };

  const getModels = () => {
    let models: { key: string; name: string; description: string; supportsVision?: boolean }[] = [];
    
    if (provider === AIProviderType.Ollama) {
      models = Object.entries(OLLAMA_MODELS).map(([key, info]) => ({
        key,
        name: info.name,
        description: info.description,
        supportsVision: false
      }));
    } else if (provider === AIProviderType.OpenAI) {
      models = Object.entries(OPENAI_MODELS).map(([key, info]) => ({
        key,
        name: info.name,
        description: info.description,
        supportsVision: key.includes('gpt-4o')
      }));
    } else if (provider === AIProviderType.Perplexity) {
      models = Object.entries(PERPLEXITY_MODELS).map(([key, info]) => ({
        key,
        name: info.name,
        description: info.description,
        supportsVision: info.supportsVision
      }));
    }
    
    // Filter to vision-only if requested
    if (showVisionOnly) {
      models = models.filter(m => m.supportsVision);
    }
    
    return models;
  };

  const models = getModels();
  const currentModelInfo = models.find(m => m.key === currentModel);

  // If no models available for this provider, don't render
  if (models.length === 0) {
    return null;
  }

  return (
    <Select value={currentModel} onValueChange={handleModelChange}>
      <SelectTrigger className={`${compact ? 'h-6 text-[10px] min-w-[110px] max-w-[150px]' : 'h-7 text-xs w-36'} gap-1.5 px-2 rounded-md border border-border bg-secondary/50 hover:bg-secondary/80 transition-colors`}>
        {getProviderIcon()}
        <SelectValue>
          <span className="truncate">{currentModelInfo?.name || currentModel}</span>
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        {models.map((model) => (
          <SelectItem key={model.key} value={model.key} className="text-xs py-1.5">
            <div className="flex items-center gap-2">
              <div className="flex flex-col">
                <span className="flex items-center gap-1">
                  {model.name}
                  {model.supportsVision && (
                    <Eye className="h-3 w-3 text-primary" />
                  )}
                </span>
                {!compact && (
                  <span className="text-[10px] text-muted-foreground">{model.description}</span>
                )}
              </div>
            </div>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
