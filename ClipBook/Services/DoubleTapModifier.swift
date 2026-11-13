import AppKit
import Carbon

/// A shortcut made of one modifier key pressed twice in quick succession, such
/// as ⌘ ⌘. It is stored as the modifier written twice, e.g. "cmd+cmd".
enum DoubleTapModifier: CaseIterable {
    case command
    case option
    case control
    case shift

    /// Reads a stored shortcut, accepting every spelling of the modifier that
    /// key combinations accept, e.g. "command+command" or "alt+alt".
    init?(shortcut: String) {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard parts.count == 2,
              let first = Self.allCases.first(where: { $0.storageAliases.contains(parts[0]) }),
              first.storageAliases.contains(parts[1]) else {
            return nil
        }

        self = first
    }

    /// The modifier whose left or right key has the given virtual key code.
    init?(keyCode: UInt16) {
        guard let modifier = Self.allCases.first(where: { $0.sides.contains { $0.keyCode == keyCode } }) else {
            return nil
        }

        self = modifier
    }

    var storageText: String {
        let token = storageAliases[0]
        return token + "+" + token
    }

    var displayText: String {
        symbol + " " + symbol
    }

    var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        case .shift:
            return "⇧"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .option:
            return .option
        case .control:
            return .control
        case .shift:
            return .shift
        }
    }

    private var storageAliases: [String] {
        switch self {
        case .command:
            return ["cmd", "command"]
        case .option:
            return ["option", "alt"]
        case .control:
            return ["control", "ctrl"]
        case .shift:
            return ["shift"]
        }
    }

    /// The left and right keys of the modifier, with the device-dependent bit
    /// (from IOKit's NX_DEVICE*KEYMASK) that is set while that key is down.
    fileprivate var sides: [(keyCode: UInt16, deviceMask: UInt)] {
        switch self {
        case .command:
            return [(55, 0x08), (54, 0x10)]
        case .option:
            return [(58, 0x20), (61, 0x40)]
        case .control:
            return [(59, 0x01), (62, 0x2000)]
        case .shift:
            return [(56, 0x02), (60, 0x04)]
        }
    }

    fileprivate static let allDeviceMasks: UInt = allCases
        .flatMap(\.sides)
        .reduce(0) { $0 | $1.deviceMask }
}

/// Recognizes a modifier key tapped twice: pressed and released on its own,
/// then pressed and released again shortly after. Any other key, modifier or
/// click in between cancels it, so holding ⌘ for ⌘C and then pressing ⌘V
/// quickly never reads as a double tap.
struct DoubleTapModifierDetector {
    /// How long each tap may hold the key down. A longer press is the start of
    /// a combination or a hesitation, not a tap.
    static let maximumTapDuration: TimeInterval = 0.3
    /// How long after the first tap is released the second one must start.
    static let maximumIntervalBetweenTaps: TimeInterval = 0.4

    private enum State {
        case idle
        case firstTapDown(keyCode: UInt16, time: TimeInterval)
        case firstTapUp(keyCode: UInt16, time: TimeInterval)
        case secondTapDown(keyCode: UInt16, time: TimeInterval)
    }

    private var state = State.idle

    /// Feeds a flagsChanged event. Returns the modifier when this event
    /// releases the second tap. Both taps must use the same key, so tapping the
    /// left ⌘ and then the right one does not count.
    mutating func handleFlagsChanged(_ event: NSEvent) -> DoubleTapModifier? {
        handleFlagsChanged(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            timestamp: event.timestamp
        )
    }

    mutating func handleFlagsChanged(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        timestamp: TimeInterval
    ) -> DoubleTapModifier? {
        guard let modifier = DoubleTapModifier(keyCode: keyCode),
              let side = modifier.sides.first(where: { $0.keyCode == keyCode }) else {
            // Caps Lock, Fn and other keys that report as modifier changes.
            reset()
            return nil
        }

        let heldFlags = modifierFlags.intersection([.command, .option, .control, .shift, .function])
        let heldKeys = modifierFlags.rawValue & DoubleTapModifier.allDeviceMasks
        let isKeyDown = heldKeys & side.deviceMask != 0

        if isKeyDown {
            // The key must be the only modifier held, so ⌘ pressed while ⇧ is
            // down, or both ⌘ keys at once, is not a tap.
            guard heldFlags == modifier.flag, heldKeys == side.deviceMask else {
                reset()
                return nil
            }

            if case let .firstTapUp(firstKeyCode, releasedAt) = state,
               firstKeyCode == keyCode,
               timestamp - releasedAt <= Self.maximumIntervalBetweenTaps {
                state = .secondTapDown(keyCode: keyCode, time: timestamp)
            } else {
                state = .firstTapDown(keyCode: keyCode, time: timestamp)
            }
            return nil
        }

        // The key was released. Anything else still held means the user is in
        // the middle of some other combination.
        guard heldFlags.isEmpty, heldKeys == 0 else {
            reset()
            return nil
        }

        switch state {
        case let .firstTapDown(downKeyCode, pressedAt)
            where downKeyCode == keyCode && timestamp - pressedAt <= Self.maximumTapDuration:
            state = .firstTapUp(keyCode: keyCode, time: timestamp)
            return nil
        case let .secondTapDown(downKeyCode, pressedAt)
            where downKeyCode == keyCode && timestamp - pressedAt <= Self.maximumTapDuration:
            reset()
            return modifier
        default:
            reset()
            return nil
        }
    }

    /// Cancels a tap in progress. Called for every key press or click.
    mutating func reset() {
        state = .idle
    }
}

/// Watches the keyboard of every app for a modifier key tapped twice.
///
/// Carbon hot keys cannot express a modifier on its own, so this monitors
/// modifier changes instead. macOS delivers key events of other apps only to
/// apps trusted for Accessibility; until ClipBook is, the monitor sees just the
/// keys pressed in ClipBook's own windows, and it starts watching other apps as
/// soon as the permission is granted.
final class DoubleTapModifierMonitor {
    private static let eventMask: NSEvent.EventTypeMask = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown
    ]

    private let modifier: DoubleTapModifier
    private let handler: () -> Void
    private var detector = DoubleTapModifierDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var permissionTimer: Timer?

    init(modifier: DoubleTapModifier, handler: @escaping () -> Void) {
        self.modifier = modifier
        self.handler = handler

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.eventMask) { [weak self] event in
            self?.handle(event)
            return event
        }
        installGlobalMonitor()

        if !AccessibilityPermission.isTrusted {
            waitForAccessibilityPermission()
        }
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        removeGlobalMonitor()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func installGlobalMonitor() {
        removeGlobalMonitor()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.eventMask) { [weak self] event in
            self?.handle(event)
        }
    }

    private func removeGlobalMonitor() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    /// A monitor added before the permission was granted may never receive key
    /// events, so it is added again once ClipBook is trusted.
    private func waitForAccessibilityPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AccessibilityPermission.isTrusted else {
                return
            }

            timer.invalidate()
            self?.permissionTimer = nil
            self?.installGlobalMonitor()
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            detector.reset()
            return
        }

        // While a password field or a terminal with Secure Keyboard Entry has
        // focus, macOS hides key presses from other apps but still reports
        // modifier changes, so ⌘A followed by ⌘V would look like a double tap.
        guard !IsSecureEventInputEnabled() else {
            detector.reset()
            return
        }

        guard detector.handleFlagsChanged(event) == modifier else {
            return
        }

        handler()
    }
}
