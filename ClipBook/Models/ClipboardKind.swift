import Foundation
import AppKit
import Carbon
import Combine
import SQLite3

enum ClipboardKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case text
    case richText
    case link
    case email
    case color
    case image
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: L10n.string("Text")
        case .richText: L10n.string("Rich Text")
        case .link: L10n.string("Link")
        case .email: L10n.string("Email")
        case .color: L10n.string("Color")
        case .image: L10n.string("Image")
        case .file: L10n.string("File")
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.page"
        case .richText: "richtext.page"
        case .link: "link"
        case .email: "envelope"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "document"
        }
    }

    var isEditableText: Bool {
        switch self {
        case .text, .richText, .link, .email, .color:
            return true
        case .image, .file:
            return false
        }
    }

    var canEditTextContent: Bool {
        isEditableText
    }

    static func classifyText(_ text: String, treatDigitNumbersAsColor: Bool) -> ClipboardKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ColorText(trimmed, allowsBareHex: treatDigitNumbersAsColor) != nil {
            return .color
        }
        if trimmed.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil {
            return .email
        }
        if ClipboardItem.linkURL(from: trimmed) != nil {
            return .link
        }
        return .text
    }

}
