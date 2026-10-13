import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

struct KeyboardShortcutParser {
    struct Parsed: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    static func parse(_ shortcut: String) -> Parsed? {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last, let keyCode = keyCodes[key] else {
            return nil
        }

        var modifiers: UInt32 = 0
        if parts.contains("cmd") || parts.contains("command") {
            modifiers |= UInt32(cmdKey)
        }
        if parts.contains("shift") {
            modifiers |= UInt32(shiftKey)
        }
        if parts.contains("option") || parts.contains("alt") {
            modifiers |= UInt32(optionKey)
        }
        if parts.contains("control") || parts.contains("ctrl") {
            modifiers |= UInt32(controlKey)
        }

        return Parsed(keyCode: keyCode, modifiers: modifiers)
    }

    /// Whether the shortcut includes at least one modifier key. A bare key such
    /// as Return must never be registered system-wide: the hotkey would swallow
    /// that key in every application, including ClipBook's own history panel.
    static func hasModifiers(_ shortcut: String) -> Bool {
        guard let parsed = parse(shortcut) else {
            return false
        }

        return parsed.modifiers != 0
    }

    static func menuItemKeyEquivalent(for shortcut: String) -> (keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags)? {
        guard let parsed = parse(shortcut) else {
            return nil
        }

        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last else {
            return nil
        }

        var modifierFlags = NSEvent.ModifierFlags()
        if parsed.modifiers & UInt32(cmdKey) != 0 {
            modifierFlags.insert(.command)
        }
        if parsed.modifiers & UInt32(shiftKey) != 0 {
            modifierFlags.insert(.shift)
        }
        if parsed.modifiers & UInt32(optionKey) != 0 {
            modifierFlags.insert(.option)
        }
        if parsed.modifiers & UInt32(controlKey) != 0 {
            modifierFlags.insert(.control)
        }

        if key.hasPrefix("keypad") {
            modifierFlags.insert(.numericPad)
        }

        let keyEquivalent: String
        switch key {
        case "return":
            keyEquivalent = "\r"
        case "escape":
            keyEquivalent = String(Character(UnicodeScalar(27)!))
        case "delete":
            keyEquivalent = String(Character(UnicodeScalar(NSEvent.SpecialKey.delete.rawValue)!))
        case "tab":
            keyEquivalent = "\t"
        case "space":
            keyEquivalent = " "
        default:
            if let specialKey = specialKeyEquivalents[key] {
                keyEquivalent = String(Character(UnicodeScalar(specialKey)!))
            } else if let keypadCharacter = keypadCharacters[key] {
                keyEquivalent = keypadCharacter
            } else {
                keyEquivalent = key
            }
        }

        return (keyEquivalent, modifierFlags)
    }

    static func event(_ event: NSEvent, matches shortcut: String) -> Bool {
        guard let parsed = parse(shortcut) else {
            return false
        }

        return UInt32(event.keyCode) == parsed.keyCode && eventModifierFlags(event) == parsed.modifiers
    }

    private static func eventModifierFlags(_ event: NSEvent) -> UInt32 {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        var modifiers: UInt32 = 0

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }

    /// Returns the storage token for a virtual key code, or `nil` when the key
    /// cannot be used in a shortcut.
    static func keyToken(for keyCode: UInt16) -> String? {
        keyTokensByCode[UInt32(keyCode)]
    }

    /// Returns the label shown for a key token, e.g. "↩" for "return".
    static func keyDisplayText(for key: String) -> String {
        switch key {
        case "return":
            return "↩"
        case "escape":
            return L10n.string("Esc")
        case "delete":
            return "⌫"
        case "forwarddelete":
            return "⌦"
        case "tab":
            return "⇥"
        case "space":
            return L10n.string("Space")
        case "left":
            return "←"
        case "right":
            return "→"
        case "down":
            return "↓"
        case "up":
            return "↑"
        case "home":
            return "↖"
        case "end":
            return "↘"
        case "pageup":
            return "⇞"
        case "pagedown":
            return "⇟"
        case "keypadenter":
            return "⌤"
        case "keypadclear":
            return "⌧"
        default:
            if let keypadCharacter = keypadCharacters[key] {
                return "Num " + keypadCharacter
            }
            return key.uppercased()
        }
    }

    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "§": 10, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, "space": 49, "return": 36, "tab": 48,
        "escape": 53, "delete": 51, "forwarddelete": 117, "left": 123, "right": 124,
        "down": 125, "up": 126, "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98,
        "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111, "f13": 105,
        "f14": 107, "f15": 113, "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,
        "keypad0": 82, "keypad1": 83, "keypad2": 84, "keypad3": 85, "keypad4": 86,
        "keypad5": 87, "keypad6": 88, "keypad7": 89, "keypad8": 91, "keypad9": 92,
        "keypaddecimal": 65, "keypadmultiply": 67, "keypadplus": 69, "keypadclear": 71,
        "keypaddivide": 75, "keypadenter": 76, "keypadminus": 78, "keypadequals": 81
    ]

    private static let keyTokensByCode: [UInt32: String] = Dictionary(
        uniqueKeysWithValues: keyCodes.map { ($0.value, $0.key) }
    )

    /// Characters typed by keypad keys. Keypad tokens are spelled out because
    /// "+" separates the parts of a stored shortcut.
    private static let keypadCharacters: [String: String] = [
        "keypad0": "0", "keypad1": "1", "keypad2": "2", "keypad3": "3", "keypad4": "4",
        "keypad5": "5", "keypad6": "6", "keypad7": "7", "keypad8": "8", "keypad9": "9",
        "keypaddecimal": ".", "keypadmultiply": "*", "keypadplus": "+",
        "keypaddivide": "/", "keypadminus": "-", "keypadequals": "=",
        "keypadenter": "\u{3}"
    ]

    /// Menu key equivalents for keys that do not type a character.
    private static let specialKeyEquivalents: [String: Int] = [
        "left": NSLeftArrowFunctionKey, "right": NSRightArrowFunctionKey,
        "up": NSUpArrowFunctionKey, "down": NSDownArrowFunctionKey,
        "forwarddelete": NSDeleteFunctionKey, "home": NSHomeFunctionKey,
        "end": NSEndFunctionKey, "pageup": NSPageUpFunctionKey,
        "pagedown": NSPageDownFunctionKey, "keypadclear": NSClearLineFunctionKey,
        "f1": NSF1FunctionKey, "f2": NSF2FunctionKey, "f3": NSF3FunctionKey,
        "f4": NSF4FunctionKey, "f5": NSF5FunctionKey, "f6": NSF6FunctionKey,
        "f7": NSF7FunctionKey, "f8": NSF8FunctionKey, "f9": NSF9FunctionKey,
        "f10": NSF10FunctionKey, "f11": NSF11FunctionKey, "f12": NSF12FunctionKey,
        "f13": NSF13FunctionKey, "f14": NSF14FunctionKey, "f15": NSF15FunctionKey,
        "f16": NSF16FunctionKey, "f17": NSF17FunctionKey, "f18": NSF18FunctionKey,
        "f19": NSF19FunctionKey, "f20": NSF20FunctionKey
    ]
}
