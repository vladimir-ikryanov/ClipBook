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

export function isShortcutMatch(shortcut: string, event: KeyboardEvent): boolean {
  const keys = shortcut.split(' + ');
  return keys.every(key => {
    if (key === 'Meta') {
      return event.metaKey;
    } else if (key === 'Control') {
      return event.ctrlKey;
    } else if (key === 'Alt') {
      return event.altKey;
    } else if (key === 'Shift') {
      return event.shiftKey;
    } else {
      return event.key === key;
    }
  });
}
