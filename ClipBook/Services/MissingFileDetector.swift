import Foundation

/// Tells whether the files of a file item are gone, deleted or moved
/// elsewhere. A file counts as gone only when macOS can say so for sure: a
/// file on a drive that isn't connected may come back, and a network volume
/// can be slow to answer or unreachable, so files there count as present.
struct MissingFileDetector {
  struct Volume: Equatable {
    let path: String
    let isLocal: Bool
  }

  /// Where macOS mounts volumes. A path there that no mounted volume holds is
  /// on a volume that isn't mounted now.
  private static let mountPointFolders = ["/Volumes/", "/Network/", "/net/"]

  private let volumes: [Volume]
  private let fileExists: (String) -> Bool

  /// Reads the mounted volumes once, so a detector is meant for one check of
  /// the history.
  init(fileManager: FileManager = .default) {
    self.init(volumes: Self.mountedVolumes(fileManager: fileManager)) { path in
      fileManager.fileExists(atPath: path)
    }
  }

  init(volumes: [Volume], fileExists: @escaping (String) -> Bool) {
    self.volumes = volumes
    self.fileExists = fileExists
  }

  /// Whether the item is a file item and every one of its files is gone.
  func isMissingAllFiles(of item: ClipboardItem) -> Bool {
    item.kind == .file && !item.filePaths.isEmpty && item.filePaths.allSatisfy(isMissing)
  }

  func isMissing(_ path: String) -> Bool {
    canCheck(path) && !fileExists(path)
  }

  private func canCheck(_ path: String) -> Bool {
    // The volume of a path is the mounted volume with the longest path that
    // holds it. The startup volume holds everything, so it is left out here.
    let volume = volumes
      .filter { $0.path != "/" && (path == $0.path || path.hasPrefix($0.path + "/")) }
      .max { $0.path.count < $1.path.count }
    if let volume {
      return volume.isLocal
    }

    return path.hasPrefix("/") && !Self.mountPointFolders.contains { path.hasPrefix($0) }
  }

  private static func mountedVolumes(fileManager: FileManager) -> [Volume] {
    let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey], options: []) ?? []
    return urls.map { url in
      // A volume that doesn't say whether it is local is treated as a network
      // volume, whose files are never reported as gone.
      let isLocal = (try? url.resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal ?? false
      return Volume(path: url.standardizedFileURL.path, isLocal: isLocal)
    }
  }
}
