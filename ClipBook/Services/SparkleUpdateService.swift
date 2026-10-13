import AppKit
import Sparkle

final class SparkleUpdateService: UpdateService {
  // The updater is started only after the user's preference has been applied,
  // so Sparkle never schedules a background check the user has turned off.
  private let updaterController = SPUStandardUpdaterController(
    startingUpdater: false,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )
  private var isUpdaterStarted = false
  private var willRelaunchObserver: NSObjectProtocol?
  private(set) var isRelaunchingToInstallUpdate = false

  init() {
    // Sparkle posts this right before it quits the app, and the quit follows
    // at once, so the flag is set synchronously rather than on a later turn
    // of the main queue.
    willRelaunchObserver = NotificationCenter.default.addObserver(
      forName: .SUUpdaterWillRestart,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      self?.isRelaunchingToInstallUpdate = true
    }
  }

  func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
    let updater = updaterController.updater
    if updater.automaticallyChecksForUpdates != enabled {
      updater.automaticallyChecksForUpdates = enabled
    }
    startUpdaterIfNeeded()
  }

  func checkForUpdates(presenting _: NSWindow?) {
    startUpdaterIfNeeded()
    updaterController.checkForUpdates(nil)
  }

  private func startUpdaterIfNeeded() {
    guard !isUpdaterStarted else {
      return
    }
    isUpdaterStarted = true
    updaterController.startUpdater()
  }
}
