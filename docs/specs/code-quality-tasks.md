# Code Quality Improvement Tasks

> Quick reference for implementation. See `code-quality-improvements.md` for full details.

---

## 🔴 TIER 1: Critical (Do First)

### T1.1 - Remove Console Logging
```
Status: [x] COMPLETED (Dec 7, 2024)
Files:  src/app/HistoryPane.tsx:345
        src/settings/Calendar.tsx:116,127,142 (kept - proper error handling)
Action: Removed debug log, kept error logs in catch blocks
```

### T1.2 - Secure API Keys
```
Status: [ ] Not Started
Files:  src/pref.tsx (AI key functions)
        src-cpp/ (new Keychain bridge)
Action: Store in macOS Keychain instead of localStorage
```

### T1.3 - Replace eval()
```
Status: [ ] Not Started
Files:  src/ai/prompts/quick-transforms.ts:503
Action: Use safe math parser (mathjs or custom)
```

---

## 🟠 TIER 2: Type Safety

### T2.1 - Global Window Interface
```
Status: [ ] Not Started
Create: src/types/global.d.ts
Update: tsconfig.json
Action: Type all (window as any) usages (17 instances)
```

### T2.2 - Fix DB Typing
```
Status: [ ] Not Started
Files:  src/db.tsx:85
Action: Create ClipUpdate partial type
```

### T2.3 - Fix @ts-ignore
```
Status: [x] COMPLETED (Dec 7, 2024)
Files:  src/settings/Appearance.tsx:163
Action: Extended CSSProperties type with CSS variable support
```

---

## 🟡 TIER 3: Deduplication

### T3.1 - Extract UUID Utility
```
Status: [x] COMPLETED (Dec 7, 2024)
Create: src/lib/crypto.ts (generateUUID, generatePassword, generateHex)
Update: src/app/ToolsDialog.tsx
        src/ai/prompts/quick-transforms.ts
        src/settings/Tools.tsx
```

---

## 🟢 TIER 4: Performance

### T4.1 - Memoize HistoryItemPane
```
Status: [ ] Not Started
Files:  src/app/HistoryItemPane.tsx
Action: Wrap with React.memo + custom comparison
```

### T4.2 - Split HistoryPane
```
Status: [ ] Not Started
Files:  src/app/HistoryPane.tsx (1661 lines)
Create: src/app/history/
        - HistoryToolbar.tsx
        - HistoryList.tsx
        - HistoryEmpty.tsx
        - hooks/useHistoryItems.ts
        - hooks/useHistorySelection.ts
        - hooks/useHistoryPaste.ts
        - hooks/useHistoryFilter.ts
```

### T4.3 - Loading States
```
Status: [ ] Not Started
Files:  Multiple
Action: Add loading indicators to async operations
```

---

## 🔵 TIER 5: Accessibility

### T5.1 - ARIA Labels
```
Status: [ ] Not Started
Files:  PreviewToolBar.tsx
        Commands.tsx
        HistoryItemContextMenu.tsx
        + other UI components
Action: Add aria-label to all icon buttons
```

---

## 📋 Implementation Order

### Quick Wins (Start Here)
1. [ ] T1.1 - Console logging (15 min)
2. [ ] T2.3 - @ts-ignore (15 min)
3. [ ] T3.1 - UUID utility (30 min)

### Type Safety Week
4. [ ] T2.1 - Global interface (2 hrs)
5. [ ] T2.2 - DB typing (30 min)

### Security Sprint
6. [ ] T1.2 - API keys (2 hrs + native)
7. [ ] T1.3 - eval() (1 hr)

### Performance Phase
8. [ ] T4.1 - Memoize (1 hr)
9. [ ] T4.2 - Split (4 hrs)

### Polish
10. [ ] T5.1 - ARIA (2 hrs)
11. [ ] T4.3 - Loading (2 hrs)

---

## ✅ Completion Log

| Date | Task | Notes |
|------|------|-------|
| Dec 7, 2024 | T1.1 | Removed debug console.log from HistoryPane |
| Dec 7, 2024 | T2.3 | Fixed @ts-ignore with proper CSS typing |
| Dec 7, 2024 | T3.1 | Created lib/crypto.ts, deduplicated UUID generation |

---

## Commands

```bash
# Create improvement branch
git checkout -b improve/code-quality

# After each tier
git add -A
git commit -m "fix: [TIER-X] description"
```
