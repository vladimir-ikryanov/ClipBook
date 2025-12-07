import { AIProvider, StreamCallbacks, ContextMessage } from './ai-service';

export interface OpenAIConfig {
  apiKey: string;
  model?: string;
  temperature?: number;
  maxTokens?: number;
}

// Available OpenAI models
export const OPENAI_MODELS = {
  'gpt-4o': { name: 'GPT-4o', description: 'Latest and most capable' },
  'gpt-4o-mini': { name: 'GPT-4o Mini', description: 'Fast and cost-effective' },
  'gpt-4-turbo': { name: 'GPT-4 Turbo', description: 'Powerful, good balance' },
  'gpt-4': { name: 'GPT-4', description: 'Original GPT-4' },
  'gpt-3.5-turbo': { name: 'GPT-3.5 Turbo', description: 'Fast and cheap' },
  'o1-preview': { name: 'O1 Preview', description: 'Advanced reasoning (beta)' },
  'o1-mini': { name: 'O1 Mini', description: 'Fast reasoning (beta)' },
} as const;

export type OpenAIModel = keyof typeof OPENAI_MODELS;

export class OpenAIProvider implements AIProvider {
  name = "OpenAI";
  private config: OpenAIConfig;

  constructor(config: OpenAIConfig | string, model?: string, temperature?: number) {
    // Support both old and new constructor signatures
    if (typeof config === 'string') {
      this.config = {
        apiKey: config,
        model: model || 'gpt-4o-mini',
        temperature: temperature ?? 0.3,
        maxTokens: 2000
      };
    } else {
      this.config = {
        model: 'gpt-4o-mini',
        temperature: 0.3,
        maxTokens: 2000,
        ...config
      };
    }
  }

  supportsStreaming(): boolean {
    // O1 models don't support streaming yet
    const model = this.config.model || '';
    return !model.startsWith('o1-');
  }

  async isAvailable(): Promise<boolean> {
    return !!this.config.apiKey && this.config.apiKey.length > 0;
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
    // Build messages array: system prompt, context messages, then current request
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

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`
      },
      body: JSON.stringify({
        model: this.config.model,
        messages,
        temperature: this.config.temperature,
        max_tokens: this.config.maxTokens
      })
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(`OpenAI API error: ${error.error?.message || response.statusText}`);
    }

    const data = await response.json();
    let result = data.choices[0]?.message?.content || '';
    
    return this.cleanResponse(result);
  }

  async rewriteStream(
    text: string,
    instruction: string,
    callbacks: StreamCallbacks,
    contextMessages?: ContextMessage[]
  ): Promise<void> {
    // O1 models don't support streaming
    if (!this.supportsStreaming()) {
      try {
        const result = await this.rewrite(text, instruction, contextMessages);
        callbacks.onChunk(result);
        callbacks.onComplete(result);
      } catch (error) {
        callbacks.onError(error as Error);
      }
      return;
    }

    try {
      // Build messages array: system prompt, context messages, then current request
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

      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.apiKey}`
        },
        body: JSON.stringify({
          model: this.config.model,
          messages,
          temperature: this.config.temperature,
          max_tokens: this.config.maxTokens,
          stream: true
        })
      });

      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        throw new Error(`OpenAI API error: ${error.error?.message || response.statusText}`);
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
          if (line.startsWith('data: ')) {
            const data = line.slice(6).trim();
            
            if (data === '[DONE]') {
              const cleanedText = this.cleanResponse(fullText);
              callbacks.onComplete(cleanedText);
              return;
            }

            try {
              const json = JSON.parse(data);
              const content = json.choices?.[0]?.delta?.content;
              if (content) {
                fullText += content;
                callbacks.onChunk(content);
              }
            } catch {
              // Ignore parse errors
            }
          }
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
      /^Certainly[,!]?\s*[Hh]ere[^:]*:\s*/i,
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

  // Vision capabilities
  supportsVision(): boolean {
    const model = this.config.model || '';
    // GPT-4o and GPT-4o-mini support vision
    return model.includes('gpt-4o');
  }

  async analyzeImage(imageBase64: string, prompt: string): Promise<string> {
    if (!this.supportsVision()) {
      throw new Error('Current model does not support vision. Use gpt-4o or gpt-4o-mini.');
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`
      },
      body: JSON.stringify({
        model: this.config.model,
        messages: [{
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { 
              type: 'image_url', 
              image_url: { 
                url: imageBase64.startsWith('data:') ? imageBase64 : `data:image/png;base64,${imageBase64}`,
                detail: 'auto'
              }
            }
          ]
        }],
        max_tokens: 1500
      })
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(`OpenAI Vision API error: ${error.error?.message || response.statusText}`);
    }

    const data = await response.json();
    let result = data.choices[0]?.message?.content || '';
    
    return this.cleanResponse(result);
  }

  updateConfig(config: Partial<OpenAIConfig>): void {
    this.config = { ...this.config, ...config };
  }

  getConfig(): OpenAIConfig {
    return { ...this.config };
  }
}
