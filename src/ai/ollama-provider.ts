import { AIProvider } from './ai-service';

export class OllamaProvider implements AIProvider {
  name = "Ollama";
  private model: string;
  private temperature: number;
  private baseUrl: string;

  constructor(model: string = "llama3.2", temperature: number = 0.7) {
    this.model = model;
    this.temperature = temperature;
    this.baseUrl = "http://localhost:11434";
  }

  async isAvailable(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/api/tags`);
      return response.ok;
    } catch {
      return false;
    }
  }

  async rewrite(text: string, instruction: string): Promise<string> {
    const prompt = `${instruction}\n\nInput text:\n${text}`;
    
    const response = await fetch(`${this.baseUrl}/api/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: this.model,
        prompt: prompt,
        temperature: this.temperature,
        stream: false,
        system: "You are a direct assistant. Follow instructions exactly. Return only the requested output with no additional text, explanations, or labels."
      })
    });

    if (!response.ok) {
      throw new Error(`Ollama error: ${response.statusText}`);
    }

    const data = await response.json();
    let result = data.response || '';
    
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
    
    // Remove markdown bold/italic artifacts if any
    result = result.replace(/\*\*/g, '');
    
    // Remove multiple spaces left by cleanup
    result = result.replace(/\s{2,}/g, ' ');
    
    return result.trim();
  }
}

