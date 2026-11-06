import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

final class GlobalShortcutService {
    private struct Registration {
        let identifier: GlobalShortcutIdentifier
        let shortcut: String
    }

    private let isEnabled: Bool
    private var handlers: [UInt32: () -> Void] = [:]
    private var registrations: [Registration] = []
    #if DEBUG
    /// How many times the registrations were rebuilt. Tests use it to check that saving
    /// unrelated preferences leaves the hotkeys alone.
    private(set) var unregisterAllCallCount = 0
    #endif
    private var hotKeys: [EventHotKeyRef] = []
    private var doubleTapMonitors: [DoubleTapModifierMonitor] = []
    private var eventHandler: EventHandlerRef?
    private var layoutObserver: NSObjectProtocol?

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
        if isEnabled {
            installHandler()
            // A shortcut names the character its key types, so the key to listen
            // for changes when the user switches, say, from U.S. to Dvorak.
            layoutObserver = NotificationCenter.default.addObserver(
                forName: KeyboardLayoutMap.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reregisterHotKeys()
            }
        }
    }

    deinit {
        unregisterAll()
        if let layoutObserver {
            NotificationCenter.default.removeObserver(layoutObserver)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ identifier: GlobalShortcutIdentifier, shortcut: String, handler: @escaping () -> Void) {
        // A modifier tapped twice, such as ⌘ ⌘, cannot be a Carbon hot key.
        if let modifier = DoubleTapModifier(shortcut: shortcut) {
            handlers[identifier.rawValue] = handler
            if isEnabled {
                doubleTapMonitors.append(DoubleTapModifierMonitor(modifier: modifier) {
                    DispatchQueue.main.async(execute: handler)
                })
            }
            return
        }

        // A modifier-less hotkey (e.g. a bare Return) is captured system-wide and
        // steals that key from every application, so it is never registered.
        guard KeyboardShortcutParser.hasModifiers(shortcut) else {
            if !shortcut.isEmpty {
                NSLog("ClipBook refused to register global shortcut without modifiers: \(shortcut)")
            }
            return
        }

        let registration = Registration(identifier: identifier, shortcut: shortcut)
        handlers[identifier.rawValue] = handler
        registrations.append(registration)
        if isEnabled {
            installHotKey(for: registration)
        }
    }

    #if DEBUG
    /// Whether a handler is stored for `identifier`. Lets tests see what
    /// `register` accepted without a hot key being registered.
    func hasHandler(for identifier: GlobalShortcutIdentifier) -> Bool {
        handlers[identifier.rawValue] != nil
    }
    #endif

    func unregisterAll() {
        #if DEBUG
        unregisterAllCallCount += 1
        #endif
        removeHotKeys()
        doubleTapMonitors.forEach { $0.invalidate() }
        doubleTapMonitors.removeAll()
        registrations.removeAll()
        handlers.removeAll()
    }

    private func reregisterHotKeys() {
        removeHotKeys()
        registrations.forEach(installHotKey)
    }

    private func removeHotKeys() {
        if isEnabled {
            hotKeys.forEach { UnregisterEventHotKey($0) }
        }
        hotKeys.removeAll()
    }

    private func installHotKey(for registration: Registration) {
        guard isEnabled, let parsed = KeyboardShortcutParser.parse(registration.shortcut) else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType("CLPB"), id: registration.identifier.rawValue)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(parsed.keyCode, parsed.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr, let hotKeyRef else {
            NSLog("ClipBook failed to register global shortcut \(registration.shortcut): \(status)")
            return
        }

        hotKeys.append(hotKeyRef)
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
