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

    /// The sidebar groups, in the style of System Settings. About is not part
    /// of them: it is the app row at the top of the sidebar.
    static var sidebarGroups: [[SettingsSection]] {
        [
            [.general, .history, .sounds],
            [.tags, .storage, .shortcuts],
            [.privacy, .importExport, .license],
        ]
        .map { group in group.filter { visibleSections.contains($0) } }
        .filter { !$0.isEmpty }
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

    /// A filled symbol, drawn in white on the section's colored tile.
    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .history: "clock.arrow.circlepath"
        case .sounds: "speaker.wave.2.fill"
        case .tags: "tag.fill"
        case .importExport: "square.and.arrow.down.fill"
        case .storage: "internaldrive.fill"
        case .shortcuts: "keyboard.fill"
        case .privacy: "hand.raised.fill"
        case .license: "checkmark.seal.fill"
        case .about: "info.circle.fill"
        }
    }

    /// The tile color, picked to match the closest pane in System Settings.
    var tileColor: Color {
        switch self {
        case .general: .gray
        case .history: .teal
        case .sounds: .pink
        case .tags: .orange
        case .importExport: .green
        case .storage: .indigo
        case .shortcuts: .gray
        case .privacy: .blue
        case .license: .purple
        case .about: .gray
        }
    }

    /// One sentence shown under the title in the pane header. About has no
    /// header; its summary is the version, shown under the app name in the
    /// sidebar.
    var summary: String {
        switch self {
        case .general: L10n.string("Choose how ClipBook starts, looks, and opens.")
        case .history: L10n.string("Choose what the history shows and what clicks and keys do with items.")
        case .sounds: L10n.string("Choose which actions play a sound.")
        case .tags: L10n.string("Create and edit tags to organize your clipboard items.")
        case .importExport: L10n.string("Back up your history and tags, or bring them from another Mac.")
        case .storage: L10n.string("Choose how long items stay in your history and in the Trash.")
        case .shortcuts: L10n.string("Set the keyboard shortcuts for the history window and its items.")
        case .privacy: L10n.string("Choose how sensitive content is handled and which apps ClipBook ignores.")
        case .license: L10n.string("Activate or manage your ClipBook license.")
        case .about: L10n.string("Version %@", Self.appVersion)
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? ReleaseConfiguration.marketingVersion
    }
}
