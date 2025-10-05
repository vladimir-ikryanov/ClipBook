import { AIProvider } from './ai-service';

export class PerplexityProvider implements AIProvider {
  name = "Perplexity";
  private apiKey: string;
  private model: string;
  private temperature: number;

  constructor(apiKey: string, model: string = "sonar", temperature: number = 0.7) {
    this.apiKey = apiKey;
    this.model = model;
    this.temperature = temperature;
  }

  async isAvailable(): Promise<boolean> {
    return !!this.apiKey && this.apiKey.length > 0;
  }

  async rewrite(text: string, instruction: string): Promise<string> {
    const response = await fetch('https://api.perplexity.ai/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        model: this.model,
        messages: [
          {
            role: "system",
            content: "You are a direct assistant. Follow instructions exactly. Return ONLY the requested output with absolutely no additional text, explanations, labels, citations, references, or commentary. Never include citation numbers like [1][2][3]. Never say 'Here is...' or similar phrases."
          },
          {
            role: "user",
            content: `${instruction}\n\nInput text:\n${text}`
          }
        ],
        temperature: this.temperature,
        max_tokens: 2000,
        return_citations: false,
        return_images: false,
        return_related_questions: false,
        search_recency_filter: "month"
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`Perplexity API error: ${error.error?.message || error.message || 'Unknown error'}`);
    }

    const data = await response.json();
    let result = data.choices[0]?.message?.content || '';
    
    // Clean up any unwanted prefixes/suffixes
    result = result.trim();
    
    // Remove common AI response patterns
    const patterns = [
      /^Here is the [^:]+:\s*/i,
      /^Here's the [^:]+:\s*/i,
      /^Here is [^:]+:\s*/i,
      /^Here's [^:]+:\s*/i,
      /^The [^:]+:\s*/i,
      /^Summary:\s*/i,
      /^Translation:\s*/i,
      /^Improved version:\s*/i,
      /^Rewritten version:\s*/i,
      /^Fixed code:\s*/i
    ];
    
    for (const pattern of patterns) {
      result = result.replace(pattern, '');
    }
    
    // Remove citation references like [1], [2], [1][2][3], etc.
    result = result.replace(/\[\d+\]/g, '');
    
    // Remove multiple spaces left by removed citations
    result = result.replace(/\s{2,}/g, ' ');
    
    return result.trim();
  }
}

