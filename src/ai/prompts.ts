/**
 * AI Prompts - Re-export from modular structure
 * 
 * This file maintains backwards compatibility while the actual
 * prompts are now organized in src/ai/prompts/ folder for better
 * performance and maintainability.
 * 
 * Quick transforms (⚡) run INSTANTLY without API calls
 * AI actions use optimized short prompts for faster responses
 */

// Re-export everything from the modular structure
export type { AIAction } from './prompts/index';

export {
  // Core functions
  ACTION_CATEGORIES,
  ACTION_METADATA,
  getPrompt,
  getAllActions,
  actionRequiresParams,
  getActionParamName,
  
  // Performance optimizations
  getOptimizedPrompt,
  getActionSettings,
  requiresAI,
  
  // Raw data
  CORE_PROMPTS,
} from './prompts/index';

// Legacy export for backwards compatibility
import { CORE_PROMPTS } from './prompts/index';

// Map old format to new
export const AI_PROMPTS = Object.fromEntries(
  Object.entries(CORE_PROMPTS).map(([key, config]) => [
    key,
    typeof config.prompt === 'function' ? config.prompt : config.prompt
  ])
);
