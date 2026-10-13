import AppKit

// Builds the "Tags" menu of the item preview toolbar out of the Tags submenu of
// the regular history item context menu. Toggling a tag keeps the preview
// open, while the actions that present another sheet or the settings window
// dismiss the preview first.
@MainActor
final class ItemPreviewTagsMenu: NSObject {
  private final class ForwardedAction {
    weak var target: AnyObject?
    let selector: Selector

    init(target: AnyObject?, selector: Selector) {
      self.target = target
      self.selector = selector
    }
  }

  private static let toggleTagSelector = #selector(HistoryContentViewController.toggleTagMenuItem(_:))

  private let makeItemMenu: (ClipboardItem) -> NSMenu
  private let dismissPreview: () -> Void
  private var forwardedActions: [ObjectIdentifier: ForwardedAction] = [:]

  init(
    makeItemMenu: @escaping (ClipboardItem) -> NSMenu,
    dismissPreview: @escaping () -> Void
  ) {
    self.makeItemMenu = makeItemMenu
    self.dismissPreview = dismissPreview
    super.init()
  }

  // The Tags entry of the context menu is recognized by its content rather
  // than by its title, because the title is localized and varies by item kind.
  static func isTagsMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard let submenu = menuItem.submenu else {
      return false
    }
    return submenu.items.contains { $0.action == toggleTagSelector }
      || submenu.items.contains { $0.action == #selector(HistoryContentViewController.newTagMenuItem(_:)) }
  }

  func makeMenu(for item: ClipboardItem) -> NSMenu {
    let menu = NSMenu()
    guard let tagsMenu = makeItemMenu(item).items.first(where: Self.isTagsMenuItem)?.submenu else {
      return menu
    }

    let menuItems = tagsMenu.items
    tagsMenu.removeAllItems()
    menuItems.forEach(menu.addItem)

    forwardedActions.removeAll()
    for menuItem in menuItems {
      guard let action = menuItem.action, action != Self.toggleTagSelector else {
        continue
      }
      forwardedActions[ObjectIdentifier(menuItem)] = ForwardedAction(
        target: menuItem.target,
        selector: action
      )
      menuItem.target = self
      menuItem.action = #selector(performForwardedAction(_:))
    }

    return menu
  }

  @objc private func performForwardedAction(_ sender: NSMenuItem) {
    guard let forwardedAction = forwardedActions[ObjectIdentifier(sender)] else {
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
