// AI Service - Core provider abstraction with streaming support

import { AIConversationContext } from './ai-context';

export interface StreamCallbacks {
  onChunk: (chunk: string) => void;
  onComplete: (fullText: string) => void;
  onError: (error: Error) => void;
}

// Context messages for multi-turn conversations
export interface ContextMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface AIProvider {
  name: string;
  rewrite(text: string, instruction: string, contextMessages?: ContextMessage[]): Promise<string>;
  rewriteStream?(
    text: string,
    instruction: string,
    callbacks: StreamCallbacks,
    contextMessages?: ContextMessage[]
  ): Promise<void>;
  isAvailable(): Promise<boolean>;
  supportsStreaming(): boolean;
  // Vision capabilities
  supportsVision?(): boolean;
  analyzeImage?(imageBase64: string, prompt: string): Promise<string>;
}

export enum AIProviderType {
  OpenAI = "openai",
  Ollama = "ollama",
  Perplexity = "perplexity"
}

export interface AIConfig {
  provider: AIProviderType;
  apiKey?: string;
  model?: string;
  temperature?: number;
  maxTokens?: number;
  // Perplexity-specific options
  returnCitations?: boolean;
  searchRecencyFilter?: 'day' | 'week' | 'month' | 'year';
  searchDomains?: string[];
}

export class AIService {
  private providers: Map<AIProviderType, AIProvider>;
  private config: AIConfig;
  private cache: Map<string, { response: string; timestamp: number }> = new Map();
  private cacheMaxAge: number = 5 * 60 * 1000; // 5 minutes

  constructor(config: AIConfig) {
    this.config = config;
    this.providers = new Map();
  }

  private getCacheKey(text: string, instruction: string): string {
    return `${this.config.provider}:${this.config.model}:${instruction}:${text}`.substring(0, 500);
  }

  async rewrite(text: string, instruction: string, context?: AIConversationContext): Promise<string> {
    const provider = this.getProvider();
    if (!provider) {
      throw new Error("AI provider not configured");
    }

    const isAvailable = await provider.isAvailable();
    if (!isAvailable) {
      throw new Error(`${provider.name} is not available`);
    }

    // Skip cache if context exists (follow-up conversations should be fresh)
    if (!context || context.isEmpty()) {
      const cacheKey = this.getCacheKey(text, instruction);
      const cached = this.cache.get(cacheKey);
      if (cached && Date.now() - cached.timestamp < this.cacheMaxAge) {
        return cached.response;
      }
    }

    const contextMessages = context?.getMessagesForAPI();
    const response = await this.rewriteWithRetry(provider, text, instruction, 3, contextMessages);
    
    // Only cache if no context (single-turn requests)
    if (!context || context.isEmpty()) {
      const cacheKey = this.getCacheKey(text, instruction);
      this.cache.set(cacheKey, { response, timestamp: Date.now() });
    }
    
    return response;
  }

  async rewriteStream(
    text: string,
    instruction: string,
    callbacks: StreamCallbacks,
    context?: AIConversationContext
  ): Promise<void> {
    const provider = this.getProvider();
    if (!provider) {
      callbacks.onError(new Error("AI provider not configured"));
      return;
    }

    const isAvailable = await provider.isAvailable();
    if (!isAvailable) {
      callbacks.onError(new Error(`${provider.name} is not available`));
      return;
    }

    const contextMessages = context?.getMessagesForAPI();

    if (!provider.supportsStreaming() || !provider.rewriteStream) {
      // Fallback to non-streaming
      try {
        const result = await provider.rewrite(text, instruction, contextMessages);
        callbacks.onChunk(result);
        callbacks.onComplete(result);
      } catch (error) {
        callbacks.onError(error as Error);
      }
      return;
    }

    await provider.rewriteStream(text, instruction, callbacks, contextMessages);
  }

  private async rewriteWithRetry(
    provider: AIProvider,
    text: string,
    instruction: string,
    maxRetries: number = 3,
    contextMessages?: ContextMessage[]
  ): Promise<string> {
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await provider.rewrite(text, instruction, contextMessages);
      } catch (error) {
        lastError = error as Error;

        // Check if retryable (rate limit errors)
        if (this.isRateLimitError(error)) {
          const delay = Math.pow(2, attempt) * 1000; // Exponential backoff
          await this.sleep(delay);
          continue;
        }

        // Non-retryable error, throw immediately
        throw error;
      }
    }

    throw lastError || new Error("Max retries exceeded");
  }

  private isRateLimitError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      error?.status === 429 ||
      message.includes('rate limit') ||
      message.includes('too many requests') ||
      message.includes('quota exceeded')
    );
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  getProvider(): AIProvider | undefined {
    return this.providers.get(this.config.provider);
  }

  setProvider(type: AIProviderType, provider: AIProvider) {
    this.providers.set(type, provider);
  }

  updateConfig(config: Partial<AIConfig>) {
    this.config = { ...this.config, ...config };
  }

  getConfig(): AIConfig {
    return this.config;
  }

  clearCache() {
    this.cache.clear();
  }

  supportsStreaming(): boolean {
    const provider = this.getProvider();
    return provider?.supportsStreaming() ?? false;
  }

  supportsVision(): boolean {
    const provider = this.getProvider();
    return provider?.supportsVision?.() ?? false;
  }

  async analyzeImage(imageBase64: string, prompt: string): Promise<string> {
    const provider = this.getProvider();
    if (!provider) {
      throw new Error("AI provider not configured");
    }

    if (!provider.supportsVision?.() || !provider.analyzeImage) {
      throw new Error(`${provider.name} does not support image analysis`);
    }

    const isAvailable = await provider.isAvailable();
    if (!isAvailable) {
      throw new Error(`${provider.name} is not available`);
    }

    return await provider.analyzeImage(imageBase64, prompt);
  }
}

let aiService: AIService | null = null;

export function getAIService(): AIService {
  if (!aiService) {
    aiService = new AIService({
      provider: AIProviderType.Ollama,
      temperature: 0.7,
      maxTokens: 2000
    });
  }
  return aiService;
}

export function resetAIService(): void {
  aiService = null;
}
