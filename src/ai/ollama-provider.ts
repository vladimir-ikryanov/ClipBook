import { AIProvider, StreamCallbacks, ContextMessage } from './ai-service';

export interface OllamaConfig {
  model?: string;
  temperature?: number;
  baseUrl?: string;
}

// Popular Ollama models
export const OLLAMA_MODELS = {
  'llama3.2': { name: 'Llama 3.2', description: 'Latest Llama, recommended' },
  'llama3.1': { name: 'Llama 3.1', description: 'Powerful, larger context' },
  'mistral': { name: 'Mistral 7B', description: 'Fast and capable' },
  'mixtral': { name: 'Mixtral 8x7B', description: 'Mixture of experts' },
  'phi3': { name: 'Phi-3', description: 'Microsoft, lightweight' },
  'gemma2': { name: 'Gemma 2', description: 'Google, efficient' },
  'codellama': { name: 'Code Llama', description: 'Best for code' },
  'qwen2.5': { name: 'Qwen 2.5', description: 'Alibaba, multilingual' },
} as const;

export type OllamaModel = keyof typeof OLLAMA_MODELS;

export class OllamaProvider implements AIProvider {
  name = "Ollama";
  private config: OllamaConfig;

  constructor(config: OllamaConfig | string, temperature?: number) {
    // Support both old and new constructor signatures
    if (typeof config === 'string') {
      this.config = {
        model: config,
        temperature: temperature ?? 0.3,
        baseUrl: "http://localhost:11434"
      };
    } else {
      this.config = {
        model: 'llama3.2',
        temperature: 0.3,
        baseUrl: "http://localhost:11434",
        ...config
      };
    }
  }

  supportsStreaming(): boolean {
    return true;
  }

  async isAvailable(): Promise<boolean> {
    try {
      const response = await fetch(`${this.config.baseUrl}/api/tags`, {
        method: 'GET',
        signal: AbortSignal.timeout(3000) // 3 second timeout
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  async getAvailableModels(): Promise<string[]> {
    try {
      const response = await fetch(`${this.config.baseUrl}/api/tags`);
      if (!response.ok) return [];
      const data = await response.json();
      return data.models?.map((m: any) => m.name) || [];
    } catch {
      return [];
    }
  }

  private buildSystemPrompt(): string {
    return `You are a text transformation assistant. Your role is to modify, improve, or transform the given text according to the user's instructions.

CRITICAL RULES:
1. Return ONLY the transformed text, nothing else
2. NO explanations, NO introductions, NO labels
3. Do NOT say "Here is..." or similar phrases
4. Do NOT wrap the output in quotes
5. Do NOT add any commentary before or after
6. Just output the final result directly`;
  }

  async rewrite(text: string, instruction: string, contextMessages?: ContextMessage[]): Promise<string> {
    // Use /api/chat endpoint for context support
    const messages: { role: string; content: string }[] = [
      {
        role: "system",
        content: this.buildSystemPrompt()
      }
    ];
    
    // Add context messages if present (for follow-up conversations)
    if (contextMessages && contextMessages.length > 0) {
      messages.push(...contextMessages);
    }
    
    // Add current user message
    messages.push({
      role: "user",
      content: `${instruction}\n\n---\nText to process:\n${text}`
    });

    const response = await fetch(`${this.config.baseUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: this.config.model,
        messages,
        options: {
          temperature: this.config.temperature
        },
        stream: false
      })
    });

    if (!response.ok) {
      throw new Error(`Ollama error: ${response.statusText}`);
    }

    const data = await response.json();
    let result = data.message?.content || '';
    
    return this.cleanResponse(result);
  }

  async rewriteStream(
    text: string,
    instruction: string,
    callbacks: StreamCallbacks,
    contextMessages?: ContextMessage[]
  ): Promise<void> {
    try {
      // Use /api/chat endpoint for context support
      const messages: { role: string; content: string }[] = [
        {
          role: "system",
          content: this.buildSystemPrompt()
        }
      ];
      
      // Add context messages if present (for follow-up conversations)
      if (contextMessages && contextMessages.length > 0) {
        messages.push(...contextMessages);
      }
      
      // Add current user message
      messages.push({
        role: "user",
        content: `${instruction}\n\n---\nText to process:\n${text}`
      });

      const response = await fetch(`${this.config.baseUrl}/api/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: this.config.model,
          messages,
          options: {
            temperature: this.config.temperature
          },
          stream: true
        })
      });

      if (!response.ok) {
        throw new Error(`Ollama error: ${response.statusText}`);
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('Response body is not readable');
      }

      const decoder = new TextDecoder();
      let fullText = '';
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.trim()) {
            try {
              const json = JSON.parse(line);
              const content = json.message?.content;
              if (content) {
                fullText += content;
                callbacks.onChunk(content);
              }
              if (json.done) {
                const cleanedText = this.cleanResponse(fullText);
                callbacks.onComplete(cleanedText);
                return;
              }
            } catch {
              // Ignore parse errors
            }
          }
        }
      }

      // Process remaining buffer
      if (buffer.trim()) {
        try {
          const json = JSON.parse(buffer);
          const content = json.message?.content;
          if (content) {
            fullText += content;
            callbacks.onChunk(content);
          }
        } catch {
          // Ignore
        }
      }

      const cleanedText = this.cleanResponse(fullText);
      callbacks.onComplete(cleanedText);

    } catch (error) {
      callbacks.onError(error as Error);
    }
  }

  private cleanResponse(result: string): string {
    result = result.trim();
    
    // Remove common AI response patterns
    const patterns = [
      /^Here is the [^:]+:\s*/i,
      /^Here's the [^:]+:\s*/i,
      /^Here is [^:]+:\s*/i,
      /^Here's [^:]+:\s*/i,
      /^The [^:]+:\s*/i,
      /^Sure[,!]?\s*[Hh]ere[^:]*:\s*/i,
      /^Summary:\s*/i,
      /^Translation:\s*/i,
      /^Improved version:\s*/i,
      /^Rewritten version:\s*/i,
      /^Fixed code:\s*/i,
      /^Output:\s*/i,
      /^Result:\s*/i,
    ];
    
    for (const pattern of patterns) {
      result = result.replace(pattern, '');
    }
    
    // Remove markdown bold/italic artifacts
    result = result.replace(/\*\*([^*]+)\*\*/g, '$1');
    result = result.replace(/\*([^*]+)\*/g, '$1');
    
    // Remove citation references
    result = result.replace(/\[\d+\]/g, '');
    
    // Remove multiple spaces
    result = result.replace(/\s{2,}/g, ' ');
    
    // Remove wrapping quotes
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.slice(1, -1);
    }
    
    return result.trim();
  }

  updateConfig(config: Partial<OllamaConfig>): void {
    this.config = { ...this.config, ...config };
  }

  getConfig(): OllamaConfig {
    return { ...this.config };
  }
}
