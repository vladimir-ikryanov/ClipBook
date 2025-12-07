# AI Improvements - Task Tracker

**Created:** December 7, 2025  
**Last Updated:** December 7, 2025

---

## 📊 Progress Overview

| Feature | Status | Priority | Est. Time |
|---------|--------|----------|-----------|
| Quick Rewrite Button | `- [x]` ✅ Complete | HIGH | 2-3 hours |
| Perplexity Citations UI | `- [x]` ✅ Complete | HIGH | 3-4 hours |
| Conversation Context Memory | `- [x]` ✅ Complete | MEDIUM | 3-4 hours |
| Image Analysis (Vision) | `- [x]` ✅ Complete | MEDIUM | 4-5 hours |
| Streaming UI Polish | `- [x]` ✅ Complete | MEDIUM | 2-3 hours |
| Perplexity Vision (Sonar Pro) | `- [x]` ✅ Complete | MEDIUM | 1 hour |
| Model Switcher in Dialogs | `- [x]` ✅ Complete | MEDIUM | 1 hour |
| Image Paste/Drop Support | `- [x]` ✅ Complete | MEDIUM | 1 hour |

**Total Estimated Time:** 17-22 hours

---

## 🎯 Task 1: Quick Rewrite Toolbar Button

**Priority:** HIGH  
**Estimated Time:** 2-3 hours

### Tasks

- [ ] **1.1** Create `QuickRewriteButton.tsx` component
  - Basic button with loading state
  - Uses `improveWriting` action by default
  - Error handling via tooltip

- [ ] **1.2** Add button to `PreviewToolBar.tsx`
  - Position: After AI Wand button, before Tools
  - Only visible for text items
  - Icon: `Sparkles` from lucide-react

- [ ] **1.3** Implement quick action handler
  - Get AI service
  - Call rewrite with `improveWriting` prompt
  - Update item content on success
  - Emit `EditItem` event

- [ ] **1.4** Add dropdown for multiple quick actions (Optional)
  - Quick Improve (improveWriting)
  - Quick Summarize (summarize)
  - Make Professional (makeProfessional)
  - "More Actions..." → opens full dialog

- [ ] **1.5** Add i18n translations
  - `preview.toolbar.quickImprove`
  - `preview.toolbar.quickSummarize`
  - etc.

### Files to Modify
```
src/app/QuickRewriteButton.tsx     (NEW)
src/app/PreviewToolBar.tsx         (MODIFY)
public/locales/en/translation.json (MODIFY)
```

---

## 🎯 Task 2: Perplexity Citations UI

**Priority:** HIGH  
**Estimated Time:** 3-4 hours

### Tasks

- [ ] **2.1** Enhance `AIService` return type
  - Create `RewriteResult` interface
  - Return citations when available
  - Backwards compatible (string | RewriteResult)

- [ ] **2.2** Update `PerplexityProvider`
  - Enable `returnCitations: true` for research actions
  - Expose citations via enhanced response
  - Detect research vs rewrite actions

- [ ] **2.3** Create `CitationsPanel.tsx` component
  - Collapsible panel design
  - Show title, URL, snippet for each citation
  - Clickable links (open in browser)
  - Count indicator

- [ ] **2.4** Integrate into `AIRewriteDialog.tsx`
  - Store citations in state
  - Show panel below result when citations exist
  - Hide for non-research actions

- [ ] **2.5** Add styling and animations
  - Smooth expand/collapse
  - Hover states for links
  - Consistent with app design

### Files to Modify
```
src/ai/ai-service.ts               (MODIFY)
src/ai/perplexity-provider.ts      (MODIFY)
src/app/CitationsPanel.tsx         (NEW)
src/app/AIRewriteDialog.tsx        (MODIFY)
```

---

## 🎯 Task 3: Conversation Context Memory

**Priority:** MEDIUM  
**Estimated Time:** 3-4 hours

### Tasks

- [ ] **3.1** Create `ai-context.ts` module
  - `Message` interface
  - `AIConversationContext` class
  - add/get/clear methods
  - Max message limit (10)

- [ ] **3.2** Update providers to use context
  - Modify message array construction
  - Include context messages before current prompt
  - Ollama: Use `/api/chat` endpoint instead of `/api/generate`

- [ ] **3.3** Integrate into `AIRewriteDialog.tsx`
  - Create context instance (per dialog session)
  - Add messages after each exchange
  - Clear on dialog close

- [ ] **3.4** Add context UI elements
  - Message count indicator
  - "New Conversation" button
  - Visual feedback when context used

- [ ] **3.5** Test follow-up functionality
  - Verify context improves responses
  - Test with all providers
  - Ensure memory clears properly

### Files to Modify
```
src/ai/ai-context.ts               (NEW)
src/ai/ai-service.ts               (MODIFY)
src/ai/ollama-provider.ts          (MODIFY - use /api/chat)
src/ai/openai-provider.ts          (MODIFY)
src/ai/perplexity-provider.ts      (MODIFY)
src/app/AIRewriteDialog.tsx        (MODIFY)
```

---

## 🎯 Task 4: Image Analysis (Vision)

**Priority:** MEDIUM  
**Estimated Time:** 4-5 hours

### Tasks

- [ ] **4.1** Add vision interface to providers
  - `supportsVision()` method
  - `analyzeImage(base64, prompt)` method
  - Define in `AIProvider` interface

- [ ] **4.2** Implement OpenAI vision
  - Check model supports vision (gpt-4o, gpt-4o-mini)
  - Construct vision API request
  - Handle image as base64 data URL

- [ ] **4.3** Create image action prompts
  - Describe Image
  - Extract Text (OCR alternative)
  - Analyze Content
  - Summarize Document

- [ ] **4.4** Update `AIRewriteDialog.tsx` for images
  - Detect when image item selected
  - Show image preview instead of text
  - Show image-specific actions
  - Display text result

- [ ] **4.5** Add image support to `PreviewToolBar.tsx`
  - Show AI button for images (not just text)
  - Only when provider supports vision

- [ ] **4.6** Test with various image types
  - Screenshots
  - Photos
  - Documents
  - Charts/diagrams

### Files to Modify
```
src/ai/ai-service.ts               (MODIFY)
src/ai/openai-provider.ts          (MODIFY)
src/ai/prompts/image-prompts.ts    (NEW)
src/app/AIRewriteDialog.tsx        (MODIFY)
src/app/PreviewToolBar.tsx         (MODIFY)
```

---

## 🎯 Task 5: Streaming UI Polish

**Priority:** MEDIUM  
**Estimated Time:** 2-3 hours

### Tasks

- [ ] **5.1** Add cursor animation
  - Blinking cursor at end of streaming text
  - CSS animation for smooth blink
  - Hide when streaming complete

- [ ] **5.2** Implement Stop button
  - Add AbortController to streaming
  - Button shows during streaming
  - Cancels current generation
  - Updates UI state properly

- [ ] **5.3** Smooth text batching
  - Buffer small chunks
  - Render at 50ms intervals
  - Prevents choppy appearance

- [ ] **5.4** Visual state improvements
  - Clear "Generating..." indicator
  - Progress-like border animation
  - Smooth transition to complete state

- [ ] **5.5** Update all providers for abort support
  - Pass signal to fetch calls
  - Handle AbortError gracefully

### Files to Modify
```
src/app/AIRewriteDialog.tsx        (MODIFY)
src/ai/ai-service.ts               (MODIFY)
src/ai/ollama-provider.ts          (MODIFY)
src/ai/openai-provider.ts          (MODIFY)
src/ai/perplexity-provider.ts      (MODIFY)
src/index.css                      (MODIFY - cursor animation)
```

---

## 📋 Implementation Order

**Recommended sequence:**

1. **Quick Rewrite Button** - Quick win, high impact
2. **Streaming UI Polish** - Improves existing feature
3. **Perplexity Citations** - High value for research users
4. **Conversation Context** - Enhances all interactions
5. **Image Analysis** - New capability, more complex

---

## ✅ Completion Checklist

Before marking complete:

- [ ] All tasks checked off
- [ ] No TypeScript errors
- [ ] No linter warnings
- [ ] Tested with Ollama provider
- [ ] Tested with OpenAI provider
- [ ] Tested with Perplexity provider
- [ ] i18n translations added
- [ ] UI consistent with app design
- [ ] Error states handled
- [ ] Loading states shown

---

## 📝 Notes

### Current Findings from Code Review

1. **Streaming is ALREADY IMPLEMENTED** ✅
   - All 3 providers have `rewriteStream()` method
   - `AIRewriteDialog.tsx` handles streaming display
   - Works with `supportsStreaming()` check

2. **Citations are PARTIALLY IMPLEMENTED**
   - `PerplexityProvider` has `Citation` interface
   - `getLastCitations()` method exists
   - BUT: No UI to display them

3. **Context Memory NOT IMPLEMENTED**
   - Messages are sent one-off
   - No history between requests

4. **Vision NOT IMPLEMENTED**
   - No `analyzeImage` method
   - No image handling in dialog

---

## 🔗 Related Files Reference

```
Existing AI Files:
├── src/ai/ai-service.ts           # Core service, caching, retry
├── src/ai/ollama-provider.ts      # Local Ollama
├── src/ai/openai-provider.ts      # OpenAI API
├── src/ai/perplexity-provider.ts  # Perplexity + citations
├── src/ai/prompts.ts              # Re-exports
└── src/ai/prompts/
    ├── core-prompts.ts            # AI action configs
    ├── quick-transforms.ts        # Local transforms
    └── index.ts                   # Exports

UI Files:
├── src/app/AIRewriteDialog.tsx    # Main dialog
├── src/app/PreviewToolBar.tsx     # Toolbar with AI button
└── src/app/PreviewToolBarMenu.tsx # More actions menu

Settings:
├── src/settings/AISettings.tsx    # AI configuration
└── src/pref.tsx                   # AI preferences storage

New Files (December 7, 2025):
├── src/app/QuickRewriteButton.tsx # Quick improve button
├── src/app/CitationsPanel.tsx     # Perplexity citations display
├── src/app/ImageAnalysisDialog.tsx # Image analysis dialog
├── src/app/ModelSwitcher.tsx      # Model selection in dialogs
├── src/ai/ai-context.ts           # Conversation context memory
└── src/ai/prompts/image-prompts.ts # Image analysis prompts
```

---

## 🎯 Task 6: Perplexity Vision Support (Sonar Pro)

**Priority:** MEDIUM  
**Status:** ✅ Complete

### Tasks

- [x] **6.1** Update PERPLEXITY_MODELS with vision support flags
- [x] **6.2** Add `supportsVision()` method to PerplexityProvider
- [x] **6.3** Implement `analyzeImage()` for Perplexity

### Files Modified
```
src/ai/perplexity-provider.ts
```

---

## 🎯 Task 7: Model Switcher in Dialogs

**Priority:** MEDIUM  
**Status:** ✅ Complete

### Tasks

- [x] **7.1** Create `ModelSwitcher.tsx` component
- [x] **7.2** Show only models for current provider
- [x] **7.3** Show vision indicator on supported models
- [x] **7.4** Add to AIRewriteDialog header
- [x] **7.5** Add to ImageAnalysisDialog header (vision-only models)

### Files Created/Modified
```
src/app/ModelSwitcher.tsx         (NEW)
src/app/AIRewriteDialog.tsx       (MODIFIED)
src/app/ImageAnalysisDialog.tsx   (MODIFIED)
```

---

## 🎯 Task 8: Image Paste/Drop Support

**Priority:** MEDIUM  
**Status:** ✅ Complete

### Tasks

- [x] **8.1** Add paste handler (⌘V) for images
- [x] **8.2** Add drag & drop support
- [x] **8.3** Visual drop zone indicator
- [x] **8.4** Update image preview dynamically

### Files Modified
```
src/app/ImageAnalysisDialog.tsx
```
