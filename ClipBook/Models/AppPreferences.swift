import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

enum HistoryItemActionPreference: String, Codable, CaseIterable, Identifiable {
    case paste
    case copy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paste: L10n.string("Paste")
        case .copy: L10n.string("Copy")
        }
    }

    init(preferenceValue: String) {
        switch preferenceValue {
        case Self.paste.rawValue, "Paste":
            self = .paste
        case Self.copy.rawValue, "Copy":
            self = .copy
        default:
            self = .paste
        }
    }
}

enum HistoryItemClickActionPreference: String, Codable, CaseIterable, Identifiable {
    case select
    case paste
    case copy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: L10n.string("Select")
        case .paste: L10n.string("Paste")
        case .copy: L10n.string("Copy")
        }
    }

    init(preferenceValue: String) {
        self = Self(rawValue: preferenceValue) ?? .select
    }
}

enum CopyAndMergeSeparatorPreference: String, Codable, CaseIterable, Identifiable {
    case newLine
    case space
    case comma
    case empty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newLine: L10n.string("New line")
        case .space: L10n.string("Space")
        case .comma: L10n.string("Comma")
        case .empty: L10n.string("Empty")
        }
    }

    init(preferenceValue: String) {
        switch preferenceValue {
        case Self.newLine.rawValue, "New line":
            self = .newLine
        case Self.space.rawValue, "Space":
            self = .space
        case Self.comma.rawValue, "Comma":
            self = .comma
        case Self.empty.rawValue, "Empty":
            self = .empty
        default:
            self = .newLine
        }
    }
}

struct AppPreferences: Codable, Equatable {
    static let defaultShowHistoryShortcut = "shift+cmd+v"
    static let defaultPauseShortcut = "shift+cmd+p"
    static let defaultPasteNextShortcut = "control+v"
    static let defaultPasteNextRichShortcut = "shift+control+v"
    static let defaultPasteNextAndDeleteShortcut = "option+control+v"
    static let defaultPasteNextRichAndDeleteShortcut = "shift+option+control+v"
    static let defaultCloseHistoryShortcut = "escape"
    static let defaultCloseHistorySecondaryShortcut = "cmd+w"
    // Matches the shortcut that shows the history, so that the same
    // combination opens and closes the window.
    static let defaultCloseHistoryTertiaryShortcut = defaultShowHistoryShortcut
    static let defaultSelectNextItemShortcut = "down"
    static let defaultSelectPreviousItemShortcut = "up"
    static let defaultPasteSelectedShortcut = "return"
    static let defaultPasteSelectedSecondaryShortcut = "shift+return"
    static let defaultPasteAndDeleteSelectedShortcut = "option+return"
    static let defaultPasteAndDeleteSelectedSecondaryShortcut = "shift+option+return"
    static let defaultCopySelectedShortcut = "cmd+c"
    static let defaultCopySelectedSecondaryShortcut = "shift+cmd+c"
    static let defaultDeleteItemShortcut = "cmd+delete"
    static let defaultToggleFavoriteShortcut = "cmd+s"
    static let defaultShowInFinderShortcut = "cmd+o"
    static let defaultOpenInBrowserShortcut = "cmd+b"
    static let defaultEditItemShortcut = "cmd+e"
    static let defaultRenameItemShortcut = "cmd+r"
    static let defaultTransformItemShortcut = "cmd+t"
    static let defaultFocusSearchFieldShortcut = "cmd+f"
    static let defaultOpenSettingsShortcut = "cmd+,"
    static let defaultShowCommandPaletteShortcut = "cmd+k"
    static let defaultShowInHistoryShortcut = "cmd+l"
    static let defaultTogglePreviewPaneShortcut = "cmd+p"
    static let defaultToggleDetailsShortcut = "cmd+i"
    static let defaultToggleSensitiveContentShortcut = "cmd+u"
    // The filter panel used to own Cmd+F, which now focuses the search field.
    // The copy sequence mode used to be one of the "Sort By" options.
    private static let legacyCopySequenceSortOption = "Copy Sequence"
    // The single-click action used to be a toggle that could only paste.
    private enum LegacyCodingKeys: String, CodingKey {
        case pasteOnClick
    }
    static let defaultHistoryWindowWidth: Double = 620
    static let defaultHistoryWindowHeight: Double = 700
    static let defaultSettingsWindowWidth: Double = 680
    static let defaultSettingsWindowHeight: Double = 720
    static let defaultTrashRetentionDays = 30
    static let trashRetentionDayOptions = [0, 1, 7, 30, 90]

    var appearance: AppAppearance = .system
    var language = "en"
    var launchAtLogin = true
    var showMainWindowAtStartup = false
    var checkForUpdatesAutomatically = true
    var soundEffectsEnabled = true
    var playSoundOnCopy = true
    var playSoundOnPaste = true
    var playSoundOnDelete = true
    var playSoundOnSelectionAdd = true
    var playSoundOnSelectionRemove = true
    var showMenuBarIcon = true
    var openHistoryOnMenuBarIconClick = true
    var hideOnFocusLoss = true
    var openWindowStrategy = "activeScreenCenter"
    var historyWindowX: Double?
    var historyWindowY: Double?
    var historyWindowWidth: Double?
    var historyWindowHeight: Double?
    var settingsWindowX: Double?
    var settingsWindowY: Double?
    var settingsWindowWidth: Double?
    var settingsWindowHeight: Double?
    var historySortOption = HistorySortOption.lastCopyTime.rawValue
    var isHistorySortReversed = false
    var copySequenceModeEnabled = false
    var pinFavoritesToTop = true
    var singleClickAction = HistoryItemClickActionPreference.select.rawValue
    // A remembered selection only helps while items stay in place, so it can't
    // be on together with moving items to the top after an action.
    var updateHistoryAfterAction = true {
        didSet {
            if updateHistoryAfterAction {
                rememberHistorySelection = false
            }
        }
    }
    var rememberHistorySelection = false {
        didSet {
            if rememberHistorySelection {
                updateHistoryAfterAction = false
            }
        }
    }
    var copyAndMergeEnabled = false
    var copyToClipboardAfterMerge = true
    var copyAndMergeSeparator = CopyAndMergeSeparatorPreference.newLine.rawValue
    /// The key pressed between items when several items are pasted at once.
    var multiPasteKey = PasteInterItemAction.defaultAction.rawValue
    var showPreviewForLinks = true
    var showCommandNumberShortcut = true
    var showHistoryDividers = false
    var showPreviewPane = true
    var showPreviewPaneDetails = true
    /// Shows the history as tiles while it is filtered to images only, so the
    /// pictures are big enough to tell apart.
    var showImagesAsTiles = true
    /// The height of the preview pane at the bottom of the history window,
    /// and the share of the window width it takes on the right. Nil until
    /// the user resizes the pane.
    var previewPaneHeight: Double?
    var previewPaneWidthRatio: Double?
    var treatDigitNumbersAsColor = true
    var preferPastingAsPlainText = true
    var doubleClickAction = HistoryItemActionPreference.paste.rawValue
    var numberKeyAction = HistoryItemActionPreference.paste.rawValue
    var ignoreTransientContent = true
    var ignoreConcealedContent = true
    var detectSensitiveContent = true
    var ignoreSensitiveContent = false
    var showDuringScreenSharing = false
    var ignoredAppsText = ""
    var textRetentionDays = Self.unlimitedRetentionDays
    var richTextRetentionDays = Self.unlimitedRetentionDays
    var imageRetentionDays = Self.unlimitedRetentionDays
    var fileRetentionDays = Self.unlimitedRetentionDays
    var linkRetentionDays = Self.unlimitedRetentionDays
    var emailRetentionDays = Self.unlimitedRetentionDays
    var colorRetentionDays = Self.unlimitedRetentionDays
    var keepFavoritesOnClearHistory = true
    /// How many days deleted items stay in the Trash. Zero turns the Trash
    /// off, and deleting an item then deletes it for good.
    var trashRetentionDays = Self.defaultTrashRetentionDays
    var warnOnClearHistory = true
    var clearHistoryOnQuit = false
    var clearHistoryOnReboot = false
    var showHistoryShortcut = Self.defaultShowHistoryShortcut
    var pauseShortcut = Self.defaultPauseShortcut
    var pasteNextShortcut = Self.defaultPasteNextShortcut
    var pasteNextRichShortcut = Self.defaultPasteNextRichShortcut
    var pasteNextAndDeleteShortcut = Self.defaultPasteNextAndDeleteShortcut
    var pasteNextRichAndDeleteShortcut = Self.defaultPasteNextRichAndDeleteShortcut
    var closeHistoryShortcut = Self.defaultCloseHistoryShortcut
    var closeHistorySecondaryShortcut = Self.defaultCloseHistorySecondaryShortcut
    var closeHistoryTertiaryShortcut = Self.defaultCloseHistoryTertiaryShortcut
    var selectNextItemShortcut = Self.defaultSelectNextItemShortcut
    var selectPreviousItemShortcut = Self.defaultSelectPreviousItemShortcut
    var pasteSelectedShortcut = Self.defaultPasteSelectedShortcut
    var pasteSelectedSecondaryShortcut = Self.defaultPasteSelectedSecondaryShortcut
    var pasteAndDeleteSelectedShortcut = Self.defaultPasteAndDeleteSelectedShortcut
    var pasteAndDeleteSelectedSecondaryShortcut = Self.defaultPasteAndDeleteSelectedSecondaryShortcut
    var copySelectedShortcut = Self.defaultCopySelectedShortcut
    var copySelectedSecondaryShortcut = Self.defaultCopySelectedSecondaryShortcut
    var deleteItemShortcut = Self.defaultDeleteItemShortcut
    var toggleFavoriteShortcut = Self.defaultToggleFavoriteShortcut
    var showInFinderShortcut = Self.defaultShowInFinderShortcut
    var openInBrowserShortcut = Self.defaultOpenInBrowserShortcut
    var editItemShortcut = Self.defaultEditItemShortcut
    var renameItemShortcut = Self.defaultRenameItemShortcut
    var transformItemShortcut = Self.defaultTransformItemShortcut
    var focusSearchFieldShortcut = Self.defaultFocusSearchFieldShortcut
    var openSettingsShortcut = Self.defaultOpenSettingsShortcut
    var showCommandPaletteShortcut = Self.defaultShowCommandPaletteShortcut
    var showInHistoryShortcut = Self.defaultShowInHistoryShortcut
    var togglePreviewPaneShortcut = Self.defaultTogglePreviewPaneShortcut
    var toggleDetailsShortcut = Self.defaultToggleDetailsShortcut
    var toggleSensitiveContentShortcut = Self.defaultToggleSensitiveContentShortcut
    var licenseKey = ""
    var hasMigratedV1LicenseKey = false
    var hasCompletedOnboarding = false
    var hasProvidedTrialExpiredFeedback = false
    /// When the history was first opened after the trial ended, which is when
    /// the trial-ended dialog was shown.
    var trialExpiredAt: Date?
    /// When the discount that follows the trial was offered. The offer lasts a
    /// limited time from then.
    var trialDiscountOfferedAt: Date?
    /// The days left in the trial when its notice was closed. The notice comes
    /// back once fewer days are left.
    var dismissedTrialNoticeDaysLeft: Int?

    init() {}

    /// Global shortcuts are registered system-wide, so a stored combination
    /// without a modifier (for example a bare Return recorded by mistake) would
    /// steal that key from every application. Such a value falls back to the
    /// default; an empty value keeps the shortcut disabled.
    static func sanitizedGlobalShortcut(_ shortcut: String?, default defaultShortcut: String) -> String {
        guard let shortcut else {
            return defaultShortcut
        }
        if shortcut.isEmpty || KeyboardShortcutParser.hasModifiers(shortcut) {
            return shortcut
        }

        return defaultShortcut
    }

    init(from decoder: Decoder) throws {
        let defaults = AppPreferences()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? defaults.appearance
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? defaults.language
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showMainWindowAtStartup = try container.decodeIfPresent(Bool.self, forKey: .showMainWindowAtStartup) ?? defaults.showMainWindowAtStartup
        checkForUpdatesAutomatically = try container.decodeIfPresent(Bool.self, forKey: .checkForUpdatesAutomatically) ?? defaults.checkForUpdatesAutomatically
        soundEffectsEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEffectsEnabled) ?? defaults.soundEffectsEnabled
        playSoundOnCopy = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnCopy) ?? defaults.playSoundOnCopy
        playSoundOnPaste = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnPaste) ?? defaults.playSoundOnPaste
        playSoundOnDelete = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnDelete) ?? defaults.playSoundOnDelete
        playSoundOnSelectionAdd = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnSelectionAdd) ?? defaults.playSoundOnSelectionAdd
        playSoundOnSelectionRemove = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnSelectionRemove) ?? defaults.playSoundOnSelectionRemove
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? defaults.showMenuBarIcon
        openHistoryOnMenuBarIconClick = try container.decodeIfPresent(Bool.self, forKey: .openHistoryOnMenuBarIconClick) ?? defaults.openHistoryOnMenuBarIconClick
        hideOnFocusLoss = try container.decodeIfPresent(Bool.self, forKey: .hideOnFocusLoss) ?? defaults.hideOnFocusLoss
        openWindowStrategy = HistoryWindowOpenStrategy(
            preferenceValue: try container.decodeIfPresent(String.self, forKey: .openWindowStrategy) ?? defaults.openWindowStrategy
        ).rawValue
        historyWindowX = try container.decodeIfPresent(Double.self, forKey: .historyWindowX) ?? defaults.historyWindowX
        historyWindowY = try container.decodeIfPresent(Double.self, forKey: .historyWindowY) ?? defaults.historyWindowY
        historyWindowWidth = try container.decodeIfPresent(Double.self, forKey: .historyWindowWidth) ?? defaults.historyWindowWidth
        historyWindowHeight = try container.decodeIfPresent(Double.self, forKey: .historyWindowHeight) ?? defaults.historyWindowHeight
        settingsWindowX = try container.decodeIfPresent(Double.self, forKey: .settingsWindowX) ?? defaults.settingsWindowX
        settingsWindowY = try container.decodeIfPresent(Double.self, forKey: .settingsWindowY) ?? defaults.settingsWindowY
        settingsWindowWidth = try container.decodeIfPresent(Double.self, forKey: .settingsWindowWidth) ?? defaults.settingsWindowWidth
        settingsWindowHeight = try container.decodeIfPresent(Double.self, forKey: .settingsWindowHeight) ?? defaults.settingsWindowHeight
        let storedHistorySortOption = try container.decodeIfPresent(String.self, forKey: .historySortOption)
            ?? defaults.historySortOption
        historySortOption = HistorySortOption(preferenceValue: storedHistorySortOption).rawValue
        isHistorySortReversed = try container.decodeIfPresent(Bool.self, forKey: .isHistorySortReversed) ?? defaults.isHistorySortReversed
        copySequenceModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .copySequenceModeEnabled)
            ?? (storedHistorySortOption == Self.legacyCopySequenceSortOption)
        pinFavoritesToTop = try container.decodeIfPresent(Bool.self, forKey: .pinFavoritesToTop) ?? defaults.pinFavoritesToTop
        if let storedSingleClickAction = try container.decodeIfPresent(String.self, forKey: .singleClickAction) {
            singleClickAction = HistoryItemClickActionPreference(preferenceValue: storedSingleClickAction).rawValue
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let pasteOnClick = try legacyContainer.decodeIfPresent(Bool.self, forKey: .pasteOnClick) ?? false
            singleClickAction = pasteOnClick ? HistoryItemClickActionPreference.paste.rawValue : defaults.singleClickAction
        }
        updateHistoryAfterAction = try container.decodeIfPresent(Bool.self, forKey: .updateHistoryAfterAction) ?? defaults.updateHistoryAfterAction
        // Property observers don't run while decoding, so a stored pair with both
        // settings on is resolved here, in favor of moving items to the top.
        let storedRememberHistorySelection = try container.decodeIfPresent(Bool.self, forKey: .rememberHistorySelection)
            ?? defaults.rememberHistorySelection
        rememberHistorySelection = storedRememberHistorySelection && !updateHistoryAfterAction
        copyAndMergeEnabled = try container.decodeIfPresent(Bool.self, forKey: .copyAndMergeEnabled) ?? defaults.copyAndMergeEnabled
        copyToClipboardAfterMerge = try container.decodeIfPresent(Bool.self, forKey: .copyToClipboardAfterMerge) ?? defaults.copyToClipboardAfterMerge
        copyAndMergeSeparator = CopyAndMergeSeparatorPreference(
            preferenceValue: try container.decodeIfPresent(String.self, forKey: .copyAndMergeSeparator) ?? defaults.copyAndMergeSeparator
        ).rawValue
        multiPasteKey = PasteInterItemAction(
            preferenceValue: try container.decodeIfPresent(String.self, forKey: .multiPasteKey) ?? defaults.multiPasteKey
        ).rawValue
        showPreviewForLinks = try container.decodeIfPresent(Bool.self, forKey: .showPreviewForLinks) ?? defaults.showPreviewForLinks
        showCommandNumberShortcut = try container.decodeIfPresent(Bool.self, forKey: .showCommandNumberShortcut) ?? defaults.showCommandNumberShortcut
        showHistoryDividers = try container.decodeIfPresent(Bool.self, forKey: .showHistoryDividers) ?? defaults.showHistoryDividers
        showPreviewPane = try container.decodeIfPresent(Bool.self, forKey: .showPreviewPane) ?? defaults.showPreviewPane
        showPreviewPaneDetails = try container.decodeIfPresent(Bool.self, forKey: .showPreviewPaneDetails) ?? defaults.showPreviewPaneDetails
        showImagesAsTiles = try container.decodeIfPresent(Bool.self, forKey: .showImagesAsTiles) ?? defaults.showImagesAsTiles
        previewPaneHeight = try container.decodeIfPresent(Double.self, forKey: .previewPaneHeight)
        previewPaneWidthRatio = try container.decodeIfPresent(Double.self, forKey: .previewPaneWidthRatio)
        treatDigitNumbersAsColor = try container.decodeIfPresent(Bool.self, forKey: .treatDigitNumbersAsColor) ?? defaults.treatDigitNumbersAsColor
        preferPastingAsPlainText = try container.decodeIfPresent(Bool.self, forKey: .preferPastingAsPlainText) ?? defaults.preferPastingAsPlainText
        doubleClickAction = HistoryItemActionPreference(
            preferenceValue: try container.decodeIfPresent(String.self, forKey: .doubleClickAction) ?? defaults.doubleClickAction
        ).rawValue
        numberKeyAction = HistoryItemActionPreference(
            preferenceValue: try container.decodeIfPresent(String.self, forKey: .numberKeyAction) ?? defaults.numberKeyAction
        ).rawValue
        ignoreTransientContent = try container.decodeIfPresent(Bool.self, forKey: .ignoreTransientContent) ?? defaults.ignoreTransientContent
        ignoreConcealedContent = try container.decodeIfPresent(Bool.self, forKey: .ignoreConcealedContent) ?? defaults.ignoreConcealedContent
        detectSensitiveContent = try container.decodeIfPresent(Bool.self, forKey: .detectSensitiveContent) ?? defaults.detectSensitiveContent
        ignoreSensitiveContent = try container.decodeIfPresent(Bool.self, forKey: .ignoreSensitiveContent) ?? defaults.ignoreSensitiveContent
        showDuringScreenSharing = try container.decodeIfPresent(Bool.self, forKey: .showDuringScreenSharing) ?? defaults.showDuringScreenSharing
        ignoredAppsText = try container.decodeIfPresent(String.self, forKey: .ignoredAppsText) ?? defaults.ignoredAppsText
        textRetentionDays = try container.decodeIfPresent(Int.self, forKey: .textRetentionDays) ?? defaults.textRetentionDays
        // Rich text used to share the Texts period, so a preferences file
        // written before it had a slider of its own keeps that behaviour.
        richTextRetentionDays = try container.decodeIfPresent(Int.self, forKey: .richTextRetentionDays) ?? textRetentionDays
        imageRetentionDays = try container.decodeIfPresent(Int.self, forKey: .imageRetentionDays) ?? defaults.imageRetentionDays
        fileRetentionDays = try container.decodeIfPresent(Int.self, forKey: .fileRetentionDays) ?? defaults.fileRetentionDays
        linkRetentionDays = try container.decodeIfPresent(Int.self, forKey: .linkRetentionDays) ?? defaults.linkRetentionDays
        emailRetentionDays = try container.decodeIfPresent(Int.self, forKey: .emailRetentionDays) ?? defaults.emailRetentionDays
        colorRetentionDays = try container.decodeIfPresent(Int.self, forKey: .colorRetentionDays) ?? defaults.colorRetentionDays
        keepFavoritesOnClearHistory = try container.decodeIfPresent(Bool.self, forKey: .keepFavoritesOnClearHistory) ?? defaults.keepFavoritesOnClearHistory
        trashRetentionDays = try container.decodeIfPresent(Int.self, forKey: .trashRetentionDays) ?? defaults.trashRetentionDays
        warnOnClearHistory = try container.decodeIfPresent(Bool.self, forKey: .warnOnClearHistory) ?? defaults.warnOnClearHistory
        clearHistoryOnQuit = try container.decodeIfPresent(Bool.self, forKey: .clearHistoryOnQuit) ?? defaults.clearHistoryOnQuit
        clearHistoryOnReboot = try container.decodeIfPresent(Bool.self, forKey: .clearHistoryOnReboot) ?? defaults.clearHistoryOnReboot
        showHistoryShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .showHistoryShortcut),
            default: defaults.showHistoryShortcut
        )
        pauseShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .pauseShortcut),
            default: defaults.pauseShortcut
        )
        pasteNextShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .pasteNextShortcut),
            default: defaults.pasteNextShortcut
        )
        pasteNextRichShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .pasteNextRichShortcut),
            default: defaults.pasteNextRichShortcut
        )
        pasteNextAndDeleteShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .pasteNextAndDeleteShortcut),
            default: defaults.pasteNextAndDeleteShortcut
        )
        pasteNextRichAndDeleteShortcut = Self.sanitizedGlobalShortcut(
            try container.decodeIfPresent(String.self, forKey: .pasteNextRichAndDeleteShortcut),
            default: defaults.pasteNextRichAndDeleteShortcut
        )
        closeHistoryShortcut = try container.decodeIfPresent(String.self, forKey: .closeHistoryShortcut) ?? defaults.closeHistoryShortcut
        closeHistorySecondaryShortcut = try container.decodeIfPresent(String.self, forKey: .closeHistorySecondaryShortcut) ?? defaults.closeHistorySecondaryShortcut
        closeHistoryTertiaryShortcut = try container.decodeIfPresent(String.self, forKey: .closeHistoryTertiaryShortcut) ?? defaults.closeHistoryTertiaryShortcut
        selectNextItemShortcut = try container.decodeIfPresent(String.self, forKey: .selectNextItemShortcut) ?? defaults.selectNextItemShortcut
        selectPreviousItemShortcut = try container.decodeIfPresent(String.self, forKey: .selectPreviousItemShortcut) ?? defaults.selectPreviousItemShortcut
        pasteSelectedShortcut = try container.decodeIfPresent(String.self, forKey: .pasteSelectedShortcut) ?? defaults.pasteSelectedShortcut
        pasteSelectedSecondaryShortcut = try container.decodeIfPresent(String.self, forKey: .pasteSelectedSecondaryShortcut) ?? defaults.pasteSelectedSecondaryShortcut
        pasteAndDeleteSelectedShortcut = try container.decodeIfPresent(String.self, forKey: .pasteAndDeleteSelectedShortcut) ?? defaults.pasteAndDeleteSelectedShortcut
        pasteAndDeleteSelectedSecondaryShortcut = try container.decodeIfPresent(String.self, forKey: .pasteAndDeleteSelectedSecondaryShortcut) ?? defaults.pasteAndDeleteSelectedSecondaryShortcut
        copySelectedShortcut = try container.decodeIfPresent(String.self, forKey: .copySelectedShortcut) ?? defaults.copySelectedShortcut
        copySelectedSecondaryShortcut = try container.decodeIfPresent(String.self, forKey: .copySelectedSecondaryShortcut) ?? defaults.copySelectedSecondaryShortcut
        deleteItemShortcut = try container.decodeIfPresent(String.self, forKey: .deleteItemShortcut) ?? defaults.deleteItemShortcut
        toggleFavoriteShortcut = try container.decodeIfPresent(String.self, forKey: .toggleFavoriteShortcut) ?? defaults.toggleFavoriteShortcut
        showInFinderShortcut = try container.decodeIfPresent(String.self, forKey: .showInFinderShortcut) ?? defaults.showInFinderShortcut
        openInBrowserShortcut = try container.decodeIfPresent(String.self, forKey: .openInBrowserShortcut) ?? defaults.openInBrowserShortcut
        editItemShortcut = try container.decodeIfPresent(String.self, forKey: .editItemShortcut) ?? defaults.editItemShortcut
        renameItemShortcut = try container.decodeIfPresent(String.self, forKey: .renameItemShortcut) ?? defaults.renameItemShortcut
        transformItemShortcut = try container.decodeIfPresent(String.self, forKey: .transformItemShortcut) ?? defaults.transformItemShortcut
        focusSearchFieldShortcut = try container.decodeIfPresent(String.self, forKey: .focusSearchFieldShortcut) ?? defaults.focusSearchFieldShortcut
        openSettingsShortcut = try container.decodeIfPresent(String.self, forKey: .openSettingsShortcut) ?? defaults.openSettingsShortcut
        showCommandPaletteShortcut = try container.decodeIfPresent(String.self, forKey: .showCommandPaletteShortcut) ?? defaults.showCommandPaletteShortcut
        showInHistoryShortcut = try container.decodeIfPresent(String.self, forKey: .showInHistoryShortcut) ?? defaults.showInHistoryShortcut
        togglePreviewPaneShortcut = try container.decodeIfPresent(String.self, forKey: .togglePreviewPaneShortcut) ?? defaults.togglePreviewPaneShortcut
        toggleDetailsShortcut = try container.decodeIfPresent(String.self, forKey: .toggleDetailsShortcut) ?? defaults.toggleDetailsShortcut
        toggleSensitiveContentShortcut = try container.decodeIfPresent(String.self, forKey: .toggleSensitiveContentShortcut) ?? defaults.toggleSensitiveContentShortcut
        licenseKey = try container.decodeIfPresent(String.self, forKey: .licenseKey) ?? defaults.licenseKey
        hasMigratedV1LicenseKey = try container.decodeIfPresent(Bool.self, forKey: .hasMigratedV1LicenseKey) ?? defaults.hasMigratedV1LicenseKey
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        hasProvidedTrialExpiredFeedback = try container.decodeIfPresent(Bool.self, forKey: .hasProvidedTrialExpiredFeedback) ?? defaults.hasProvidedTrialExpiredFeedback
        trialExpiredAt = try container.decodeIfPresent(Date.self, forKey: .trialExpiredAt)
        trialDiscountOfferedAt = try container.decodeIfPresent(Date.self, forKey: .trialDiscountOfferedAt)
        dismissedTrialNoticeDaysLeft = try container.decodeIfPresent(Int.self, forKey: .dismissedTrialNoticeDaysLeft)
    }

    var closeHistoryShortcuts: [String] {
        [closeHistoryShortcut, closeHistorySecondaryShortcut, closeHistoryTertiaryShortcut]
    }

    /// The shortcut that shows the history is global, so the history window
    /// never receives its key event. When it is also assigned to closing the
    /// window, the global shortcut has to do the closing itself.
    var showHistoryShortcutClosesHistory: Bool {
        closeHistoryShortcuts.contains { ShortcutConflicts.isSameShortcut($0, showHistoryShortcut) }
    }

    /// Copy sequence mode relies on the original copy order, so items are never
    /// moved to the top while it is on.
    var updatesHistoryAfterAction: Bool {
        updateHistoryAfterAction && !copySequenceModeEnabled
    }

    /// Whether deleted items go to the Trash rather than being deleted for good.
    var isTrashEnabled: Bool {
        trashRetentionDays > 0
    }

    func isSoundEffectEnabled(_ effect: SoundEffect) -> Bool {
        soundEffectsEnabled && self[keyPath: effect.preferenceKeyPath]
    }

    var ignoredApplicationEntries: [String] {
        ignoredAppsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var ignoredApps: Set<String> {
        Set(ignoredApplicationEntries.filter { !$0.isApplicationBundlePath })
    }

    func isApplicationIgnored(_ application: NSRunningApplication) -> Bool {
        Self.isApplicationIgnored(
            bundlePath: application.bundleURL?.standardizedFileURL.path,
            localizedName: application.localizedName,
            entries: ignoredApplicationEntries
        )
    }

    /// The check itself, on plain values, so the pasteboard reader can make
    /// it off the main thread.
    nonisolated static func isApplicationIgnored(bundlePath: String?, localizedName: String?, entries: [String]) -> Bool {
        for entry in entries {
            if entry.isApplicationBundlePath {
                if bundlePath == URL(fileURLWithPath: entry).standardizedFileURL.path {
                    return true
                }
            } else if entry == localizedName {
                return true
            }
        }

        return false
    }

    var historyWindowSize: NSSize {
        NSSize(
            width: historyWindowWidth ?? Self.defaultHistoryWindowWidth,
            height: historyWindowHeight ?? Self.defaultHistoryWindowHeight
        )
    }

    var historyWindowOrigin: NSPoint? {
        guard let historyWindowX,
              let historyWindowY else {
            return nil
        }

        return NSPoint(x: historyWindowX, y: historyWindowY)
    }

    var settingsWindowFrame: NSRect? {
        guard let settingsWindowX,
              let settingsWindowY,
              let settingsWindowWidth,
              let settingsWindowHeight else {
            return nil
        }

        return NSRect(
            x: settingsWindowX,
            y: settingsWindowY,
            width: max(settingsWindowWidth, 400),
            height: max(settingsWindowHeight, 400)
        )
    }
}

private extension String {
    nonisolated var isApplicationBundlePath: Bool {
        hasPrefix("/") && hasSuffix(".app")
    }
}
