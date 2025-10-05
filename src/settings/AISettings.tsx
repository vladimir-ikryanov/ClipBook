import * as React from "react";
import { useState, useEffect } from "react";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { AIProviderType, getAIService } from "@/ai/ai-service";
import { OllamaProvider } from "@/ai/ollama-provider";
import { OpenAIProvider } from "@/ai/openai-provider";
import { PerplexityProvider } from "@/ai/perplexity-provider";
import { useTranslation } from 'react-i18next';
import { 
  prefIsAIEnabled, 
  prefSetAIEnabled,
  prefGetAIProvider,
  prefSetAIProvider,
  prefGetAIAPIKey,
  prefSetAIAPIKey,
  prefGetAIModel,
  prefSetAIModel
} from "@/pref";

export default function AISettings() {
  const { t } = useTranslation();
  
  const [enabled, setEnabled] = useState(false);
  const [provider, setProvider] = useState<AIProviderType>(AIProviderType.Ollama);
  const [apiKey, setAPIKey] = useState("");
  const [model, setModel] = useState("llama3.2");

  useEffect(() => {
    setEnabled(prefIsAIEnabled());
    setProvider(prefGetAIProvider() as AIProviderType || AIProviderType.Ollama);
    setAPIKey(prefGetAIAPIKey() || "");
    setModel(prefGetAIModel() || "llama3.2");
  }, []);

  const handleEnabledChange = (checked: boolean) => {
    setEnabled(checked);
    prefSetAIEnabled(checked);
  };

  const handleProviderChange = (value: string) => {
    const newProvider = value as AIProviderType;
    setProvider(newProvider);
    prefSetAIProvider(value);
    
    if (newProvider === AIProviderType.Ollama) {
      setModel("llama3.2");
      prefSetAIModel("llama3.2");
    } else if (newProvider === AIProviderType.OpenAI) {
      setModel("gpt-3.5-turbo");
      prefSetAIModel("gpt-3.5-turbo");
    } else if (newProvider === AIProviderType.Perplexity) {
      setModel("sonar");
      prefSetAIModel("sonar");
    }

    updateAIService(
      newProvider, 
      apiKey, 
      newProvider === AIProviderType.Ollama ? "llama3.2" : 
      newProvider === AIProviderType.Perplexity ? "sonar" : 
      "gpt-3.5-turbo"
    );
  };

  const handleAPIKeyChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newKey = e.target.value;
    setAPIKey(newKey);
    prefSetAIAPIKey(newKey);
    updateAIService(provider, newKey, model);
  };

  const handleModelChange = (value: string) => {
    setModel(value);
    prefSetAIModel(value);
    updateAIService(provider, apiKey, value);
  };

  const updateAIService = (prov: AIProviderType, key: string, mod: string) => {
    const aiService = getAIService();
    
    if (prov === AIProviderType.Ollama) {
      aiService.setProvider(AIProviderType.Ollama, new OllamaProvider(mod));
    } else if (prov === AIProviderType.OpenAI) {
      aiService.setProvider(AIProviderType.OpenAI, new OpenAIProvider(key, mod));
    } else if (prov === AIProviderType.Perplexity) {
      aiService.setProvider(AIProviderType.Perplexity, new PerplexityProvider(key, mod));
    }
    
    aiService.updateConfig({ provider: prov, apiKey: key, model: mod });
  };

  return (
    <div className="flex h-screen select-none">
      <div className="flex flex-col flex-grow">
        <div className="flex pt-8 px-8 border-b border-b-border">
          <span className="text-2xl pb-3 font-semibold">AI Rewrite</span>
        </div>

        <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto">
          <div className="flex items-center justify-between pt-6 pb-1">
            <Label htmlFor="ai-enabled" className="flex flex-col text-base">
              <span>Enable AI Rewrite</span>
              <span className="text-neutral-500 font-normal text-sm">
                Use AI to improve and rewrite clipboard text
              </span>
            </Label>
            <Switch id="ai-enabled" checked={enabled} onCheckedChange={handleEnabledChange} />
          </div>

          {enabled && (
            <>
              <div className="space-y-2 pt-4">
                <Label className="text-base">AI Provider</Label>
                <Select value={provider} onValueChange={handleProviderChange}>
                  <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ollama">Ollama (Local, Free)</SelectItem>
                    <SelectItem value="openai">OpenAI (GPT-3.5/GPT-4)</SelectItem>
                    <SelectItem value="perplexity">Perplexity (Sonar)</SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  {provider === "ollama" 
                    ? "Runs locally on your Mac, 100% private, no internet required"
                    : provider === "perplexity"
                    ? "Cloud-based with web search, requires API key and internet"
                    : "Cloud-based, requires API key and internet connection"
                  }
                </p>
              </div>

              {provider !== "ollama" && (
                <div className="space-y-2">
                  <Label className="text-base">API Key</Label>
                  <Input
                    type="password"
                    value={apiKey}
                    onChange={handleAPIKeyChange}
                    placeholder="Enter your API key..."
                    className="bg-secondary-solid"
                  />
                  <p className="text-xs text-muted-foreground">
                    Your API key is stored locally and never shared
                  </p>
                </div>
              )}

              <div className="space-y-2">
                <Label className="text-base">Model</Label>
                {provider === "openai" && (
                  <Select value={model} onValueChange={handleModelChange}>
                    <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="gpt-3.5-turbo">GPT-3.5 Turbo (Fast, Cheap)</SelectItem>
                      <SelectItem value="gpt-4">GPT-4 (Best Quality)</SelectItem>
                      <SelectItem value="gpt-4-turbo-preview">GPT-4 Turbo (Balanced)</SelectItem>
                    </SelectContent>
                  </Select>
                )}
                {provider === "ollama" && (
                  <Select value={model} onValueChange={handleModelChange}>
                    <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="llama3.2">Llama 3.2 (Recommended)</SelectItem>
                      <SelectItem value="mistral">Mistral 7B</SelectItem>
                      <SelectItem value="phi3">Phi-3 (Lightweight)</SelectItem>
                    </SelectContent>
                  </Select>
                )}
                {provider === "perplexity" && (
                  <Select value={model} onValueChange={handleModelChange}>
                    <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="sonar">Sonar (Recommended)</SelectItem>
                      <SelectItem value="sonar-pro">Sonar Pro (Advanced)</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              </div>

              <div className="text-sm space-y-4 border-t pt-6 mt-6">
                <div className="rounded-lg bg-secondary-solid/50 p-4 space-y-3">
                  <p className="font-semibold text-base flex items-center gap-2">
                    {provider === "ollama" && "🦙"}
                    {provider === "openai" && "🤖"}
                    {provider === "perplexity" && "🔍"}
                    Getting Started with {provider === "ollama" ? "Ollama" : provider === "perplexity" ? "Perplexity" : "OpenAI"}
                  </p>
                  <ul className="space-y-2 pl-1">
                    {provider === "ollama" ? (
                      <>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">1.</span>
                          <div>
                            <span className="font-medium">Install Ollama:</span>
                            <code className="block mt-1 text-xs bg-background px-2 py-1 rounded border border-border">brew install ollama</code>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">2.</span>
                          <div>
                            <span className="font-medium">Pull a model:</span>
                            <code className="block mt-1 text-xs bg-background px-2 py-1 rounded border border-border">ollama pull llama3.2</code>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">3.</span>
                          <div>
                            <span className="font-medium">Start Ollama service:</span>
                            <code className="block mt-1 text-xs bg-background px-2 py-1 rounded border border-border">ollama serve</code>
                            <p className="text-xs text-muted-foreground mt-1">Keep this running in the background</p>
                          </div>
                        </li>
                      </>
                    ) : provider === "perplexity" ? (
                      <>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">1.</span>
                          <div>
                            <span className="font-medium">Get API key:</span>
                            <a href="https://www.perplexity.ai/settings/api" target="_blank" className="block mt-1 text-xs text-primary hover:underline">
                              https://www.perplexity.ai/settings/api
                            </a>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">2.</span>
                          <div>
                            <span className="font-medium">Features:</span>
                            <p className="text-xs text-muted-foreground mt-1">Web search + Real-time data access</p>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">3.</span>
                          <div>
                            <span className="font-medium">Cost:</span>
                            <p className="text-xs text-muted-foreground mt-1">~$0.001 per request (Sonar)</p>
                          </div>
                        </li>
                      </>
                    ) : (
                      <>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">1.</span>
                          <div>
                            <span className="font-medium">Get API key:</span>
                            <a href="https://platform.openai.com/api-keys" target="_blank" className="block mt-1 text-xs text-primary hover:underline">
                              https://platform.openai.com/api-keys
                            </a>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">2.</span>
                          <div>
                            <span className="font-medium">Cost:</span>
                            <p className="text-xs text-muted-foreground mt-1">~$0.0003 per rewrite (GPT-3.5)</p>
                          </div>
                        </li>
                      </>
                    )}
                  </ul>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

