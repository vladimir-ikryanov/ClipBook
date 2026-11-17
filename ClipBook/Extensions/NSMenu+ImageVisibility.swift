import AppKit

extension NSMenuItem {
  /// Raw value of `NSMenuItem.ImageVisibility.visible` in the macOS 27 SDK.
  private static let visibleImageVisibilityRawValue = 1

  /// macOS 27 hides menu item images unless the system is configured to show
  /// them. ClipBook's menus rely on their icons (a tag's icon carries the
  /// tag's color, actions are recognised by their symbols), so the items keep
  /// showing them as they did on earlier systems.
  ///
  /// The property is set through key-value coding because the typed
  /// `preferredImageVisibility` only exists in the macOS 27 SDK. A build with an
  /// earlier Xcode, such as the macOS 26 runners CI uses, cannot compile a
  /// reference to it, and `#available` only gates running, not compiling.
  func showsImageRegardlessOfSystemSetting() {
    if #available(macOS 27.0, *), responds(to: Selector(("setPreferredImageVisibility:"))) {
      setValue(Self.visibleImageVisibilityRawValue, forKey: "preferredImageVisibility")
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
