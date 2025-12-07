import { AIProvider, StreamCallbacks, ContextMessage } from './ai-service';

export interface PerplexityConfig {
  apiKey: string;
  model?: string;
  temperature?: number;
  maxTokens?: number;
  returnCitations?: boolean;
  searchRecencyFilter?: 'day' | 'week' | 'month' | 'year';
  searchDomains?: string[];
}

export interface Citation {
  url: string;
  title?: string;
  snippet?: string;
}

export interface PerplexityResponse {
  content: string;
  citations?: Citation[];
}

// Available Perplexity models
export const PERPLEXITY_MODELS = {
  'sonar': { name: 'Sonar', description: 'Fast, recommended for text tasks', supportsVision: false },
  'sonar-pro': { name: 'Sonar Pro', description: 'Advanced reasoning + Vision', supportsVision: true },
  'sonar-reasoning': { name: 'Sonar Reasoning', description: 'Best for logic and code', supportsVision: false },
} as const;

export type PerplexityModel = keyof typeof PERPLEXITY_MODELS;

export class PerplexityProvider implements AIProvider {
  name = "Perplexity";
  private config: PerplexityConfig;
  private lastCitations: Citation[] = [];

  constructor(config: PerplexityConfig | string, model?: string, temperature?: number) {
    // Support both old and new constructor signatures
    if (typeof config === 'string') {
      this.config = {
        apiKey: config,
        model: model || 'sonar',
        temperature: temperature ?? 0.3, // Lower temperature for more predictable rewrites
        maxTokens: 2000,
        returnCitations: false,
        searchRecencyFilter: 'month'
      };
    } else {
      this.config = {
        model: 'sonar',
        temperature: 0.3,
        maxTokens: 2000,
        returnCitations: false,
        searchRecencyFilter: 'month',
        ...config
      };
    }
  }

  supportsStreaming(): boolean {
    return true;
  }

  async isAvailable(): Promise<boolean> {
    return !!this.config.apiKey && this.config.apiKey.length > 0;
  }

  getLastCitations(): Citation[] {
    return this.lastCitations;
  }

  private buildSystemPrompt(isRewrite: boolean): string {
    if (isRewrite) {
      // For rewriting tasks, explicitly tell the model NOT to search the web
      return `You are a text transformation assistant. Your role is to modify, improve, or transform the given text according to the instructions.

CRITICAL INSTRUCTIONS:
1. DO NOT search the web or use external information
2. Work ONLY with the text provided by the user
3. Return ONLY the transformed text, nothing else
4. NO explanations, NO introductions, NO labels
5. NO citations or references
6. Do NOT say "Here is..." or similar phrases
7. Just output the final result directly`;
    }
    
    // For research/search tasks
    return `You are a helpful assistant with access to real-time web search. Provide accurate, well-researched responses.`;
  }

  async rewrite(text: string, instruction: string, contextMessages?: ContextMessage[]): Promise<string> {
    // Determine if this is a rewrite/transform task vs a research task
    const isRewriteTask = this.isRewriteInstruction(instruction);
    
    // Build messages array: system prompt, context messages, then current request
    const messages: { role: string; content: string }[] = [
      {
        role: "system",
        content: this.buildSystemPrompt(isRewriteTask)
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
    
    const body: any = {
      model: this.config.model,
      messages,
      temperature: this.config.temperature,
      max_tokens: this.config.maxTokens,
    };

    // For rewrite tasks, disable web search features
    if (isRewriteTask) {
      body.return_citations = false;
      body.return_images = false;
      body.return_related_questions = false;
    } else {
      // Enable citations by default for research/search tasks
      body.return_citations = this.config.returnCitations !== false;
      body.return_images = false;
      body.return_related_questions = false;
      if (this.config.searchRecencyFilter) {
        body.search_recency_filter = this.config.searchRecencyFilter;
      }
      if (this.config.searchDomains && this.config.searchDomains.length > 0) {
        body.search_domain_filter = this.config.searchDomains;
      }
    }

    const response = await fetch('https://api.perplexity.ai/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(`Perplexity API error: ${error.error?.message || error.message || response.statusText}`);
    }

    const data = await response.json();
    let result = data.choices[0]?.message?.content || '';
    
    // Store citations if available
    this.lastCitations = data.citations || [];
    
    // Clean up the result
    result = this.cleanResponse(result);
    
    return result;
  }

  async rewriteStream(
    text: string,
    instruction: string,
    callbacks: StreamCallbacks,
    contextMessages?: ContextMessage[]
  ): Promise<void> {
    const isRewriteTask = this.isRewriteInstruction(instruction);
    
    // Build messages array: system prompt, context messages, then current request
    const messages: { role: string; content: string }[] = [
      {
        role: "system",
        content: this.buildSystemPrompt(isRewriteTask)
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
    
    const body: any = {
      model: this.config.model,
      messages,
      temperature: this.config.temperature,
      max_tokens: this.config.maxTokens,
      stream: true, // Enable streaming
      return_citations: false,
      return_images: false,
      return_related_questions: false,
    };

    try {
      const response = await fetch('https://api.perplexity.ai/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.apiKey}`
        },
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        throw new Error(`Perplexity API error: ${error.error?.message || error.message || response.statusText}`);
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
        buffer = lines.pop() || ''; // Keep incomplete line in buffer

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
              // Ignore parse errors for incomplete chunks
            }
          }
        }
      }

      // Handle case where [DONE] wasn't received
      const cleanedText = this.cleanResponse(fullText);
      callbacks.onComplete(cleanedText);

    } catch (error) {
      callbacks.onError(error as Error);
    }
  }

  private isRewriteInstruction(instruction: string): boolean {
    const rewriteKeywords = [
      'rewrite', 'improve', 'fix', 'correct', 'enhance', 'polish',
      'summarize', 'translate', 'convert', 'format', 'transform',
      'professional', 'casual', 'formal', 'simplify', 'expand',
      'grammar', 'spelling', 'tone', 'style', 'shorten', 'lengthen',
      'paraphrase', 'rephrase', 'capitalize', 'lowercase', 'uppercase',
      'bullet', 'extract', 'clean', 'trim', 'remove', 'add'
    ];
    
    const lowerInstruction = instruction.toLowerCase();
    return rewriteKeywords.some(keyword => lowerInstruction.includes(keyword));
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
      /^Of course[,!]?\s*[Hh]ere[^:]*:\s*/i,
      /^Summary:\s*/i,
      /^Translation:\s*/i,
      /^Improved version:\s*/i,
      /^Rewritten version:\s*/i,
      /^Rewritten text:\s*/i,
      /^Fixed code:\s*/i,
      /^Output:\s*/i,
      /^Result:\s*/i,
      /^Answer:\s*/i,
      /^Response:\s*/i,
    ];
    
    for (const pattern of patterns) {
      result = result.replace(pattern, '');
    }
    
    // Remove citation references like [1], [2], [1][2][3], etc.
    result = result.replace(/\[\d+\]/g, '');
    
    // Remove multiple spaces left by removed citations
    result = result.replace(/\s{2,}/g, ' ');
    
    // Remove leading/trailing quotes if the entire response is wrapped
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.slice(1, -1);
    }
    
    return result.trim();
  }

  // Vision capabilities
  supportsVision(): boolean {
    const model = this.config.model || 'sonar';
    const modelInfo = PERPLEXITY_MODELS[model as keyof typeof PERPLEXITY_MODELS];
    return modelInfo?.supportsVision ?? false;
  }

  async analyzeImage(imageBase64: string, prompt: string): Promise<string> {
    if (!this.supportsVision()) {
      throw new Error('Current model does not support vision. Use sonar-pro for image analysis.');
    }

    const imageUrl = imageBase64.startsWith('data:') ? imageBase64 : `data:image/png;base64,${imageBase64}`;

    const response = await fetch('https://api.perplexity.ai/chat/completions', {
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
                url: imageUrl
              }
            }
          ]
        }],
        max_tokens: 1500
      })
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(`Perplexity Vision API error: ${error.error?.message || response.statusText}`);
    }

    const data = await response.json();
    let result = data.choices[0]?.message?.content || '';
    
    // Store citations if available
    this.lastCitations = data.citations || [];
    
    return this.cleanResponse(result);
  }

  updateConfig(config: Partial<PerplexityConfig>): void {
    this.config = { ...this.config, ...config };
  }

  getConfig(): PerplexityConfig {
    return { ...this.config };
  }
}
