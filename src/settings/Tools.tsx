import * as React from "react";
import { useState, useEffect, useMemo } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { generateUUID } from "@/lib/crypto";
import {
  CopyIcon,
  CheckIcon,
  Fingerprint,
  Key,
  Binary,
  Clock,
  Timer,
  FolderOpen,
  Terminal,
  Calculator,
  Palette,
  Search,
  Network,
  Hash,
  GitBranch,
  FileJson,
  Code,
  Type,
  ArrowDownUp,
  FileText,
  Zap,
} from "lucide-react";
import { useTranslation } from 'react-i18next';

declare const closeSettingsWindow: () => void;

// Tool definitions
interface Tool {
  id: string;
  name: string;
  description: string;
  icon: React.ReactNode;
  category: string;
  placeholder?: string;
  execute: (input: string) => string;
}

// All available tools
const TOOLS: Tool[] = [
  // Generate
  {
    id: 'uuid',
    name: 'Generate UUID',
    description: 'Generate a random UUID v4',
    icon: <Fingerprint className="h-4 w-4" />,
    category: 'Generate',
    placeholder: 'Click Generate (no input needed)',
    execute: () => generateUUID()
  },
  {
    id: 'password',
    name: 'Generate Password',
    description: 'Generate a secure random password',
    icon: <Key className="h-4 w-4" />,
    category: 'Generate',
    placeholder: 'Enter length (default: 16)',
    execute: (input) => {
      const length = parseInt(input) || 16;
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?';
      let password = '';
      const array = new Uint32Array(length);
      crypto.getRandomValues(array);
      for (let i = 0; i < length; i++) {
        password += chars[array[i] % chars.length];
      }
      return password;
    }
  },
  {
    id: 'hex',
    name: 'Random Hex',
    description: 'Generate random hex bytes',
    icon: <Binary className="h-4 w-4" />,
    category: 'Generate',
    placeholder: 'Enter number of bytes (default: 32)',
    execute: (input) => {
      const bytes = parseInt(input) || 32;
      const array = new Uint8Array(bytes);
      crypto.getRandomValues(array);
      return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
    }
  },
  {
    id: 'timestamp-now',
    name: 'Current Time',
    description: 'Get current date/time in multiple formats',
    icon: <Clock className="h-4 w-4" />,
    category: 'Generate',
    placeholder: 'Click Generate (no input needed)',
    execute: () => {
      const now = new Date();
      return `ISO: ${now.toISOString()}\nLocal: ${now.toLocaleString()}\nUnix (seconds): ${Math.floor(now.getTime() / 1000)}\nUnix (milliseconds): ${now.getTime()}`;
    }
  },

  // Time
  {
    id: 'timestamp-to-date',
    name: 'Timestamp → Date',
    description: 'Convert Unix timestamp to readable date',
    icon: <Timer className="h-4 w-4" />,
    category: 'Time',
    placeholder: 'Enter Unix timestamp (e.g., 1701878400)',
    execute: (input) => {
      const ts = parseInt(input.trim());
      if (isNaN(ts)) return 'Invalid timestamp';
      const date = ts > 9999999999 ? new Date(ts) : new Date(ts * 1000);
      return `ISO: ${date.toISOString()}\nLocal: ${date.toLocaleString()}\nDay: ${date.toLocaleDateString('en-US', { weekday: 'long' })}`;
    }
  },
  {
    id: 'date-to-timestamp',
    name: 'Date → Timestamp',
    description: 'Convert date string to Unix timestamp',
    icon: <Timer className="h-4 w-4" />,
    category: 'Time',
    placeholder: 'Enter date (e.g., 2024-01-15 or Jan 15, 2024)',
    execute: (input) => {
      const date = new Date(input.trim());
      if (isNaN(date.getTime())) return 'Invalid date format';
      return `Unix (seconds): ${Math.floor(date.getTime() / 1000)}\nUnix (milliseconds): ${date.getTime()}\nISO: ${date.toISOString()}`;
    }
  },

  // Path
  {
    id: 'basename',
    name: 'Get Filename',
    description: 'Extract filename from a path (like basename)',
    icon: <FolderOpen className="h-4 w-4" />,
    category: 'Path',
    placeholder: '/path/to/file.txt',
    execute: (input) => {
      const path = input.trim();
      return path.split(/[/\\]/).pop() || path;
    }
  },
  {
    id: 'dirname',
    name: 'Get Directory',
    description: 'Extract directory from a path (like dirname)',
    icon: <FolderOpen className="h-4 w-4" />,
    category: 'Path',
    placeholder: '/path/to/file.txt',
    execute: (input) => {
      const path = input.trim();
      const parts = path.split(/[/\\]/);
      parts.pop();
      return parts.join('/') || '/';
    }
  },
  {
    id: 'extension',
    name: 'Get Extension',
    description: 'Extract file extension from a path',
    icon: <FileText className="h-4 w-4" />,
    category: 'Path',
    placeholder: '/path/to/file.txt',
    execute: (input) => {
      const path = input.trim();
      const match = path.match(/\.([^.]+)$/);
      return match ? match[1] : 'No extension';
    }
  },

  // Dev Tools
  {
    id: 'regex',
    name: 'Test Regex',
    description: 'Test a regular expression pattern',
    icon: <Code className="h-4 w-4" />,
    category: 'Dev Tools',
    placeholder: '/pattern/flags\ntest string to match',
    execute: (input) => {
      const lines = input.split('\n');
      if (lines.length < 2) return 'Format: /pattern/flags (line 1)\ntest string (line 2+)';
      
      const regexLine = lines[0].trim();
      const testString = lines.slice(1).join('\n');
      
      const match = regexLine.match(/^\/(.+)\/([gimsuy]*)$/);
      if (!match) return 'Invalid regex format. Use: /pattern/flags';
      
      try {
        const regex = new RegExp(match[1], match[2]);
        const matches = testString.match(regex);
        if (matches) {
          return `✅ Match found!\n\nMatches (${matches.length}):\n${matches.map((m, i) => `${i + 1}. "${m}"`).join('\n')}`;
        }
        return '❌ No match found';
      } catch (e) {
        return `Error: ${e instanceof Error ? e.message : 'Invalid regex'}`;
      }
    }
  },
  {
    id: 'cron',
    name: 'Parse Cron',
    description: 'Explain a cron expression',
    icon: <Clock className="h-4 w-4" />,
    category: 'Dev Tools',
    placeholder: '0 9 * * 1-5',
    execute: (input) => {
      const parts = input.trim().split(/\s+/);
      if (parts.length < 5) return 'Invalid cron expression\nFormat: minute hour day month weekday';
      
      const [min, hour, day, month, weekday] = parts;
      const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      
      const explain = (val: string, unit: string, max: number) => {
        if (val === '*') return `Every ${unit}`;
        if (val.includes('/')) return `Every ${val.split('/')[1]} ${unit}s`;
        if (val.includes('-')) return `${unit}s ${val}`;
        if (val.includes(',')) return `${unit}s ${val}`;
        return `${unit} ${val}`;
      };
      
      return `Minute: ${min} → ${explain(min, 'minute', 59)}
Hour: ${hour} → ${explain(hour, 'hour', 23)}
Day: ${day} → ${explain(day, 'day', 31)}
Month: ${month} → ${explain(month, 'month', 12)}
Weekday: ${weekday} → ${weekday === '*' ? 'Every day' : weekday.split(',').map(w => weekdays[parseInt(w)] || w).join(', ')}`;
    }
  },
  {
    id: 'env',
    name: 'To .env Format',
    description: 'Convert key-value pairs to export format',
    icon: <Terminal className="h-4 w-4" />,
    category: 'Dev Tools',
    placeholder: 'API_KEY=abc123\nDB_HOST=localhost',
    execute: (input) => {
      const lines = input.trim().split('\n');
      return lines.map(line => {
        const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)[\s:=]+(.+)$/);
        if (match) {
          const value = match[2].trim().replace(/"/g, '\\"');
          return `export ${match[1]}="${value}"`;
        }
        return `# ${line}`;
      }).join('\n');
    }
  },
  {
    id: 'diff',
    name: 'Compare Lines',
    description: 'Simple diff between two texts',
    icon: <ArrowDownUp className="h-4 w-4" />,
    category: 'Dev Tools',
    placeholder: 'Text 1\n---\nText 2',
    execute: (input) => {
      const parts = input.split(/\n---\n/);
      if (parts.length !== 2) return 'Separate two texts with --- on its own line';
      
      const lines1 = parts[0].split('\n');
      const lines2 = parts[1].split('\n');
      const results: string[] = [];
      
      const maxLen = Math.max(lines1.length, lines2.length);
      for (let i = 0; i < maxLen; i++) {
        const l1 = lines1[i] || '';
        const l2 = lines2[i] || '';
        if (l1 === l2) {
          results.push(`  ${l1}`);
        } else {
          if (l1) results.push(`- ${l1}`);
          if (l2) results.push(`+ ${l2}`);
        }
      }
      return results.join('\n');
    }
  },

  // Math
  {
    id: 'calc',
    name: 'Calculator',
    description: 'Evaluate a math expression',
    icon: <Calculator className="h-4 w-4" />,
    category: 'Math',
    placeholder: '(100 * 1.08) + 50',
    execute: (input) => {
      try {
        const sanitized = input.replace(/[^0-9+\-*/.()%\s]/g, '');
        if (sanitized.replace(/\s/g, '') !== input.replace(/\s/g, '')) {
          return 'Only basic math operations allowed';
        }
        const result = Function(`"use strict"; return (${sanitized})`)();
        return `${input.trim()} = ${result}`;
      } catch {
        return 'Invalid expression';
      }
    }
  },
  {
    id: 'bytes',
    name: 'Parse Bytes',
    description: 'Convert between byte units',
    icon: <Calculator className="h-4 w-4" />,
    category: 'Math',
    placeholder: '1073741824',
    execute: (input) => {
      const num = parseFloat(input);
      if (isNaN(num)) return 'Invalid number';
      
      const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
      const results: string[] = [];
      
      for (let i = 0; i < units.length; i++) {
        const val = num / Math.pow(1024, i);
        if (val >= 0.01 || i === 0) {
          results.push(`${val.toFixed(2)} ${units[i]}`);
        }
      }
      return results.join('\n');
    }
  },

  // Colors
  {
    id: 'hex-rgb',
    name: 'Hex → RGB',
    description: 'Convert hex color to RGB',
    icon: <Palette className="h-4 w-4" />,
    category: 'Colors',
    placeholder: '#FF5733 or FF5733',
    execute: (input) => {
      const hex = input.trim().replace('#', '');
      if (!/^[0-9A-Fa-f]{6}$/.test(hex)) return 'Invalid hex color (use #RRGGBB)';
      
      const r = parseInt(hex.slice(0, 2), 16);
      const g = parseInt(hex.slice(2, 4), 16);
      const b = parseInt(hex.slice(4, 6), 16);
      
      return `RGB: rgb(${r}, ${g}, ${b})\nRGBA: rgba(${r}, ${g}, ${b}, 1)\nCSS: --color: ${r} ${g} ${b};\nValues: R=${r}, G=${g}, B=${b}`;
    }
  },
  {
    id: 'rgb-hex',
    name: 'RGB → Hex',
    description: 'Convert RGB values to hex',
    icon: <Palette className="h-4 w-4" />,
    category: 'Colors',
    placeholder: '255, 87, 51 or rgb(255, 87, 51)',
    execute: (input) => {
      const match = input.match(/(\d+)\s*,?\s*(\d+)\s*,?\s*(\d+)/);
      if (!match) return 'Invalid RGB format';
      
      const r = Math.min(255, parseInt(match[1]));
      const g = Math.min(255, parseInt(match[2]));
      const b = Math.min(255, parseInt(match[3]));
      
      const hex = '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('');
      return `Hex: ${hex.toUpperCase()}\nLowercase: ${hex}\nCSS: color: ${hex};`;
    }
  },

  // Extract
  {
    id: 'extract-ips',
    name: 'Extract IPs',
    description: 'Find all IP addresses in text',
    icon: <Network className="h-4 w-4" />,
    category: 'Extract',
    placeholder: 'Paste text containing IP addresses...',
    execute: (input) => {
      const ipv4 = input.match(/\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/g);
      const results: string[] = [];
      if (ipv4) results.push('IPv4:\n' + Array.from(new Set(ipv4)).join('\n'));
      return results.length > 0 ? results.join('\n\n') : 'No IP addresses found';
    }
  },
  {
    id: 'extract-emails',
    name: 'Extract Emails',
    description: 'Find all email addresses in text',
    icon: <Search className="h-4 w-4" />,
    category: 'Extract',
    placeholder: 'Paste text containing emails...',
    execute: (input) => {
      const emails = input.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g);
      return emails ? Array.from(new Set(emails)).join('\n') : 'No emails found';
    }
  },
  {
    id: 'extract-urls',
    name: 'Extract URLs',
    description: 'Find all URLs in text',
    icon: <Search className="h-4 w-4" />,
    category: 'Extract',
    placeholder: 'Paste text containing URLs...',
    execute: (input) => {
      const urls = input.match(/https?:\/\/[^\s<>"{}|\\^`[\]]+/g);
      return urls ? Array.from(new Set(urls)).join('\n') : 'No URLs found';
    }
  },

  // Encode
  {
    id: 'base64-encode',
    name: 'Base64 Encode',
    description: 'Encode text to Base64',
    icon: <Binary className="h-4 w-4" />,
    category: 'Encode',
    placeholder: 'Text to encode...',
    execute: (input) => {
      try {
        return btoa(unescape(encodeURIComponent(input)));
      } catch {
        return 'Error encoding to Base64';
      }
    }
  },
  {
    id: 'base64-decode',
    name: 'Base64 Decode',
    description: 'Decode Base64 to text',
    icon: <Binary className="h-4 w-4" />,
    category: 'Encode',
    placeholder: 'Base64 string to decode...',
    execute: (input) => {
      try {
        return decodeURIComponent(escape(atob(input.trim())));
      } catch {
        return 'Invalid Base64 string';
      }
    }
  },
  {
    id: 'url-encode',
    name: 'URL Encode',
    description: 'Encode text for URLs',
    icon: <Binary className="h-4 w-4" />,
    category: 'Encode',
    placeholder: 'Text to encode...',
    execute: (input) => encodeURIComponent(input)
  },
  {
    id: 'url-decode',
    name: 'URL Decode',
    description: 'Decode URL-encoded text',
    icon: <Binary className="h-4 w-4" />,
    category: 'Encode',
    placeholder: 'URL-encoded text...',
    execute: (input) => {
      try {
        return decodeURIComponent(input);
      } catch {
        return 'Invalid URL encoding';
      }
    }
  },

  // JSON
  {
    id: 'json-format',
    name: 'Format JSON',
    description: 'Pretty-print JSON',
    icon: <FileJson className="h-4 w-4" />,
    category: 'JSON',
    placeholder: '{"key":"value","nested":{"a":1}}',
    execute: (input) => {
      try {
        return JSON.stringify(JSON.parse(input), null, 2);
      } catch {
        return 'Invalid JSON';
      }
    }
  },
  {
    id: 'json-minify',
    name: 'Minify JSON',
    description: 'Compress JSON to one line',
    icon: <FileJson className="h-4 w-4" />,
    category: 'JSON',
    placeholder: 'Paste formatted JSON...',
    execute: (input) => {
      try {
        return JSON.stringify(JSON.parse(input));
      } catch {
        return 'Invalid JSON';
      }
    }
  },

  // Convert
  {
    id: 'slug',
    name: 'To Slug',
    description: 'Convert to URL-friendly slug',
    icon: <Type className="h-4 w-4" />,
    category: 'Convert',
    placeholder: 'My Blog Post Title',
    execute: (input) => {
      return input.toLowerCase().trim()
        .replace(/[^\w\s-]/g, '')
        .replace(/[\s_-]+/g, '-')
        .replace(/^-+|-+$/g, '');
    }
  },
  {
    id: 'camel',
    name: 'To camelCase',
    description: 'Convert to camelCase',
    icon: <Type className="h-4 w-4" />,
    category: 'Convert',
    placeholder: 'my variable name',
    execute: (input) => {
      return input.replace(/\W+/g, ' ').split(' ')
        .map((word, i) => i === 0 ? word.toLowerCase() : word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join('');
    }
  },
  {
    id: 'snake',
    name: 'To snake_case',
    description: 'Convert to snake_case',
    icon: <Type className="h-4 w-4" />,
    category: 'Convert',
    placeholder: 'myVariableName',
    execute: (input) => {
      return input.replace(/\W+/g, ' ').split(/ |\B(?=[A-Z])/)
        .map(word => word.toLowerCase()).join('_');
    }
  },
  {
    id: 'kebab',
    name: 'To kebab-case',
    description: 'Convert to kebab-case',
    icon: <Type className="h-4 w-4" />,
    category: 'Convert',
    placeholder: 'myVariableName',
    execute: (input) => {
      return input.replace(/\W+/g, ' ').split(/ |\B(?=[A-Z])/)
        .map(word => word.toLowerCase()).join('-');
    }
  },

  // GitHub
  {
    id: 'commit',
    name: 'Format Commit',
    description: 'Format as conventional commit message',
    icon: <GitBranch className="h-4 w-4" />,
    category: 'GitHub',
    placeholder: 'Add user authentication',
    execute: (input) => {
      const lines = input.trim().split('\n').filter(l => l.trim());
      if (lines.length === 0) return input;
      
      const firstLine = lines[0];
      if (/^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?:/.test(firstLine)) {
        return input;
      }
      
      const lower = firstLine.toLowerCase();
      let type = 'chore';
      if (lower.includes('add') || lower.includes('new') || lower.includes('implement')) type = 'feat';
      else if (lower.includes('fix') || lower.includes('bug') || lower.includes('issue')) type = 'fix';
      else if (lower.includes('doc') || lower.includes('readme')) type = 'docs';
      else if (lower.includes('refactor') || lower.includes('clean')) type = 'refactor';
      else if (lower.includes('test')) type = 'test';
      
      return `${type}: ${firstLine.charAt(0).toLowerCase() + firstLine.slice(1)}${lines.length > 1 ? '\n\n' + lines.slice(1).join('\n') : ''}`;
    }
  },
  {
    id: 'code-block',
    name: 'Wrap in Code Block',
    description: 'Wrap text in markdown code fence',
    icon: <Code className="h-4 w-4" />,
    category: 'GitHub',
    placeholder: 'const x = 1;',
    execute: (input) => '```\n' + input + '\n```'
  },

  // Analyze
  {
    id: 'word-count',
    name: 'Word Frequency',
    description: 'Count word occurrences',
    icon: <Search className="h-4 w-4" />,
    category: 'Analyze',
    placeholder: 'Paste text to analyze...',
    execute: (input) => {
      const words = input.toLowerCase().match(/\b[a-z]+\b/g);
      if (!words) return 'No words found';
      
      const freq: Record<string, number> = {};
      words.forEach(w => freq[w] = (freq[w] || 0) + 1);
      
      return Object.entries(freq)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 20)
        .map(([word, count]) => `${count.toString().padStart(4)} ${word}`)
        .join('\n');
    }
  },
  {
    id: 'stats',
    name: 'Text Stats',
    description: 'Count characters, words, lines',
    icon: <Hash className="h-4 w-4" />,
    category: 'Analyze',
    placeholder: 'Paste text to analyze...',
    execute: (input) => {
      const chars = input.length;
      const charsNoSpace = input.replace(/\s/g, '').length;
      const words = input.trim().split(/\s+/).filter(w => w.length > 0).length;
      const lines = input.split('\n').length;
      const sentences = input.split(/[.!?]+/).filter(s => s.trim().length > 0).length;
      const paragraphs = input.split(/\n\s*\n/).filter(p => p.trim().length > 0).length;
      
      return `Characters: ${chars}\nCharacters (no spaces): ${charsNoSpace}\nWords: ${words}\nLines: ${lines}\nSentences: ${sentences}\nParagraphs: ${paragraphs}`;
    }
  },
];

// Get unique categories
const CATEGORIES = Array.from(new Set(TOOLS.map(t => t.category)));

export default function Tools() {
  const { t } = useTranslation();
  
  const [selectedCategory, setSelectedCategory] = useState(CATEGORIES[0]);
  const [selectedTool, setSelectedTool] = useState<Tool | null>(null);
  const [input, setInput] = useState('');
  const [output, setOutput] = useState('');
  const [copied, setCopied] = useState(false);

  // Filter tools by category
  const filteredTools = useMemo(() => 
    TOOLS.filter(tool => tool.category === selectedCategory),
    [selectedCategory]
  );

  // Select first tool when category changes
  useEffect(() => {
    if (filteredTools.length > 0 && (!selectedTool || selectedTool.category !== selectedCategory)) {
      setSelectedTool(filteredTools[0]);
      setInput('');
      setOutput('');
    }
  }, [selectedCategory, filteredTools, selectedTool]);

  // Handle keyboard
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow();
        e.preventDefault();
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const handleExecute = () => {
    if (selectedTool) {
      const result = selectedTool.execute(input);
      setOutput(result);
    }
  };

  const handleCopy = () => {
    if (output) {
      navigator.clipboard.writeText(output);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="px-6 py-4 border-b border-border draggable">
        <div className="flex items-center gap-2">
          <Zap className="h-5 w-5 text-yellow-500" />
          <h1 className="text-lg font-semibold">{t('settings.tools.title', { defaultValue: 'Developer Tools' })}</h1>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          {t('settings.tools.description', { defaultValue: 'Quick utilities for developers - all run locally and instantly' })}
        </p>
      </div>

      {/* Main content */}
      <div className="flex-1 overflow-hidden flex">
        {/* Categories */}
        <div className="w-48 border-r border-border p-2 overflow-y-auto bg-secondary-solid/30">
          {CATEGORIES.map(category => (
            <button
              key={category}
              onClick={() => setSelectedCategory(category)}
              className={`w-full text-left px-3 py-2 rounded-md text-sm mb-1 transition-colors ${
                selectedCategory === category
                  ? 'bg-primary text-primary-foreground'
                  : 'hover:bg-secondary'
              }`}
            >
              {category}
            </button>
          ))}
        </div>

        {/* Tools list */}
        <div className="w-56 border-r border-border p-2 overflow-y-auto">
          {filteredTools.map(tool => (
            <button
              key={tool.id}
              onClick={() => {
                setSelectedTool(tool);
                setInput('');
                setOutput('');
              }}
              className={`w-full text-left px-3 py-2 rounded-md text-sm mb-1 transition-colors ${
                selectedTool?.id === tool.id
                  ? 'bg-secondary border border-border'
                  : 'hover:bg-secondary/50'
              }`}
            >
              <div className="flex items-center gap-2">
                {tool.icon}
                <span className="truncate">{tool.name}</span>
              </div>
            </button>
          ))}
        </div>

        {/* Tool panel */}
        <div className="flex-1 p-4 overflow-y-auto">
          {selectedTool && (
            <div className="space-y-4 max-w-2xl">
              <div>
                <h2 className="text-lg font-medium flex items-center gap-2">
                  {selectedTool.icon}
                  {selectedTool.name}
                </h2>
                <p className="text-sm text-muted-foreground mt-1">{selectedTool.description}</p>
              </div>

              <div className="space-y-2">
                <Label>Input</Label>
                <Textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder={selectedTool.placeholder}
                  className="h-32 font-mono text-sm"
                />
              </div>

              <Button onClick={handleExecute} className="w-full">
                <Zap className="h-4 w-4 mr-2" />
                Generate / Execute
              </Button>

              {output && (
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <Label>Output</Label>
                    <Button variant="ghost" size="sm" onClick={handleCopy}>
                      {copied ? (
                        <>
                          <CheckIcon className="h-4 w-4 mr-1 text-green-500" />
                          Copied!
                        </>
                      ) : (
                        <>
                          <CopyIcon className="h-4 w-4 mr-1" />
                          Copy
                        </>
                      )}
                    </Button>
                  </div>
                  <Textarea
                    value={output}
                    readOnly
                    className="h-40 font-mono text-sm bg-secondary-solid"
                  />
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

