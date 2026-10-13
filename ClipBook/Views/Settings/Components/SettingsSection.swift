import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case history
    case sounds
    case tags
    case storage
    case shortcuts
    case privacy
    case importExport
    case license
    case about

    var id: String { rawValue }

    static var visibleSections: [SettingsSection] {
        #if CLIPBOOK_COMMERCIAL
        return allCases
        #else
        return allCases.filter { $0 != .license }
        #endif
    }

    var title: String {
        switch self {
        case .general: L10n.string("General")
        case .history: L10n.string("History")
        case .sounds: L10n.string("Sounds")
        case .tags: L10n.string("Tags")
        case .importExport: L10n.string("Import")
        case .storage: L10n.string("Storage")
        case .shortcuts: L10n.string("Shortcuts")
        case .privacy: L10n.string("Privacy")
        case .license: L10n.string("License")
        case .about: L10n.string("About")
        }
    }

    /// Caption shown in the window header, which can be more descriptive than
    /// the shorter sidebar label.
    var detailTitle: String {
        switch self {
        case .sounds: L10n.string("Sound Effects")
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .history: "clock.arrow.circlepath"
        case .sounds: "speaker.wave.2"
        case .tags: "circle"
        case .importExport: "square.and.arrow.down"
        case .storage: "internaldrive"
        case .shortcuts: "keyboard"
        case .privacy: "lock"
        case .license: "checkmark.seal"
        case .about: "info.circle"
        }
    }
}
