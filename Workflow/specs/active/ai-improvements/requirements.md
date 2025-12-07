# AI Improvements - Requirements Specification

**Created:** December 7, 2025  
**Status:** 🟡 In Progress  
**Priority:** High

---

## 📋 Overview

Enhance ClipBook's AI capabilities with improved UX, new features, and better integration.

---

## ✅ Current State Analysis

### What's Already Implemented

| Feature | Status | Notes |
|---------|--------|-------|
| AI Streaming | ✅ **WORKING** | All 3 providers support streaming |
| Ollama Provider | ✅ Complete | Local, private, supports streaming |
| OpenAI Provider | ✅ Complete | GPT-4o, streaming (except O1 models) |
| Perplexity Provider | ✅ Complete | Sonar models, streaming, web search |
| AI Rewrite Dialog | ✅ Complete | Side-by-side comparison, 40+ actions |
| Caching | ✅ Complete | 5-minute TTL in ai-service.ts |
| Retry Logic | ✅ Complete | Exponential backoff for rate limits |

### What's Missing/Needed

| Feature | Status | Priority |
|---------|--------|----------|
| Citations UI for Perplexity | ❌ Missing | HIGH |
| Quick Rewrite Button | ❌ Missing | HIGH |
| Conversation Context Memory | ❌ Missing | MEDIUM |
| Image Analysis (Vision) | ❌ Missing | MEDIUM |
| Streaming UI Polish | ⚠️ Basic | MEDIUM |

---

## 🎯 Feature Requirements

### 1. Quick Rewrite Toolbar Button (HIGH)

**User Story:** As a user, I want to quickly improve my text with one click without opening the full AI dialog.

**Requirements:**
- Add "Quick Improve" button to PreviewToolBar (next to AI Wand icon)
- One-click to improve writing using default action ("improveWriting")
- Show inline loading state
- Replace text automatically when done
- Optional: Dropdown for quick actions (Improve, Summarize, Professional)

**Acceptance Criteria:**
- [ ] Quick improve button visible for text items
- [ ] Single click triggers AI improvement
- [ ] Loading indicator shown during processing
- [ ] Text replaced automatically on completion
- [ ] Error handling with tooltip message

---

### 2. Perplexity Citations UI (HIGH)

**User Story:** As a user using Perplexity for research tasks, I want to see the sources cited so I can verify information.

**Requirements:**
- Display citations when `returnCitations: true` and research actions used
- Show as collapsible panel below result text
- Each citation shows: title, URL, snippet
- Clickable URLs open in browser
- Only show for research/fact-check actions (not rewrites)

**Acceptance Criteria:**
- [ ] Citations panel appears when citations available
- [ ] Citations show title, URL, and snippet
- [ ] URLs are clickable and open in browser
- [ ] Panel is collapsible/expandable
- [ ] Citations hidden for rewrite-type actions

---

### 3. Conversation Context Memory (MEDIUM)

**User Story:** As a user, I want the AI to remember our conversation so I can ask follow-up questions.

**Requirements:**
- Store last N messages (configurable, default 5)
- Context persists within a dialog session
- "New Conversation" button to clear context
- Context indicator showing how many messages stored
- Memory cleared when dialog closes

**Acceptance Criteria:**
- [ ] Follow-up questions work correctly
- [ ] Context shown in UI (e.g., "3 messages in context")
- [ ] "New Conversation" clears history
- [ ] Memory auto-clears on dialog close
- [ ] Works with all providers

---

### 4. Image Analysis / Vision (MEDIUM)

**User Story:** As a user, I want to analyze images from my clipboard using AI.

**Requirements:**
- Support for OpenAI GPT-4o Vision
- Actions: Describe image, Extract text (better than OCR), Analyze content
- Show in AI dialog when image item selected
- Display analysis result as text

**Provider Support:**
- OpenAI: GPT-4o, GPT-4o-mini (vision capable)
- Ollama: llava, bakllava models
- Perplexity: Not supported

**Acceptance Criteria:**
- [ ] AI button visible for image items
- [ ] Image analysis actions available
- [ ] Result displayed in dialog
- [ ] Works with OpenAI vision models
- [ ] Graceful fallback if provider doesn't support vision

---

### 5. Streaming UI Improvements (MEDIUM)

**User Story:** As a user, I want a smoother streaming experience that feels responsive.

**Current State:** Basic streaming works, text appears chunk by chunk.

**Improvements Needed:**
- Blinking cursor animation at end of streaming text
- Smoother text appearance (batch small chunks)
- "Stop" button to cancel generation
- Better visual distinction between streaming and complete states

**Acceptance Criteria:**
- [ ] Cursor animation during streaming
- [ ] Stop button to cancel
- [ ] Smooth text rendering
- [ ] Clear visual states (generating vs complete)

---

## 📐 Non-Functional Requirements

### Performance
- Quick rewrite should complete in <3s for short text
- Streaming should start within 500ms
- No UI lag during streaming

### Privacy
- All conversation context stored locally only
- No data sent without user action
- Image data not persisted after analysis

### Compatibility
- Works with all existing AI providers
- Graceful degradation if feature not supported

---

## 🚫 Out of Scope

- Additional AI providers (Claude, Gemini, etc.)
- Cross-platform clipboard sync
- Batch processing multiple items
- Custom provider support

---

## 📚 Reference Files

```
src/ai/
├── ai-service.ts          # Core service with streaming
├── ollama-provider.ts     # ✅ Streaming implemented
├── openai-provider.ts     # ✅ Streaming implemented
├── perplexity-provider.ts # ✅ Streaming + citations stored
└── prompts/               # Action definitions

src/app/
├── AIRewriteDialog.tsx    # Main dialog (needs enhancements)
└── PreviewToolBar.tsx     # Toolbar (needs quick button)
```
