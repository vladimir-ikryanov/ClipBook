import AppKit

extension NSWorkspace {
  /// URL of the application bundle with the given name, looked up in the
  /// standard application folders.
  ///
  /// `fullPath(forApplication:)` has been deprecated since macOS 11 without a
  /// replacement for lookups by name, so the folders Launch Services registers
  /// applications from are checked directly.
  nonisolated func applicationURL(named name: String) -> URL? {
    let fileManager = FileManager.default
    let bundleName = name.hasSuffix(".app") ? name : name + ".app"

    var directories = fileManager.urls(for: .applicationDirectory, in: .allDomainsMask)
    directories += directories.map { $0.appendingPathComponent("Utilities") }
    directories += [
      URL(fileURLWithPath: "/System/Applications"),
      URL(fileURLWithPath: "/System/Applications/Utilities"),
      URL(fileURLWithPath: "/System/Library/CoreServices")
    ]

    var checked: Set<String> = []
    for directory in directories {
      let url = directory.appendingPathComponent(bundleName)
      guard checked.insert(url.path).inserted else {
        continue
      }

      if fileManager.fileExists(atPath: url.path) {
        return url
      }
    }

    return nil
  }
}
