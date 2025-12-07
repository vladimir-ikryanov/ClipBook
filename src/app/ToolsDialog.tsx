import '../app.css';
import * as React from "react";
import { useState, useEffect, useMemo } from "react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { ScrollArea } from "@/components/ui/scroll-area";
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
  X,
} from "lucide-react";
import { useTranslation } from 'react-i18next';
import { VisuallyHidden } from "@radix-ui/react-visually-hidden";

interface ToolsDialogProps {
  open: boolean;
  onClose: () => void;
  initialText?: string;
  onInsertResult?: (text: string) => void;
}

// Tool definition
interface Tool {
  id: string;
  name: string;
  description: string;
  icon: React.ReactNode;
  category: string;
  placeholder?: string;
  execute: (input: string) => string;
}

// All tools - same as Settings/Tools but optimized for dialog
const TOOLS: Tool[] = [
  // Generate
  {
    id: 'uuid',
    name: 'UUID',
    description: 'Generate UUID v4',
    icon: <Fingerprint className="h-3.5 w-3.5" />,
    category: 'Generate',
    execute: () => generateUUID()
  },
  {
    id: 'password',
    name: 'Password',
    description: 'Secure password',
    icon: <Key className="h-3.5 w-3.5" />,
    category: 'Generate',
    placeholder: 'Length (16)',
    execute: (input) => {
      const length = parseInt(input) || 16;
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
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
    description: 'Random hex bytes',
    icon: <Binary className="h-3.5 w-3.5" />,
    category: 'Generate',
    placeholder: 'Bytes (32)',
    execute: (input) => {
      const bytes = parseInt(input) || 32;
      const array = new Uint8Array(bytes);
      crypto.getRandomValues(array);
      return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
    }
  },
  {
    id: 'timestamp',
    name: 'Timestamp',
    description: 'Current time',
    icon: <Clock className="h-3.5 w-3.5" />,
    category: 'Generate',
    execute: () => {
      const now = new Date();
      return `${now.toISOString()}\n${Math.floor(now.getTime() / 1000)}`;
    }
  },
  // Time
  {
    id: 'ts-to-date',
    name: 'TS → Date',
    description: 'Timestamp to date',
    icon: <Timer className="h-3.5 w-3.5" />,
    category: 'Time',
    placeholder: '1701878400',
    execute: (input) => {
      const ts = parseInt(input.trim());
      if (isNaN(ts)) return 'Invalid';
      const date = ts > 9999999999 ? new Date(ts) : new Date(ts * 1000);
      return date.toLocaleString();
    }
  },
  {
    id: 'date-to-ts',
    name: 'Date → TS',
    description: 'Date to timestamp',
    icon: <Timer className="h-3.5 w-3.5" />,
    category: 'Time',
    placeholder: '2024-01-15',
    execute: (input) => {
      const date = new Date(input.trim());
      if (isNaN(date.getTime())) return 'Invalid';
      return Math.floor(date.getTime() / 1000).toString();
    }
  },
  // Path
  {
    id: 'basename',
    name: 'Basename',
    description: 'Get filename',
    icon: <FolderOpen className="h-3.5 w-3.5" />,
    category: 'Path',
    placeholder: '/path/to/file.txt',
    execute: (input) => input.split(/[/\\]/).pop() || input
  },
  {
    id: 'dirname',
    name: 'Dirname',
    description: 'Get directory',
    icon: <FolderOpen className="h-3.5 w-3.5" />,
    category: 'Path',
    placeholder: '/path/to/file.txt',
    execute: (input) => {
      const parts = input.split(/[/\\]/);
      parts.pop();
      return parts.join('/') || '/';
    }
  },
  {
    id: 'extension',
    name: 'Extension',
    description: 'Get file ext',
    icon: <FileText className="h-3.5 w-3.5" />,
    category: 'Path',
    placeholder: 'file.txt',
    execute: (input) => {
      const match = input.match(/\.([^.]+)$/);
      return match ? match[1] : 'None';
    }
  },
  // Encode
  {
    id: 'base64-enc',
    name: 'Base64 Enc',
    description: 'Encode to Base64',
    icon: <Binary className="h-3.5 w-3.5" />,
    category: 'Encode',
    placeholder: 'Text to encode',
    execute: (input) => {
      try { return btoa(unescape(encodeURIComponent(input))); }
      catch { return 'Error'; }
    }
  },
  {
    id: 'base64-dec',
    name: 'Base64 Dec',
    description: 'Decode Base64',
    icon: <Binary className="h-3.5 w-3.5" />,
    category: 'Encode',
    placeholder: 'Base64 string',
    execute: (input) => {
      try { return decodeURIComponent(escape(atob(input.trim()))); }
      catch { return 'Invalid'; }
    }
  },
  {
    id: 'url-enc',
    name: 'URL Encode',
    description: 'Encode for URL',
    icon: <Binary className="h-3.5 w-3.5" />,
    category: 'Encode',
    placeholder: 'Text to encode',
    execute: (input) => encodeURIComponent(input)
  },
  {
    id: 'url-dec',
    name: 'URL Decode',
    description: 'Decode URL',
    icon: <Binary className="h-3.5 w-3.5" />,
    category: 'Encode',
    placeholder: 'URL encoded text',
    execute: (input) => {
      try { return decodeURIComponent(input); }
      catch { return 'Invalid'; }
    }
  },
  // JSON
  {
    id: 'json-fmt',
    name: 'Format JSON',
    description: 'Pretty print',
    icon: <FileJson className="h-3.5 w-3.5" />,
    category: 'JSON',
    placeholder: '{"key":"value"}',
    execute: (input) => {
      try { return JSON.stringify(JSON.parse(input), null, 2); }
      catch { return 'Invalid JSON'; }
    }
  },
  {
    id: 'json-min',
    name: 'Minify JSON',
    description: 'Compress JSON',
    icon: <FileJson className="h-3.5 w-3.5" />,
    category: 'JSON',
    placeholder: 'Formatted JSON',
    execute: (input) => {
      try { return JSON.stringify(JSON.parse(input)); }
      catch { return 'Invalid JSON'; }
    }
  },
  // Convert
  {
    id: 'slug',
    name: 'To Slug',
    description: 'URL-friendly slug',
    icon: <Type className="h-3.5 w-3.5" />,
    category: 'Convert',
    placeholder: 'My Title Here',
    execute: (input) => input.toLowerCase().trim().replace(/[^\w\s-]/g, '').replace(/[\s_-]+/g, '-').replace(/^-+|-+$/g, '')
  },
  {
    id: 'camel',
    name: 'camelCase',
    description: 'To camelCase',
    icon: <Type className="h-3.5 w-3.5" />,
    category: 'Convert',
    placeholder: 'my variable name',
    execute: (input) => input.replace(/\W+/g, ' ').split(' ').map((w, i) => i === 0 ? w.toLowerCase() : w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('')
  },
  {
    id: 'snake',
    name: 'snake_case',
    description: 'To snake_case',
    icon: <Type className="h-3.5 w-3.5" />,
    category: 'Convert',
    placeholder: 'myVariableName',
    execute: (input) => input.replace(/\W+/g, ' ').split(/ |\B(?=[A-Z])/).map(w => w.toLowerCase()).join('_')
  },
  {
    id: 'kebab',
    name: 'kebab-case',
    description: 'To kebab-case',
    icon: <Type className="h-3.5 w-3.5" />,
    category: 'Convert',
    placeholder: 'myVariableName',
    execute: (input) => input.replace(/\W+/g, ' ').split(/ |\B(?=[A-Z])/).map(w => w.toLowerCase()).join('-')
  },
  // Colors
  {
    id: 'hex-rgb',
    name: 'Hex → RGB',
    description: 'Hex to RGB',
    icon: <Palette className="h-3.5 w-3.5" />,
    category: 'Colors',
    placeholder: '#FF5733',
    execute: (input) => {
      const hex = input.trim().replace('#', '');
      if (!/^[0-9A-Fa-f]{6}$/.test(hex)) return 'Invalid hex';
      const r = parseInt(hex.slice(0, 2), 16);
      const g = parseInt(hex.slice(2, 4), 16);
      const b = parseInt(hex.slice(4, 6), 16);
      return `rgb(${r}, ${g}, ${b})`;
    }
  },
  {
    id: 'rgb-hex',
    name: 'RGB → Hex',
    description: 'RGB to Hex',
    icon: <Palette className="h-3.5 w-3.5" />,
    category: 'Colors',
    placeholder: '255, 87, 51',
    execute: (input) => {
      const match = input.match(/(\d+)\s*,?\s*(\d+)\s*,?\s*(\d+)/);
      if (!match) return 'Invalid RGB';
      const r = Math.min(255, parseInt(match[1]));
      const g = Math.min(255, parseInt(match[2]));
      const b = Math.min(255, parseInt(match[3]));
      return '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase();
    }
  },
  // Math
  {
    id: 'calc',
    name: 'Calculate',
    description: 'Math expression',
    icon: <Calculator className="h-3.5 w-3.5" />,
    category: 'Math',
    placeholder: '(100 * 1.08) + 50',
    execute: (input) => {
      try {
        const sanitized = input.replace(/[^0-9+\-*/.()%\s]/g, '');
        const result = Function(`"use strict"; return (${sanitized})`)();
        return String(result);
      } catch { return 'Invalid'; }
    }
  },
  {
    id: 'bytes',
    name: 'Parse Bytes',
    description: 'Convert bytes',
    icon: <Calculator className="h-3.5 w-3.5" />,
    category: 'Math',
    placeholder: '1073741824',
    execute: (input) => {
      const num = parseFloat(input);
      if (isNaN(num)) return 'Invalid';
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      for (let i = units.length - 1; i >= 0; i--) {
        const val = num / Math.pow(1024, i);
        if (val >= 1) return `${val.toFixed(2)} ${units[i]}`;
      }
      return `${num} B`;
    }
  },
  // Extract
  {
    id: 'emails',
    name: 'Emails',
    description: 'Extract emails',
    icon: <Search className="h-3.5 w-3.5" />,
    category: 'Extract',
    placeholder: 'Text with emails...',
    execute: (input) => {
      const emails = input.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g);
      return emails ? Array.from(new Set(emails)).join('\n') : 'None found';
    }
  },
  {
    id: 'urls',
    name: 'URLs',
    description: 'Extract URLs',
    icon: <Search className="h-3.5 w-3.5" />,
    category: 'Extract',
    placeholder: 'Text with URLs...',
    execute: (input) => {
      const urls = input.match(/https?:\/\/[^\s<>"{}|\\^`[\]]+/g);
      return urls ? Array.from(new Set(urls)).join('\n') : 'None found';
    }
  },
  {
    id: 'ips',
    name: 'IPs',
    description: 'Extract IPs',
    icon: <Network className="h-3.5 w-3.5" />,
    category: 'Extract',
    placeholder: 'Text with IPs...',
    execute: (input) => {
      const ips = input.match(/\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/g);
      return ips ? Array.from(new Set(ips)).join('\n') : 'None found';
    }
  },
  // Analyze
  {
    id: 'stats',
    name: 'Stats',
    description: 'Text statistics',
    icon: <Hash className="h-3.5 w-3.5" />,
    category: 'Analyze',
    placeholder: 'Text to analyze...',
    execute: (input) => {
      const chars = input.length;
      const words = input.trim().split(/\s+/).filter(w => w.length > 0).length;
      const lines = input.split('\n').length;
      return `${chars} chars, ${words} words, ${lines} lines`;
    }
  },
  // Dev
  {
    id: 'regex',
    name: 'Test Regex',
    description: 'Test pattern',
    icon: <Code className="h-3.5 w-3.5" />,
    category: 'Dev',
    placeholder: '/pattern/flags\ntest string',
    execute: (input) => {
      const lines = input.split('\n');
      if (lines.length < 2) return 'Need: /pattern/flags\\ntext';
      const regexLine = lines[0].trim();
      const testString = lines.slice(1).join('\n');
      const match = regexLine.match(/^\/(.+)\/([gimsuy]*)$/);
      if (!match) return 'Invalid regex';
      try {
        const regex = new RegExp(match[1], match[2]);
        const matches = testString.match(regex);
        return matches ? `✓ ${matches.length} match(es)` : '✗ No match';
      } catch { return 'Error'; }
    }
  },
  {
    id: 'commit',
    name: 'Commit Msg',
    description: 'Format commit',
    icon: <GitBranch className="h-3.5 w-3.5" />,
    category: 'Dev',
    placeholder: 'Add user auth',
    execute: (input) => {
      const lower = input.toLowerCase();
      let type = 'chore';
      if (lower.includes('add') || lower.includes('new')) type = 'feat';
      else if (lower.includes('fix') || lower.includes('bug')) type = 'fix';
      else if (lower.includes('doc')) type = 'docs';
      return `${type}: ${input.charAt(0).toLowerCase() + input.slice(1)}`;
    }
  },
  {
    id: 'code-block',
    name: 'Code Block',
    description: 'Wrap in fence',
    icon: <Code className="h-3.5 w-3.5" />,
    category: 'Dev',
    placeholder: 'const x = 1;',
    execute: (input) => '```\n' + input + '\n```'
  },
];

const CATEGORIES = Array.from(new Set(TOOLS.map(t => t.category)));

const CATEGORY_ICONS: Record<string, React.ReactNode> = {
  'Generate': <Zap className="h-3.5 w-3.5" />,
  'Time': <Clock className="h-3.5 w-3.5" />,
  'Path': <FolderOpen className="h-3.5 w-3.5" />,
  'Encode': <Binary className="h-3.5 w-3.5" />,
  'JSON': <FileJson className="h-3.5 w-3.5" />,
  'Convert': <Type className="h-3.5 w-3.5" />,
  'Colors': <Palette className="h-3.5 w-3.5" />,
  'Math': <Calculator className="h-3.5 w-3.5" />,
  'Extract': <Search className="h-3.5 w-3.5" />,
  'Analyze': <Hash className="h-3.5 w-3.5" />,
  'Dev': <Terminal className="h-3.5 w-3.5" />,
};

export default function ToolsDialog(props: ToolsDialogProps) {
  const { t } = useTranslation();
  
  const [selectedCategory, setSelectedCategory] = useState(CATEGORIES[0]);
  const [selectedTool, setSelectedTool] = useState<Tool>(TOOLS[0]);
  const [input, setInput] = useState(props.initialText || '');
  const [output, setOutput] = useState('');
  const [copied, setCopied] = useState(false);

  const filteredTools = useMemo(() => 
    TOOLS.filter(tool => tool.category === selectedCategory),
    [selectedCategory]
  );

  useEffect(() => {
    if (props.open) {
      setInput(props.initialText || '');
      setOutput('');
      setCopied(false);
    }
  }, [props.open, props.initialText]);

  useEffect(() => {
    if (filteredTools.length > 0 && selectedTool.category !== selectedCategory) {
      setSelectedTool(filteredTools[0]);
      setOutput('');
    }
  }, [selectedCategory, filteredTools, selectedTool]);

  const handleExecute = () => {
    const result = selectedTool.execute(input);
    setOutput(result);
  };

  const handleCopy = () => {
    if (output) {
      navigator.clipboard.writeText(output);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }
  };

  const handleInsert = () => {
    if (output && props.onInsertResult) {
      props.onInsertResult(output);
      props.onClose();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    e.stopPropagation();
    if (e.key === 'Escape') props.onClose();
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') handleExecute();
  };

  return (
    <Dialog open={props.open} onOpenChange={(open) => !open && props.onClose()}>
      <DialogContent 
        onKeyDown={handleKeyDown}
        className="max-w-3xl w-[800px] p-0 gap-0 overflow-hidden"
      >
        <VisuallyHidden>
          <DialogTitle>Developer Tools</DialogTitle>
          <DialogDescription>Quick utilities for developers</DialogDescription>
        </VisuallyHidden>
        
        <div className="flex h-[480px]">
          {/* Left sidebar - Categories */}
          <div className="w-28 bg-secondary/50 border-r border-border flex flex-col">
            <div className="p-2 border-b border-border">
              <div className="flex items-center gap-1.5 px-2 py-1">
                <Zap className="h-4 w-4 text-yellow-500" />
                <span className="text-xs font-semibold">Tools</span>
              </div>
            </div>
            <ScrollArea className="flex-1">
              <div className="p-1">
                {CATEGORIES.map(cat => (
                  <button
                    key={cat}
                    onClick={() => setSelectedCategory(cat)}
                    className={`w-full flex items-center gap-1.5 px-2 py-1.5 rounded text-xs transition-colors ${
                      selectedCategory === cat 
                        ? 'bg-primary text-primary-foreground' 
                        : 'hover:bg-secondary text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    {CATEGORY_ICONS[cat]}
                    <span className="truncate">{cat}</span>
                  </button>
                ))}
              </div>
            </ScrollArea>
          </div>

          {/* Middle - Tool list */}
          <div className="w-36 border-r border-border flex flex-col">
            <div className="p-2 border-b border-border">
              <span className="text-xs font-medium text-muted-foreground px-2">
                {selectedCategory}
              </span>
            </div>
            <ScrollArea className="flex-1">
              <div className="p-1">
                {filteredTools.map(tool => (
                  <button
                    key={tool.id}
                    onClick={() => {
                      setSelectedTool(tool);
                      setOutput('');
                    }}
                    className={`w-full flex items-center gap-1.5 px-2 py-1.5 rounded text-xs transition-colors ${
                      selectedTool.id === tool.id 
                        ? 'bg-secondary text-foreground' 
                        : 'hover:bg-secondary/50 text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    {tool.icon}
                    <span className="truncate">{tool.name}</span>
                  </button>
                ))}
              </div>
            </ScrollArea>
          </div>

          {/* Right - Tool panel */}
          <div className="flex-1 flex flex-col">
            {/* Tool header */}
            <div className="px-4 py-2.5 border-b border-border flex items-center justify-between">
              <div className="flex items-center gap-2">
                {selectedTool.icon}
                <span className="text-sm font-medium">{selectedTool.name}</span>
              </div>
              <span className="text-xs text-muted-foreground">{selectedTool.description}</span>
            </div>

            {/* Input/Output */}
            <div className="flex-1 p-3 flex flex-col gap-3 overflow-hidden">
              <div className="flex-1 flex flex-col min-h-0">
                <label className="text-xs font-medium text-muted-foreground mb-1.5">Input</label>
                <Textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder={selectedTool.placeholder || 'Enter input...'}
                  className="flex-1 min-h-0 text-sm font-mono resize-none"
                />
              </div>

              <Button onClick={handleExecute} size="sm" className="w-full h-8">
                <Zap className="h-3.5 w-3.5 mr-1.5" />
                Execute
                <span className="ml-2 text-[10px] opacity-60">⌘↵</span>
              </Button>

              <div className="flex-1 flex flex-col min-h-0">
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-medium text-muted-foreground">Output</label>
                  {output && (
                    <Button variant="ghost" size="sm" onClick={handleCopy} className="h-6 px-2 text-xs">
                      {copied ? <CheckIcon className="h-3 w-3 mr-1 text-green-500" /> : <CopyIcon className="h-3 w-3 mr-1" />}
                      {copied ? 'Copied' : 'Copy'}
                    </Button>
                  )}
                </div>
                <Textarea
                  value={output}
                  readOnly
                  placeholder="Result will appear here..."
                  className="flex-1 min-h-0 text-sm font-mono resize-none bg-secondary/30"
                />
              </div>
            </div>

            {/* Footer */}
            <div className="px-3 py-2 border-t border-border flex items-center justify-end gap-2">
              <Button variant="secondary" size="sm" onClick={props.onClose} className="h-7">
                Close
              </Button>
              {output && props.onInsertResult && (
                <Button size="sm" onClick={handleInsert} className="h-7">
                  Insert Result
                </Button>
              )}
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

