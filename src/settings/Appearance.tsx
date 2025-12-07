import * as React from "react";
import { useTheme, Theme, FontSize, FontFamily } from "@/app/ThemeProvider";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Switch } from "@/components/ui/switch";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sun,
  Moon,
  Monitor,
  Sparkles,
  GlassWater,
  Type,
  Palette,
  Check,
} from "lucide-react";
import { useTranslation } from 'react-i18next';

declare const closeSettingsWindow: () => void;

// Theme options with icons
const THEMES: { value: Theme; label: string; description: string; icon: React.ReactNode }[] = [
  { value: "light", label: "Light", description: "Clean and bright", icon: <Sun className="h-4 w-4" /> },
  { value: "dark", label: "Dark", description: "Easy on the eyes", icon: <Moon className="h-4 w-4" /> },
  { value: "system", label: "System", description: "Match macOS", icon: <Monitor className="h-4 w-4" /> },
  { value: "amoled", label: "AMOLED", description: "True black, saves battery", icon: <Sparkles className="h-4 w-4" /> },
  { value: "glass-light", label: "Glass Light", description: "Translucent light theme", icon: <GlassWater className="h-4 w-4" /> },
  { value: "glass-dark", label: "Glass Dark", description: "Translucent dark theme", icon: <GlassWater className="h-4 w-4" /> },
];

// Font family options
const FONT_FAMILIES: { value: FontFamily; label: string; preview: string }[] = [
  { value: "system", label: "System Default", preview: "The quick brown fox" },
  { value: "inter", label: "Inter", preview: "The quick brown fox" },
  { value: "sf-pro", label: "SF Pro", preview: "The quick brown fox" },
  { value: "jetbrains-mono", label: "JetBrains Mono", preview: "The quick brown fox" },
];

// Font size options
const FONT_SIZES: { value: FontSize; label: string; size: string }[] = [
  { value: "small", label: "Small", size: "13px" },
  { value: "medium", label: "Medium", size: "14px" },
  { value: "large", label: "Large", size: "15px" },
];

// Accent color presets
const ACCENT_COLORS = [
  { value: "#006fff", label: "Blue" },
  { value: "#8b5cf6", label: "Purple" },
  { value: "#ec4899", label: "Pink" },
  { value: "#ef4444", label: "Red" },
  { value: "#f97316", label: "Orange" },
  { value: "#eab308", label: "Yellow" },
  { value: "#22c55e", label: "Green" },
  { value: "#14b8a6", label: "Teal" },
];

export default function Appearance() {
  const { t } = useTranslation();
  const { config, setConfig, resolvedTheme } = useTheme();

  // Handle keyboard
  React.useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow();
        e.preventDefault();
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="px-6 py-4 border-b border-border draggable">
        <div className="flex items-center gap-2">
          <Palette className="h-5 w-5 text-primary" />
          <h1 className="text-lg font-semibold">
            {t('settings.appearance.title', { defaultValue: 'Appearance' })}
          </h1>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          {t('settings.appearance.description', { defaultValue: 'Customize the look and feel of ClipBook' })}
        </p>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-8">
        
        {/* Theme Selection */}
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold">
              {t('settings.appearance.theme', { defaultValue: 'Theme' })}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {t('settings.appearance.themeDescription', { defaultValue: 'Choose your preferred appearance' })}
            </p>
          </div>
          
          <div className="grid grid-cols-2 gap-2">
            {THEMES.map((theme) => (
              <button
                key={theme.value}
                onClick={() => setConfig({ theme: theme.value })}
                className={`flex items-start gap-3 p-3 rounded-lg border transition-all text-left ${
                  config.theme === theme.value
                    ? 'border-primary bg-primary/5'
                    : 'border-border hover:border-primary/50 hover:bg-accent/50'
                }`}
              >
                <div className={`p-2 rounded-md ${
                  config.theme === theme.value ? 'bg-primary text-primary-foreground' : 'bg-secondary'
                }`}>
                  {theme.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium">{theme.label}</span>
                    {config.theme === theme.value && (
                      <Check className="h-3.5 w-3.5 text-primary" />
                    )}
                  </div>
                  <span className="text-xs text-muted-foreground">{theme.description}</span>
                </div>
              </button>
            ))}
          </div>
        </section>

        {/* Accent Color */}
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold">
              {t('settings.appearance.accentColor', { defaultValue: 'Accent Color' })}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {t('settings.appearance.accentColorDescription', { defaultValue: 'Highlight color for buttons and links' })}
            </p>
          </div>
          
          <div className="flex flex-wrap gap-2">
            {ACCENT_COLORS.map((color) => (
                <button
                key={color.value}
                onClick={() => setConfig({ accentColor: color.value })}
                className={`w-8 h-8 rounded-full transition-all relative ${
                  config.accentColor === color.value
                    ? 'ring-2 ring-offset-2 ring-offset-background'
                    : 'hover:scale-110'
                }`}
                style={{ 
                  backgroundColor: color.value,
                  '--tw-ring-color': config.accentColor === color.value ? color.value : undefined
                } as React.CSSProperties & { '--tw-ring-color'?: string }}
                title={color.label}
              >
                {config.accentColor === color.value && (
                  <Check className="h-4 w-4 text-white absolute inset-0 m-auto" />
                )}
              </button>
            ))}
          </div>
        </section>

        {/* Typography */}
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold flex items-center gap-2">
              <Type className="h-4 w-4" />
              {t('settings.appearance.typography', { defaultValue: 'Typography' })}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {t('settings.appearance.typographyDescription', { defaultValue: 'Font family and size preferences' })}
            </p>
          </div>

          <div className="grid gap-4">
            {/* Font Family */}
            <div className="flex items-center justify-between">
              <Label className="text-sm">
                {t('settings.appearance.fontFamily', { defaultValue: 'Font Family' })}
              </Label>
              <Select 
                value={config.fontFamily} 
                onValueChange={(v) => setConfig({ fontFamily: v as FontFamily })}
              >
                <SelectTrigger className="w-48">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {FONT_FAMILIES.map((font) => (
                    <SelectItem key={font.value} value={font.value}>
                      <span style={{ 
                        fontFamily: font.value === 'system' 
                          ? '-apple-system, BlinkMacSystemFont, sans-serif'
                          : font.value === 'inter'
                          ? '"Inter", sans-serif'
                          : font.value === 'sf-pro'
                          ? '"SF Pro Text", sans-serif'
                          : '"JetBrains Mono", monospace'
                      }}>
                        {font.label}
                      </span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Font Size */}
            <div className="flex items-center justify-between">
              <Label className="text-sm">
                {t('settings.appearance.fontSize', { defaultValue: 'Font Size' })}
              </Label>
              <div className="flex gap-1">
                {FONT_SIZES.map((size) => (
                  <Button
                    key={size.value}
                    variant={config.fontSize === size.value ? "default" : "secondary"}
                    size="sm"
                    onClick={() => setConfig({ fontSize: size.value })}
                    className="min-w-16"
                  >
                    {size.label}
                  </Button>
                ))}
              </div>
            </div>
          </div>
        </section>

        {/* Accessibility */}
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold">
              {t('settings.appearance.accessibility', { defaultValue: 'Accessibility' })}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {t('settings.appearance.accessibilityDescription', { defaultValue: 'Visual comfort settings' })}
            </p>
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <Label className="text-sm">
                  {t('settings.appearance.reduceTransparency', { defaultValue: 'Reduce Transparency' })}
                </Label>
                <p className="text-xs text-muted-foreground">
                  {t('settings.appearance.reduceTransparencyDescription', { defaultValue: 'Use solid backgrounds instead of blur effects' })}
                </p>
              </div>
              <Switch
                checked={config.reduceTransparency}
                onCheckedChange={(checked) => setConfig({ reduceTransparency: checked })}
              />
            </div>
          </div>
        </section>

        {/* Preview */}
        <section className="space-y-4">
          <div>
            <h2 className="text-sm font-semibold">
              {t('settings.appearance.preview', { defaultValue: 'Preview' })}
            </h2>
          </div>
          
          <div className={`p-4 rounded-lg border border-border ${
            (resolvedTheme === 'glass-light' || resolvedTheme === 'glass-dark') && !config.reduceTransparency
              ? 'glass-panel'
              : 'bg-background'
          }`}>
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-xs font-bold">
                  CB
                </div>
                <div>
                  <p className="text-sm font-medium">ClipBook</p>
                  <p className="text-xs text-muted-foreground">Your clipboard manager</p>
                </div>
              </div>
              <div className="flex gap-2">
                <Button size="sm" style={{ backgroundColor: config.accentColor }}>
                  Primary
                </Button>
                <Button size="sm" variant="secondary">
                  Secondary
                </Button>
                <Button size="sm" variant="ghost">
                  Ghost
                </Button>
              </div>
              <p className="text-sm text-foreground">
                This is how text will appear with your current settings. 
                <span className="text-muted-foreground"> Muted text looks like this.</span>
              </p>
            </div>
          </div>
        </section>

        {/* Reset */}
        <section className="pt-4 border-t border-border">
          <Button 
            variant="secondary" 
            size="sm"
            onClick={() => setConfig({
              theme: "system",
              fontSize: "medium",
              fontFamily: "system",
              accentColor: "#006fff",
              reduceTransparency: false,
            })}
          >
            {t('settings.appearance.resetDefaults', { defaultValue: 'Reset to Defaults' })}
          </Button>
        </section>
      </div>
    </div>
  );
}

