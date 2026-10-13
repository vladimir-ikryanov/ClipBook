import SwiftUI
import AppKit
import Combine

final class OnboardingWindow: NSObject, NSWindowDelegate {
  private static let defaultWindowSize = NSSize(width: 600, height: 490)
  private static let toolbarIdentifier = NSToolbar.Identifier("OnboardingToolbar")

  private let model: AppModel
  private let coordinator: AppCoordinator
  private let window: NSWindow

  init(model: AppModel, coordinator: AppCoordinator) {
    self.model = model
    self.coordinator = coordinator
    let content = OnboardingView(model: model)
      .environmentObject(coordinator)
    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    super.init()
    window.contentView = NSHostingView(rootView: content)
    window.delegate = self
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    // A window with a toolbar gets the larger, concentric corner radius on macOS 26.
    window.toolbar = Self.makeToolbar()
    window.toolbarStyle = .unified
    window.backgroundColor = .windowBackgroundColor
    window.collectionBehavior = [.moveToActiveSpace]
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
  }

  func show() {
    centerWindowOnActiveScreen()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func close() {
    window.close()
  }

  func windowWillClose(_ notification: Notification) {
    coordinator.onboardingDidClose()
  }

  private func centerWindowOnActiveScreen() {
    let mouseLocation = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    guard let screen else {
      window.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    let origin = NSPoint(
      x: visibleFrame.midX - window.frame.width / 2,
      y: visibleFrame.midY - window.frame.height / 2
    )
    window.setFrameOrigin(origin)
  }

  private static func makeToolbar() -> NSToolbar {
    let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
    toolbar.allowsUserCustomization = false
    if #available(macOS 15.0, *) {
      toolbar.allowsDisplayModeCustomization = false
    }
    toolbar.autosavesConfiguration = false
    return toolbar
  }
}

private struct OnboardingView: View {
  @ObservedObject var model: AppModel
  @EnvironmentObject private var coordinator: AppCoordinator
  @State private var selectedStep: OnboardingStep = .intro
  @State private var selectedLanguage = L10n.languageIdentifier
  @State private var isAccessibilityTrusted = AccessibilityPermission.isTrusted

  private var canGoBack: Bool {
    selectedStep.previous != nil
  }

  private var isLastStep: Bool {
    selectedStep.next == nil
  }

  private var continueTitle: String {
    isLastStep ? L10n.string("Open History") : L10n.string("Continue")
  }

  var body: some View {
    ZStack {
      Color.clear
        .ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer(minLength: 34)

        stepContent
          .id(selectedStep)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.horizontal, 72)

        bottomBar
      }
    }
    .id(model.localizationRevision)
    .frame(minWidth: 700, minHeight: 400)
    .onAppear {
      selectedLanguage = model.preferences.language
      isAccessibilityTrusted = AccessibilityPermission.isTrusted
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      isAccessibilityTrusted = AccessibilityPermission.isTrusted
    }
  }

  @ViewBuilder
  private var stepContent: some View {
    switch selectedStep {
    case .intro:
      introStep
    case .historyShortcut:
      shortcutStep
    case .selectAndSearch:
      selectAndSearchStep
    case .accessibility:
      accessibilityStep
    case .organize:
      organizeStep
    case .finish:
      finishStep
    }
  }

  private var introStep: some View {
    VStack(spacing: 22) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

      VStack(spacing: 8) {
        Text(L10n.string("Welcome to ClipBook"))
          .font(.system(size: 42, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)

        Text(L10n.string("Keep everything you copy and quickly access your\nclipboard history whenever you need it."))
          .font(.title3)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Picker(L10n.string("Language"), selection: $selectedLanguage) {
        ForEach(OnboardingLanguage.allCases) { language in
          Text(language.title).tag(language.identifier)
        }
      }
      .labelsHidden()
      .controlSize(.large)
      .frame(width: 180)
      .onChange(of: selectedLanguage) { language in
        model.preferences.language = language
        coordinator.savePreferences()
      }
    }
  }

  private var shortcutStep: some View {
    OnboardingStepLayout(
      systemImage: "list.bullet.clipboard",
      title: L10n.string("Open clipboard history"),
      subtitle: L10n.string("Access your clipboard history everywhere by pressing this global shortcut.")
    ) {
      shortcutBadge(model.preferences.showHistoryShortcut)
    }
  }

  private var selectAndSearchStep: some View {
    OnboardingStepLayout(
      systemImage: "list.bullet",
      title: L10n.string("Select & Paste"),
      subtitle: L10n.string("Select an item and press Return to paste it directly to the active app.")
    ) {
      HStack(spacing: 10) {
        shortcutBadge(model.preferences.selectPreviousItemShortcut)
        shortcutBadge(model.preferences.selectNextItemShortcut)
        shortcutBadge(model.preferences.pasteSelectedShortcut)
      }
    }
  }

  private var accessibilityStep: some View {
    OnboardingStepLayout(
      systemImage: "keyboard.badge.ellipsis",
      title: L10n.string("Accessibility"),
      subtitle: L10n.string("To paste directly into other apps, ClipBook needs Accessibility permission.")
    ) {
      VStack(spacing: 14) {
        if isAccessibilityTrusted {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.green)
            .accessibilityLabel(L10n.string("Accessibility access granted"))
        } else {
          Button(L10n.string("Grant Access")) {
            AccessibilityPermission.openSettings()
            isAccessibilityTrusted = AccessibilityPermission.isTrusted
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        }
      }
    }
  }

  private var organizeStep: some View {
    OnboardingStepLayout(
      systemImage: "tray.full",
      title: L10n.string("Organize your history"),
      subtitle: L10n.string("Mark important clips as favorites and add tags to easily find them later.")
    ) {
      HStack(spacing: 12) {
        featurePill(systemImage: "star.fill", title: L10n.string("Favorites"))
        featurePill(systemImage: "tag.fill", title: L10n.string("Tags"))
      }
    }
  }

  private var finishStep: some View {
    OnboardingStepLayout(
      systemImage: "checkmark.circle.fill",
      systemImageColor: .green,
      title: L10n.string("You are ready"),
      subtitle: L10n.string("ClipBook is now watching your clipboard. Copy something, open history, and paste it back whenever you need it.")
    )
  }

  private var bottomBar: some View {
    ZStack {
      HStack {
        if canGoBack {
          backButton
        }

        Spacer()

        continueButton
      }

      progressIndicator
    }
    .padding(.horizontal, 15)
    .frame(height: 64)
  }

  @ViewBuilder
  private var backButton: some View {
    let button = Button(L10n.string("Back")) {
      goBack()
    }
    .keyboardShortcut(.leftArrow, modifiers: [])
    .focusable(false)

    if #available(macOS 26.0, *) {
      button
        .buttonStyle(.glass)
        .controlSize(.extraLarge)
    } else {
      button
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
  }

  @ViewBuilder
  private var continueButton: some View {
    let button = Button(continueTitle) {
      continueForward()
    }
    .focusable(false)

    if #available(macOS 26.0, *) {
      if isLastStep {
        button
          .buttonStyle(.glassProminent)
          .controlSize(.extraLarge)
      } else {
        button
          .buttonStyle(.glass)
          .controlSize(.extraLarge)
      }
    } else if isLastStep {
      button
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    } else {
      button
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
  }

  private var progressIndicator: some View {
    HStack(spacing: 8) {
      ForEach(OnboardingStep.allCases) { step in
        Capsule()
          .fill(step == selectedStep ? Color(nsColor: .lightGray) : Color.secondary.opacity(0.28))
          .frame(width: step == selectedStep ? 28 : 8, height: 8)
          .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedStep)
          .accessibilityLabel(step.title)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.string("Onboarding progress"))
  }

  private func goBack() {
    guard let previousStep = selectedStep.previous else {
      return
    }
    selectedStep = previousStep
  }

  private func continueForward() {
    guard let nextStep = selectedStep.next else {
      coordinator.completeOnboarding(openHistory: true)
      return
    }
    selectedStep = nextStep
  }

  private func shortcutBadge(_ shortcut: String) -> some View {
    let parts = Self.shortcutDisplayParts(for: shortcut)

    return HStack(spacing: 8) {
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        Text(part)
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(.primary)
          .frame(minWidth: 44, minHeight: 44)
          .padding(.horizontal, part.count > 1 ? 20 : 0)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
    }
  }

  private func featurePill(systemImage: String, title: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 14, weight: .regular))
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(.thinMaterial, in: Capsule())
  }

  private static func shortcutDisplayParts(for shortcut: String) -> [String] {
    guard !shortcut.isEmpty else {
      return [L10n.string("Not set")]
    }

    let parts = shortcut.lowercased().split(separator: "+").map(String.init)
    guard let key = parts.last else {
      return [L10n.string("Not set")]
    }

    var result: [String] = []
    if parts.contains("cmd") || parts.contains("command") {
      result.append("⌘")
    }
    if parts.contains("shift") {
      result.append("⇧")
    }
    if parts.contains("option") || parts.contains("alt") {
      result.append("⌥")
    }
    if parts.contains("control") || parts.contains("ctrl") {
      result.append("⌃")
    }
    result.append(keyDisplayText(for: key))
    return result
  }

  private static func keyDisplayText(for key: String) -> String {
    KeyboardShortcutParser.keyDisplayText(for: key)
  }

}

private struct OnboardingStepLayout<Accessory: View>: View {
  let systemImage: String
  let systemImageColor: Color
  let title: String
  let subtitle: String
  let accessory: Accessory

  init(systemImage: String, systemImageColor: Color = .secondary, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) {
    self.systemImage = systemImage
    self.systemImageColor = systemImageColor
    self.title = title
    self.subtitle = subtitle
    self.accessory = accessory()
  }

  init(systemImage: String, systemImageColor: Color = .secondary, title: String, subtitle: String) where Accessory == EmptyView {
    self.init(systemImage: systemImage, systemImageColor: systemImageColor, title: title, subtitle: subtitle) {
      EmptyView()
    }
  }

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: systemImage)
        .font(.system(size: 76, weight: .semibold))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(systemImageColor)

      VStack(spacing: 10) {
        Text(title)
          .font(.system(size: 36, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)

        Text(subtitle)
          .font(.title3)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineLimit(3)
          .frame(maxWidth: 520)
      }

      accessory
        .padding(.top, 4)
    }
  }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
  case intro
  case historyShortcut
  case selectAndSearch
  case accessibility
  case organize
  case finish

  var id: Int {
    rawValue
  }

  var title: String {
    switch self {
    case .intro:
      return L10n.string("Intro")
    case .historyShortcut:
      return L10n.string("Open history")
    case .selectAndSearch:
      return L10n.string("Select and search")
    case .accessibility:
      return L10n.string("Accessibility")
    case .organize:
      return L10n.string("Organize")
    case .finish:
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

private enum OnboardingLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case englishUnitedKingdom = "en-GB"
  case german = "de"
  case italian = "it"
  case portugueseBrazil = "pt-BR"
  case spanish = "es"
  case japanese = "ja"
  case simplifiedChinese = "zh-Hans"

  var id: String {
    rawValue
  }

  var identifier: String {
    rawValue
  }

  var title: String {
    switch self {
    case .english:
      return "English"
    case .englishUnitedKingdom:
      return "English (UK)"
    case .german:
      return "Deutsch"
    case .italian:
      return "Italiano"
    case .portugueseBrazil:
      return "Português (Brasil)"
    case .spanish:
      return "Español"
    case .japanese:
      return "日本語"
    case .simplifiedChinese:
      return "简体中文"
    }
  }
}
