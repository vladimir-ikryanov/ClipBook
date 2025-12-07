# Theme System & UI Improvements Specification

## Overview
Comprehensive enhancement of ClipBook's visual design system including:
- Extended theme support (AMOLED, Glass/Glassmorphism)
- Typography customization system
- Improved color contrast and accessibility
- User-adjustable appearance settings

---

## 1. Current State Analysis

### Existing Theme System
```
Current: Light | Dark | System (auto-switch)
Location: src/app/ThemeProvider.tsx
CSS Variables: src/index.css (~200 variables)
```

### Identified Issues
1. **Color Contrast Problems**
   - Some text colors clash with backgrounds
   - Button borders not visible in certain themes
   - Muted foreground too similar to background in dark mode

2. **Limited Theme Options**
   - Only Light/Dark/System
   - No AMOLED (true black) option
   - No glassmorphism/translucent option

3. **No Typography Customization**
   - Fixed 14px base font size
   - No font family selection
   - No user-adjustable sizing

---

## 2. New Theme Architecture

### Theme Types
```typescript
type ThemeMode = "light" | "dark" | "system" | "amoled" | "glass-light" | "glass-dark";

interface ThemeConfig {
  mode: ThemeMode;
  accentColor: string;        // User-selected accent
  fontSize: "small" | "medium" | "large";
  fontFamily: "system" | "inter" | "sf-pro" | "jetbrains-mono";
  contrast: "normal" | "high";
  reduceTransparency: boolean;
}
```

### Theme Definitions

#### AMOLED Theme (True Black)
```css
.amoled {
  --background: #000000;
  --background-solid: #000000;
  --foreground: #ffffff;
  --card: #0a0a0a;
  --secondary: #0a0a0a;
  --secondary-solid: #0a0a0a;
  --muted: #0a0a0a;
  --border: #1a1a1a;
  --accent: #1a1a1a;
  /* True blacks save battery on OLED */
}
```

#### Glass Light Theme (Glassmorphism)
```css
.glass-light {
  --background: rgba(255, 255, 255, 0.6);
  --background-solid: rgba(255, 255, 255, 0.85);
  --card: rgba(255, 255, 255, 0.4);
  --secondary: rgba(255, 255, 255, 0.3);
  --border: rgba(255, 255, 255, 0.3);
  /* Backdrop blur applied via Tailwind */
}
```

#### Glass Dark Theme
```css
.glass-dark {
  --background: rgba(0, 0, 0, 0.5);
  --background-solid: rgba(20, 20, 20, 0.85);
  --card: rgba(40, 40, 40, 0.4);
  --secondary: rgba(30, 30, 30, 0.5);
  --border: rgba(255, 255, 255, 0.1);
}
```

---

## 3. Typography System

### Font Scale
```css
:root {
  /* Size scale */
  --font-size-xs: 0.75rem;    /* 12px */
  --font-size-sm: 0.8125rem;  /* 13px */
  --font-size-base: 0.875rem; /* 14px - default */
  --font-size-md: 1rem;       /* 16px */
  --font-size-lg: 1.125rem;   /* 18px */
  --font-size-xl: 1.25rem;    /* 20px */
  
  /* Line heights */
  --line-height-tight: 1.25;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.625;
  
  /* Font weights */
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
}
```

### Font Families
```css
/* System (default) */
--font-family-system: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;

/* Inter - Clean, modern */
--font-family-inter: "Inter", -apple-system, sans-serif;

/* SF Pro - Native macOS feel */
--font-family-sf: "SF Pro Text", -apple-system, sans-serif;

/* JetBrains Mono - Developer-focused */
--font-family-mono: "JetBrains Mono", "SF Mono", Menlo, monospace;
```

### User Font Size Adjustment
```css
/* Small */
:root[data-font-size="small"] { font-size: 13px; }

/* Medium (default) */
:root[data-font-size="medium"] { font-size: 14px; }

/* Large */
:root[data-font-size="large"] { font-size: 15px; }
```

---

## 4. Color Contrast Fixes

### Problem Areas
| Component | Issue | Fix |
|-----------|-------|-----|
| Muted text on dark | Too similar to bg | Increase to #a0a0a0 |
| Secondary buttons | Border invisible | Add visible border |
| Input placeholders | Too faint | Increase opacity |
| Disabled states | Indistinguishable | Add distinct opacity |

### Minimum Contrast Ratios (WCAG AA)
- Normal text: 4.5:1
- Large text: 3:1
- UI components: 3:1

### Fixed Color Palette
```css
/* Dark mode text hierarchy */
--text-primary: #f5f5f5;      /* Main content */
--text-secondary: #a8a8a8;    /* Supporting text */
--text-muted: #6b6b6b;        /* Subtle hints */
--text-disabled: #4a4a4a;     /* Disabled state */

/* Light mode text hierarchy */
--text-primary-light: #1a1a1a;
--text-secondary-light: #525252;
--text-muted-light: #737373;
--text-disabled-light: #a3a3a3;
```

---

## 5. Glassmorphism Implementation

### CSS Properties
```css
.glass-panel {
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid var(--glass-border);
  box-shadow: 
    0 4px 6px -1px rgba(0, 0, 0, 0.1),
    0 2px 4px -1px rgba(0, 0, 0, 0.06),
    inset 0 1px 0 rgba(255, 255, 255, 0.1);
}

.glass-panel-elevated {
  background: var(--glass-bg-elevated);
  backdrop-filter: blur(30px);
  border: 1px solid var(--glass-border-elevated);
}
```

### Fallback for Reduced Transparency
```css
@media (prefers-reduced-transparency: reduce) {
  .glass-panel {
    background: var(--background-solid);
    backdrop-filter: none;
  }
}
```

---

## 6. Implementation Plan

### Phase 1: Theme Infrastructure
- [ ] Extend ThemeProvider to support new themes
- [ ] Add theme configuration storage (localStorage)
- [ ] Create CSS variable sets for each theme
- [ ] Add theme switcher in Settings

### Phase 2: Typography System
- [ ] Define font scale CSS variables
- [ ] Add font family options
- [ ] Create font size selector component
- [ ] Apply typography across all components

### Phase 3: Color Contrast Fixes
- [ ] Audit all color combinations
- [ ] Fix low-contrast text colors
- [ ] Update button/border colors
- [ ] Test with accessibility tools

### Phase 4: Glassmorphism
- [ ] Create glass utility classes
- [ ] Apply to dialog, panels, cards
- [ ] Add reduced-transparency fallback
- [ ] Test performance

### Phase 5: Settings UI
- [ ] Create Appearance settings panel
- [ ] Add live theme preview
- [ ] Font size slider
- [ ] Accent color picker

---

## 7. Files to Modify

```
src/
├── index.css                    # Add new theme variables
├── app/
│   └── ThemeProvider.tsx        # Extend theme types & logic
├── settings/
│   ├── Appearance.tsx           # NEW: Appearance settings
│   ├── Settings.tsx             # Add Appearance to nav
│   └── SettingsSidebarItem.tsx  # Add new item type
├── lib/
│   └── theme-utils.ts           # NEW: Theme helpers
└── components/
    └── ui/
        └── glass-panel.tsx      # NEW: Glass components
```

---

## 8. Theme Preview Colors

### Light Theme
| Purpose | Color | Hex |
|---------|-------|-----|
| Background | White | #ffffff |
| Foreground | Dark gray | #252525 |
| Primary | Blue | #006fff |
| Secondary bg | Light gray | #f5f5f5 |
| Border | Gray | #e5e5e5 |

### Dark Theme
| Purpose | Color | Hex |
|---------|-------|-----|
| Background | Dark gray | #1a1a1a |
| Foreground | Off-white | #e8e8e8 |
| Primary | Blue | #006fff |
| Secondary bg | Darker gray | #252525 |
| Border | Medium gray | #3a3a3a |

### AMOLED Theme
| Purpose | Color | Hex |
|---------|-------|-----|
| Background | True black | #000000 |
| Foreground | White | #ffffff |
| Primary | Bright blue | #0088ff |
| Secondary bg | Near black | #0a0a0a |
| Border | Dark gray | #1a1a1a |

### Glass Light Theme
| Purpose | Color | Alpha |
|---------|-------|-------|
| Background | White | 60% |
| Panel bg | White | 40% |
| Border | White | 30% |
| Blur | 20px | - |

### Glass Dark Theme
| Purpose | Color | Alpha |
|---------|-------|-------|
| Background | Black | 50% |
| Panel bg | Gray | 40% |
| Border | White | 10% |
| Blur | 20px | - |

---

## 9. Accessibility Considerations

1. **High Contrast Mode**
   - Provide alternative with stronger contrast
   - Thicker borders
   - Bolder text weights

2. **Reduced Motion**
   - Disable transitions for `prefers-reduced-motion`

3. **Reduced Transparency**
   - Solid backgrounds when `prefers-reduced-transparency`

4. **Screen Reader**
   - Theme changes announced via ARIA live regions

---

## 10. Testing Checklist

- [ ] All themes render correctly
- [ ] Text readable in all themes
- [ ] Buttons/controls visible
- [ ] No color clashes
- [ ] Glass blur performs well
- [ ] Settings persist across restart
- [ ] System theme sync works
- [ ] Font changes apply globally
- [ ] Accessibility modes work

