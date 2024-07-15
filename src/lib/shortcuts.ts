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

type ModifierKey = 'Meta' | 'Alt' | 'Control' | 'Shift';
interface ParsedShortcut {
  key: string;
  modifiers: ModifierKey[];
}

const parseShortcut = (shortcut: string): ParsedShortcut => {
  const parts = shortcut.split(' + ');
  const modifiers: ModifierKey[] = [];
  let key = '';

  parts.forEach(part => {
    switch (part) {
      case 'Meta':
      case 'Alt':
      case 'Control':
      case 'Shift':
        modifiers.push(part);
        break;
      default:
        key = part;
    }
  });

  return { key, modifiers };
};

export const isShortcutMatch = (shortcut: string, event: KeyboardEvent): boolean => {
  const { key, modifiers } = parseShortcut(shortcut);

  const metaKey = event.metaKey;
  const altKey = event.altKey;
  const ctrlKey = event.ctrlKey;
  const shiftKey = event.shiftKey;

  const allModifiersMatch =
      (modifiers.includes('Meta') === metaKey) &&
      (modifiers.includes('Alt') === altKey) &&
      (modifiers.includes('Control') === ctrlKey) &&
      (modifiers.includes('Shift') === shiftKey);

  return allModifiersMatch && event.key.toLowerCase() === key.toLowerCase();
};
