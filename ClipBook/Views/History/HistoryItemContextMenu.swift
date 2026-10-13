import AppKit
import UniformTypeIdentifiers

struct HistoryTagMenuSelection {
  let item: ClipboardItem
  let tag: Tag
}

struct HistoryTransformMenuSelection {
  let item: ClipboardItem
  let transform: ClipboardTextTransform
}

@MainActor
final class HistoryItemContextMenu {
  private weak var target: HistoryContentViewController?
  private let availableTags: [Tag]
  private let preferences: AppPreferences

  init(target: HistoryContentViewController, availableTags: [Tag], preferences: AppPreferences) {
    self.target = target
    self.availableTags = availableTags
    self.preferences = preferences
  }

  func makeMenu(for item: ClipboardItem) -> NSMenu {
    let menu = makeMenuForKind(of: item)
    addPasteAndDeleteItems(to: menu, for: item)
    addSensitiveContentItems(to: menu, for: item)
    addShowInHistoryItem(to: menu, for: item)
    menu.showsItemImagesRegardlessOfSystemSetting()
    return menu
  }

  private func makeMenuForKind(of item: ClipboardItem) -> NSMenu {
    switch item.kind {
    case .text:
      return makeTextMenu(for: item)
    case .richText:
      return makeTextMenu(for: item)
    case .link:
      return makeLinkMenu(for: item)
    case .email:
      return makeEmailMenu(for: item)
    case .color:
      return makeColorMenu(for: item)
    case .image:
      return makeImageMenu(for: item)
    case .file where item.isMissingSingleFileItem:
      return makeMissingFileMenu(for: item)
    case .file where item.isMultipleFileItem:
      return makeMultipleFilesMenu(for: item)
    case .file where item.firstFileIsImage:
      return makeImageFileMenu(for: item)
    case .file:
      return makeFileMenu(for: item)
    }
  }

  private func makeTextMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    if item.kind == .richText {
      addRichTextPasteAndCopyItems(to: menu, appName: appName, appIcon: appIcon)
    } else {
      // A plain text item has no formatting to strip, so the "as plain text"
      // variants would only duplicate the regular paste and copy actions.
      menu.addItem(makeMenuItem(
        title: L10n.string("Paste to %@", appName),
        action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
        image: appIcon,
        shortcut: preferences.pasteSelectedShortcut
      ))
      menu.addItem(makeMenuItem(
        title: "Copy to Clipboard",
        action: #selector(HistoryContentViewController.copyMenuItem(_:)),
        systemImageName: "square.on.square",
        shortcut: preferences.copySelectedShortcut
      ))
    }

    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Edit...",
      action: #selector(HistoryContentViewController.editMenuItem(_:)),
      systemImageName: "square.and.pencil",
      shortcut: preferences.editItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeTransformMenuItem(for: item, systemImageName: "wand.and.sparkles"))
    if target?.canSplit(item) == true {
      menu.addItem(makeMenuItem(
        title: L10n.string("Split"),
        action: #selector(HistoryContentViewController.splitMenuItem(_:)),
        systemImageName: "arrow.up.and.line.horizontal.and.arrow.down"
      ))
    }
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(for: item))
    menu.addItem(.separator())
    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  // Rich text can be pasted either with its formatting or as plain text, so
  // both variants are listed, the preferred one first and on the primary
  // shortcut.
  private func addRichTextPasteAndCopyItems(to menu: NSMenu, appName: String, appIcon: NSImage?) {
    let plainTextPasteItem = makeMenuItem(
      title: L10n.string("Paste as Plain Text to %@", appName),
      action: #selector(HistoryContentViewController.pastePlainTextMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.pasteSelectedShortcut
        : preferences.pasteSelectedSecondaryShortcut
    )
    let standardPasteItem = makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.pasteSelectedSecondaryShortcut
        : preferences.pasteSelectedShortcut
    )
    let pasteItems = preferences.preferPastingAsPlainText
      ? [plainTextPasteItem, standardPasteItem]
      : [standardPasteItem, plainTextPasteItem]
    pasteItems.forEach(menu.addItem)

    let plainTextCopyItem = makeMenuItem(
      title: L10n.string("Copy as Plain Text to Clipboard"),
      action: #selector(HistoryContentViewController.copyPlainTextMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.copySelectedShortcut
        : preferences.copySelectedSecondaryShortcut
    )
    let standardCopyItem = makeMenuItem(
      title: "Copy to Clipboard",
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.preferPastingAsPlainText
        ? preferences.copySelectedSecondaryShortcut
        : preferences.copySelectedShortcut
    )
    let copyItems = preferences.preferPastingAsPlainText
      ? [plainTextCopyItem, standardCopyItem]
      : [standardCopyItem, plainTextCopyItem]
    copyItems.forEach(menu.addItem)
  }

  private func makeLinkMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Open in Browser",
      action: #selector(HistoryContentViewController.openInBrowserMenuItem(_:)),
      systemImageName: "globe",
      shortcut: preferences.openInBrowserShortcut
    ))
    if preferences.showPreviewForLinks {
      menu.addItem(makeMenuItem(
        title: L10n.string("Update Link Preview"),
        action: #selector(HistoryContentViewController.updateLinkMenuItem(_:)),
        systemImageName: "arrow.clockwise"
      ))
    }
    menu.addItem(.separator())
    menu.addItem(makeMenuItem(
      title: "Edit...",
      action: #selector(HistoryContentViewController.editMenuItem(_:)),
      systemImageName: "square.and.pencil",
      shortcut: preferences.editItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeTransformMenuItem(for: item, systemImageName: "wand.and.sparkles"))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeEmailMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Edit...",
      action: #selector(HistoryContentViewController.editMenuItem(_:)),
      systemImageName: "square.and.pencil",
      shortcut: preferences.editItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeTransformMenuItem(for: item, systemImageName: "wand.and.sparkles"))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeColorMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Edit...",
      action: #selector(HistoryContentViewController.editMenuItem(_:)),
      systemImageName: "square.and.pencil",
      shortcut: preferences.editItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeTransformMenuItem(for: item, systemImageName: "wand.and.sparkles"))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeImageMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(.separator())

    if item.canCopyTextFromImage {
      menu.addItem(makeMenuItem(
        title: "Copy Text from Image",
        action: #selector(HistoryContentViewController.copyTextFromImageMenuItem(_:)),
        systemImageName: "text.viewfinder"
      ))
    }
    if item.canCopyTextFromQRCode {
      menu.addItem(makeMenuItem(
        title: "Copy Text from QR Code",
        action: #selector(HistoryContentViewController.copyTextFromQRCodeMenuItem(_:)),
        systemImageName: "qrcode.viewfinder"
      ))
    }
    menu.addItem(makeMenuItem(
      title: L10n.string("Save as File..."),
      action: #selector(HistoryContentViewController.saveImageAsFileMenuItem(_:)),
      systemImageName: "square.and.arrow.down"
    ))
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeOpenInAssociatedApplicationMenuItem(for: item))
    menu.addItem(makeMenuItem(
      title: "Open With...",
      action: #selector(HistoryContentViewController.openWithMenuItem(_:)),
      systemImageName: "square.and.arrow.up"
    ))
    menu.addItem(.separator())
    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeImageFileMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Paste Path to %@", appName),
      action: #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedSecondaryShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy Path to Clipboard"),
      action: #selector(HistoryContentViewController.copyFilePathMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedSecondaryShortcut
    ))
    menu.addItem(.separator())

    if item.canCopyTextFromImage {
      menu.addItem(makeMenuItem(
        title: L10n.string("Copy Text from Image"),
        action: #selector(HistoryContentViewController.copyTextFromImageMenuItem(_:)),
        systemImageName: "text.viewfinder"
      ))
    }
    if item.canCopyTextFromQRCode {
      menu.addItem(makeMenuItem(
        title: L10n.string("Copy Text from QR Code"),
        action: #selector(HistoryContentViewController.copyTextFromQRCodeMenuItem(_:)),
        systemImageName: "qrcode.viewfinder"
      ))
    }
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Show in Finder",
      action: #selector(HistoryContentViewController.showInFinderMenuItem(_:)),
      image: Self.applicationIcon(bundleIdentifier: "com.apple.finder", fallbackSystemImageName: "folder", title: "Show in Finder"),
      shortcut: preferences.showInFinderShortcut
    ))
    menu.addItem(makeOpenInAssociatedApplicationMenuItem(for: item))
    menu.addItem(makeMenuItem(
      title: "Open With...",
      action: #selector(HistoryContentViewController.openWithMenuItem(_:)),
      systemImageName: "square.and.arrow.up"
    ))
    menu.addItem(.separator())
    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeMultipleFilesMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste %d Items to %@", item.filePaths.count, appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy %d Items to Clipboard", item.filePaths.count),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeFileMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste to %@", appName),
      action: #selector(HistoryContentViewController.pasteMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Paste Path to %@", appName),
      action: #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedSecondaryShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy to Clipboard"),
      action: #selector(HistoryContentViewController.copyMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy Path to Clipboard"),
      action: #selector(HistoryContentViewController.copyFilePathMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedSecondaryShortcut
    ))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Show in Finder",
      action: #selector(HistoryContentViewController.showInFinderMenuItem(_:)),
      image: Self.applicationIcon(bundleIdentifier: "com.apple.finder", fallbackSystemImageName: "folder", title: "Show in Finder"),
      shortcut: preferences.showInFinderShortcut
    ))
    menu.addItem(makeOpenInAssociatedApplicationMenuItem(for: item))
    menu.addItem(makeMenuItem(
      title: "Open With...",
      action: #selector(HistoryContentViewController.openWithMenuItem(_:)),
      systemImageName: "square.and.arrow.up"
    ))
    menu.addItem(.separator())
    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  private func makeMissingFileMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()

    let targetApplication = Self.pasteTargetApplication()
    let appName = Self.pasteTargetApplicationName(for: targetApplication)
    let appIcon = Self.applicationIcon(for: targetApplication)

    menu.addItem(makeMenuItem(
      title: L10n.string("Paste Path to %@", appName),
      action: #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)),
      image: appIcon,
      shortcut: preferences.pasteSelectedSecondaryShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Copy Path to Clipboard"),
      action: #selector(HistoryContentViewController.copyFilePathMenuItem(_:)),
      systemImageName: "square.on.square",
      shortcut: preferences.copySelectedSecondaryShortcut
    ))
    menu.addItem(.separator())

    if item.canCopyTextFromImage {
      menu.addItem(makeMenuItem(
        title: L10n.string("Copy Text from Image"),
        action: #selector(HistoryContentViewController.copyTextFromImageMenuItem(_:)),
        systemImageName: "text.viewfinder"
      ))
    }
    if item.canCopyTextFromQRCode {
      menu.addItem(makeMenuItem(
        title: L10n.string("Copy Text from QR Code"),
        action: #selector(HistoryContentViewController.copyTextFromQRCodeMenuItem(_:)),
        systemImageName: "qrcode.viewfinder"
      ))
    }
    menu.addItem(makeMenuItem(
      title: item.isFavorite ? L10n.string("Remove from Favorites") : L10n.string("Add to Favorites"),
      action: #selector(HistoryContentViewController.favoriteMenuItem(_:)),
      systemImageName: "star",
      shortcut: preferences.toggleFavoriteShortcut
    ))
    menu.addItem(makeMenuItem(
      title: L10n.string("Rename..."),
      action: #selector(HistoryContentViewController.renameMenuItem(_:)),
      systemImageName: "rectangle.and.pencil.and.ellipsis",
      shortcut: preferences.renameItemShortcut
    ))
    menu.addItem(makeMenuItem(
      title: "Preview",
      action: #selector(HistoryContentViewController.previewMenuItem(_:)),
      systemImageName: "eye",
      shortcut: "space"
    ))
    menu.addItem(.separator())

    menu.addItem(makeTagsMenuItem(title: "Tags...", for: item))
    menu.addItem(.separator())

    menu.addItem(makeMenuItem(
      title: "Delete",
      action: #selector(HistoryContentViewController.deleteMenuItem(_:)),
      systemImageName: "trash",
      shortcut: preferences.deleteItemShortcut,
      isDestructive: true
    ))

    configure(menu, representedObject: item)

    return menu
  }

  /// Offered only while a search or a filter narrows the list, and placed
  /// right after "Preview", because both are ways of looking at the item.
  private func addShowInHistoryItem(to menu: NSMenu, for item: ClipboardItem) {
    guard target?.canShowInHistory == true else {
      return
    }

    let menuItem = makeMenuItem(
      title: "Show in History",
      action: #selector(HistoryContentViewController.showInHistoryMenuItem(_:)),
      systemImageName: "clock.arrow.circlepath",
      shortcut: preferences.showInHistoryShortcut
    )
    menuItem.target = target
    menuItem.representedObject = item

    let previewIndex = menu.items.firstIndex {
      $0.action == #selector(HistoryContentViewController.previewMenuItem(_:))
    }
    menu.insertItem(menuItem, at: previewIndex.map { $0 + 1 } ?? menu.numberOfItems)
  }

  // An item with content to hide can have it shown for now, or for good by saying it is
  // not sensitive. Any other item with text can be hidden by hand.
  private func addSensitiveContentItems(to menu: NSMenu, for item: ClipboardItem) {
    guard item.kind.canHoldSensitiveContent, let target else {
      return
    }

    var menuItems: [NSMenuItem] = []
    if target.isSensitiveContentMasked(in: item) {
      let hidesContent = target.hidesSensitiveContent(of: item)
      menuItems.append(makeMenuItem(
        title: hidesContent
          ? L10n.string("Show Sensitive Content")
          : L10n.string("Hide Sensitive Content"),
        action: #selector(HistoryContentViewController.sensitiveContentVisibilityMenuItem(_:)),
        systemImageName: hidesContent ? "eye" : "eye.slash",
        shortcut: preferences.toggleSensitiveContentShortcut
      ))
      menuItems.append(makeMenuItem(
        title: L10n.string("Mark as Not Sensitive"),
        action: #selector(HistoryContentViewController.sensitiveMenuItem(_:)),
        systemImageName: "lock.open"
      ))
    } else {
      menuItems.append(makeMenuItem(
        title: L10n.string("Mark as Sensitive"),
        action: #selector(HistoryContentViewController.sensitiveMenuItem(_:)),
        systemImageName: "lock"
      ))
    }

    let renameIndex = menu.items.firstIndex {
      $0.action == #selector(HistoryContentViewController.renameMenuItem(_:))
    }
    var index = renameIndex.map { $0 + 1 } ?? menu.numberOfItems
    for menuItem in menuItems {
      menuItem.target = target
      menuItem.representedObject = item
      menu.insertItem(menuItem, at: index)
      index += 1
    }
  }

  // Every paste item gets a paste-and-delete twin right after it.
  private func addPasteAndDeleteItems(to menu: NSMenu, for item: ClipboardItem) {
    guard target?.canPasteAndDelete(item) == true else {
      return
    }

    let appName = Self.pasteTargetApplicationName(for: Self.pasteTargetApplication())
    let pasteIndices = menu.items.indices.filter { index in
      menu.items[index].action.map { Self.pasteAndDeleteActions[$0] != nil } == true
    }
    for pasteIndex in pasteIndices.reversed() {
      let pasteItem = menu.items[pasteIndex]
      guard let pasteAction = pasteItem.action,
            let pasteAndDeleteAction = Self.pasteAndDeleteActions[pasteAction] else {
        continue
      }

      let menuItem = Self.makePasteAndDeleteMenuItem(
        title: pasteAndDeleteTitle(for: pasteAction, item: item, appName: appName),
        after: pasteItem,
        shortcut: pasteAndDeleteShortcut(for: pasteItem)
      )
      menuItem.action = pasteAndDeleteAction
      menuItem.target = target
      menuItem.representedObject = item
      menu.insertItem(menuItem, at: pasteIndex + 1)
    }
  }

  private static let pasteAndDeleteActions: [Selector: Selector] = [
    #selector(HistoryContentViewController.pasteMenuItem(_:)):
      #selector(HistoryContentViewController.pasteAndDeleteMenuItem(_:)),
    #selector(HistoryContentViewController.pastePlainTextMenuItem(_:)):
      #selector(HistoryContentViewController.pastePlainTextAndDeleteMenuItem(_:)),
    #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)):
      #selector(HistoryContentViewController.pasteFilePathAndDeleteMenuItem(_:))
  ]

  private func pasteAndDeleteTitle(for pasteAction: Selector, item: ClipboardItem, appName: String) -> String {
    switch pasteAction {
    case #selector(HistoryContentViewController.pastePlainTextMenuItem(_:)):
      return L10n.string("Paste as Plain Text to %@ & Delete", appName)
    case #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)):
      return L10n.string("Paste Path to %@ & Delete", appName)
    default:
      break
    }

    if item.isMultipleFileItem {
      return L10n.string("Paste %d Items to %@ & Delete", item.filePaths.count, appName)
    }
    return L10n.string("Paste to %@ & Delete", appName)
  }

  /// The twin of the item on the paste shortcut takes the paste-and-delete
  /// shortcut, and the twin of the item on the secondary paste shortcut takes
  /// the secondary one.
  private func pasteAndDeleteShortcut(for pasteItem: NSMenuItem) -> String? {
    if Self.menuItem(pasteItem, shows: preferences.pasteSelectedShortcut) {
      return preferences.pasteAndDeleteSelectedShortcut
    }
    if Self.menuItem(pasteItem, shows: preferences.pasteSelectedSecondaryShortcut) {
      return preferences.pasteAndDeleteSelectedSecondaryShortcut
    }
    return nil
  }

  private static func menuItem(_ menuItem: NSMenuItem, shows shortcut: String) -> Bool {
    let shortcutItem = NSMenuItem()
    applyShortcut(shortcut, to: shortcutItem)
    return !shortcutItem.keyEquivalent.isEmpty
      && shortcutItem.keyEquivalent == menuItem.keyEquivalent
      && shortcutItem.keyEquivalentModifierMask == menuItem.keyEquivalentModifierMask
  }

  /// Pasting and deleting is a variation of a paste item, so it appears in
  /// place of that item while Option is held, like the alternates in Finder's
  /// menus. AppKit only swaps items that share a key equivalent, so when the
  /// two shortcuts are on different keys the item is listed on its own instead.
  static func makePasteAndDeleteMenuItem(
    title: String,
    after pasteItem: NSMenuItem,
    shortcut: String?
  ) -> NSMenuItem {
    let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    applyShortcut(shortcut, to: menuItem)
    menuItem.image = pasteItem.image
    if menuItem.keyEquivalent.isEmpty, pasteItem.keyEquivalent.isEmpty {
      menuItem.keyEquivalentModifierMask = [.option]
      menuItem.isAlternate = pasteItem.keyEquivalentModifierMask != [.option]
    } else {
      menuItem.isAlternate = menuItem.keyEquivalent == pasteItem.keyEquivalent
        && menuItem.keyEquivalentModifierMask != pasteItem.keyEquivalentModifierMask
    }
    return menuItem
  }

  private func configure(_ menu: NSMenu, representedObject: Any) {
    for menuItem in menu.items where !menuItem.isSeparatorItem {
      menuItem.target = target
      menuItem.representedObject = representedObject
    }
  }

  private func makeMenuItem(
    title: String,
    action: Selector,
    systemImageName: String,
    shortcut: String? = nil,
    isDestructive: Bool = false
  ) -> NSMenuItem {
    let localizedTitle = L10n.string(forKey: title)
    return makeMenuItem(
      title: localizedTitle,
      action: action,
      image: NSImage(systemSymbolName: systemImageName, accessibilityDescription: localizedTitle),
      shortcut: shortcut,
      isDestructive: isDestructive
    )
  }

  private func makeMenuItem(
    title: String,
    action: Selector,
    image: NSImage?,
    shortcut: String? = nil,
    isDestructive: Bool = false
  ) -> NSMenuItem {
    let localizedTitle = L10n.string(forKey: title)
    let menuItem = NSMenuItem(title: localizedTitle, action: action, keyEquivalent: "")
    Self.applyShortcut(shortcut, to: menuItem)
    menuItem.image = isDestructive
      ? image?.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemRed)) ?? image
      : image
    if isDestructive {
      menuItem.attributedTitle = NSAttributedString(
        string: localizedTitle,
        attributes: [.foregroundColor: NSColor.systemRed]
      )
    }
    return menuItem
  }

  /// A menu item can only render a shortcut through a real key equivalent, so
  /// the stored preference is translated into one. A key with no usable
  /// single-character equivalent is left blank instead of drawn wrong.
  static func applyShortcut(_ shortcut: String?, to menuItem: NSMenuItem) {
    guard let shortcut else {
      return
    }

    // AppKit spells out a space key equivalent as a localized "Space" in the
    // shortcut column, which reads better than a symbol for it.
    if shortcut.lowercased() == "space" {
      menuItem.keyEquivalent = " "
      menuItem.keyEquivalentModifierMask = []
      return
    }

    guard let equivalent = KeyboardShortcutParser.menuItemKeyEquivalent(for: shortcut),
          equivalent.keyEquivalent.count == 1 else {
      return
    }

    menuItem.keyEquivalent = equivalent.keyEquivalent
    menuItem.keyEquivalentModifierMask = equivalent.modifierFlags
  }

  private func makeTagsMenuItem(title: String = "Tags", for item: ClipboardItem) -> NSMenuItem {
    let menuItem = NSMenuItem(title: L10n.string(forKey: title), action: nil, keyEquivalent: "")
    menuItem.image = NSImage(systemSymbolName: "circle", accessibilityDescription: L10n.string("Tags"))

    let submenu = NSMenu()
    for tag in availableTags {
      let tagItem = NSMenuItem(title: tag.name, action: #selector(HistoryContentViewController.toggleTagMenuItem(_:)), keyEquivalent: "")
      tagItem.target = target
      tagItem.image = NSImage.tagMenuIcon(color: NSColor(tagHexString: tag.color))
      tagItem.state = item.tags.contains(tag.id) ? .on : .off
      tagItem.representedObject = HistoryTagMenuSelection(item: item, tag: tag)
      submenu.addItem(tagItem)
    }

    if !availableTags.isEmpty {
      submenu.addItem(.separator())
    }

    let newTagItem = NSMenuItem(title: L10n.string("New Tag..."), action: #selector(HistoryContentViewController.newTagMenuItem(_:)), keyEquivalent: "")
    newTagItem.target = target
    newTagItem.image = NSImage(systemSymbolName: "plus", accessibilityDescription: L10n.string("New Tag"))
    newTagItem.representedObject = item
    submenu.addItem(newTagItem)
    submenu.addItem(.separator())

    let editTagsItem = NSMenuItem(title: L10n.string("Edit Tags..."), action: Selector(("editTagsMenuItem:")), keyEquivalent: "")
    editTagsItem.target = target
    editTagsItem.image = NSImage(systemSymbolName: "circle", accessibilityDescription: L10n.string("Edit Tags"))
    submenu.addItem(editTagsItem)

    menuItem.submenu = submenu
    return menuItem
  }

  private func makeTransformMenuItem(for item: ClipboardItem, systemImageName: String) -> NSMenuItem {
    let title = L10n.string("Transform")
    let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    menuItem.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: title)
    // The shortcut opens the transform command palette rather than this
    // submenu, but it reaches the same transforms, so it is worth surfacing.
    Self.applyShortcut(preferences.transformItemShortcut, to: menuItem)

    let submenu = NSMenu()
    for transform in ClipboardTextTransform.sortedCases {
      let transformItem = NSMenuItem(
        title: transform.title,
        action: #selector(HistoryContentViewController.applyTransformMenuItem(_:)),
        keyEquivalent: ""
      )
      transformItem.target = target
      transformItem.representedObject = HistoryTransformMenuSelection(item: item, transform: transform)
      submenu.addItem(transformItem)
    }

    menuItem.submenu = submenu
    return menuItem
  }

  private func makeOpenInAssociatedApplicationMenuItem(for item: ClipboardItem) -> NSMenuItem {
    let application = item.quickLookURL.flatMap {
      AssociatedApplication.forOpening($0, iconSize: NSSize(width: 16, height: 16))
    }
    let title = application.map { AssociatedApplication.openTitle(forName: $0.name) }
      ?? L10n.string("Open")

    return makeMenuItem(
      title: title,
      action: #selector(HistoryContentViewController.openInAssociatedApplicationMenuItem(_:)),
      image: application?.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: title)
    )
  }

  private static func pasteTargetApplicationName(for application: NSRunningApplication?) -> String {
    application?.localizedName ?? L10n.string("Active App")
  }

  private static func pasteTargetApplication() -> NSRunningApplication? {
    let clipBookBundleIdentifier = Bundle.main.bundleIdentifier
    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
       frontmostApplication.bundleIdentifier != clipBookBundleIdentifier {
      return frontmostApplication
    }

    return NSWorkspace.shared.runningApplications.first { application in
      application.bundleIdentifier != clipBookBundleIdentifier
        && application.activationPolicy == .regular
        && !application.isHidden
    }
  }

  private static func applicationIcon(for application: NSRunningApplication?) -> NSImage {
    let icon: NSImage
    if let bundleURL = application?.bundleURL {
      icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
    } else {
      icon = NSWorkspace.shared.icon(for: .application)
    }

    icon.size = NSSize(width: 16, height: 16)
    return icon
  }

  private static func applicationIcon(
    bundleIdentifier: String,
    fallbackSystemImageName: String,
    title: String
  ) -> NSImage? {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
      return NSImage(systemSymbolName: fallbackSystemImageName, accessibilityDescription: title)
    }

    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    icon.size = NSSize(width: 16, height: 16)
    return icon
  }
}

private extension ClipboardItem {
  var isMissingSingleFileItem: Bool {
    guard kind == .file,
          filePaths.count == 1,
          let filePath = filePaths.first else {
      return false
    }

    return !FileManager.default.fileExists(atPath: filePath)
  }
}

private extension NSColor {
  convenience init?(tagHexString: String) {
    let hex = tagHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let value = Int(hex, radix: 16) else {
      return nil
    }

    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}

private extension NSImage {
  static func tagMenuIcon(color: NSColor?) -> NSImage? {
    guard let color else {
      return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: L10n.string("Tag"))
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
    return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: L10n.string("Tag"))?
      .withSymbolConfiguration(configuration)
  }
}
