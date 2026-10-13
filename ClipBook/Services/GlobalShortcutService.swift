import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

final class GlobalShortcutService {
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    init() {
        installHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ identifier: GlobalShortcutIdentifier, shortcut: String, handler: @escaping () -> Void) {
        guard let parsed = KeyboardShortcutParser.parse(shortcut) else {
            return
        }

        // A modifier-less hotkey (e.g. a bare Return) is captured system-wide and
        // steals that key from every application, so it is never registered.
        guard parsed.modifiers != 0 else {
            NSLog("ClipBook refused to register global shortcut without modifiers: \(shortcut)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType("CLPB"), id: identifier.rawValue)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(parsed.keyCode, parsed.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr, let hotKeyRef else {
            NSLog("ClipBook failed to register global shortcut \(shortcut): \(status)")
            return
        }

        handlers[identifier.rawValue] = handler
        hotKeys.append(hotKeyRef)
    }

    func unregisterAll() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        handlers.removeAll()
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else {
                return noErr
            }
            let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            DispatchQueue.main.async {
                service.handlers[hotKeyID.id]?()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }
}
