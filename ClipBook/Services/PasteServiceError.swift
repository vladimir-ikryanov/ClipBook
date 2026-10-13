import Foundation
import AppKit
import UniformTypeIdentifiers

enum PasteServiceError: LocalizedError {
    case accessibilityPermissionRequired
    case unsupportedItem

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired: "Accessibility permission is required to paste into other apps."
        case .unsupportedItem: "This clipboard item cannot be copied or pasted."
        }
    }
}
