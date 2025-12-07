# AI Improvements - Technical Design

**Created:** December 7, 2025  
**Status:** 🟡 In Progress

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      PreviewToolBar                              │
├─────────────────────────────────────────────────────────────────┤
│  [Paste] [Copy] [AI Wand] [⚡Quick] [Tools] ... [Star] [More]   │
│                            │         │                           │
│                            │         └── Quick Rewrite Button    │
│                            └── Opens Full AI Dialog              │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AIRewriteDialog                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────────────────────────────┐  │
│  │  Original   │  │  Result (Streaming)                      │  │
│  │  Text       │  │  ████████████████░░░░░░░░░░░░░░░░░▌     │  │
│  │             │  │                                          │  │
│  │             │  ├──────────────────────────────────────────┤  │
│  │             │  │  📚 Citations (Perplexity only)          │  │
│  │             │  │  [1] Source Title - url.com              │  │
│  │             │  │  [2] Another Source - other.com          │  │
│  └─────────────┘  └─────────────────────────────────────────┘  │
│                                                                  │
│  Context: 3 messages │ [New Conversation]     [Stop] [Generate] │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Quick Rewrite Button

### Location
`src/app/PreviewToolBar.tsx` - Add after the AI Wand button

### Component Design

```tsx
// New component: QuickRewriteButton.tsx
interface QuickRewriteButtonProps {
  selectedItem: Clip;
  onComplete: (newText: string) => void;
}

function QuickRewriteButton({ selectedItem, onComplete }: QuickRewriteButtonProps) {
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleQuickRewrite = async () => {
    setIsProcessing(true);
    setError(null);
    
    try {
      const aiService = getAIService();
      const result = await aiService.rewrite(
        selectedItem.content,
        getOptimizedPrompt('improveWriting')
      );
      onComplete(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button 
          variant="toolbar" 
          size="toolbar" 
          onClick={handleQuickRewrite}
          disabled={isProcessing}
        >
          {isProcessing ? (
            <Loader2 className="h-5 w-5 animate-spin" />
          ) : (
            <Sparkles className="h-5 w-5" />
          )}
        </Button>
      </TooltipTrigger>
      <TooltipContent>
        {error ? (
          <span className="text-destructive">{error}</span>
        ) : (
          <span>Quick Improve</span>
        )}
      </TooltipContent>
    </Tooltip>
  );
}
```

### Dropdown Variant (Optional Enhancement)

```tsx
<DropdownMenu>
  <DropdownMenuTrigger asChild>
    <Button variant="toolbar" size="toolbar">
      <Sparkles className="h-5 w-5" />
      <ChevronDown className="h-3 w-3 ml-0.5" />
    </Button>
  </DropdownMenuTrigger>
  <DropdownMenuContent>
    <DropdownMenuItem onClick={() => quickAction('improveWriting')}>
      <Sparkles className="h-4 w-4 mr-2" />
      Quick Improve
    </DropdownMenuItem>
    <DropdownMenuItem onClick={() => quickAction('summarize')}>
      <NotebookText className="h-4 w-4 mr-2" />
      Quick Summarize
    </DropdownMenuItem>
    <DropdownMenuItem onClick={() => quickAction('makeProfessional')}>
      <Briefcase className="h-4 w-4 mr-2" />
      Make Professional
    </DropdownMenuItem>
    <DropdownMenuSeparator />
    <DropdownMenuItem onClick={openFullDialog}>
      <WandIcon className="h-4 w-4 mr-2" />
      More Actions...
    </DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>
```

---

## 2. Perplexity Citations UI

### Data Flow

```
PerplexityProvider.rewrite()
       │
       ├── API Response includes citations[]
       │
       ├── Store in this.lastCitations
       │
       └── Return content + expose getLastCitations()

AIService.rewrite()
       │
       └── After rewrite, check if provider has citations
           │
           └── Return { content, citations? }

AIRewriteDialog
       │
       └── Display citations panel if available
```

### Interface Changes

```typescript
// ai-service.ts - Enhanced return type
export interface RewriteResult {
  content: string;
  citations?: Citation[];
  usedWebSearch?: boolean;
}

// AIService method signature (backwards compatible)
async rewrite(text: string, instruction: string): Promise<string | RewriteResult> {
  // ... existing code ...
  
  // After getting result, check for citations
  if (provider instanceof PerplexityProvider) {
    const citations = provider.getLastCitations();
    if (citations.length > 0) {
      return {
        content: response,
        citations,
        usedWebSearch: true
      };
    }
  }
  
  return response;
}
```

### Citations Panel Component

```tsx
// CitationsPanel.tsx
interface CitationsPanelProps {
  citations: Citation[];
  expanded?: boolean;
}

function CitationsPanel({ citations, expanded = false }: CitationsPanelProps) {
  const [isExpanded, setIsExpanded] = useState(expanded);
  
  if (citations.length === 0) return null;
  
  return (
    <div className="border-t border-border mt-2 pt-2">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground"
      >
        <BookOpen className="h-3.5 w-3.5" />
        <span>Sources ({citations.length})</span>
        <ChevronDown className={`h-3 w-3 transition-transform ${isExpanded ? 'rotate-180' : ''}`} />
      </button>
      
      {isExpanded && (
        <div className="mt-2 space-y-2">
          {citations.map((citation, i) => (
            <a
              key={i}
              href={citation.url}
              target="_blank"
              rel="noopener noreferrer"
              className="block p-2 rounded bg-secondary/50 hover:bg-secondary text-xs"
            >
              <div className="font-medium truncate">{citation.title || citation.url}</div>
              {citation.snippet && (
                <div className="text-muted-foreground mt-0.5 line-clamp-2">{citation.snippet}</div>
              )}
              <div className="text-primary/70 mt-1 truncate">{citation.url}</div>
            </a>
          ))}
        </div>
      )}
    </div>
  );
}
```

---

## 3. Conversation Context Memory

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   AIConversationContext                          │
├─────────────────────────────────────────────────────────────────┤
│  messages: Message[]     // Array of {role, content}            │
│  maxMessages: number     // Default 10 (5 exchanges)            │
│                                                                  │
│  addMessage(role, content)                                       │
│  getMessages(): Message[]                                        │
│  clear()                                                         │
│  getMessageCount(): number                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation

```typescript
// ai-context.ts
export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
}

export class AIConversationContext {
  private messages: Message[] = [];
  private maxMessages: number = 10;
  
  addUserMessage(content: string): void {
    this.addMessage('user', content);
  }
  
  addAssistantMessage(content: string): void {
    this.addMessage('assistant', content);
  }
  
  private addMessage(role: 'user' | 'assistant', content: string): void {
    this.messages.push({
      role,
      content,
      timestamp: Date.now()
    });
    
    // Trim to max messages
    if (this.messages.length > this.maxMessages) {
      this.messages = this.messages.slice(-this.maxMessages);
    }
  }
  
  getMessages(): Message[] {
    return [...this.messages];
  }
  
  clear(): void {
    this.messages = [];
  }
  
  getCount(): number {
    return this.messages.length;
  }
  
  isEmpty(): boolean {
    return this.messages.length === 0;
  }
}

// Usage in providers - modify API call to include context
const messages = [
  { role: 'system', content: systemPrompt },
  ...context.getMessages(),
  { role: 'user', content: currentPrompt }
];
```

### UI Integration

```tsx
// In AIRewriteDialog.tsx
const [context] = useState(() => new AIConversationContext());

// Show context indicator
{context.getCount() > 0 && (
  <div className="flex items-center gap-2 text-xs text-muted-foreground">
    <MessageSquare className="h-3.5 w-3.5" />
    <span>{context.getCount()} messages in context</span>
    <button
      onClick={() => context.clear()}
      className="text-primary hover:underline"
    >
      New Conversation
    </button>
  </div>
)}
```

---

## 4. Image Analysis / Vision

### Provider Capability Check

```typescript
// ai-service.ts
export interface AIProvider {
  name: string;
  rewrite(text: string, instruction: string): Promise<string>;
  rewriteStream?(...): Promise<void>;
  isAvailable(): Promise<boolean>;
  supportsStreaming(): boolean;
  supportsVision?(): boolean;  // NEW
  analyzeImage?(imageBase64: string, prompt: string): Promise<string>;  // NEW
}
```

### OpenAI Vision Implementation

```typescript
// openai-provider.ts
supportsVision(): boolean {
  const model = this.config.model || '';
  // GPT-4o and GPT-4o-mini support vision
  return model.includes('gpt-4o');
}

async analyzeImage(imageBase64: string, prompt: string): Promise<string> {
  if (!this.supportsVision()) {
    throw new Error('Current model does not support vision');
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
              url: `data:image/png;base64,${imageBase64}`,
              detail: 'auto'
            }
          }
        ]
      }],
      max_tokens: 1500
    })
  });

  const data = await response.json();
  return data.choices[0]?.message?.content || '';
}
```

### Image Actions

```typescript
// prompts/image-prompts.ts
export const IMAGE_ACTIONS = {
  describeImage: {
    prompt: 'Describe this image in detail. What do you see?',
    maxTokens: 1000,
  },
  extractText: {
    prompt: 'Extract all text visible in this image. Return only the text, formatted clearly.',
    maxTokens: 2000,
  },
  analyzeContent: {
    prompt: 'Analyze this image. What is it showing? What is the context?',
    maxTokens: 1500,
  },
  summarizeDocument: {
    prompt: 'This appears to be a document or screenshot. Summarize its content.',
    maxTokens: 1000,
  },
};
```

---

## 5. Streaming UI Improvements

### Cursor Animation

```tsx
// Add cursor component
const StreamingCursor = () => (
  <span className="inline-block w-0.5 h-4 bg-primary animate-pulse ml-0.5" />
);

// In result textarea area
{isStreaming && (
  <div className="flex-1 p-3 font-mono text-sm overflow-y-auto">
    {streamingText}
    <StreamingCursor />
  </div>
)}
```

### Stop Button

```tsx
const abortControllerRef = useRef<AbortController | null>(null);

const handleGenerate = async () => {
  abortControllerRef.current = new AbortController();
  
  // Pass signal to streaming
  await aiService.rewriteStream(text, instruction, {
    signal: abortControllerRef.current.signal,
    onChunk: (chunk) => { ... },
    // ...
  });
};

const handleStop = () => {
  abortControllerRef.current?.abort();
  setIsStreaming(false);
};

// UI
{isStreaming && (
  <Button variant="destructive" size="sm" onClick={handleStop}>
    <Square className="h-3 w-3 mr-1" />
    Stop
  </Button>
)}
```

### Smooth Text Batching

```typescript
// Batch small chunks for smoother rendering
let chunkBuffer = '';
let renderTimeout: number | null = null;

const flushBuffer = () => {
  if (chunkBuffer) {
    setStreamingText(prev => prev + chunkBuffer);
    chunkBuffer = '';
  }
};

callbacks.onChunk = (chunk) => {
  chunkBuffer += chunk;
  
  // Render at most every 50ms
  if (!renderTimeout) {
    renderTimeout = setTimeout(() => {
      flushBuffer();
      renderTimeout = null;
    }, 50);
  }
};
```

---

## 📁 File Changes Summary

| File | Change |
|------|--------|
| `src/app/PreviewToolBar.tsx` | Add QuickRewriteButton |
| `src/app/AIRewriteDialog.tsx` | Add citations panel, context UI, stop button |
| `src/ai/ai-service.ts` | Add context support, enhanced return type |
| `src/ai/ai-context.ts` | NEW - Conversation context class |
| `src/ai/openai-provider.ts` | Add vision support |
| `src/ai/perplexity-provider.ts` | Expose citations properly |
| `src/app/CitationsPanel.tsx` | NEW - Citations display component |
| `src/app/QuickRewriteButton.tsx` | NEW - Quick action button |
