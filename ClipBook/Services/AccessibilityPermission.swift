import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// The Accessibility list in System Settings.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}
