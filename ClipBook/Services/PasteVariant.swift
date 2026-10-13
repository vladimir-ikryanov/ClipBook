import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum PasteVariant {
    case standard
    case plainText
    case rich
    case filePath
    case pasteAndReturn
    case pasteAndTab
}

/// The key ClipBook presses between two items when several items are pasted at
/// once. It is a key press and not a piece of text, so the target app decides
/// what it means: Return can start a new line or send a message.
enum PasteInterItemAction: String, CaseIterable, Identifiable {
    case none
    case returnKey
    case shiftReturn
    case keyUp
    case keyDown
    case tab
    case space
    case commaSpace

    static let defaultAction = PasteInterItemAction.shiftReturn

    var id: String { rawValue }

    init(preferenceValue: String) {
        self = PasteInterItemAction(rawValue: preferenceValue) ?? Self.defaultAction
    }

    var title: String {
        switch self {
        case .none:
            return L10n.string("Nothing")
        case .returnKey:
            return L10n.string("Return")
        case .shiftReturn:
            return L10n.string("Shift+Return")
        case .keyUp:
            return L10n.string("Up Arrow")
        case .keyDown:
            return L10n.string("Down Arrow")
        case .tab:
            return L10n.string("Tab")
        case .space:
            return L10n.string("Space")
        case .commaSpace:
            return L10n.string("Comma + Space")
        }
    }

    var systemImageName: String {
        switch self {
        case .none:
            return "nosign"
        case .returnKey:
            return "return"
        case .shiftReturn:
            return "shift"
        case .keyUp:
            return "arrow.up"
        case .keyDown:
            return "arrow.down"
        case .tab:
            return "arrow.right.to.line"
        case .space:
            return "space"
        case .commaSpace:
            return "textformat"
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .none:
            return nil
        case .returnKey, .shiftReturn:
            return 36
        case .keyUp:
            return 126
        case .keyDown:
            return 125
        case .tab:
            return 48
        case .space:
            return 49
        case .commaSpace:
            return nil
        }
    }

    /// Text typed between items instead of a key press.
    var text: String? {
        switch self {
        case .commaSpace:
            return ", "
        default:
            return nil
        }
    }

    var flags: CGEventFlags {
        switch self {
        case .shiftReturn:
            return .maskShift
        default:
            return []
        }
    }
}
