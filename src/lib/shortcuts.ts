const keySymbolMap: { [key: string]: string } = {
  MetaLeft: '⌘',
  MetaRight: '⌘',
  AltLeft: '⌥',
  AltRight: '⌥',
  ControlLeft: '⌃',
  ControlRight: '⌃',
  ShiftLeft: '⇧',
  ShiftRight: '⇧',
  Delete: 'Del',
  Backspace: '⌫',
  ArrowUp: '↑',
  ArrowDown: '↓',
  ArrowLeft: '←',
  ArrowRight: '→',
  Enter: '↵',
  Escape: 'Esc',
  Space: '␣',
  Tab: '⇥',
  Digit0: '0',
  Digit1: '1',
  Digit2: '2',
  Digit3: '3',
  Digit4: '4',
  Digit5: '5',
  Digit6: '6',
  Digit7: '7',
  Digit8: '8',
  Digit9: '9',
  KeyA: 'A',
  KeyB: 'B',
  KeyC: 'C',
  KeyD: 'D',
  KeyE: 'E',
  KeyF: 'F',
  KeyG: 'G',
  KeyH: 'H',
  KeyI: 'I',
  KeyJ: 'J',
  KeyK: 'K',
  KeyL: 'L',
  KeyM: 'M',
  KeyN: 'N',
  KeyO: 'O',
  KeyP: 'P',
  KeyQ: 'Q',
  KeyR: 'R',
  KeyS: 'S',
  KeyT: 'T',
  KeyU: 'U',
  KeyV: 'V',
  KeyW: 'W',
  KeyX: 'X',
  KeyY: 'Y',
  KeyZ: 'Z',
  Minus: '-',
  Equal: '=',
  BracketLeft: '[',
  BracketRight: ']',
  Semicolon: ';',
  Quote: '\'',
  Backquote: '`',
  Backslash: '\\',
  Comma: ',',
  Period: '.',
  Slash: '/',
  Numpad0: '0',
  Numpad1: '1',
  Numpad2: '2',
  Numpad3: '3',
  Numpad4: '4',
  Numpad5: '5',
  Numpad6: '6',
  Numpad7: '7',
  Numpad8: '8',
  Numpad9: '9',
  NumpadMultiply: '*',
  NumpadAdd: '+',
  NumpadSubtract: '-',
  NumpadDecimal: '.',
  NumpadComma: ',',
  NumpadDivide: '/',
  NumpadEnter: '↵',
  NumpadEqual: '=',
  F1: 'F1',
  F2: 'F2',
  F3: 'F3',
  F4: 'F4',
  F5: 'F5',
  F6: 'F6',
  F7: 'F7',
  F8: 'F8',
  F9: 'F9',
  F10: 'F10',
  F11: 'F11',
  F12: 'F12',
  F13: 'F13',
  F14: 'F14',
  F15: 'F15',
  F16: 'F16',
  F17: 'F17',
  F18: 'F18',
  F19: 'F19',
  F20: 'F20',
  F21: 'F21',
  F22: 'F22',
  F23: 'F23',
  F24: 'F24',
  NumLock: 'NumLock',
  PageUp: 'PgUp',
  PageDown: 'PgDown',
  Home: 'Home',
  End: 'End'
};

export function keysToDisplayShortcut(keys: string[]): string {
  return keys
      .map(key => keySymbolMap[key] || key)
      .join(' ');
}

export function shortcutToDisplayShortcut(shortcut: string): string {
  return keysToDisplayShortcut(shortcut.split(' + '));
}

type ModifierKey = 'MetaLeft' | 'MetaRight' | 'AltLeft' | 'AltRight' | 'ControlLeft' | 'ControlRight' | 'ShiftLeft' | 'ShiftRight';

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
      case 'MetaLeft':
      case 'MetaRight':
      case 'AltLeft':
      case 'AltRight':
      case 'ControlLeft':
      case 'ControlRight':
      case 'ShiftLeft':
      case 'ShiftRight':
        modifiers.push(part);
        break;
      default:
        key = part;
    }
  });

  return {key, modifiers};
};

export const isShortcutMatch = (shortcut: string, event: KeyboardEvent): boolean => {
  const {key, modifiers} = parseShortcut(shortcut);

  const metaKey = event.metaKey;
  const altKey = event.altKey;
  const ctrlKey = event.ctrlKey;
  const shiftKey = event.shiftKey;

  const allModifiersMatch =
      (modifiers.includes('MetaLeft') || modifiers.includes('MetaRight')) === metaKey &&
      (modifiers.includes('AltLeft') || modifiers.includes('AltRight')) === altKey &&
      (modifiers.includes('ControlLeft') || modifiers.includes('ControlRight')) === ctrlKey &&
      (modifiers.includes('ShiftLeft') || modifiers.includes('ShiftRight')) === shiftKey;

  return allModifiersMatch && event.code === key;
};

export const isModifierKey = (key: string): boolean => {
  return ['MetaLeft', 'MetaRight', 'AltLeft', 'AltRight', 'ControlLeft', 'ControlRight', 'ShiftLeft', 'ShiftRight'].includes(key);
}
