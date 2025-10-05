export interface AIProvider {
  name: string;
  rewrite(text: string, instruction: string): Promise<string>;
  isAvailable(): Promise<boolean>;
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
}

export class AIService {
  private providers: Map<AIProviderType, AIProvider>;
  private config: AIConfig;

  constructor(config: AIConfig) {
    this.config = config;
    this.providers = new Map();
  }

  async rewrite(text: string, instruction: string): Promise<string> {
    const provider = this.getProvider();
    if (!provider) {
      throw new Error("AI provider not configured");
    }

    const isAvailable = await provider.isAvailable();
    if (!isAvailable) {
      throw new Error(`${provider.name} is not available`);
    }

    return provider.rewrite(text, instruction);
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

