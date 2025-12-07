# Theme Color Audit & Fix Specification

## Problem Analysis

### Identified Issues

1. **Selection Color Conflict (Critical)**
   - File: `src/app/HistoryItemPane.tsx` line 346
   - When item selected: `bg-accent` is used
   - In dark theme: `--accent: rgba(255, 255, 255, 0.08)` (nearly invisible)
   - Text remains default color (light) → poor contrast
   
2. **Text/Background Pairing Issues**
   - `--foreground` in dark: #f5f5f5 (white)
   - `--accent` in dark: rgba(255, 255, 255, 0.08) (light overlay)
   - Result: White text on light overlay = hard to see selection
   
3. **Inconsistent Theme Application**
   - Default dark mode uses: `@media (prefers-color-scheme: dark)`
   - New themes use: `.amoled`, `.glass-dark` class selectors
   - ThemeProvider adds class but media query still applies

---

## Color Contrast Requirements

### WCAG AA Minimum Contrast Ratios
- Normal text (< 18pt): 4.5:1
- Large text (≥ 18pt): 3:1
- UI components: 3:1

### Theme Color Matrix (Selection States)

| Theme | Selection BG | Selection Text | Hover BG | Hover Text |
|-------|-------------|----------------|----------|------------|
| Light | #e0e7ff (blue tint) | #1a1a1a | #f3f4f6 | #1a1a1a |
| Dark | #374151 (gray-700) | #f5f5f5 | #1f2937 | #f5f5f5 |
| AMOLED | #1f2937 (gray-800) | #ffffff | #111827 | #ffffff |
| Glass Light | rgba(99,102,241,0.15) | #1a1a1a | rgba(0,0,0,0.05) | #1a1a1a |
| Glass Dark | rgba(99,102,241,0.25) | #f5f5f5 | rgba(255,255,255,0.08) | #f5f5f5 |

---

## Required CSS Variable Additions

### Selection State Variables (NEW)
```css
/* Selection colors - distinct from accent */
--selection: /* background for selected items */
--selection-foreground: /* text color when selected */
--selection-hover: /* hover state for selected items */
```

### Light Theme
```css
--selection: #e0e7ff;
--selection-foreground: #1e1b4b;
--selection-hover: #c7d2fe;
```

### Dark Theme
```css
--selection: #374151;
--selection-foreground: #f9fafb;
--selection-hover: #4b5563;
```

### AMOLED Theme
```css
--selection: #1f2937;
--selection-foreground: #ffffff;
--selection-hover: #374151;
```

### Glass Light Theme
```css
--selection: rgba(99, 102, 241, 0.15);
--selection-foreground: #312e81;
--selection-hover: rgba(99, 102, 241, 0.1);
```

### Glass Dark Theme
```css
--selection: rgba(99, 102, 241, 0.25);
--selection-foreground: #e0e7ff;
--selection-hover: rgba(99, 102, 241, 0.15);
```

---

## Files to Modify

### 1. src/index.css
- Add `--selection`, `--selection-foreground`, `--selection-hover` to ALL themes
- Fix existing contrast issues in accent colors

### 2. tailwind.config.js
- Add selection color mapping to theme config

### 3. src/app/HistoryItemPane.tsx
- Replace `bg-accent` with `bg-selection`
- Add `text-selection-foreground` when selected

### 4. Other components using bg-accent for selection
- Audit all 36 files using accent colors
- Replace selection-related uses with new selection colors

---

## Implementation Steps

1. **Add selection CSS variables to index.css** (all 6 themes)
2. **Add selection colors to tailwind.config.js**
3. **Fix HistoryItemPane.tsx selection styling**
4. **Fix other selection-using components**
5. **Test all themes for contrast**
6. **Build and verify**

