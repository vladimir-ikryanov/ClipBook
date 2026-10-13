import Foundation
import AppKit

protocol UpdateService {
  func setAutomaticallyChecksForUpdates(_ enabled: Bool)
  func checkForUpdates(presenting window: NSWindow?)
  /// True once the app is about to quit so the downloaded update can be installed.
  var isRelaunchingToInstallUpdate: Bool { get }
}
