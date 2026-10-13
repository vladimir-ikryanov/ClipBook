import AppKit

extension NSMenuItem {
  /// macOS 27 hides menu item images unless the system is configured to show
  /// them. ClipBook's menus rely on their icons (a tag's icon carries the
  /// tag's color, actions are recognised by their symbols), so the items keep
  /// showing them as they did on earlier systems.
  func showsImageRegardlessOfSystemSetting() {
    if #available(macOS 27.0, *) {
      preferredImageVisibility = .visible
    }
  }
}

extension NSMenu {
  /// Keeps the images of every item in the menu and its submenus visible.
  /// Applied once a menu is fully built; items moved into another menu keep
  /// the setting.
  func showsItemImagesRegardlessOfSystemSetting() {
    for item in items {
      if item.image != nil {
        item.showsImageRegardlessOfSystemSetting()
      }

      item.submenu?.showsItemImagesRegardlessOfSystemSetting()
    }
  }
}
