import AppKit
import Sparkle

final class SparkleUpdateService: NSObject, UpdateService, SPUStandardUserDriverDelegate {
  // The updater is started only after the user's preference has been applied,
  // so Sparkle never schedules a background check the user has turned off.
  private var updaterController: SPUStandardUpdaterController!
  private var isUpdaterStarted = false
  private var willRelaunchObserver: NSObjectProtocol?
  private(set) var isRelaunchingToInstallUpdate = false

  override init() {
    super.init()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: self
    )
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
    bringAppToFront()
    updaterController.checkForUpdates(nil)
  }

  private func startUpdaterIfNeeded() {
    guard !isUpdaterStarted else {
      return
    }
    isUpdaterStarted = true
    updaterController.startUpdater()
  }

  // ClipBook is an accessory app, so a click in the status menu leaves another
  // app frontmost. Sparkle activates the app cooperatively on macOS 14 and
  // later, which the system refuses in that case, and its windows then open
  // behind the frontmost app as if nothing happened. The result of a check the
  // user asked for is brought to the front explicitly instead.
  private func bringAppToFront() {
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - SPUStandardUserDriverDelegate

  // Sparkle shows "You're up to date" and error alerts with runModal, which
  // does not activate the app on its own.
  func standardUserDriverWillShowModalAlert() {
    bringAppToFront()
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    if state.userInitiated {
      bringAppToFront()
    }
  }
}
