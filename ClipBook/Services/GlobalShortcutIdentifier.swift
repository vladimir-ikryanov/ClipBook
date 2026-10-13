import SwiftUI
import AppKit
import Carbon
import Combine

enum GlobalShortcutIdentifier: UInt32 {
    case showHistory = 1
    case pauseCapture = 2
    case pasteNext = 3
    case pasteNextRich = 4
    case pasteNextAndDelete = 5
    case pasteNextRichAndDelete = 6
}
