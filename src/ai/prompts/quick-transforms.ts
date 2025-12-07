/**
 * Quick Transforms - Local text operations that don't need AI
 * These are INSTANT and FREE - no API calls needed!
 * 
 * NOTE: Basic transforms like uppercase, lowercase, capitalize, sentence case,
 * remove empty lines, trim whitespace are ALREADY in ClipBook's built-in
 * FormatTextCommands.tsx - so we only add ADDITIONAL transforms here.
 */

import { generateUUID } from '@/lib/crypto';

export type QuickTransform = (text: string) => string;

export const QUICK_TRANSFORMS: Record<string, QuickTransform> = {
  // ============================================
  // EXTRACTIONS - Not in ClipBook built-in
  // ============================================
  extractEmails: (text) => {
    const emails = text.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g);
    return emails ? Array.from(new Set(emails)).join('\n') : 'No emails found';
  },
  extractUrls: (text) => {
    const urls = text.match(/https?:\/\/[^\s<>"{}|\\^`[\]]+/g);
    return urls ? Array.from(new Set(urls)).join('\n') : 'No URLs found';
  },
  extractNumbers: (text) => {
    const numbers = text.match(/\d+([.,]\d+)?/g);
    return numbers ? Array.from(new Set(numbers)).join(', ') : 'No numbers found';
  },
  extractPhoneNumbers: (text) => {
    // Match common phone formats: (123) 456-7890, 123-456-7890, +1 123 456 7890, etc.
    const phones = text.match(/[\+]?[(]?[0-9]{1,3}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}/g);
    return phones ? Array.from(new Set(phones)).join('\n') : 'No phone numbers found';
  },
  extractDates: (text) => {
    // Match common date formats
    const dates = text.match(/\d{1,4}[-\/\.]\d{1,2}[-\/\.]\d{1,4}|\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}/gi);
    return dates ? Array.from(new Set(dates)).join('\n') : 'No dates found';
  },
  extractHashtags: (text) => {
    const hashtags = text.match(/#[a-zA-Z0-9_]+/g);
    return hashtags ? Array.from(new Set(hashtags)).join('\n') : 'No hashtags found';
  },
  extractMentions: (text) => {
    const mentions = text.match(/@[a-zA-Z0-9_]+/g);
    return mentions ? Array.from(new Set(mentions)).join('\n') : 'No mentions found';
  },

  // ============================================
  // FORMAT TRANSFORMS - Not in ClipBook built-in
  // ============================================
  toBulletPoints: (text) => {
    return text
      .split(/[\n]+/)
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .map(s => `• ${s}`)
      .join('\n');
  },
  toNumberedList: (text) => {
    return text
      .split(/[\n]+/)
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .map((s, i) => `${i + 1}. ${s}`)
      .join('\n');
  },
  normalizeLineBreaks: (text) => text.replace(/\r\n/g, '\n').replace(/\r/g, '\n'),
  
  // ============================================
  // TEXT ANALYSIS - Not in ClipBook built-in
  // ============================================
  countStats: (text) => {
    const words = text.trim().split(/\s+/).filter(w => w.length > 0).length;
    const chars = text.length;
    const charsNoSpace = text.replace(/\s/g, '').length;
    const lines = text.split('\n').length;
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0).length;
    const paragraphs = text.split(/\n\s*\n/).filter(p => p.trim().length > 0).length;
    return `Words: ${words}\nCharacters: ${chars}\nCharacters (no spaces): ${charsNoSpace}\nLines: ${lines}\nSentences: ${sentences}\nParagraphs: ${paragraphs}`;
  },

  // ============================================
  // SORT & UNIQUE - Not in ClipBook built-in
  // ============================================
  sortLines: (text) => text.split('\n').sort().join('\n'),
  sortLinesReverse: (text) => text.split('\n').sort().reverse().join('\n'),
  sortLinesAlphaIgnoreCase: (text) => text.split('\n').sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())).join('\n'),
  uniqueLines: (text) => Array.from(new Set(text.split('\n'))).join('\n'),
  removeDuplicateWords: (text) => Array.from(new Set(text.split(/\s+/))).join(' '),
  
  // ============================================
  // REVERSE - Not in ClipBook built-in
  // ============================================
  reverse: (text) => text.split('').reverse().join(''),
  reverseWords: (text) => text.split(' ').reverse().join(' '),
  reverseLines: (text) => text.split('\n').reverse().join('\n'),
  
  // ============================================
  // ENCODING - Not in ClipBook built-in
  // ============================================
  toBase64: (text) => {
    try {
      return btoa(unescape(encodeURIComponent(text)));
    } catch {
      return 'Error: Could not encode to Base64';
    }
  },
  fromBase64: (text) => {
    try {
      return decodeURIComponent(escape(atob(text.trim())));
    } catch {
      return 'Error: Invalid Base64 string';
    }
  },
  encodeUri: (text) => encodeURIComponent(text),
  decodeUri: (text) => {
    try {
      return decodeURIComponent(text);
    } catch {
      return 'Error: Invalid URI encoding';
    }
  },
  escapeHtml: (text) => {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  },
  unescapeHtml: (text) => {
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'");
  },

  // ============================================
  // JSON/CODE - Not in ClipBook built-in
  // ============================================
  formatJson: (text) => {
    try {
      return JSON.stringify(JSON.parse(text), null, 2);
    } catch {
      return 'Error: Invalid JSON';
    }
  },
  minifyJson: (text) => {
    try {
      return JSON.stringify(JSON.parse(text));
    } catch {
      return 'Error: Invalid JSON';
    }
  },
  
  // ============================================
  // SLUG/CASE CONVERSIONS - Not in ClipBook built-in
  // ============================================
  toSlug: (text) => {
    return text
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, '')
      .replace(/[\s_-]+/g, '-')
      .replace(/^-+|-+$/g, '');
  },
  toSnakeCase: (text) => {
    return text
      .replace(/\W+/g, ' ')
      .split(/ |\B(?=[A-Z])/)
      .map(word => word.toLowerCase())
      .join('_');
  },
  toCamelCase: (text) => {
    return text
      .replace(/\W+/g, ' ')
      .split(' ')
      .map((word, index) => 
        index === 0 
          ? word.toLowerCase() 
          : word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
      )
      .join('');
  },
  toPascalCase: (text) => {
    return text
      .replace(/\W+/g, ' ')
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join('');
  },
  toKebabCase: (text) => {
    return text
      .replace(/\W+/g, ' ')
      .split(/ |\B(?=[A-Z])/)
      .map(word => word.toLowerCase())
      .join('-');
  },

  // ============================================
  // DEVELOPER TOOLS - Git/GitHub/Code helpers
  // ============================================
  extractGitHubUrls: (text) => {
    const urls = text.match(/https?:\/\/github\.com\/[^\s<>"{}|\\^`[\]]+/g);
    return urls ? Array.from(new Set(urls)).join('\n') : 'No GitHub URLs found';
  },
  extractGitHubIssues: (text) => {
    // Match #123 or org/repo#123 patterns
    const issues = text.match(/([\w-]+\/[\w-]+)?#\d+/g);
    return issues ? Array.from(new Set(issues)).join('\n') : 'No issue references found';
  },
  wrapInCodeBlock: (text) => {
    return '```\n' + text + '\n```';
  },
  wrapInCodeBlockLang: (text) => {
    // Try to detect language from content
    let lang = 'text';
    if (text.includes('function') || text.includes('const ') || text.includes('let ')) lang = 'javascript';
    else if (text.includes('def ') || text.includes('import ') && text.includes(':')) lang = 'python';
    else if (text.includes('func ') || text.includes('package ')) lang = 'go';
    else if (text.includes('fn ') || text.includes('let mut')) lang = 'rust';
    else if (text.includes('<?php')) lang = 'php';
    else if (text.includes('<html') || text.includes('<div')) lang = 'html';
    else if (text.includes('{') && text.includes(':') && (text.includes('"') || text.includes("'"))) lang = 'json';
    return '```' + lang + '\n' + text + '\n```';
  },
  stripCodeBlock: (text) => {
    return text.replace(/^```[\w]*\n?/gm, '').replace(/```$/gm, '').trim();
  },
  formatCommitMessage: (text) => {
    // Format as conventional commit
    const lines = text.split('\n').filter(l => l.trim());
    if (lines.length === 0) return text;
    
    const firstLine = lines[0];
    // Check if already formatted
    if (/^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?:/.test(firstLine)) {
      return text;
    }
    
    // Auto-detect type
    const lower = firstLine.toLowerCase();
    let type = 'chore';
    if (lower.includes('add') || lower.includes('new') || lower.includes('implement')) type = 'feat';
    else if (lower.includes('fix') || lower.includes('bug') || lower.includes('issue')) type = 'fix';
    else if (lower.includes('doc') || lower.includes('readme')) type = 'docs';
    else if (lower.includes('style') || lower.includes('format')) type = 'style';
    else if (lower.includes('refactor') || lower.includes('clean')) type = 'refactor';
    else if (lower.includes('test')) type = 'test';
    else if (lower.includes('perf') || lower.includes('optim')) type = 'perf';
    
    return `${type}: ${firstLine.charAt(0).toLowerCase() + firstLine.slice(1)}${lines.length > 1 ? '\n\n' + lines.slice(1).join('\n') : ''}`;
  },
  
  // ============================================
  // MARKDOWN HELPERS
  // ============================================
  toMarkdownLink: (text) => {
    // If text looks like a URL, create a markdown link
    const urlMatch = text.match(/https?:\/\/[^\s]+/);
    if (urlMatch) {
      const url = urlMatch[0];
      // Try to get domain as title
      const domain = url.match(/https?:\/\/([^\/]+)/)?.[1] || 'Link';
      return `[${domain}](${url})`;
    }
    return `[${text}](url)`;
  },
  toMarkdownImage: (text) => {
    const urlMatch = text.match(/https?:\/\/[^\s]+/);
    if (urlMatch) {
      return `![image](${urlMatch[0]})`;
    }
    return `![alt text](${text})`;
  },
  toMarkdownTable: (text) => {
    const lines = text.split('\n').filter(l => l.trim());
    if (lines.length === 0) return text;
    
    // Try to detect delimiter (comma, tab, pipe)
    const firstLine = lines[0];
    let delimiter = ',';
    if (firstLine.includes('\t')) delimiter = '\t';
    else if (firstLine.includes('|')) delimiter = '|';
    
    const rows = lines.map(line => line.split(delimiter).map(cell => cell.trim()));
    const maxCols = Math.max(...rows.map(r => r.length));
    
    // Pad rows to same length
    const paddedRows = rows.map(row => {
      while (row.length < maxCols) row.push('');
      return row;
    });
    
    // Build table
    const header = '| ' + paddedRows[0].join(' | ') + ' |';
    const separator = '| ' + paddedRows[0].map(() => '---').join(' | ') + ' |';
    const body = paddedRows.slice(1).map(row => '| ' + row.join(' | ') + ' |').join('\n');
    
    return header + '\n' + separator + (body ? '\n' + body : '');
  },
  stripMarkdown: (text) => {
    return text
      .replace(/\*\*(.+?)\*\*/g, '$1')  // bold
      .replace(/\*(.+?)\*/g, '$1')       // italic
      .replace(/__(.+?)__/g, '$1')       // bold
      .replace(/_(.+?)_/g, '$1')         // italic
      .replace(/~~(.+?)~~/g, '$1')       // strikethrough
      .replace(/`(.+?)`/g, '$1')         // inline code
      .replace(/^#+\s*/gm, '')           // headers
      .replace(/^\s*[-*+]\s+/gm, '')     // bullets
      .replace(/^\s*\d+\.\s+/gm, '')     // numbered lists
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')  // links
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1'); // images
  },

  // ============================================
  // SYSTEM / TERMINAL-LIKE TOOLS (Safe, no shell)
  // ============================================
  
  // Generate random string (like openssl rand)
  generateUUID: () => generateUUID(),
  
  generatePassword: (text) => {
    // Generate secure password, length from input or default 16
    const length = parseInt(text) || 16;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?';
    let password = '';
    const array = new Uint32Array(length);
    crypto.getRandomValues(array);
    for (let i = 0; i < length; i++) {
      password += chars[array[i] % chars.length];
    }
    return password;
  },
  
  generateRandomHex: (text) => {
    const bytes = parseInt(text) || 32;
    const array = new Uint8Array(bytes);
    crypto.getRandomValues(array);
    return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
  },

  // Timestamp conversions (like date command)
  timestampToDate: (text) => {
    const ts = parseInt(text.trim());
    if (isNaN(ts)) return 'Invalid timestamp';
    // Handle both seconds and milliseconds
    const date = ts > 9999999999 ? new Date(ts) : new Date(ts * 1000);
    return date.toISOString() + '\n' + date.toLocaleString();
  },
  
  dateToTimestamp: (text) => {
    const date = new Date(text.trim());
    if (isNaN(date.getTime())) return 'Invalid date';
    return `Seconds: ${Math.floor(date.getTime() / 1000)}\nMilliseconds: ${date.getTime()}`;
  },
  
  currentTimestamp: () => {
    const now = new Date();
    return `ISO: ${now.toISOString()}\nLocal: ${now.toLocaleString()}\nUnix (s): ${Math.floor(now.getTime() / 1000)}\nUnix (ms): ${now.getTime()}`;
  },

  // IP/Network parsing (like nslookup parsing)
  extractIPs: (text) => {
    const ipv4 = text.match(/\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/g);
    const ipv6 = text.match(/([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|::([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}/g);
    const results: string[] = [];
    if (ipv4) results.push('IPv4:\n' + Array.from(new Set(ipv4)).join('\n'));
    if (ipv6) results.push('IPv6:\n' + Array.from(new Set(ipv6)).join('\n'));
    return results.length > 0 ? results.join('\n\n') : 'No IP addresses found';
  },

  // Path operations (like basename, dirname)
  pathBasename: (text) => {
    const path = text.trim();
    return path.split(/[/\\]/).pop() || path;
  },
  
  pathDirname: (text) => {
    const path = text.trim();
    const parts = path.split(/[/\\]/);
    parts.pop();
    return parts.join('/') || '/';
  },
  
  pathExtension: (text) => {
    const path = text.trim();
    const match = path.match(/\.([^.]+)$/);
    return match ? match[1] : 'No extension';
  },

  // Environment variable format (for scripts)
  toEnvFormat: (text) => {
    // Convert key=value pairs or JSON to export format
    const lines = text.trim().split('\n');
    return lines.map(line => {
      const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)[\s:=]+(.+)$/);
      if (match) {
        const value = match[2].trim().replace(/"/g, '\\"');
        return `export ${match[1]}="${value}"`;
      }
      return `# ${line}`;
    }).join('\n');
  },

  // Cron expression helper
  parseCron: (text) => {
    const parts = text.trim().split(/\s+/);
    if (parts.length < 5) return 'Invalid cron expression (need 5 fields: min hour day month weekday)';
    const [min, hour, day, month, weekday] = parts;
    const descriptions = [
      `Minute: ${min} ${min === '*' ? '(every minute)' : ''}`,
      `Hour: ${hour} ${hour === '*' ? '(every hour)' : ''}`,
      `Day: ${day} ${day === '*' ? '(every day)' : ''}`,
      `Month: ${month} ${month === '*' ? '(every month)' : ''}`,
      `Weekday: ${weekday} ${weekday === '*' ? '(every day)' : '(0=Sun, 1=Mon, ...)'}`
    ];
    return descriptions.join('\n');
  },

  // Regex tester
  testRegex: (text) => {
    // Format: /pattern/flags\ntest string
    const lines = text.split('\n');
    if (lines.length < 2) return 'Format: /pattern/flags (line 1) + test string (line 2+)';
    
    const regexLine = lines[0].trim();
    const testString = lines.slice(1).join('\n');
    
    const match = regexLine.match(/^\/(.+)\/([gimsuy]*)$/);
    if (!match) return 'Invalid regex format. Use: /pattern/flags';
    
    try {
      const regex = new RegExp(match[1], match[2]);
      const matches = testString.match(regex);
      if (matches) {
        return `✅ Match found!\n\nMatches:\n${matches.join('\n')}\n\nFull match: "${matches[0]}"`;
      }
      return '❌ No match';
    } catch (e) {
      return `Error: ${e instanceof Error ? e.message : 'Invalid regex'}`;
    }
  },

  // Diff helper - show line differences
  compareLines: (text) => {
    // Format: text1\n---\ntext2
    const parts = text.split(/\n---\n/);
    if (parts.length !== 2) return 'Format: text1\\n---\\ntext2 (separate with --- on its own line)';
    
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
  },

  // Byte/size calculations (like du)
  parseSize: (text) => {
    const num = parseFloat(text);
    if (isNaN(num)) return 'Invalid number';
    
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    const results: string[] = [];
    
    // Assume input is bytes
    for (let i = 0; i < units.length; i++) {
      const val = num / Math.pow(1024, i);
      if (val >= 1 || i === 0) {
        results.push(`${val.toFixed(2)} ${units[i]}`);
      }
    }
    return results.join('\n');
  },

  // Calculate expression (like bc)
  calculate: (text) => {
    try {
      // Safe evaluation - only allow math operations
      const sanitized = text.replace(/[^0-9+\-*/.()%\s]/g, '');
      if (sanitized !== text.replace(/\s/g, '').replace(/Math\.\w+/g, '')) {
        return 'Only basic math operations allowed (+, -, *, /, %, parentheses)';
      }
      // eslint-disable-next-line no-eval
      const result = Function(`"use strict"; return (${sanitized})`)();
      return `${text.trim()} = ${result}`;
    } catch {
      return 'Invalid expression';
    }
  },

  // Word frequency (like wc + sort | uniq -c)
  wordFrequency: (text) => {
    const words = text.toLowerCase().match(/\b[a-z]+\b/g);
    if (!words) return 'No words found';
    
    const freq: Record<string, number> = {};
    words.forEach(w => freq[w] = (freq[w] || 0) + 1);
    
    return Object.entries(freq)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(([word, count]) => `${count.toString().padStart(4)} ${word}`)
      .join('\n');
  },

  // Character frequency
  charFrequency: (text) => {
    const freq: Record<string, number> = {};
    for (const char of text) {
      if (char.trim()) {
        freq[char] = (freq[char] || 0) + 1;
      }
    }
    
    return Object.entries(freq)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 30)
      .map(([char, count]) => `${count.toString().padStart(4)} '${char}'`)
      .join('\n');
  },

  // Color conversions
  hexToRgb: (text) => {
    const hex = text.trim().replace('#', '');
    if (!/^[0-9A-Fa-f]{6}$/.test(hex)) return 'Invalid hex color (use #RRGGBB or RRGGBB)';
    
    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    
    return `RGB: rgb(${r}, ${g}, ${b})\nRGBA: rgba(${r}, ${g}, ${b}, 1)\nValues: R=${r}, G=${g}, B=${b}`;
  },
  
  rgbToHex: (text) => {
    const match = text.match(/(\d+)\s*,?\s*(\d+)\s*,?\s*(\d+)/);
    if (!match) return 'Invalid RGB (use: r, g, b or r g b)';
    
    const r = Math.min(255, parseInt(match[1]));
    const g = Math.min(255, parseInt(match[2]));
    const b = Math.min(255, parseInt(match[3]));
    
    const hex = '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('');
    return `Hex: ${hex.toUpperCase()}\nLowercase: ${hex}`;
  },
};

// Check if an action can be done locally (instantly)
export function isQuickTransform(action: string): boolean {
  return action in QUICK_TRANSFORMS;
}

// Execute a quick transform
export function executeQuickTransform(action: string, text: string): string | null {
  const transform = QUICK_TRANSFORMS[action];
  if (transform) {
    return transform(text);
  }
  return null;
}

// Get all quick transform actions
export function getQuickTransformActions(): string[] {
  return Object.keys(QUICK_TRANSFORMS);
}

