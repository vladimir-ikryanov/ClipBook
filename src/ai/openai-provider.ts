import { AIProvider } from './ai-service';

export class OpenAIProvider implements AIProvider {
  name = "OpenAI";
  private apiKey: string;
  private model: string;
  private temperature: number;

  constructor(apiKey: string, model: string = "gpt-3.5-turbo", temperature: number = 0.7) {
    this.apiKey = apiKey;
    this.model = model;
    this.temperature = temperature;
  }

  async isAvailable(): Promise<boolean> {
    return !!this.apiKey && this.apiKey.length > 0;
  }

  async rewrite(text: string, instruction: string): Promise<string> {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
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
            content: "You are a direct assistant. Follow instructions exactly. Return ONLY the requested output with absolutely no additional text, explanations, labels, or commentary. Never say 'Here is...' or similar phrases."
          },
          {
            role: "user",
            content: `${instruction}\n\nInput text:\n${text}`
          }
        ],
        temperature: this.temperature,
        max_tokens: 2000
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`OpenAI API error: ${error.error?.message || 'Unknown error'}`);
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
      /^Fixed code:\s*/i,
      /^Output:\s*/i,
      /^Result:\s*/i
    ];
    
    for (const pattern of patterns) {
      result = result.replace(pattern, '');
    }
    
    // Remove citation references like [1], [2], [1][2][3], etc.
    result = result.replace(/\[\d+\]/g, '');
    
    // Remove multiple spaces left by cleanup
    result = result.replace(/\s{2,}/g, ' ');
    
    return result.trim();
  }
}

