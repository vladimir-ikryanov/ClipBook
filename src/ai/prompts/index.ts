/**
 * AI Prompts - Main Entry Point
 * 
 * Optimized for performance:
 * 1. AI prompts are SHORT (fewer tokens = faster)
 * 2. Performance settings per action type
 */

import { CORE_PROMPTS, getOptimizedPrompt, getActionSettings, requiresAI } from './core-prompts';

// Re-export everything
export { CORE_PROMPTS, getOptimizedPrompt, getActionSettings, requiresAI } from './core-prompts';

// All available actions
export type AIAction = keyof typeof CORE_PROMPTS;

// Action categories for UI
export const ACTION_CATEGORIES = {
  'Writing': ['improveWriting', 'rewrite', 'paraphrase', 'expand'],
  'Summary': ['summarize', 'summarizeBullets'],
  'Tone': ['makeProfessional', 'makeCasual', 'makeFriendly', 'makeConfident', 'simplify'],
  'Code': ['fixCode', 'explainCode', 'optimizeCode'],
  'Format': ['formatJSON', 'toMarkdown'],
  'Extract': ['extractKeywords'],
  'Language': ['translate', 'detectLanguage'],
  'Fix': ['fixGrammar', 'fixSpelling', 'fixPunctuation'],
  'Research 🌐': ['research', 'factCheck'],
  'Advanced': ['generatePrompt', 'custom'],
} as const;

// Action metadata for UI display
export const ACTION_METADATA: Record<string, { label: string; description: string; usesWebSearch?: boolean }> = {
  // Writing
  improveWriting: { label: 'Improve Writing', description: 'Fix grammar, enhance clarity' },
  rewrite: { label: 'Rewrite', description: 'Same meaning, different words' },
  paraphrase: { label: 'Paraphrase', description: 'Express differently' },
  expand: { label: 'Expand', description: 'Add more detail' },
  
  // Summary
  summarize: { label: 'Summarize', description: 'Condense to key points' },
  summarizeBullets: { label: 'Bullet Summary', description: 'Key points as bullets' },
  
  // Tone
  makeProfessional: { label: 'Professional', description: 'Formal business tone' },
  makeCasual: { label: 'Casual', description: 'Friendly, conversational' },
  makeFriendly: { label: 'Friendly', description: 'Warm and approachable' },
  makeConfident: { label: 'Confident', description: 'Assertive tone' },
  simplify: { label: 'Simplify', description: 'Easier to understand' },
  
  // Code
  fixCode: { label: 'Fix Code', description: 'Fix bugs and improve' },
  explainCode: { label: 'Explain Code', description: 'Add comments' },
  optimizeCode: { label: 'Optimize Code', description: 'Improve performance' },
  
  // Format (AI)
  formatJSON: { label: 'AI Format JSON', description: 'Smart JSON formatting' },
  toMarkdown: { label: 'To Markdown', description: 'Convert to Markdown' },
  
  // Extract (AI)
  extractKeywords: { label: 'Extract Keywords', description: 'AI-powered keyword extraction' },
  
  // Language
  translate: { label: 'Translate', description: 'Translate to any language' },
  detectLanguage: { label: 'Detect Language', description: 'Identify the language' },
  
  // Fix
  fixGrammar: { label: 'Fix Grammar', description: 'Correct grammar only' },
  fixSpelling: { label: 'Fix Spelling', description: 'Correct spelling only' },
  fixPunctuation: { label: 'Fix Punctuation', description: 'Correct punctuation' },
  
  // Research (uses web search)
  research: { label: 'Research 🌐', description: 'Search web for info', usesWebSearch: true },
  factCheck: { label: 'Fact Check 🌐', description: 'Verify with web search', usesWebSearch: true },
  
  // Advanced
  generatePrompt: { label: 'Generate Prompt', description: 'Create an AI instruction' },
  custom: { label: 'Custom', description: 'Your own instruction' },
};

// Get prompt (backwards compatible)
export function getPrompt(action: AIAction, params?: any): string {
  return getOptimizedPrompt(action, params);
}

// Get all actions
export function getAllActions(): AIAction[] {
  return Object.keys(CORE_PROMPTS) as AIAction[];
}

// Check if action requires params
export function actionRequiresParams(action: AIAction): boolean {
  return ['translate', 'generatePrompt', 'custom', 'convertCode'].includes(action);
}

// Get param name for action
export function getActionParamName(action: AIAction): string | null {
  switch (action) {
    case 'translate': return 'language';
    case 'generatePrompt': return 'topic';
    case 'custom': return 'instruction';
    default: return null;
  }
}

