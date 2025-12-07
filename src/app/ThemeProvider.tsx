import { createContext, useContext, useEffect, useState } from "react"

// Native functions for theme persistence (bridged from native app)
declare const saveTheme: ((theme: string) => void) | undefined;
declare const getTheme: (() => string) | undefined;

// Extended theme types
export type Theme = "dark" | "light" | "system" | "amoled" | "glass-light" | "glass-dark"

// All themes are now supported by native code
const NATIVE_SUPPORTED_THEMES: Theme[] = ["dark", "light", "system", "amoled", "glass-light", "glass-dark"]
export type FontSize = "small" | "medium" | "large"
export type FontFamily = "system" | "inter" | "sf-pro" | "jetbrains-mono"

export interface ThemeConfig {
  theme: Theme
  fontSize: FontSize
  fontFamily: FontFamily
  accentColor: string
  reduceTransparency: boolean
}

const DEFAULT_CONFIG: ThemeConfig = {
  theme: "system",
  fontSize: "medium",
  fontFamily: "system",
  accentColor: "#006fff",
  reduceTransparency: false,
}

type ThemeProviderProps = {
  children: React.ReactNode
  defaultTheme?: Theme
  storageKey?: string
}

type ThemeProviderState = {
  theme: Theme
  config: ThemeConfig
  setTheme: (theme: Theme) => void
  setConfig: (config: Partial<ThemeConfig>) => void
  resolvedTheme: "light" | "dark" | "amoled" | "glass-light" | "glass-dark"
}

const initialState: ThemeProviderState = {
  theme: "system",
  config: DEFAULT_CONFIG,
  setTheme: () => null,
  setConfig: () => null,
  resolvedTheme: "light",
}

const ThemeProviderContext = createContext<ThemeProviderState>(initialState)

// Font family CSS mapping
const FONT_FAMILIES: Record<FontFamily, string> = {
  "system": '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  "inter": '"Inter", -apple-system, BlinkMacSystemFont, sans-serif',
  "sf-pro": '"SF Pro Text", "SF Pro Display", -apple-system, BlinkMacSystemFont, sans-serif',
  "jetbrains-mono": '"JetBrains Mono", "SF Mono", Menlo, Monaco, monospace',
}

// Font size values
const FONT_SIZES: Record<FontSize, string> = {
  "small": "13px",
  "medium": "14px",
  "large": "15px",
}

// Helper to get theme from native preferences or localStorage
function getNativeTheme(): Theme | null {
  try {
    if (typeof getTheme === 'function') {
      const nativeTheme = getTheme()
      if (nativeTheme && ['dark', 'light', 'system', 'amoled', 'glass-light', 'glass-dark'].includes(nativeTheme)) {
        return nativeTheme as Theme
      }
    }
  } catch {}
  return null
}

// Helper to save theme to native preferences (only for supported themes)
function setNativeTheme(theme: Theme) {
  try {
    // Only save to native if the theme is supported by native code
    if (typeof saveTheme === 'function' && NATIVE_SUPPORTED_THEMES.includes(theme)) {
      saveTheme(theme)
    }
  } catch {}
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = "clipboard-ui-theme",
  ...props
}: ThemeProviderProps) {
  const [config, setConfigState] = useState<ThemeConfig>(() => {
    try {
      const stored = localStorage.getItem(`${storageKey}-config`)
      if (stored) {
        const parsedConfig = { ...DEFAULT_CONFIG, ...JSON.parse(stored) }
        // Only sync with native theme if the stored theme is one native supports
        // (native can't store extended themes like amoled, glass-light, glass-dark)
        const nativeTheme = getNativeTheme()
        if (nativeTheme && 
            nativeTheme !== parsedConfig.theme && 
            NATIVE_SUPPORTED_THEMES.includes(parsedConfig.theme)) {
          // Update localStorage to match native (only for native-supported themes)
          parsedConfig.theme = nativeTheme
          localStorage.setItem(`${storageKey}-config`, JSON.stringify(parsedConfig))
          localStorage.setItem(storageKey, nativeTheme)
        }
        return parsedConfig
      }
    } catch {}
    // No stored config - check native preferences first, then localStorage, then default
    const nativeTheme = getNativeTheme()
    const theme = nativeTheme || (localStorage.getItem(storageKey) as Theme) || defaultTheme
    return { ...DEFAULT_CONFIG, theme }
  })

  // Get resolved theme (actual theme applied)
  const getResolvedTheme = (): "light" | "dark" | "amoled" | "glass-light" | "glass-dark" => {
    if (config.theme === "system") {
      return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
    }
    return config.theme as "light" | "dark" | "amoled" | "glass-light" | "glass-dark"
  }

  const [resolvedTheme, setResolvedTheme] = useState(getResolvedTheme)

  // Apply theme to document
  const applyTheme = (themeConfig: ThemeConfig) => {
    const root = window.document.documentElement

    // Remove all theme classes
    root.classList.remove("light", "dark", "amoled", "glass-light", "glass-dark")

    // Apply resolved theme
    const resolved = themeConfig.theme === "system" 
      ? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
      : themeConfig.theme as "light" | "dark" | "amoled" | "glass-light" | "glass-dark"
    root.classList.add(resolved)
    setResolvedTheme(resolved)

    // Apply font size
    root.style.fontSize = FONT_SIZES[themeConfig.fontSize]

    // Apply font family
    root.style.fontFamily = FONT_FAMILIES[themeConfig.fontFamily]

    // Apply accent color as CSS variable
    root.style.setProperty("--accent-color", themeConfig.accentColor)
    
    // Apply reduce transparency
    if (themeConfig.reduceTransparency) {
      root.setAttribute("data-reduce-transparency", "true")
    } else {
      root.removeAttribute("data-reduce-transparency")
    }
  }

  useEffect(() => {
    applyTheme(config)

    // Listen for system theme changes
    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    const handleChange = () => {
      if (config.theme === "system") {
        applyTheme(config)
      }
    }
    mediaQuery.addEventListener("change", handleChange)
    return () => mediaQuery.removeEventListener("change", handleChange)
  }, [config])

  // Listen for theme changes from other windows (via localStorage)
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === `${storageKey}-config` && e.newValue) {
        try {
          const newConfig = { ...DEFAULT_CONFIG, ...JSON.parse(e.newValue) }
          setConfigState(newConfig)
        } catch {}
      }
    }
    
    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [storageKey])

  // Sync with native theme on visibility change (when app becomes visible)
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        // Re-read theme from native/localStorage in case it changed
        const nativeTheme = getNativeTheme()
        // Only sync with native if current theme is one native supports
        // (don't override extended themes like amoled, glass-light, glass-dark)
        if (nativeTheme && 
            nativeTheme !== config.theme && 
            NATIVE_SUPPORTED_THEMES.includes(config.theme)) {
          const newConfig = { ...config, theme: nativeTheme }
          setConfigState(newConfig)
        } else {
          // Also check localStorage for other config changes
          try {
            const stored = localStorage.getItem(`${storageKey}-config`)
            if (stored) {
              const storedConfig = JSON.parse(stored)
              // Only update if different
              if (JSON.stringify(storedConfig) !== JSON.stringify(config)) {
                setConfigState({ ...DEFAULT_CONFIG, ...storedConfig })
              }
            }
          } catch {}
        }
      }
    }
    
    document.addEventListener('visibilitychange', handleVisibilityChange)
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange)
  }, [config, storageKey])

  const setTheme = (theme: Theme) => {
    const newConfig = { ...config, theme }
    localStorage.setItem(storageKey, theme)
    localStorage.setItem(`${storageKey}-config`, JSON.stringify(newConfig))
    setNativeTheme(theme) // Sync with native preferences
    setConfigState(newConfig)
  }

  const setConfig = (partial: Partial<ThemeConfig>) => {
    const newConfig = { ...config, ...partial }
    localStorage.setItem(`${storageKey}-config`, JSON.stringify(newConfig))
    if (partial.theme) {
      localStorage.setItem(storageKey, partial.theme)
      setNativeTheme(partial.theme) // Sync with native preferences
    }
    setConfigState(newConfig)
  }

  const value = {
    theme: config.theme,
    config,
    setTheme,
    setConfig,
    resolvedTheme,
  }

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      {children}
    </ThemeProviderContext.Provider>
  )
}

export const useTheme = () => {
  const context = useContext(ThemeProviderContext)

  if (context === undefined)
    throw new Error("useTheme must be used within a ThemeProvider")

  return context
}
