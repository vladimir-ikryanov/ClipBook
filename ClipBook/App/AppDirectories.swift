import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine

enum AppDirectories {
  static func applicationSupport(fileManager: FileManager) -> URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let directory = base.appendingPathComponent("ClipBook2", isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
