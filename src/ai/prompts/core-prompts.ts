/**
 * Core AI Prompts - Optimized for speed and quality
 * 
 * PERFORMANCE TIPS:
 * - Shorter prompts = faster responses + lower cost
 * - Lower max_tokens = faster responses (set per action)
 * - Temperature 0.3 = consistent, fast; 0.7 = creative, slower
 */

// Performance settings per action type
export interface ActionConfig {
  prompt: string | ((param: string) => string);
  maxTokens: number;      // Lower = faster
  temperature: number;    // 0.1-0.3 = fast/consistent, 0.5-0.8 = creative
  requiresAI: boolean;    // false = use quick transform instead
}

// Optimized prompts - SHORTER = FASTER
export const CORE_PROMPTS: Record<string, ActionConfig> = {
  // ========== WRITING (Most common) ==========
  improveWriting: {
    prompt: `Fix grammar, enhance clarity, improve quality. Keep original meaning.
Return ONLY the improved text.`,
    maxTokens: 1500,
    temperature: 0.3,
    requiresAI: true
  },

  rewrite: {
    prompt: `Rewrite with different words and structure. Same meaning.
Return ONLY the rewritten text.`,
    maxTokens: 1500,
    temperature: 0.5,
    requiresAI: true
  },

  paraphrase: {
    prompt: `Paraphrase: same ideas, different words.
Return ONLY the paraphrased text.`,
    maxTokens: 1500,
    temperature: 0.5,
    requiresAI: true
  },

  // ========== SUMMARY ==========
  summarize: {
    prompt: `Summarize to key points only.
Return ONLY the summary.`,
    maxTokens: 500,  // Summaries should be short
    temperature: 0.3,
    requiresAI: true
  },

  summarizeBullets: {
    prompt: `Summarize as bullet points.
Return ONLY bullet points using "•".`,
    maxTokens: 500,
    temperature: 0.3,
    requiresAI: true
  },

  expand: {
    prompt: `Expand with more detail and examples.
Return ONLY the expanded text.`,
    maxTokens: 2000,
    temperature: 0.6,
    requiresAI: true
  },

  // ========== TONE ==========
  makeProfessional: {
    prompt: `Convert to professional business tone.
Return ONLY the professional text.`,
    maxTokens: 1500,
    temperature: 0.3,
    requiresAI: true
  },

  makeCasual: {
    prompt: `Convert to casual, friendly tone.
Return ONLY the casual text.`,
    maxTokens: 1500,
    temperature: 0.5,
    requiresAI: true
  },

  makeFriendly: {
    prompt: `Make more warm and friendly.
Return ONLY the friendly text.`,
    maxTokens: 1500,
    temperature: 0.5,
    requiresAI: true
  },

  makeConfident: {
    prompt: `Rewrite with confident, assertive tone. Remove hedging words.
Return ONLY the confident text.`,
    maxTokens: 1500,
    temperature: 0.3,
    requiresAI: true
  },

  simplify: {
    prompt: `Simplify for easy reading. Use simple words, short sentences.
Return ONLY the simplified text.`,
    maxTokens: 1500,
    temperature: 0.3,
    requiresAI: true
  },

  // ========== CODE ==========
  fixCode: {
    prompt: `Fix bugs, improve quality. Add brief inline comments.
Return ONLY the fixed code.`,
    maxTokens: 2000,
    temperature: 0.2,  // Low temp for code accuracy
    requiresAI: true
  },

  explainCode: {
    prompt: `Add detailed inline comments explaining the code.
Return ONLY the commented code.`,
    maxTokens: 2500,
    temperature: 0.3,
    requiresAI: true
  },

  optimizeCode: {
    prompt: `Optimize for performance. Comment on changes.
Return ONLY the optimized code.`,
    maxTokens: 2000,
    temperature: 0.2,
    requiresAI: true
  },

  // ========== FORMAT ==========
  formatJSON: {
    prompt: `Format/prettify this JSON.
Return ONLY the formatted JSON.`,
    maxTokens: 2000,
    temperature: 0.1,  // Very low for formatting
    requiresAI: true
  },

  toMarkdown: {
    prompt: `Convert to Markdown format.
Return ONLY the Markdown.`,
    maxTokens: 2000,
    temperature: 0.3,
    requiresAI: true
  },

  // ========== LANGUAGE ==========
  translate: {
    prompt: (lang: string) => `Translate to ${lang}. Natural phrasing.
Return ONLY the ${lang} translation.`,
    maxTokens: 2000,
    temperature: 0.3,
    requiresAI: true
  },

  detectLanguage: {
    prompt: `What language is this?
Return ONLY the language name.`,
    maxTokens: 50,  // Very short response needed
    temperature: 0.1,
    requiresAI: true
  },

  // ========== FIX ==========
  fixGrammar: {
    prompt: `Fix grammar only. Don't change style or words.
Return ONLY the corrected text.`,
    maxTokens: 1500,
    temperature: 0.2,
    requiresAI: true
  },

  fixSpelling: {
    prompt: `Fix spelling only.
Return ONLY the corrected text.`,
    maxTokens: 1500,
    temperature: 0.1,
    requiresAI: true
  },

  fixPunctuation: {
    prompt: `Fix punctuation only.
Return ONLY the corrected text.`,
    maxTokens: 1500,
    temperature: 0.1,
    requiresAI: true
  },

  // ========== EXTRACT (AI-powered for complex extraction) ==========
  extractKeywords: {
    prompt: `Extract important keywords.
Return ONLY comma-separated keywords.`,
    maxTokens: 200,
    temperature: 0.2,
    requiresAI: true
  },

  // ========== ADVANCED ==========
  generatePrompt: {
    prompt: (topic: string) => `Create a clear AI instruction for: ${topic}
Return ONLY the instruction prompt.`,
    maxTokens: 500,
    temperature: 0.6,
    requiresAI: true
  },

  research: {
    prompt: `Research this topic. Provide accurate info with sources.
Be comprehensive but concise.`,
    maxTokens: 2000,
    temperature: 0.5,
    requiresAI: true
  },

  factCheck: {
    prompt: `Verify the facts in this text. Note what's accurate or not.`,
    maxTokens: 1500,
    temperature: 0.3,
    requiresAI: true
  },

  custom: {
    prompt: (instruction: string) => `${instruction}
Return ONLY the result.`,
    maxTokens: 2000,
    temperature: 0.5,
    requiresAI: true
  },

  // ========== QUICK (Local transforms - NO AI) ==========
  // Note: Basic case/whitespace transforms (uppercase, lowercase, capitalize, 
  // sentence case, trim, remove empty lines) are in ClipBook's built-in 
  // FormatTextCommands - we only add ADDITIONAL transforms here
  
  // Extractions
  extractEmails: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractUrls: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractNumbers: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractPhoneNumbers: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractDates: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractHashtags: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractMentions: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Format
  toBulletPoints: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toNumberedList: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Analysis
  countStats: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Sort & Unique
  sortLines: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  sortLinesReverse: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  uniqueLines: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Reverse
  reverse: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  reverseWords: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  reverseLines: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Encoding
  toBase64: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  fromBase64: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  encodeUri: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  decodeUri: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  escapeHtml: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  unescapeHtml: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // JSON
  formatJson: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  minifyJson: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Case conversions
  toSlug: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toSnakeCase: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toCamelCase: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toPascalCase: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toKebabCase: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Developer tools
  extractGitHubUrls: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractGitHubIssues: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  wrapInCodeBlock: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  wrapInCodeBlockLang: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  stripCodeBlock: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  formatCommitMessage: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // Markdown
  toMarkdownLink: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toMarkdownImage: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toMarkdownTable: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  stripMarkdown: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  
  // System/Terminal-like tools (safe, no shell execution)
  generateUUID: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  generatePassword: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  generateRandomHex: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  timestampToDate: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  dateToTimestamp: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  currentTimestamp: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  extractIPs: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  pathBasename: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  pathDirname: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  pathExtension: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  toEnvFormat: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  parseCron: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  testRegex: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  compareLines: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  parseSize: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  calculate: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  wordFrequency: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  charFrequency: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  hexToRgb: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
  rgbToHex: { prompt: '', maxTokens: 0, temperature: 0, requiresAI: false },
};

// Get the prompt string for an action
export function getOptimizedPrompt(action: string, param?: string): string {
  const config = CORE_PROMPTS[action];
  if (!config) return '';
  
  if (typeof config.prompt === 'function') {
    return config.prompt(param || '');
  }
  return config.prompt;
}

// Get performance settings for an action
export function getActionSettings(action: string): { maxTokens: number; temperature: number } {
  const config = CORE_PROMPTS[action];
  return {
    maxTokens: config?.maxTokens || 1500,
    temperature: config?.temperature || 0.5
  };
}

// Check if action requires AI
export function requiresAI(action: string): boolean {
  const config = CORE_PROMPTS[action];
  return config?.requiresAI ?? true;
}

