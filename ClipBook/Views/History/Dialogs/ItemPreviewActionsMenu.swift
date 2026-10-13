import AppKit

// Builds the "More actions" menu of the item preview toolbar out of the regular
// history item context menu. Actions that already have a dedicated toolbar
// button, along with the paste and copy actions (the preview is a read-only
// look at the item, not a place to act on the clipboard), are dropped. Most of
// the remaining actions dismiss the preview before they run, because they
// present a sheet on the history window themselves; the ones that update the
// item in place (currently just Transform) run directly and leave the preview
// open, picking up the change through the usual model-driven refresh.
@MainActor
final class ItemPreviewActionsMenu: NSObject {
  fileprivate final class ForwardedAction {
    weak var target: AnyObject?
    let selector: Selector
    let dismissesPreview: Bool

    init(target: AnyObject?, selector: Selector, dismissesPreview: Bool) {
      self.target = target
      self.selector = selector
      self.dismissesPreview = dismissesPreview
    }
  }

  // Actions that mutate the item in place rather than opening a sheet, so the
  // preview can stay open and simply refresh once the change lands.
  private static let inPlaceActionSelectors: Set<Selector> = [
    #selector(HistoryContentViewController.applyTransformMenuItem(_:)),
    #selector(HistoryContentViewController.sensitiveMenuItem(_:))
  ]

  private static let excludedActionSelectors: Set<Selector> = [
    #selector(HistoryContentViewController.editMenuItem(_:)),
    #selector(HistoryContentViewController.favoriteMenuItem(_:)),
    #selector(HistoryContentViewController.sensitiveContentVisibilityMenuItem(_:)),
    #selector(HistoryContentViewController.previewMenuItem(_:)),
    #selector(HistoryContentViewController.pasteMenuItem(_:)),
    #selector(HistoryContentViewController.pastePlainTextMenuItem(_:)),
    #selector(HistoryContentViewController.pasteFilePathMenuItem(_:)),
    #selector(HistoryContentViewController.copyMenuItem(_:)),
    #selector(HistoryContentViewController.copyPlainTextMenuItem(_:)),
    #selector(HistoryContentViewController.copyFilePathMenuItem(_:)),
    #selector(HistoryContentViewController.copyTextFromImageMenuItem(_:)),
    #selector(HistoryContentViewController.copyTextFromQRCodeMenuItem(_:))
  ]

  private let makeItemMenu: (ClipboardItem) -> NSMenu
  private let dismissPreview: () -> Void
  fileprivate var forwardedActions: [ObjectIdentifier: ForwardedAction] = [:]

  init(
    makeItemMenu: @escaping (ClipboardItem) -> NSMenu,
    dismissPreview: @escaping () -> Void
  ) {
    self.makeItemMenu = makeItemMenu
    self.dismissPreview = dismissPreview
    super.init()
  }

  func makeMenu(for item: ClipboardItem) -> NSMenu {
    let menu = makeItemMenu(item)
    Self.removeExcludedActions(from: menu)
    // Tags have their own toolbar button as well.
    for menuItem in menu.items where ItemPreviewTagsMenu.isTagsMenuItem(menuItem) {
      menu.removeItem(menuItem)
    }
    Self.removeRedundantSeparators(from: menu)

    forwardedActions.removeAll()
    forwardActions(in: menu)

    return menu
  }

  private static func removeExcludedActions(from menu: NSMenu) {
    for menuItem in menu.items {
      guard let action = menuItem.action, excludedActionSelectors.contains(action) else {
        continue
      }
      menu.removeItem(menuItem)
    }
  }

  private static func removeRedundantSeparators(from menu: NSMenu) {
    for menuItem in menu.items where menuItem.isSeparatorItem {
      let index = menu.index(of: menuItem)
      let isLeading = index == 0
      let isTrailing = index == menu.numberOfItems - 1
      let followsSeparator = index > 0 && menu.item(at: index - 1)?.isSeparatorItem == true
      guard isLeading || isTrailing || followsSeparator else {
        continue
      }
      menu.removeItem(menuItem)
    }
  }

  private func forwardActions(in menu: NSMenu) {
    for menuItem in menu.items {
      if let submenu = menuItem.submenu {
        forwardActions(in: submenu)
        continue
      }

      guard let action = menuItem.action else {
        continue
      }

      forwardedActions[ObjectIdentifier(menuItem)] = ForwardedAction(
        target: menuItem.target,
        selector: action,
        dismissesPreview: !Self.inPlaceActionSelectors.contains(action)
      )
      menuItem.target = self
      menuItem.action = #selector(performForwardedAction(_:))
    }
  }

  @objc private func performForwardedAction(_ sender: NSMenuItem) {
    guard let forwardedAction = forwardedActions[ObjectIdentifier(sender)] else {
      return
    }

    guard forwardedAction.dismissesPreview else {
      NSApp.sendAction(forwardedAction.selector, to: forwardedAction.target, from: sender)
      return
    }

    dismissPreview()
    // Give the sheet a chance to finish dismissing, so an action that presents
    // another sheet on the history window is not queued behind the preview.
    DispatchQueue.main.async {
      NSApp.sendAction(forwardedAction.selector, to: forwardedAction.target, from: sender)
    }
  }
}

extension ItemPreviewActionsMenu: NSMenuItemValidation {
  // The forwarded items are validated the way the history menu validates them,
  // which disables the ones a read-only history doesn't allow.
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard let forwardedAction = forwardedActions[ObjectIdentifier(menuItem)],
          let target = forwardedAction.target as? HistoryContentViewController else {
      return true
    }

    return target.isMenuActionAvailable(forwardedAction.selector, representedObject: menuItem.representedObject)
  }
}
