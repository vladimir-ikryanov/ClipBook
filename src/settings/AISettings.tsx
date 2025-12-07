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
import { OllamaProvider, OLLAMA_MODELS } from "@/ai/ollama-provider";
import { OpenAIProvider, OPENAI_MODELS } from "@/ai/openai-provider";
import { PerplexityProvider, PERPLEXITY_MODELS } from "@/ai/perplexity-provider";
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
import { CheckCircle, XCircle, Loader2 } from "lucide-react";

type ConnectionStatus = 'idle' | 'checking' | 'connected' | 'error';

export default function AISettings() {
  const { t } = useTranslation();
  
  const [enabled, setEnabled] = useState(false);
  const [provider, setProvider] = useState<AIProviderType>(AIProviderType.Ollama);
  const [apiKey, setAPIKey] = useState("");
  const [model, setModel] = useState("llama3.2");
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('idle');
  const [statusMessage, setStatusMessage] = useState("");

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
    setConnectionStatus('idle');
    setStatusMessage("");
    
    // Set default model for provider
    let defaultModel = "llama3.2";
    if (newProvider === AIProviderType.Ollama) {
      defaultModel = "llama3.2";
    } else if (newProvider === AIProviderType.OpenAI) {
      defaultModel = "gpt-4o-mini";
    } else if (newProvider === AIProviderType.Perplexity) {
      defaultModel = "sonar";
    }
    
    setModel(defaultModel);
    prefSetAIModel(defaultModel);
    updateAIService(newProvider, apiKey, defaultModel);
  };

  const handleAPIKeyChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newKey = e.target.value;
    setAPIKey(newKey);
    prefSetAIAPIKey(newKey);
    setConnectionStatus('idle');
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
      aiService.setProvider(AIProviderType.Ollama, new OllamaProvider({ model: mod }));
    } else if (prov === AIProviderType.OpenAI) {
      aiService.setProvider(AIProviderType.OpenAI, new OpenAIProvider({ apiKey: key, model: mod }));
    } else if (prov === AIProviderType.Perplexity) {
      aiService.setProvider(AIProviderType.Perplexity, new PerplexityProvider({ apiKey: key, model: mod }));
    }
    
    aiService.updateConfig({ provider: prov, apiKey: key, model: mod });
  };

  const testConnection = async () => {
    setConnectionStatus('checking');
    setStatusMessage("Testing connection...");
    
    try {
      const aiService = getAIService();
      const providerInstance = aiService.getProvider();
      
      if (!providerInstance) {
        setConnectionStatus('error');
        setStatusMessage("Provider not configured");
        return;
      }
      
      const isAvailable = await providerInstance.isAvailable();
      
      if (isAvailable) {
        setConnectionStatus('connected');
        setStatusMessage("Connected successfully!");
      } else {
        setConnectionStatus('error');
        if (provider === AIProviderType.Ollama) {
          setStatusMessage("Ollama not running. Start with: ollama serve");
        } else {
          setStatusMessage("Invalid API key or connection failed");
        }
      }
    } catch (error) {
      setConnectionStatus('error');
      setStatusMessage(error instanceof Error ? error.message : "Connection failed");
    }
  };

  const getProviderDescription = () => {
    switch (provider) {
      case AIProviderType.Ollama:
        return "Runs locally on your Mac. 100% private, no internet required. Free to use.";
      case AIProviderType.OpenAI:
        return "Cloud-based AI by OpenAI. Requires API key and internet. Best quality.";
      case AIProviderType.Perplexity:
        return "Cloud-based AI with web search. Great for research and current info.";
      default:
        return "";
    }
  };

  const renderModelOptions = () => {
    if (provider === AIProviderType.OpenAI) {
      return Object.entries(OPENAI_MODELS).map(([key, info]) => (
        <SelectItem key={key} value={key}>
          <div className="flex flex-col">
            <span>{info.name}</span>
            <span className="text-xs text-muted-foreground">{info.description}</span>
          </div>
        </SelectItem>
      ));
    }
    
    if (provider === AIProviderType.Ollama) {
      return Object.entries(OLLAMA_MODELS).map(([key, info]) => (
        <SelectItem key={key} value={key}>
          <div className="flex flex-col">
            <span>{info.name}</span>
            <span className="text-xs text-muted-foreground">{info.description}</span>
          </div>
        </SelectItem>
      ));
    }
    
    if (provider === AIProviderType.Perplexity) {
      return Object.entries(PERPLEXITY_MODELS).map(([key, info]) => (
        <SelectItem key={key} value={key}>
          <div className="flex flex-col">
            <span>{info.name}</span>
            <span className="text-xs text-muted-foreground">{info.description}</span>
          </div>
        </SelectItem>
      ));
    }
    
    return null;
  };

  return (
    <div className="flex h-screen select-none">
      <div className="flex flex-col flex-grow">
        <div className="flex pt-8 px-8 border-b border-b-border">
          <span className="text-2xl pb-3 font-semibold">AI Rewrite</span>
        </div>

        <div className="flex flex-col px-8 pb-8 gap-4 flex-grow overflow-y-auto">
          {/* Enable/Disable */}
          <div className="flex items-center justify-between pt-6 pb-1">
            <Label htmlFor="ai-enabled" className="flex flex-col text-base">
              <span>Enable AI Rewrite</span>
              <span className="text-neutral-500 font-normal text-sm">
                Use AI to transform, improve, and rewrite clipboard text
              </span>
            </Label>
            <Switch id="ai-enabled" checked={enabled} onCheckedChange={handleEnabledChange} />
          </div>

          {enabled && (
            <>
              {/* Provider Selection */}
              <div className="space-y-2 pt-4">
                <Label className="text-base">AI Provider</Label>
                <Select value={provider} onValueChange={handleProviderChange}>
                  <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ollama">
                      <div className="flex items-center gap-2">
                        <span>🦙</span>
                        <span>Ollama (Local, Free)</span>
                      </div>
                    </SelectItem>
                    <SelectItem value="openai">
                      <div className="flex items-center gap-2">
                        <span>🤖</span>
                        <span>OpenAI (GPT-4o, O1)</span>
                      </div>
                    </SelectItem>
                    <SelectItem value="perplexity">
                      <div className="flex items-center gap-2">
                        <span>🔍</span>
                        <span>Perplexity (Sonar + Search)</span>
                      </div>
                    </SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  {getProviderDescription()}
                </p>
              </div>

              {/* API Key (for cloud providers) */}
              {provider !== "ollama" && (
                <div className="space-y-2">
                  <Label className="text-base">API Key</Label>
                  <div className="flex gap-2">
                    <Input
                      type="password"
                      value={apiKey}
                      onChange={handleAPIKeyChange}
                      placeholder="Enter your API key..."
                      className="bg-secondary-solid flex-1"
                    />
                    <Button 
                      variant="outline" 
                      onClick={testConnection}
                      disabled={!apiKey || connectionStatus === 'checking'}
                    >
                      {connectionStatus === 'checking' ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : (
                        "Test"
                      )}
                    </Button>
                  </div>
                  
                  {/* Connection Status */}
                  {connectionStatus !== 'idle' && (
                    <div className={`flex items-center gap-2 text-xs ${
                      connectionStatus === 'connected' ? 'text-green-500' :
                      connectionStatus === 'error' ? 'text-red-500' :
                      'text-muted-foreground'
                    }`}>
                      {connectionStatus === 'connected' && <CheckCircle className="h-3 w-3" />}
                      {connectionStatus === 'error' && <XCircle className="h-3 w-3" />}
                      {connectionStatus === 'checking' && <Loader2 className="h-3 w-3 animate-spin" />}
                      {statusMessage}
                    </div>
                  )}
                  
                  <p className="text-xs text-muted-foreground">
                    Your API key is stored locally and never shared.
                  </p>
                </div>
              )}

              {/* Model Selection */}
              <div className="space-y-2">
                <Label className="text-base">Model</Label>
                <Select value={model} onValueChange={handleModelChange}>
                  <SelectTrigger className="w-full h-10 px-3 rounded-md border border-input bg-background">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {renderModelOptions()}
                  </SelectContent>
                </Select>
              </div>

              {/* Test Connection for Ollama */}
              {provider === "ollama" && (
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    <Button 
                      variant="outline" 
                      onClick={testConnection}
                      disabled={connectionStatus === 'checking'}
                      size="sm"
                    >
                      {connectionStatus === 'checking' ? (
                        <>
                          <Loader2 className="h-4 w-4 animate-spin mr-2" />
                          Checking...
                        </>
                      ) : (
                        "Test Ollama Connection"
                      )}
                    </Button>
                    
                    {connectionStatus !== 'idle' && (
                      <span className={`flex items-center gap-1 text-xs ${
                        connectionStatus === 'connected' ? 'text-green-500' :
                        connectionStatus === 'error' ? 'text-red-500' :
                        'text-muted-foreground'
                      }`}>
                        {connectionStatus === 'connected' && <CheckCircle className="h-3 w-3" />}
                        {connectionStatus === 'error' && <XCircle className="h-3 w-3" />}
                        {statusMessage}
                      </span>
                    )}
                  </div>
                </div>
              )}

              {/* Setup Instructions */}
              <div className="text-sm space-y-4 border-t pt-6 mt-4">
                <div className="rounded-lg bg-secondary-solid/50 p-4 space-y-3">
                  <p className="font-semibold text-base flex items-center gap-2">
                    {provider === "ollama" && "🦙"}
                    {provider === "openai" && "🤖"}
                    {provider === "perplexity" && "🔍"}
                    Getting Started
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
                            <code className="block mt-1 text-xs bg-background px-2 py-1 rounded border border-border">ollama pull {model}</code>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">3.</span>
                          <div>
                            <span className="font-medium">Start Ollama:</span>
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
                            <a href="https://www.perplexity.ai/settings/api" target="_blank" rel="noopener noreferrer" className="block mt-1 text-xs text-primary hover:underline">
                              https://www.perplexity.ai/settings/api
                            </a>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">2.</span>
                          <div>
                            <span className="font-medium">Features:</span>
                            <p className="text-xs text-muted-foreground mt-1">
                              ✓ Real-time web search<br/>
                              ✓ Streaming responses<br/>
                              ✓ Current information
                            </p>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">3.</span>
                          <div>
                            <span className="font-medium">Pricing:</span>
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
                            <a href="https://platform.openai.com/api-keys" target="_blank" rel="noopener noreferrer" className="block mt-1 text-xs text-primary hover:underline">
                              https://platform.openai.com/api-keys
                            </a>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">2.</span>
                          <div>
                            <span className="font-medium">Features:</span>
                            <p className="text-xs text-muted-foreground mt-1">
                              ✓ Best quality output<br/>
                              ✓ Streaming responses<br/>
                              ✓ Advanced reasoning (O1)
                            </p>
                          </div>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-primary font-semibold mt-0.5">3.</span>
                          <div>
                            <span className="font-medium">Pricing:</span>
                            <p className="text-xs text-muted-foreground mt-1">
                              GPT-4o Mini: ~$0.0001/request<br/>
                              GPT-4o: ~$0.005/request
                            </p>
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
