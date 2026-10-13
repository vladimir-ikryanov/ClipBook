import AppKit
import SwiftUI

struct ShortcutRow: View {
    let title: String
    @Binding var text: String
    let defaultText: String
    var locked = false
    /// Global shortcuts are captured system-wide, so they must include a
    /// modifier key: a bare key would be stolen from every application.
    var requiresModifiers = false
    /// Returns the title of the action already using the given shortcut, or
    /// `nil` when the shortcut is free to assign.
    var conflictingActionTitle: (String) -> String? = { _ in nil }
    /// Called when the recorder starts or stops waiting for a combination.
    var onRecordingChanged: (Bool) -> Void = { _ in }

    @State private var conflictMessage: String?
    @State private var conflictMessageID = 0

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutRecorder(
                shortcut: $text,
                defaultShortcut: defaultText,
                isDisabled: locked,
                hasConflict: conflictMessage != nil,
                commit: commit,
                onRecordingStarted: { conflictMessage = nil },
                onRecordingChanged: onRecordingChanged
            )
            .popover(isPresented: showsConflictPopover, arrowEdge: .bottom) {
                conflictPopover
            }
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var conflictPopover: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(conflictMessage ?? "")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 260, alignment: .leading)
    }

    private var showsConflictPopover: Binding<Bool> {
        Binding(
            get: { conflictMessage != nil },
            set: { isPresented in
                if !isPresented {
                    conflictMessage = nil
                }
            }
        )
    }

    /// Assigns `newShortcut` unless another action already uses it or it lacks
    /// a required modifier. Returns whether the shortcut was assigned.
    private func commit(_ newShortcut: String) -> Bool {
        if requiresModifiers, !newShortcut.isEmpty, !KeyboardShortcutParser.hasModifiers(newShortcut) {
            showConflictMessage(L10n.string("Global shortcuts need a modifier key (⌘, ⌥, ⌃ or ⇧)"))
            return false
        }

        guard let conflict = conflictingActionTitle(newShortcut) else {
            text = newShortcut
            conflictMessage = nil
            return true
        }

        showConflictMessage(
            L10n.string(
                "%@ is already used by \"%@\"",
                ShortcutFormatter.displayText(for: newShortcut),
                conflict
            )
        )
        return false
    }

    private func showConflictMessage(_ message: String) {
        conflictMessageID += 1
        let messageID = conflictMessageID
        conflictMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if conflictMessageID == messageID {
                conflictMessage = nil
            }
        }
    }
}

private struct ShortcutRecorder: View {
    @Binding var shortcut: String
    let defaultShortcut: String
    let isDisabled: Bool
    let hasConflict: Bool
    /// Assigns the shortcut, returning whether it was accepted.
    let commit: (String) -> Bool
    let onRecordingStarted: () -> Void
    let onRecordingChanged: (Bool) -> Void

    @State private var isHovered = false
    @State private var isRecording = false
    @State private var draft: ShortcutDraft?

    private var displayText: String {
        if isRecording {
            return draft?.displayText ?? L10n.string("Recording...")
        }

        return ShortcutFormatter.displayText(for: shortcut)
    }

    private var isDefaultShortcut: Bool {
        if shortcut == defaultShortcut {
            return true
        }

        // Treat spellings of the same key combination as equal, e.g.
        // "cmd+shift+c" and "shift+cmd+c".
        guard let parsed = KeyboardShortcutParser.parse(shortcut) else {
            return false
        }

        return parsed == KeyboardShortcutParser.parse(defaultShortcut)
    }

    private var showsCancelButton: Bool {
        isRecording && !isDisabled
    }

    private var showsClearButton: Bool {
        isHovered && !shortcut.isEmpty && !isDisabled && !isRecording
    }

    private var showsRevertButton: Bool {
        !isDefaultShortcut && !isDisabled && !isRecording
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(displayText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(shortcut.isEmpty || isRecording ? .secondary : .primary)
                .lineLimit(1)
                // Keeps placeholders such as "Recording..." readable next to the
                // cancel button instead of truncating them.
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

            if showsCancelButton {
                recorderButton(systemName: "xmark.circle.fill", accessibilityLabel: L10n.string("Cancel recording")) {
                    stopRecording()
                }
            }

            if showsClearButton {
                recorderButton(systemName: "xmark.circle.fill", accessibilityLabel: L10n.string("Clear shortcut")) {
                    _ = commit("")
                    stopRecording()
                }
            }

            if showsRevertButton {
                recorderButton(systemName: "arrow.uturn.backward.circle.fill", accessibilityLabel: L10n.string("Revert shortcut")) {
                    if commit(defaultShortcut) {
                        stopRecording()
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(width: 120, height: 30)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        .overlay {
            Capsule()
                .stroke(strokeColor, lineWidth: 1)
        }
        .contentShape(Capsule())
        .onTapGesture {
            guard !isDisabled else {
                return
            }
            isRecording = true
            draft = nil
            onRecordingStarted()
        }
        .onHover { isHovered = $0 }
        .onChange(of: isRecording) { onRecordingChanged($0) }
        .opacity(isDisabled ? 0.55 : 1)
        .background(
            ShortcutEventReader(isRecording: $isRecording, draft: $draft, onCancel: stopRecording) { recordedShortcut in
                _ = commit(recordedShortcut)
                stopRecording()
            }
        )
    }

    private func recorderButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var strokeColor: Color {
        if hasConflict {
            return .red
        }

        return isRecording ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.35)
    }

    private func stopRecording() {
        isRecording = false
        draft = nil
    }
}

private struct ShortcutEventReader: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var draft: ShortcutDraft?
    let onCancel: () -> Void
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> ShortcutEventView {
        let view = ShortcutEventView()
        view.onDraftChange = { draft = $0 }
        view.onCancel = onCancel
        view.onCommit = onCommit
        return view
    }

    func updateNSView(_ nsView: ShortcutEventView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onDraftChange = { draft = $0 }
        nsView.onCancel = onCancel
        nsView.onCommit = onCommit

        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ShortcutEventView: NSView {
    var isRecording = false
    var onDraftChange: ((ShortcutDraft?) -> Void)?
    var onCancel: (() -> Void)?
    var onCommit: ((String) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        guard let window else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    override func resignFirstResponder() -> Bool {
        finishRecordingFromFocusLoss()
        return true
    }

    /// Key equivalents are offered to the view hierarchy before the main menu,
    /// so recording a combination such as ⌘C captures it instead of running the
    /// Edit menu's Copy command.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }

        return record(event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording, record(event) else {
            super.keyDown(with: event)
            return
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let modifiers = event.shortcutModifierTokens
        onDraftChange?(modifiers.isEmpty ? nil : ShortcutDraft(modifiers: modifiers, key: nil))
    }

    /// Commits the combination as soon as its key is pressed. Waiting for the
    /// keys to be released would never finish for combinations that hold down
    /// Command, because macOS does not deliver key up events while it is held.
    private func record(_ event: NSEvent) -> Bool {
        guard !event.isARepeat, let key = ShortcutFormatter.keyToken(for: event.keyCode) else {
            return false
        }

        let draft = ShortcutDraft(modifiers: event.shortcutModifierTokens, key: key)
        onDraftChange?(draft)
        onCommit?(draft.storageText)
        return true
    }

    @objc private func windowDidResignKey() {
        finishRecordingFromFocusLoss()
    }

    private func finishRecordingFromFocusLoss() {
        guard isRecording else {
            return
        }

        isRecording = false
        onDraftChange?(nil)
        onCancel?()
    }
}

private struct ShortcutDraft {
    let modifiers: [ShortcutModifier]
    let key: String?

    var displayText: String {
        let modifierText = modifiers.map(\.displayText).joined()
        guard let key else {
            return modifierText
        }

        return modifierText + ShortcutFormatter.keyDisplayText(for: key)
    }

    var storageText: String {
        (modifiers.map(\.storageText) + [key].compactMap { $0 }).joined(separator: "+")
    }
}

private enum ShortcutModifier: CaseIterable {
    case command
    case shift
    case option
    case control

    var storageText: String {
        switch self {
        case .command:
            return "cmd"
        case .shift:
            return "shift"
        case .option:
            return "option"
        case .control:
            return "control"
        }
    }

    var storageAliases: [String] {
        switch self {
        case .command:
            return ["cmd", "command"]
        case .shift:
            return ["shift"]
        case .option:
            return ["option", "alt"]
        case .control:
            return ["control", "ctrl"]
        }
    }

    var displayText: String {
        switch self {
        case .command:
            return "⌘"
        case .shift:
            return "⇧"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        }
    }
}

private enum ShortcutFormatter {
    static func displayText(for shortcut: String) -> String {
        guard !shortcut.isEmpty else {
            return L10n.string("Not set")
        }

        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last else {
            return L10n.string("Not set")
        }

        // Preserve the modifier order of the stored string, so shortcuts like
        // "shift+cmd+c" display as ⇧⌘C rather than a fixed modifier order.
        let modifiers = parts.dropLast().compactMap { part in
            ShortcutModifier.allCases.first { $0.storageAliases.contains(part) }
        }
        let modifierText = modifiers.map(\.displayText).joined()
        return modifierText + keyDisplayText(for: key)
    }

    static func keyDisplayText(for key: String) -> String {
        KeyboardShortcutParser.keyDisplayText(for: key)
    }

    static func keyToken(for keyCode: UInt16) -> String? {
        KeyboardShortcutParser.keyToken(for: keyCode)
    }
}

private extension NSEvent {
    var shortcutModifierTokens: [ShortcutModifier] {
        modifierFlags.shortcutModifierTokens
    }
}

private extension NSEvent.ModifierFlags {
    var shortcutModifierTokens: [ShortcutModifier] {
        let activeFlags = intersection([.command, .shift, .option, .control])
        return ShortcutModifier.allCases.filter { modifier in
            switch modifier {
            case .command:
                return activeFlags.contains(.command)
            case .shift:
                return activeFlags.contains(.shift)
            case .option:
                return activeFlags.contains(.option)
            case .control:
                return activeFlags.contains(.control)
            }
        }
    }
}
