import AppKit

@MainActor
protocol ItemPreviewToolbarDelegate: AnyObject {
  func itemPreviewToolbarDidRequestClose(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestToggleFavorite(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestToggleSensitiveContentVisibility(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestEdit(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbar(_ toolbar: ItemPreviewToolbar, didSelectSVGMarkup showsMarkup: Bool)
  func itemPreviewToolbarDidRequestSave(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestRestore(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestCopyTextFromImage(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestCopyTextFromQRCode(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestSaveAsFile(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestOpenInApplication(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarDidRequestShowInFinder(_ toolbar: ItemPreviewToolbar)
  func itemPreviewToolbarMoreActionsMenu(_ toolbar: ItemPreviewToolbar) -> NSMenu?
  func itemPreviewToolbarTagsMenu(_ toolbar: ItemPreviewToolbar) -> NSMenu?
}

// Unified toolbar of the item preview sheet. The leading close button is always
// present, while the trailing actions depend on the kind of the previewed item.
// While the item is being edited, the toolbar only offers Restore and Save.
// The close button stays enabled and closing is routed through the same
// confirmation as Escape.
@MainActor
final class ItemPreviewToolbar: NSObject, NSToolbarDelegate, NSMenuDelegate {
  static let height: CGFloat = 52

  private static let toolbarIdentifier = NSToolbar.Identifier("ItemPreviewToolbar")
  private static let favoriteIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarFavorite")
  private static let sensitiveContentIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarSensitiveContent")
  private static let tagsIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarTags")
  private static let svgPresentationIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarSVGPresentation")
  private static let moreActionsIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarMoreActions")
  private static let editIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarEdit")
  private static let restoreIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarRestore")
  private static let copyTextFromImageIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarCopyTextFromImage")
  private static let copyTextFromQRCodeIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarCopyTextFromQRCode")
  private static let saveAsFileIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarSaveAsFile")
  private static let openInApplicationIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarOpenInApplication")
  private static let showInFinderIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarShowInFinder")
  private static let saveIdentifier = NSToolbarItem.Identifier("ItemPreviewToolbarSave")

  weak var delegate: ItemPreviewToolbarDelegate?

  private static let closeButtonTrailingInset: CGFloat = 8
  private static let titleLeadingSpacing: CGFloat = 12
  private static let titleValueSpacing: CGFloat = 1
  // Reserved so a file name of up to this many characters is shown in full;
  // longer names, and the path underneath, are truncated.
  private static let maximumTitleCharacters = 50
  private static let maximumTitleWidth: CGFloat = {
    let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    let sample = String(repeating: "n", count: maximumTitleCharacters) as NSString
    return ceil(sample.size(withAttributes: [.font: font]).width)
  }()

  // The room the close button and the spacing around it take from the title bar.
  private static var accessoryFixedWidth: CGFloat {
    let inset = (height - ItemPreviewCloseButton.buttonSize) / 2
    return inset + ItemPreviewCloseButton.buttonSize + titleLeadingSpacing + closeButtonTrailingInset
  }

  // The width the title bar needs next to the labels: the close button, the
  // spacing around it and the widest toolbar the preview shows.
  static var minimumTitleBarWidth: CGFloat {
    accessoryFixedWidth + maximumTitleWidth + toolbarItemsWidth
  }

  // Called when the dialog is laid out, so a resize re-measures how much of
  // the name fits next to the toolbar.
  func refreshAccessoryLayout() {
    updateAccessoryWidth()
  }

  // Rough widths the title bar needs for its items, used to work out how much
  // room is left for the name of the item.
  private static let borderedItemWidth: CGFloat = 44
  private static let menuItemWidth: CGFloat = 55
  private static let segmentedItemWidth: CGFloat = 84
  private static let labelledItemWidth: CGFloat = 160
  private static let itemSpacing: CGFloat = 8
  private static let toolbarTrailingInset: CGFloat = 40
  // The widest toolbar the preview shows, reserved when a dialog is sized.
  private static let toolbarItemsWidth: CGFloat = 440
  // Below this the name is not worth showing at all.
  private static let minimumTitleWidth: CGFloat = 120

  private var item: ClipboardItem
  private var sensitiveContent: SensitiveContentPresentation
  private(set) var isEditing = false
  private weak var toolbar: NSToolbar?
  private weak var closeButton: NSButton?
  private weak var accessoryContainerView: NSView?
  private weak var titleStack: NSStackView?
  private var titleWidthConstraint: NSLayoutConstraint?
  private weak var titleField: NSTextField?
  private weak var subtitleField: NSTextField?
  private static let applicationIconSize = NSSize(width: 16, height: 16)

  private lazy var favoriteItem = makeFavoriteItem()
  private lazy var sensitiveContentItem = makeSensitiveContentItem()
  private lazy var copyTextFromImageItem = makeCopyTextFromImageItem()
  private lazy var copyTextFromQRCodeItem = makeCopyTextFromQRCodeItem()
  private lazy var saveAsFileItem = makeSaveAsFileItem()
  private lazy var openInApplicationItem = makeOpenInApplicationItem()
  private lazy var showInFinderItem = makeShowInFinderItem()
  private lazy var tagsItem = makeTagsItem()
  private lazy var svgPresentationItem = makeSVGPresentationItem()
  private weak var tagsMenu: NSMenu?
  // A read-only history (after the trial) keeps the actions that organize the
  // item, and drops the ones that edit it or hand it to another application.
  private static let readOnlyActionIdentifiers: Set<NSToolbarItem.Identifier> = [favoriteIdentifier, tagsIdentifier]
  private let isReadOnly: Bool

  private lazy var moreActionsItem = makeMoreActionsItem()
  private lazy var editItem = makeEditItem()
  private lazy var restoreItem = makeRestoreItem()
  private lazy var saveItem = makeSaveItem()

  init(item: ClipboardItem, sensitiveContent: SensitiveContentPresentation, isReadOnly: Bool = false) {
    self.item = item
    self.sensitiveContent = sensitiveContent
    self.isReadOnly = isReadOnly
    super.init()
  }

  func makeToolbar() -> NSToolbar {
    let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    if #available(macOS 15.0, *) {
      toolbar.allowsDisplayModeCustomization = false
    }
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconOnly
    toolbar.sizeMode = .regular
    self.toolbar = toolbar
    return toolbar
  }

  // The close button is a title bar accessory rather than a toolbar item,
  // because a toolbar centers custom views inside a standard-width slot and
  // therefore cannot place the button at the same offset it has from the top
  // and the bottom edge of the title bar. The item names itself next to it:
  // a single file with its name and path, everything else with its type.
  func makeCloseAccessory() -> NSTitlebarAccessoryViewController {
    let closeButton = ItemPreviewCloseButton(target: self, action: #selector(close))
    let label = L10n.string("Close")
    closeButton.toolTip = label
    closeButton.setAccessibilityLabel(label)
    self.closeButton = closeButton

    // The same styling the details bar uses for a field and its value.
    let titleField = NSTextField(labelWithString: "")
    titleField.font = .systemFont(ofSize: 12, weight: .semibold)
    titleField.textColor = .labelColor
    titleField.lineBreakMode = .byTruncatingTail
    self.titleField = titleField

    let subtitleField = NSTextField(labelWithString: "")
    subtitleField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    subtitleField.textColor = .secondaryLabelColor
    subtitleField.lineBreakMode = .byTruncatingMiddle
    self.subtitleField = subtitleField

    let titleStack = NSStackView(views: [titleField, subtitleField])
    titleStack.orientation = .vertical
    titleStack.distribution = .fill
    titleStack.alignment = .leading
    titleStack.spacing = Self.titleValueSpacing
    titleStack.translatesAutoresizingMaskIntoConstraints = false
    self.titleStack = titleStack

    // The button keeps the same distance from the leading, the top and the
    // bottom edge of the title bar.
    let inset = (Self.height - ItemPreviewCloseButton.buttonSize) / 2
    let containerView = NSView(frame: NSRect(x: 0, y: 0, width: Self.height, height: Self.height))
    containerView.addSubview(closeButton)
    containerView.addSubview(titleStack)
    NSLayoutConstraint.activate([
      closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: inset),
      closeButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      titleStack.leadingAnchor.constraint(
        equalTo: closeButton.trailingAnchor,
        constant: Self.titleLeadingSpacing
      ),
      titleStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
    ])
    let titleWidthConstraint = titleStack.widthAnchor.constraint(
      lessThanOrEqualToConstant: Self.maximumTitleWidth
    )
    titleWidthConstraint.isActive = true
    self.titleWidthConstraint = titleWidthConstraint
    accessoryContainerView = containerView
    updateTitleLabels()

    let accessory = NSTitlebarAccessoryViewController()
    accessory.layoutAttribute = .leading
    accessory.view = containerView
    return accessory
  }

  func update(item: ClipboardItem, sensitiveContent: SensitiveContentPresentation) {
    self.item = item
    self.sensitiveContent = sensitiveContent
    updateFavoriteItem()
    updateSensitiveContentItem()
    updateOpenInApplicationItem()
    updateTitleLabels()
    synchronizeItems()
  }

  // A single file is named by its file name and path; a list of files by how
  // many it holds, and every other kind by its type.
  private func updateTitleLabels() {
    guard let titleStack, let titleField, let subtitleField else {
      return
    }

    if item.kind == .file, let filePath = item.filePaths.first, !item.isMultipleFileItem {
      let fileURL = URL(fileURLWithPath: filePath)
      titleField.lineBreakMode = .byTruncatingTail
      titleField.stringValue = fileURL.lastPathComponent
      titleField.toolTip = filePath
      subtitleField.stringValue = fileURL.deletingLastPathComponent().path
      subtitleField.toolTip = filePath
      subtitleField.isHidden = false
      titleStack.isHidden = false
    } else if let browserURL = item.browserURL {
      // The address says more about a link than its type does. It is truncated
      // in the middle so the host and the end of the path both stay readable.
      // An address with hidden content is named by its type, like any other text.
      let showsAddress = !sensitiveContent.hidesContent
      titleField.lineBreakMode = .byTruncatingMiddle
      titleField.stringValue = showsAddress
        ? browserURL.absoluteString
        : ItemPreviewDetailsView.typeName(for: item)
      titleField.toolTip = showsAddress ? browserURL.absoluteString : nil
      subtitleField.isHidden = true
      titleStack.isHidden = false
    } else {
      titleField.lineBreakMode = .byTruncatingTail
      titleField.stringValue = item.isMultipleFileItem
        ? L10n.string("Files: %d items", item.filePaths.count)
        : ItemPreviewDetailsView.typeName(for: item)
      titleField.toolTip = nil
      subtitleField.isHidden = true
      titleStack.isHidden = false
    }

    updateAccessoryWidth()
  }

  // The title bar takes the width of the accessory from the frame of its view,
  // so it has to follow the name it shows, and give way to the toolbar items
  // when the dialog is too narrow for both.
  private func updateAccessoryWidth() {
    guard let containerView = accessoryContainerView else {
      return
    }

    let fixedWidth = Self.accessoryFixedWidth - Self.titleLeadingSpacing
    guard let titleStack, !titleStack.isHidden else {
      containerView.frame.size.width = ceil(fixedWidth)
      return
    }

    var availableWidth = Self.maximumTitleWidth
    if let windowWidth = containerView.window?.contentLayoutRect.width, windowWidth > 0 {
      availableWidth = windowWidth - Self.accessoryFixedWidth - estimatedToolbarWidth
    }
    let titleWidth = min(
      naturalTitleWidth(of: titleStack),
      Self.maximumTitleWidth,
      max(Self.minimumTitleWidth, availableWidth)
    )

    titleWidthConstraint?.constant = titleWidth
    containerView.frame.size.width = ceil(fixedWidth + Self.titleLeadingSpacing + titleWidth)
  }

  // The width the labels want. The constraint that caps the title has to be
  // lifted while measuring: it also caps `fittingSize`, so the labels of a new
  // item would otherwise be measured against the width the previous item
  // needed, and a long file name would inherit the narrow width of a "Text"
  // title.
  private func naturalTitleWidth(of titleStack: NSStackView) -> CGFloat {
    titleWidthConstraint?.isActive = false
    let width = titleStack.fittingSize.width
    titleWidthConstraint?.isActive = true
    return width
  }

  private var estimatedToolbarWidth: CGFloat {
    let identifiers = (showsSVGPresentationSwitch ? [Self.svgPresentationIdentifier] : []) + actionIdentifiers
    let itemsWidth = identifiers.reduce(CGFloat.zero) { partialWidth, identifier in
      switch identifier {
      case Self.openInApplicationIdentifier:
        return partialWidth + Self.labelledItemWidth
      case Self.tagsIdentifier, Self.moreActionsIdentifier:
        return partialWidth + Self.menuItemWidth
      case Self.svgPresentationIdentifier:
        return partialWidth + Self.segmentedItemWidth
      default:
        return partialWidth + Self.borderedItemWidth
      }
    }
    return itemsWidth
      + CGFloat(identifiers.count) * Self.itemSpacing
      + Self.toolbarTrailingInset
  }

  func setEditing(_ isEditing: Bool) {
    guard self.isEditing != isEditing else {
      return
    }
    self.isEditing = isEditing
    setRestoreEnabled(false)
    synchronizeItems()
  }

  // Restoring only makes sense once the text differs from the original.
  func setRestoreEnabled(_ isEnabled: Bool) {
    restoreItem.isEnabled = isEnabled
  }

  // MARK: - NSToolbarDelegate

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    itemIdentifiers
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [
      .flexibleSpace,
      Self.svgPresentationIdentifier,
      Self.favoriteIdentifier,
      Self.sensitiveContentIdentifier,
      Self.tagsIdentifier,
      Self.copyTextFromImageIdentifier,
      Self.copyTextFromQRCodeIdentifier,
      Self.saveAsFileIdentifier,
      Self.showInFinderIdentifier,
      Self.openInApplicationIdentifier,
      Self.moreActionsIdentifier,
      Self.editIdentifier,
      Self.restoreIdentifier,
      Self.saveIdentifier
    ]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case Self.favoriteIdentifier:
      return favoriteItem
    case Self.sensitiveContentIdentifier:
      return sensitiveContentItem
    case Self.copyTextFromImageIdentifier:
      return copyTextFromImageItem
    case Self.copyTextFromQRCodeIdentifier:
      return copyTextFromQRCodeItem
    case Self.saveAsFileIdentifier:
      return saveAsFileItem
    case Self.openInApplicationIdentifier:
      return openInApplicationItem
    case Self.showInFinderIdentifier:
      return showInFinderItem
    case Self.tagsIdentifier:
      return tagsItem
    case Self.svgPresentationIdentifier:
      return svgPresentationItem
    case Self.moreActionsIdentifier:
      return moreActionsItem
    case Self.editIdentifier:
      return editItem
    case Self.restoreIdentifier:
      return restoreItem
    case Self.saveIdentifier:
      return saveItem
    default:
      return nil
    }
  }

  // MARK: - NSMenuDelegate

  // Rebuilds the menu right before it opens, so it always matches the previewed
  // item and the application the item would be pasted into.
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()

    let sourceMenu = menu === tagsMenu
      ? delegate?.itemPreviewToolbarTagsMenu(self)
      : delegate?.itemPreviewToolbarMoreActionsMenu(self)
    guard let sourceMenu else {
      return
    }

    let menuItems = sourceMenu.items
    sourceMenu.removeAllItems()
    menuItems.forEach(menu.addItem)
  }

  // MARK: - Items

  // The switch of an SVG document sits between two flexible spaces, which share the
  // free room equally and so center it between the title and the actions.
  private var itemIdentifiers: [NSToolbarItem.Identifier] {
    if isEditing {
      return [.flexibleSpace, Self.restoreIdentifier, Self.saveIdentifier]
    }
    if showsSVGPresentationSwitch {
      return [.flexibleSpace, Self.svgPresentationIdentifier, .flexibleSpace] + actionIdentifiers
    }
    return [.flexibleSpace] + actionIdentifiers
  }

  // Text that is an SVG document can be previewed as its picture or its markup,
  // unless its content is hidden and shown as text anyway.
  private var showsSVGPresentationSwitch: Bool {
    !sensitiveContent.hidesContent && SVGImageRenderer.shared.rendering(for: item) != nil
  }

  // An item with content to hide gets the eye that shows and hides it, ahead of the
  // actions of its kind.
  private var actionIdentifiers: [NSToolbarItem.Identifier] {
    var identifiers = Self.actionIdentifiers(for: item)
    if isReadOnly {
      identifiers = identifiers.filter(Self.readOnlyActionIdentifiers.contains)
    }
    return sensitiveContent.isMasked ? [Self.sensitiveContentIdentifier] + identifiers : identifiers
  }

  private static func actionIdentifiers(for item: ClipboardItem) -> [NSToolbarItem.Identifier] {
    switch item.kind {
    case .text, .richText:
      return [favoriteIdentifier, tagsIdentifier, moreActionsIdentifier, editIdentifier]
    case .color:
      return [favoriteIdentifier, tagsIdentifier, editIdentifier]
    case .email:
      return [favoriteIdentifier, tagsIdentifier, editIdentifier]
    case .link:
      // Open in ... goes last, so the labelled item ends the toolbar.
      return [tagsIdentifier, editIdentifier, openInApplicationIdentifier]
    case .image:
      var identifiers: [NSToolbarItem.Identifier] = []
      if item.canCopyTextFromImage {
        identifiers.append(copyTextFromImageIdentifier)
      }
      if item.canCopyTextFromQRCode {
        identifiers.append(copyTextFromQRCodeIdentifier)
      }
      identifiers.append(contentsOf: [saveAsFileIdentifier, favoriteIdentifier, tagsIdentifier])
      // Open in ... goes last, so the labelled item ends the toolbar.
      identifiers.append(openInApplicationIdentifier)
      return identifiers
    case .file where item.isMultipleFileItem:
      return [favoriteIdentifier, tagsIdentifier]
    case .file:
      var identifiers: [NSToolbarItem.Identifier] = []
      if item.canCopyTextFromImage {
        identifiers.append(copyTextFromImageIdentifier)
      }
      if item.canCopyTextFromQRCode {
        identifiers.append(copyTextFromQRCodeIdentifier)
      }
      identifiers.append(contentsOf: [favoriteIdentifier, tagsIdentifier, showInFinderIdentifier])
      // Open in ... goes last, so the labelled item ends the toolbar.
      identifiers.append(openInApplicationIdentifier)
      return identifiers
    }
  }

  private func synchronizeItems() {
    guard let toolbar else {
      return
    }

    let identifiers = itemIdentifiers
    guard toolbar.items.map(\.itemIdentifier) != identifiers else {
      return
    }

    for index in stride(from: toolbar.items.count - 1, through: 0, by: -1) {
      toolbar.removeItem(at: index)
    }
    for (index, identifier) in identifiers.enumerated() {
      toolbar.insertItem(withItemIdentifier: identifier, at: index)
    }
  }

  private func makeFavoriteItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.favoriteIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(toggleFavorite)
    toolbarItem.isBordered = true
    toolbarItem.visibilityPriority = .high
    updateFavoriteItem(item: toolbarItem)
    return toolbarItem
  }

  private func updateFavoriteItem(item toolbarItem: NSToolbarItem? = nil) {
    let toolbarItem = toolbarItem ?? favoriteItem
    let label = item.isFavorite
      ? L10n.string("Remove from Favorites")
      : L10n.string("Add to Favorites")
    let symbolName = item.isFavorite ? "star.fill" : "star"

    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    // The button keeps its regular style; only the star is tinted, so the
    // favorite state reads from the icon rather than from the background.
    toolbarItem.image = Self.symbolImage(
      symbolName: symbolName,
      label: label,
      color: item.isFavorite ? .controlAccentColor : nil
    )
    Self.applyPlainStyle(to: toolbarItem)
  }

  private func makeSensitiveContentItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.sensitiveContentIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(toggleSensitiveContentVisibility)
    toolbarItem.isBordered = true
    toolbarItem.visibilityPriority = .high
    updateSensitiveContentItem(item: toolbarItem)
    return toolbarItem
  }

  private func updateSensitiveContentItem(item toolbarItem: NSToolbarItem? = nil) {
    let toolbarItem = toolbarItem ?? sensitiveContentItem
    let label = sensitiveContent.hidesContent
      ? L10n.string("Show Sensitive Content")
      : L10n.string("Hide Sensitive Content")

    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(
      symbolName: sensitiveContent.hidesContent ? "eye" : "eye.slash",
      label: label
    )
    Self.applyPlainStyle(to: toolbarItem)
  }

  private func makeCopyTextFromImageItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.copyTextFromImageIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(copyTextFromImage)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Copy Text from Image")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "text.viewfinder", label: label)

    return toolbarItem
  }

  private func makeCopyTextFromQRCodeItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.copyTextFromQRCodeIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(copyTextFromQRCode)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Copy Text from QR Code")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "qrcode.viewfinder", label: label)

    return toolbarItem
  }

  private func makeSaveAsFileItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.saveAsFileIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(saveAsFile)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Save as File...")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "square.and.arrow.down", label: label)

    return toolbarItem
  }

  // Carries the icon and the name of the application the item opens in, so it
  // is the only item of the toolbar that shows a label next to its image.
  private func makeOpenInApplicationItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.openInApplicationIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(openInApplication)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high
    updateOpenInApplicationItem(item: toolbarItem)

    return toolbarItem
  }

  private func updateOpenInApplicationItem(item toolbarItem: NSToolbarItem? = nil) {
    let toolbarItem = toolbarItem ?? openInApplicationItem
    // A link has no file to open, so it names the browser that would handle it.
    let application = (item.quickLookURL ?? item.browserURL).flatMap {
      AssociatedApplication.forOpening($0, iconSize: Self.applicationIconSize)
    }
    let label = application.map { AssociatedApplication.openTitle(forName: $0.name) }
      ?? L10n.string("Open")

    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.title = label
    toolbarItem.image = application?.icon
      ?? Self.symbolImage(symbolName: "app", label: label)
  }

  // Shows the Finder icon alone, so it reads as "reveal in Finder" without
  // repeating the word in a label.
  private func makeShowInFinderItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.showInFinderIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(showInFinder)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Show in Finder")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.applicationIcon(
      bundleIdentifier: "com.apple.finder",
      fallbackSymbolName: "folder",
      label: label
    )

    return toolbarItem
  }

  private func makeTagsItem() -> NSMenuToolbarItem {
    let toolbarItem = NSMenuToolbarItem(itemIdentifier: Self.tagsIdentifier)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high
    toolbarItem.showsIndicator = true

    let menu = NSMenu()
    menu.delegate = self
    toolbarItem.menu = menu
    tagsMenu = menu

    let label = L10n.string("Tags")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "circle", label: label)

    return toolbarItem
  }

  // Switches the preview of an SVG document between the picture it draws and its
  // markup. The choice stays while the preview is open, as the user moves between items.
  private func makeSVGPresentationItem() -> NSToolbarItemGroup {
    let imageLabel = L10n.string("Image")
    let textLabel = L10n.string("Text")
    let toolbarItem = NSToolbarItemGroup(
      itemIdentifier: Self.svgPresentationIdentifier,
      images: [
        Self.symbolImage(symbolName: ClipboardKind.image.systemImage, label: imageLabel),
        Self.symbolImage(symbolName: "chevron.left.forwardslash.chevron.right", label: textLabel)
      ].compactMap { $0 },
      selectionMode: .selectOne,
      labels: [imageLabel, textLabel],
      target: self,
      action: #selector(selectSVGPresentation)
    )
    toolbarItem.visibilityPriority = .high
    toolbarItem.selectedIndex = 0
    for (subitem, label) in zip(toolbarItem.subitems, [imageLabel, textLabel]) {
      subitem.toolTip = label
    }

    return toolbarItem
  }

  private func makeMoreActionsItem() -> NSMenuToolbarItem {
    let toolbarItem = NSMenuToolbarItem(itemIdentifier: Self.moreActionsIdentifier)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high
    toolbarItem.showsIndicator = true

    let menu = NSMenu()
    menu.delegate = self
    toolbarItem.menu = menu

    let label = L10n.string("More Actions")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "ellipsis.circle", label: label)

    return toolbarItem
  }

  private func makeEditItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.editIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(edit)
    toolbarItem.isBordered = true
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Edit")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.image = Self.symbolImage(symbolName: "square.and.pencil", label: label)

    return toolbarItem
  }

  private func makeRestoreItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.restoreIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(restore)
    toolbarItem.isBordered = true
    // The enabled state is driven by the editor, not by toolbar validation.
    toolbarItem.autovalidates = false
    Self.applyPlainStyle(to: toolbarItem)
    toolbarItem.visibilityPriority = .high

    let label = L10n.string("Restore")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = label
    toolbarItem.title = label

    return toolbarItem
  }

  // Save is the primary action while editing, so it gets the prominent style.
  private func makeSaveItem() -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: Self.saveIdentifier)
    toolbarItem.target = self
    toolbarItem.action = #selector(save)
    toolbarItem.isBordered = true
    toolbarItem.autovalidates = false
    toolbarItem.visibilityPriority = .high
    if #available(macOS 26.0, *) {
      toolbarItem.style = .prominent
      toolbarItem.backgroundTintColor = nil
    }

    let label = L10n.string("Save")
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    toolbarItem.toolTip = L10n.string("Save changes (⌘+S)")
    toolbarItem.title = label

    return toolbarItem
  }

  // MARK: - Actions

  @objc private func close() {
    delegate?.itemPreviewToolbarDidRequestClose(self)
  }

  @objc private func toggleFavorite() {
    delegate?.itemPreviewToolbarDidRequestToggleFavorite(self)
  }

  @objc private func toggleSensitiveContentVisibility() {
    delegate?.itemPreviewToolbarDidRequestToggleSensitiveContentVisibility(self)
  }

  @objc private func selectSVGPresentation() {
    delegate?.itemPreviewToolbar(self, didSelectSVGMarkup: svgPresentationItem.selectedIndex == 1)
  }

  @objc private func edit() {
    delegate?.itemPreviewToolbarDidRequestEdit(self)
  }

  @objc private func save() {
    delegate?.itemPreviewToolbarDidRequestSave(self)
  }

  @objc private func copyTextFromImage() {
    delegate?.itemPreviewToolbarDidRequestCopyTextFromImage(self)
  }

  @objc private func copyTextFromQRCode() {
    delegate?.itemPreviewToolbarDidRequestCopyTextFromQRCode(self)
  }

  @objc private func saveAsFile() {
    delegate?.itemPreviewToolbarDidRequestSaveAsFile(self)
  }

  @objc private func openInApplication() {
    delegate?.itemPreviewToolbarDidRequestOpenInApplication(self)
  }

  @objc private func showInFinder() {
    delegate?.itemPreviewToolbarDidRequestShowInFinder(self)
  }

  @objc private func restore() {
    delegate?.itemPreviewToolbarDidRequestRestore(self)
  }

  // MARK: - Styling

  private static func applicationIcon(
    bundleIdentifier: String,
    fallbackSymbolName: String,
    label: String
  ) -> NSImage? {
    guard let applicationURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: bundleIdentifier
    ) else {
      return symbolImage(symbolName: fallbackSymbolName, label: label)
    }

    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    icon.size = Self.applicationIconSize
    return icon
  }

  private static func symbolImage(
    symbolName: String,
    label: String,
    color: NSColor? = nil
  ) -> NSImage? {
    guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label) else {
      return nil
    }

    var configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    if let color {
      configuration = configuration.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    }
    let symbolImage = image.withSymbolConfiguration(configuration)
    // A template image is drawn in the toolbar tint, which would discard the
    // palette color.
    symbolImage?.isTemplate = color == nil
    return symbolImage
  }

  private static func applyPlainStyle(to item: NSToolbarItem) {
    if #available(macOS 26.0, *) {
      item.style = .plain
    }
  }

}

// Close button styled like the one in the Finder preview window: a filled
// circle carrying the glyph, rather than a bordered toolbar button.
private final class ItemPreviewCloseButton: NSButton {
  fileprivate static let buttonSize: CGFloat = 18

  init(target: AnyObject?, action: Selector) {
    super.init(frame: NSRect(x: 0, y: 0, width: Self.buttonSize, height: Self.buttonSize))
    self.target = target
    self.action = action
    isBordered = false
    bezelStyle = .shadowlessSquare
    imagePosition = .imageOnly
    imageScaling = .scaleProportionallyDown
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: Self.buttonSize),
      heightAnchor.constraint(equalToConstant: Self.buttonSize)
    ])
    updateImage()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // The palette colors are baked into the image, so it has to be rebuilt
  // whenever the system switches between the light and the dark appearance.
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateImage()
  }

  private func updateImage() {
    effectiveAppearance.performAsCurrentDrawingAppearance {
      let configuration = NSImage.SymbolConfiguration(
        pointSize: Self.buttonSize,
        weight: .regular
      ).applying(
        NSImage.SymbolConfiguration(
          paletteColors: [HistoryAppearance.backgroundColor, .secondaryLabelColor]
        )
      )
      image = NSImage(
        systemSymbolName: "xmark.circle.fill",
        accessibilityDescription: L10n.string("Close")
      )?.withSymbolConfiguration(configuration)
    }
  }
}
