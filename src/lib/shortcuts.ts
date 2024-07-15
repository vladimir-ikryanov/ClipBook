const keySymbolMap: { [key: string]: string } = {
  Meta: '⌘',
  Alt: '⌥',
  Control: '⌃',
  Shift: '⇧',
  Backspace: '⌫',
  ArrowUp: '↑',
  ArrowDown: '↓',
  ArrowLeft: '←',
  ArrowRight: '→',
  Enter: '↵',
  Escape: 'Esc',
  Space: '␣',
};

export function keysToDisplayShortcut(keys: string[]): string {
  return keys
      .map(key => keySymbolMap[key] || key.toUpperCase())
      .join(' ');
}

export function shortcutToDisplayShortcut(shortcut: string): string {
  return keysToDisplayShortcut(shortcut.split(' + '));
}
