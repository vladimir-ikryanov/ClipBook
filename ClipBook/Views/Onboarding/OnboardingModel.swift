import AppKit
import Combine
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case copyItems
  case openHistory
  case pasteBack
  case accessibility
  case ready

  var id: Int {
    rawValue
  }

  var title: String {
    switch self {
    case .welcome:
      return L10n.string("Welcome")
    case .copyItems:
      return L10n.string("Copy")
    case .openHistory:
      return L10n.string("Open history")
    case .pasteBack:
      return L10n.string("Paste")
    case .accessibility:
      return L10n.string("Accessibility")
    case .ready:
      return L10n.string("Finish")
    }
  }

  var previous: OnboardingStep? {
    Self(rawValue: rawValue - 1)
  }

  var next: OnboardingStep? {
    Self(rawValue: rawValue + 1)
  }
}

/// The items the user copies during onboarding so the history has something of
/// their own to paste back a moment later.
enum OnboardingSample: Int, CaseIterable, Identifiable {
  case note
  case link
  case color

  var id: Int {
    rawValue
  }

  var text: String {
    switch self {
    case .note:
      return L10n.string("Meeting moved to 3 pm")
    case .link:
      return "https://clipbook.app"
    case .color:
      return "#3B6CF6"
    }
  }

  var systemImage: String? {
    switch self {
    case .note:
      return "text.alignleft"
    case .link:
      return "link"
    case .color:
      return nil
    }
  }
}

enum OnboardingNavigationDirection {
  case forward
  case backward
}

enum OnboardingAccessibilityState {
  /// Explains the permission and offers to open System Settings.
  case request
  /// System Settings was opened, and the window waits for the switch.
  case waiting
  case granted
}

@MainActor
final class OnboardingModel: ObservableObject {
  private static let accessibilityCheckInterval: TimeInterval = 0.4

  @Published private(set) var step: OnboardingStep = .welcome
  /// Which way the last move between steps went, so the steps slide the
  /// same way.
  @Published private(set) var navigationDirection: OnboardingNavigationDirection = .forward
  @Published private(set) var savedSamples: Set<OnboardingSample> = []
  /// What was pasted from the history into the onboarding window, or nil
  /// until something was.
  @Published private(set) var pastedText: String?
  @Published var pasteFieldText = ""
  @Published private(set) var accessibilityState: OnboardingAccessibilityState

  let appModel: AppModel
  private let coordinator: AppCoordinator
  private let accessibilityGuide = AccessibilityGuideWindow()
  private var accessibilityTimer: Timer?
  private var cancellables: Set<AnyCancellable> = []
  /// Asks the onboarding window to come forward once Accessibility is on.
  var onAccessibilityGranted: (() -> Void)?
  weak var pasteField: NSTextField?

  init(appModel: AppModel, coordinator: AppCoordinator) {
    self.appModel = appModel
    self.coordinator = coordinator
    accessibilityState = Self.isAccessibilityTrusted ? .granted : .request

    coordinator.capturedClipboardItems
      .sink { [weak self] item in
        self?.markSaved(item)
      }
      .store(in: &cancellables)

    coordinator.historyPanelDidShow
      .sink { [weak self] in
        guard let self, self.step == .openHistory else {
          return
        }
        self.go(to: .pasteBack)
      }
      .store(in: &cancellables)
  }

  var showHistoryShortcut: String {
    appModel.preferences.showHistoryShortcut
  }

  var areAllSamplesSaved: Bool {
    savedSamples.count == OnboardingSample.allCases.count
  }

  func goBack() {
    guard let previous = step.previous else {
      return
    }
    go(to: previous)
  }

  func goForward() {
    guard let next = step.next else {
      coordinator.completeOnboarding()
      return
    }
    go(to: next)
  }

  // MARK: - Copying

  /// Puts the sample on the clipboard the way any app would, so ClipBook
  /// captures it like everything else the user copies.
  func copy(_ sample: OnboardingSample) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(sample.text, forType: .string)
  }

  private func markSaved(_ item: ClipboardItem) {
    let text = item.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let sample = OnboardingSample.allCases.first(where: { $0.text == text }) else {
      return
    }
    withAnimation(.easeOut(duration: 0.2)) {
      _ = savedSamples.insert(sample)
    }
  }

  // MARK: - Pasting

  /// Pastes what the history just put on the clipboard into the onboarding
  /// field. Pasting within ClipBook needs no Accessibility permission, which
  /// the user has not been asked for yet at this point.
  func receivePaste(of item: ClipboardItem, in window: NSWindow) {
    guard step == .pasteBack, pastedText == nil else {
      return
    }

    var text = ""
    if let pasteField, window.makeFirstResponder(pasteField),
       let editor = pasteField.currentEditor() as? NSTextView {
      editor.selectAll(nil)
      editor.paste(nil)
      text = pasteField.stringValue
    }
    // An image, for one, pastes nothing into a text field, so the field then
    // shows what the item is instead.
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty {
      text = item.previewText
    }
    pasteFieldText = text
    withAnimation(.easeOut(duration: 0.2)) {
      pastedText = text
    }
  }

  // MARK: - Accessibility

  func openAccessibilitySettings() {
    AccessibilityPermission.openSettings()
    accessibilityState = .waiting
    startWatchingAccessibility()
  }

  private func go(to newStep: OnboardingStep) {
    let direction: OnboardingNavigationDirection = newStep.rawValue < step.rawValue ? .backward : .forward
    guard direction != navigationDirection else {
      show(newStep)
      return
    }

    // The step that leaves slides out with the transition it was last drawn
    // with, so the new direction is drawn first and the step changes after.
    navigationDirection = direction
    DispatchQueue.main.async { [weak self] in
      self?.show(newStep)
    }
  }

  private func show(_ newStep: OnboardingStep) {
    step = newStep
    if newStep == .accessibility {
      if Self.isAccessibilityTrusted {
        accessibilityState = .granted
      } else if accessibilityState == .granted {
        accessibilityState = .request
      }
      if accessibilityState == .waiting {
        startWatchingAccessibility()
      }
    } else {
      stopWatchingAccessibility()
    }
  }

  private func startWatchingAccessibility() {
    accessibilityTimer?.invalidate()
    accessibilityTimer = Timer.scheduledTimer(withTimeInterval: Self.accessibilityCheckInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.checkAccessibility()
      }
    }
    checkAccessibility()
  }

  private func stopWatchingAccessibility() {
    accessibilityTimer?.invalidate()
    accessibilityTimer = nil
    accessibilityGuide.hide()
  }

  private func checkAccessibility() {
    guard Self.isAccessibilityTrusted else {
      accessibilityGuide.showNextToSystemSettings()
      return
    }

    stopWatchingAccessibility()
    withAnimation(.easeOut(duration: 0.2)) {
      accessibilityState = .granted
    }
    onAccessibilityGranted?()
  }

  func stop() {
    stopWatchingAccessibility()
  }

  private static var isAccessibilityTrusted: Bool {
    #if DEBUG
    // `-ClipBookOnboardingIgnoresAccessibility YES` shows the permission
    // screens on a Mac where the debug build already has the permission.
    if UserDefaults.standard.bool(forKey: "ClipBookOnboardingIgnoresAccessibility") {
      return false
    }
    #endif
    return AccessibilityPermission.isTrusted
  }
}
