# AI Service Improvements Specification

## 📋 Overview

This document provides a comprehensive review of the current AI service implementation in ClipBook and outlines planned improvements, with a focus on Perplexity API capabilities.

**Document Version:** 2.0  
**Created:** December 6, 2025  
**Updated:** December 6, 2025  
**Status:** ✅ IMPLEMENTED

---

## 🔍 Current Implementation Review

### Architecture Summary

```
src/ai/
├── ai-service.ts          # Core service & provider abstraction
├── perplexity-provider.ts # Perplexity AI implementation
├── openai-provider.ts     # OpenAI implementation
├── ollama-provider.ts     # Local Ollama implementation
└── prompts.ts             # Prompt templates

src/app/
├── AIRewriteDialog.tsx    # Main AI dialog UI
└── ...

src/settings/
└── AISettings.tsx         # AI configuration panel
```

### Current Features ✅

| Feature | Status | Notes |
|---------|--------|-------|
| Multi-provider support | ✅ | OpenAI, Ollama, Perplexity |
| Text rewriting | ✅ | Single action per request |
| Prompt templates | ✅ | 8 built-in actions |
| Custom prompts | ✅ | User can provide custom instructions |
| API key management | ✅ | Stored locally |
| Model selection | ✅ | Limited options per provider |
| Temperature control | ⚠️ | Configurable but hardcoded in some places |
| Error handling | ⚠️ | Basic, no retry logic |

### Current Limitations ❌

| Limitation | Impact | Priority |
|------------|--------|----------|
| No streaming | Poor UX for long responses | **HIGH** |
| Limited models | Missing advanced Perplexity models | HIGH |
| No citations | Perplexity's unique feature unused | MEDIUM |
| No caching | Repeated requests waste API calls | MEDIUM |
| No context memory | Each request is isolated | LOW |
| Basic error handling | No retry, no rate limit handling | HIGH |
| No image analysis | Can't analyze clipboard images | MEDIUM |

---

## 🔬 Perplexity API Deep Dive

### Available Models

| Model | Description | Use Case | Cost |
|-------|-------------|----------|------|
| `sonar` | Standard search-enhanced model | General rewriting, quick tasks | Low |
| `sonar-pro` | Advanced search-enhanced model | Complex analysis, research | Medium |
| `sonar-reasoning` | Chain-of-thought reasoning | Code analysis, logical tasks | Medium |
| `sonar-deep-research` | Deep multi-step research | Research summaries | High |

### API Parameters (Full List)

```typescript
interface PerplexityRequest {
  // Required
  model: string;
  messages: Message[];
  
  // Generation Control
  temperature?: number;        // 0-2, default 0.2
  max_tokens?: number;         // Max output tokens
  top_p?: number;              // Nucleus sampling, 0-1
  top_k?: number;              // Top-k sampling
  presence_penalty?: number;   // -2 to 2, penalize repetition
  frequency_penalty?: number;  // -2 to 2, penalize frequency
  
  // Perplexity-Specific
  return_citations?: boolean;  // Include source citations
  return_images?: boolean;     // Include relevant images
  return_related_questions?: boolean; // Suggest follow-ups
  search_domain_filter?: string[]; // Limit search domains
  search_recency_filter?: 'day' | 'week' | 'month' | 'year'; // Time filter
  
  // Streaming
  stream?: boolean;            // Enable SSE streaming
}
```

### Streaming Implementation

Perplexity supports Server-Sent Events (SSE) for real-time responses:

```typescript
// Streaming response format
interface StreamChunk {
  id: string;
  object: 'chat.completion.chunk';
  created: number;
  model: string;
  choices: [{
    index: number;
    delta: {
      role?: string;
      content?: string;
    };
    finish_reason: string | null;
  }];
}
```

### Citations Feature

When `return_citations: true`, Perplexity returns:

```typescript
interface CitationResponse {
  choices: [{
    message: {
      content: string;
      citations: Array<{
        url: string;
        title: string;
        snippet: string;
      }>;
    };
  }];
}
```

---

## 🎯 Improvement Plan

### Phase 1: Core Enhancements (Priority: HIGH)

#### 1.1 Streaming Support

**Goal:** Show AI response as it generates, dramatically improving perceived performance.

**Files to modify:**
- `src/ai/ai-service.ts` - Add streaming interface
- `src/ai/perplexity-provider.ts` - Implement SSE
- `src/ai/openai-provider.ts` - Implement SSE
- `src/ai/ollama-provider.ts` - Already supports streaming
- `src/app/AIRewriteDialog.tsx` - Real-time UI updates

**New Interface:**
```typescript
export interface AIProvider {
  name: string;
  rewrite(text: string, instruction: string): Promise<string>;
  rewriteStream(
    text: string, 
    instruction: string, 
    onChunk: (chunk: string) => void,
    onComplete: () => void,
    onError: (error: Error) => void
  ): Promise<void>;
  isAvailable(): Promise<boolean>;
}
```

**Implementation:**
```typescript
// perplexity-provider.ts
async rewriteStream(
  text: string,
  instruction: string,
  onChunk: (chunk: string) => void,
  onComplete: () => void,
  onError: (error: Error) => void
): Promise<void> {
  const response = await fetch('https://api.perplexity.ai/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`
    },
    body: JSON.stringify({
      model: this.model,
      messages: [...],
      stream: true,  // Enable streaming
      temperature: this.temperature,
    })
  });

  const reader = response.body?.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    const chunk = decoder.decode(value);
    const lines = chunk.split('\n').filter(line => line.startsWith('data: '));
    
    for (const line of lines) {
      if (line === 'data: [DONE]') {
        onComplete();
        return;
      }
      
      const json = JSON.parse(line.slice(6));
      const content = json.choices[0]?.delta?.content;
      if (content) {
        onChunk(content);
      }
    }
  }
}
```

#### 1.2 Extended Model Support

**New Perplexity Models:**
```typescript
// AISettings.tsx - Update model options
{provider === "perplexity" && (
  <Select value={model} onValueChange={handleModelChange}>
    <SelectContent>
      <SelectItem value="sonar">Sonar (Fast, Recommended)</SelectItem>
      <SelectItem value="sonar-pro">Sonar Pro (Advanced)</SelectItem>
      <SelectItem value="sonar-reasoning">Sonar Reasoning (Logic/Code)</SelectItem>
      <SelectItem value="sonar-deep-research">Deep Research (Thorough)</SelectItem>
    </SelectContent>
  </Select>
)}
```

**New OpenAI Models:**
```typescript
<SelectItem value="gpt-4o">GPT-4o (Latest)</SelectItem>
<SelectItem value="gpt-4o-mini">GPT-4o Mini (Fast & Cheap)</SelectItem>
<SelectItem value="gpt-4-turbo">GPT-4 Turbo</SelectItem>
<SelectItem value="o1-preview">O1 Preview (Reasoning)</SelectItem>
<SelectItem value="o1-mini">O1 Mini (Reasoning, Faster)</SelectItem>
```

#### 1.3 Error Handling & Retry Logic

```typescript
// ai-service.ts - Add retry logic
async rewriteWithRetry(
  text: string, 
  instruction: string, 
  maxRetries: number = 3
): Promise<string> {
  let lastError: Error | null = null;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await this.rewrite(text, instruction);
    } catch (error) {
      lastError = error as Error;
      
      // Check if retryable
      if (this.isRateLimitError(error)) {
        const delay = Math.pow(2, attempt) * 1000; // Exponential backoff
        await this.sleep(delay);
        continue;
      }
      
      // Non-retryable error
      throw error;
    }
  }
  
  throw lastError;
}

private isRateLimitError(error: any): boolean {
  return error.status === 429 || 
         error.message?.includes('rate limit') ||
         error.message?.includes('too many requests');
}
```

---

### Phase 2: Perplexity-Specific Features (Priority: MEDIUM)

#### 2.1 Citations Support

**New Interface:**
```typescript
interface RewriteResult {
  content: string;
  citations?: Citation[];
  images?: string[];
  relatedQuestions?: string[];
}

interface Citation {
  url: string;
  title: string;
  snippet: string;
}
```

**Settings Option:**
```typescript
// AISettings.tsx
{provider === "perplexity" && (
  <div className="flex items-center justify-between pt-4">
    <Label>
      <span>Show Citations</span>
      <span className="text-muted-foreground text-sm">
        Display source links when using web search
      </span>
    </Label>
    <Switch checked={showCitations} onCheckedChange={setShowCitations} />
  </div>
)}
```

**UI Component:**
```typescript
// CitationsPanel.tsx
function CitationsPanel({ citations }: { citations: Citation[] }) {
  return (
    <div className="mt-4 border-t pt-4">
      <h4 className="text-sm font-medium text-muted-foreground mb-2">
        Sources ({citations.length})
      </h4>
      <div className="space-y-2">
        {citations.map((citation, i) => (
          <a 
            key={i}
            href={citation.url}
            target="_blank"
            className="block p-2 rounded bg-secondary hover:bg-secondary/80"
          >
            <div className="text-sm font-medium">{citation.title}</div>
            <div className="text-xs text-muted-foreground truncate">
              {citation.url}
            </div>
          </a>
        ))}
      </div>
    </div>
  );
}
```

#### 2.2 Search Domain Filtering

Allow users to restrict Perplexity's web search to specific domains:

```typescript
// perplexity-provider.ts
interface PerplexityConfig {
  apiKey: string;
  model: string;
  temperature: number;
  searchDomains?: string[];  // e.g., ['wikipedia.org', 'github.com']
  recencyFilter?: 'day' | 'week' | 'month' | 'year';
  returnCitations?: boolean;
}
```

#### 2.3 Research Mode

**New Action Type:**
```typescript
// prompts.ts
research: (topic: string) => `You are a research assistant with web search capabilities.

Research the following topic thoroughly and provide a comprehensive summary with key findings.

Topic: ${topic}

Requirements:
- Include multiple perspectives
- Cite sources when possible
- Organize information clearly
- Highlight key takeaways`
```

---

### Phase 3: Enhanced Actions (Priority: MEDIUM)

#### 3.1 New Built-in Actions

```typescript
// prompts.ts - Add new actions
export const AI_PROMPTS = {
  // ... existing prompts ...
  
  extractKeywords: `Extract the most important keywords and phrases from this text.
Return ONLY a comma-separated list of keywords, nothing else.`,
  
  detectLanguage: `Detect the language of this text.
Return ONLY the language name (e.g., "English", "Spanish"), nothing else.`,
  
  formatJSON: `Format and prettify this JSON/code.
Return ONLY the formatted output, nothing else.`,
  
  convertMarkdown: `Convert this text to clean Markdown format.
Return ONLY the Markdown, nothing else.`,
  
  extractEmails: `Extract all email addresses from this text.
Return ONLY a comma-separated list of emails, nothing else.`,
  
  extractURLs: `Extract all URLs/links from this text.
Return ONLY a list of URLs (one per line), nothing else.`,
  
  grammarCheck: `Check this text for grammar and spelling errors.
Return ONLY the corrected text, nothing else.`,
  
  expandAbbreviations: `Expand any abbreviations in this text.
Return ONLY the expanded text, nothing else.`,
  
  simplifyText: `Simplify this text for easier reading.
Use simpler words and shorter sentences.
Return ONLY the simplified text, nothing else.`,
  
  bulletPoints: `Convert this text into bullet points.
Return ONLY the bullet point list, nothing else.`,
};
```

#### 3.2 Context-Aware Actions

Automatically suggest relevant actions based on clipboard content:

```typescript
// content-analyzer-actions.ts
function suggestActions(content: string): AIAction[] {
  const suggestions: AIAction[] = [];
  
  // Always available
  suggestions.push('improveWriting', 'rewrite', 'summarize');
  
  // Code detection
  if (looksLikeCode(content)) {
    suggestions.unshift('fixCode', 'explainCode');
  }
  
  // JSON detection
  if (looksLikeJSON(content)) {
    suggestions.unshift('formatJSON');
  }
  
  // Long text
  if (content.length > 500) {
    suggestions.unshift('summarize', 'bulletPoints');
  }
  
  // Contains URLs
  if (containsURLs(content)) {
    suggestions.unshift('extractURLs');
  }
  
  // Non-English detection
  if (!isEnglish(content)) {
    suggestions.unshift('translate');
  }
  
  return suggestions.slice(0, 8); // Top 8 suggestions
}
```

---

### Phase 4: Performance & UX (Priority: MEDIUM-LOW)

#### 4.1 Response Caching

```typescript
// ai-cache.ts
class AIResponseCache {
  private cache: Map<string, CacheEntry> = new Map();
  private maxAge: number = 5 * 60 * 1000; // 5 minutes
  
  private getCacheKey(text: string, instruction: string): string {
    return crypto.subtle.digest('SHA-256', 
      new TextEncoder().encode(`${text}|${instruction}`)
    ).then(hash => Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
    );
  }
  
  async get(text: string, instruction: string): Promise<string | null> {
    const key = await this.getCacheKey(text, instruction);
    const entry = this.cache.get(key);
    
    if (entry && Date.now() - entry.timestamp < this.maxAge) {
      return entry.response;
    }
    
    return null;
  }
  
  async set(text: string, instruction: string, response: string): Promise<void> {
    const key = await this.getCacheKey(text, instruction);
    this.cache.set(key, {
      response,
      timestamp: Date.now()
    });
  }
}
```

#### 4.2 Streaming UI Improvements

```typescript
// AIRewriteDialog.tsx - Streaming UI state
const [streamingText, setStreamingText] = useState('');
const [isStreaming, setIsStreaming] = useState(false);

const handleGenerateStreaming = async () => {
  setIsStreaming(true);
  setStreamingText('');
  setError('');
  
  try {
    await aiService.rewriteStream(
      props.originalText,
      instruction,
      (chunk) => {
        setStreamingText(prev => prev + chunk);
      },
      () => {
        setIsStreaming(false);
        setResult(streamingText);
      },
      (error) => {
        setIsStreaming(false);
        setError(error.message);
      }
    );
  } catch (err) {
    setIsStreaming(false);
    setError(err.message);
  }
};

// Render streaming text with cursor animation
{isStreaming && (
  <div className="relative flex-1 min-h-0">
    <div className="h-full w-full font-mono text-base p-4 bg-secondary-solid border-primary rounded-md overflow-y-auto">
      {streamingText}
      <span className="inline-block w-2 h-4 bg-primary animate-pulse ml-0.5" />
    </div>
  </div>
)}
```

#### 4.3 Keyboard Shortcuts

```typescript
// AIRewriteDialog.tsx - Add keyboard shortcuts
useEffect(() => {
  const handleKeyDown = (e: KeyboardEvent) => {
    // Cmd/Ctrl + Enter to generate
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      handleGenerate();
      e.preventDefault();
    }
    
    // Cmd/Ctrl + Shift + C to copy result
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'c') {
      if (result) {
        handleCopy();
        e.preventDefault();
      }
    }
    
    // Cmd/Ctrl + R to regenerate
    if ((e.metaKey || e.ctrlKey) && e.key === 'r' && result) {
      handleGenerate();
      e.preventDefault();
    }
  };
  
  document.addEventListener('keydown', handleKeyDown);
  return () => document.removeEventListener('keydown', handleKeyDown);
}, [result]);
```

---

### Phase 5: Advanced Features (Priority: LOW)

#### 5.1 Image Analysis (Vision Models)

```typescript
// vision-provider.ts
interface VisionProvider {
  analyzeImage(imageData: string): Promise<string>;
  extractTextFromImage(imageData: string): Promise<string>;
  describeImage(imageData: string): Promise<string>;
}

// OpenAI Vision implementation
async analyzeImage(imageBase64: string): Promise<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: 'Describe this image in detail.' },
          { type: 'image_url', image_url: { url: `data:image/png;base64,${imageBase64}` }}
        ]
      }],
      max_tokens: 1000
    })
  });
  
  const data = await response.json();
  return data.choices[0].message.content;
}
```

#### 5.2 Conversation Context

```typescript
// ai-context.ts
class AIConversationContext {
  private history: Message[] = [];
  private maxHistory: number = 10;
  
  addMessage(role: 'user' | 'assistant', content: string): void {
    this.history.push({ role, content });
    if (this.history.length > this.maxHistory * 2) {
      this.history = this.history.slice(-this.maxHistory * 2);
    }
  }
  
  getMessages(): Message[] {
    return [...this.history];
  }
  
  clear(): void {
    this.history = [];
  }
}
```

#### 5.3 Custom Provider Support

Allow users to add custom OpenAI-compatible APIs:

```typescript
interface CustomProvider {
  name: string;
  baseUrl: string;
  apiKey: string;
  model: string;
  headers?: Record<string, string>;
}

// Settings UI for custom providers
<Button variant="outline" onClick={addCustomProvider}>
  <PlusIcon className="mr-2 h-4 w-4" />
  Add Custom Provider
</Button>
```

---

## 📊 Implementation Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Streaming | HIGH | MEDIUM | P0 |
| Extended models | HIGH | LOW | P0 |
| Error handling | HIGH | LOW | P0 |
| Citations | MEDIUM | MEDIUM | P1 |
| New actions | MEDIUM | LOW | P1 |
| Response caching | MEDIUM | LOW | P1 |
| Domain filtering | LOW | LOW | P2 |
| Image analysis | HIGH | HIGH | P2 |
| Context memory | MEDIUM | MEDIUM | P2 |
| Custom providers | LOW | MEDIUM | P3 |

---

## 🗓️ Implementation Timeline

### Week 1-2: Phase 1 (Core)
- [ ] Implement streaming for all providers
- [ ] Add new Perplexity models (sonar-pro, sonar-reasoning)
- [ ] Add new OpenAI models (gpt-4o, o1-preview)
- [ ] Implement retry logic with exponential backoff
- [ ] Update AIRewriteDialog for streaming UI

### Week 3: Phase 2 (Perplexity Features)
- [ ] Implement citations support
- [ ] Add citations UI component
- [ ] Add search domain filtering
- [ ] Add recency filter options

### Week 4: Phase 3 (Enhanced Actions)
- [ ] Add 10 new built-in actions
- [ ] Implement context-aware action suggestions
- [ ] Update AIRewriteDialog action picker

### Week 5: Phase 4 (Performance)
- [ ] Implement response caching
- [ ] Add keyboard shortcuts
- [ ] Optimize streaming performance
- [ ] Add loading skeletons

### Week 6+: Phase 5 (Advanced)
- [ ] Image analysis (if needed)
- [ ] Conversation context
- [ ] Custom provider support

---

## 📝 Testing Plan

### Unit Tests
- Provider connection tests
- Streaming chunk parsing
- Error handling scenarios
- Cache hit/miss

### Integration Tests
- Full rewrite flow
- Provider switching
- Settings persistence

### E2E Tests
- Complete AI rewrite workflow
- Streaming UI updates
- Error recovery

---

## 🔒 Security Considerations

1. **API Key Storage**: Keys stored encrypted in local preferences
2. **Data Privacy**: No clipboard data sent without user action
3. **Rate Limiting**: Respect API rate limits, implement backoff
4. **Error Messages**: Never expose API keys in error messages

---

## 📚 References

- [Perplexity API Documentation](https://docs.perplexity.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)

---

## ✅ Definition of Done

- [ ] All P0 features implemented
- [ ] Streaming works for all providers
- [ ] Unit tests passing (>80% coverage)
- [ ] No regressions in existing functionality
- [ ] Documentation updated
- [ ] Settings UI updated with new options

