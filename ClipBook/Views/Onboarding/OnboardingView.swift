import AppKit
import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingModel
  @ObservedObject var appModel: AppModel
  @State private var selectedLanguage = L10n.languageIdentifier

  init(model: OnboardingModel) {
    self.model = model
    self.appModel = model.appModel
  }

  var body: some View {
    VStack(spacing: 0) {
      stepContent
        .id(model.step)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 28)

      bottomBar
    }
    .animation(.easeOut(duration: 0.18), value: model.step)
    .id(appModel.localizationRevision)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: OnboardingPalette.windowBackground))
    .ignoresSafeArea()
    .onAppear {
      selectedLanguage = appModel.preferences.language
    }
  }

  @ViewBuilder
  private var stepContent: some View {
    switch model.step {
    case .welcome:
      welcomeStep
    case .copyItems:
      copyItemsStep
    case .openHistory:
      openHistoryStep
    case .pasteBack:
      if let pastedText = model.pastedText {
        pastedStep(pastedText)
      } else {
        pasteBackStep
      }
    case .accessibility:
      switch model.accessibilityState {
      case .request:
        accessibilityRequestStep
      case .waiting:
        accessibilityWaitingStep
      case .granted:
        accessibilityGrantedStep
      }
    case .ready:
      readyStep
    }
  }

  // MARK: - Steps

  private var welcomeStep: some View {
    VStack(spacing: 0) {
      OnboardingAppIcon(size: 104)

      OnboardingTitle(L10n.string("Welcome to ClipBook"))
        .padding(.top, 18)

      OnboardingSubtitle(L10n.string("Keep, organize, find, and reuse everything you copy."))
        .padding(.top, 10)

      Picker(L10n.string("Language"), selection: $selectedLanguage) {
        ForEach(OnboardingLanguage.allCases) { language in
          Text(language.title).tag(language.identifier)
        }
      }
      .labelsHidden()
      .controlSize(.large)
      .frame(width: 170)
      .padding(.top, 22)
      .onChange(of: selectedLanguage) { language in
        model.setLanguage(language)
      }
    }
  }

  private var copyItemsStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("Copy these three things"))

      OnboardingSubtitle(L10n.string("ClipBook saves each one in the background as you copy."))
        .padding(.top, 10)

      VStack(spacing: 9) {
        ForEach(OnboardingSample.allCases) { sample in
          sampleRow(sample)
        }
      }
      .padding(.top, 22)

      Text(L10n.string("%@ of %@ saved", String(model.savedSamples.count), String(OnboardingSample.allCases.count)))
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.top, 14)
    }
  }

  private func sampleRow(_ sample: OnboardingSample) -> some View {
    HStack(spacing: 12) {
      sampleIcon(sample)

      Text(sample.text)
        .font(.system(size: 14))
        .lineLimit(1)
        .textSelection(.enabled)

      Spacer(minLength: 8)

      if model.savedSamples.contains(sample) {
        HStack(spacing: 6) {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
          Text(L10n.string("Saved"))
            .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(OnboardingPalette.success)
        .padding(.trailing, 10)
        .frame(minHeight: 34)
        .transition(.opacity)
      } else {
        Button(L10n.string("Copy")) {
          model.copy(sample)
        }
        .buttonStyle(OnboardingCopyButtonStyle())
        .focusable(false)
      }
    }
    .padding(.leading, 12)
    .padding(.trailing, 4)
    .frame(height: 44)
    .background(OnboardingPalette.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .frame(maxWidth: 420)
  }

  @ViewBuilder
  private func sampleIcon(_ sample: OnboardingSample) -> some View {
    let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
    if let systemImage = sample.systemImage {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)
        .background(OnboardingPalette.placeholder, in: shape)
    } else {
      shape
        .fill(Color(red: 0x3B / 255, green: 0x6C / 255, blue: 0xF6 / 255))
        .frame(width: 24, height: 24)
    }
  }

  private var openHistoryStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("Now bring them back"))

      OnboardingSubtitle(L10n.string("Press this shortcut to open your clipboard history."))
        .padding(.top, 10)

      OnboardingWaitingShortcut(shortcut: model.showHistoryShortcut)
        .padding(.top, 24)

      Text(L10n.string("Waiting for you to press it…"))
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(OnboardingPalette.accent)
        .padding(.top, 14)
    }
  }

  private var pasteBackStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("Paste one back"))

      OnboardingSubtitle(L10n.string("Choose any item in the history and press Return. It will be pasted here."))
        .padding(.top, 10)

      pasteField(isEditable: true)
        .padding(.top, 24)
    }
  }

  private func pastedStep(_ text: String) -> some View {
    VStack(spacing: 0) {
      OnboardingSuccessBadge()

      OnboardingTitle(L10n.string("That's the whole idea"))
        .padding(.top, 16)

      pasteField(isEditable: false)
        .padding(.top, 14)

      OnboardingSubtitle(L10n.string("Anything you copy can be pasted again, even hours later."))
        .padding(.top, 12)
    }
  }

  private func pasteField(isEditable: Bool) -> some View {
    OnboardingPasteField(
      text: $model.pasteFieldText,
      placeholder: L10n.string("Your pasted item appears here"),
      isEditable: isEditable
    ) { field in
      if isEditable {
        model.pasteField = field
        // The field is where the paste lands, so it holds the focus from the
        // start, even while the history window is the key window.
        DispatchQueue.main.async {
          field.window?.makeFirstResponder(field)
        }
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 44)
    .frame(maxWidth: 380)
    .background(OnboardingPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(isEditable ? OnboardingPalette.accent : OnboardingPalette.border, lineWidth: isEditable ? 2 : 1)
    )
  }

  private var accessibilityRequestStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("Paste like that in any app"))

      OnboardingSubtitle(L10n.string("ClipBook needs Accessibility permission to paste into other apps. In System Settings, switch on ClipBook in this list:"))
        .padding(.top, 10)

      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.string("Privacy & Security › Accessibility"))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        OnboardingAccessibilityList(isClipBookSwitchedOn: true, outlinesClipBook: true)
      }
      .padding(12)
      .frame(maxWidth: 360)
      .background(OnboardingPalette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06))
      )
      .padding(.top, 18)

      Button(L10n.string("Open System Settings")) {
        model.openAccessibilitySettings()
      }
      .onboardingPrimaryButtonStyle()
      .keyboardShortcut(.defaultAction)
      .padding(.top, 18)
    }
  }

  private var accessibilityWaitingStep: some View {
    VStack(spacing: 0) {
      OnboardingSpinner()

      OnboardingTitle(L10n.string("Waiting for permission…"))
        .padding(.top, 18)

      OnboardingSubtitle(L10n.string("Switch on ClipBook in the Accessibility list. This window continues by itself as soon as it is on."))
        .padding(.top, 10)

      Text(L10n.string("If ClipBook is already on, switch it off and on again."))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.top, 12)

      Button(L10n.string("Open Settings again")) {
        model.openAccessibilitySettings()
      }
      .onboardingSecondaryButtonStyle()
      .padding(.top, 18)
    }
  }

  private var accessibilityGrantedStep: some View {
    VStack(spacing: 0) {
      OnboardingSuccessBadge()

      OnboardingTitle(L10n.string("Direct paste is on"))
        .padding(.top, 16)

      OnboardingSubtitle(L10n.string("Return now pastes the chosen item into whatever app you are working in."))
        .padding(.top, 10)
    }
  }

  private var readyStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("You are ready"))

      VStack(spacing: 10) {
        OnboardingMenuBarIllustration(shortcut: model.showHistoryShortcut)

        HStack(spacing: 14) {
          OnboardingShortcutKeys(shortcut: model.showHistoryShortcut, keySize: 26)

          Text(L10n.string("opens your history in any app."))
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)

          Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 70)
        .background(OnboardingPalette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .frame(maxWidth: 320)
      .padding(.top, 24)
    }
  }

  // MARK: - Bottom bar

  private var bottomBar: some View {
    HStack(spacing: 10) {
      OnboardingProgressDots(step: model.step)
        // The dots are shorter than the buttons, so they sit further from the
        // bottom edge than the bar inset; the same distance from the left edge
        // keeps them evenly placed in the corner.
        .padding(.leading, (OnboardingButtonMetrics.height - OnboardingProgressDots.dotSize) / 2)

      Spacer()

      if model.step.previous != nil {
        Button(L10n.string("Back")) {
          model.goBack()
        }
        .onboardingSecondaryButtonStyle()
        .focusable(false)
      }

      forwardButton
    }
    .padding([.horizontal, .bottom], Self.bottomBarInset)
  }

  // The same distance from the bottom and the side edges of the window.
  private static let bottomBarInset: CGFloat = 20

  @ViewBuilder
  private var forwardButton: some View {
    switch forwardAction {
    case .primary(let title):
      Button(title) {
        model.goForward()
      }
      .onboardingPrimaryButtonStyle()
      .keyboardShortcut(.defaultAction)
      .focusable(false)
    case .secondary(let title):
      Button(title) {
        model.goForward()
      }
      .buttonStyle(OnboardingTextButtonStyle())
      .focusable(false)
    }
  }

  private enum ForwardAction {
    case primary(String)
    case secondary(String)
  }

  private var forwardAction: ForwardAction {
    switch model.step {
    case .welcome:
      return .primary(L10n.string("Continue"))
    case .copyItems:
      return model.areAllSamplesSaved ? .primary(L10n.string("Continue")) : .secondary(L10n.string("Skip"))
    case .openHistory:
      return .secondary(L10n.string("Skip"))
    case .pasteBack:
      return model.pastedText == nil ? .secondary(L10n.string("Skip")) : .primary(L10n.string("Continue"))
    case .accessibility:
      return model.accessibilityState == .granted ? .primary(L10n.string("Continue")) : .secondary(L10n.string("Not now"))
    case .ready:
      return .primary(L10n.string("Done"))
    }
  }
}

private struct OnboardingProgressDots: View {
  static let dotSize: CGFloat = 7

  let step: OnboardingStep

  var body: some View {
    HStack(spacing: 7) {
      ForEach(OnboardingStep.allCases) { item in
        Capsule()
          .fill(item == step ? Color.primary.opacity(0.45) : Color.primary.opacity(0.16))
          .frame(width: item == step ? 24 : Self.dotSize, height: Self.dotSize)
      }
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: step)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.string("Onboarding progress"))
    .accessibilityValue(step.title)
  }
}

/// The history shortcut in a frame that gently pulses while onboarding waits
/// for the user to press it.
private struct OnboardingWaitingShortcut: View {
  let shortcut: String
  @State private var isPulsing = false

  var body: some View {
    OnboardingShortcutKeys(shortcut: shortcut)
      .padding(10)
      .background(OnboardingPalette.accentTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(OnboardingPalette.accent, lineWidth: 2)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(OnboardingPalette.accent.opacity(isPulsing ? 0 : 0.35), lineWidth: 4)
          .padding(-5)
      )
      .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isPulsing)
      .onAppear {
        isPulsing = true
      }
  }
}

/// A drawing of the menu bar with ClipBook's icon and its menu open.
private struct OnboardingMenuBarIllustration: View {
  let shortcut: String

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Spacer()

        Circle()
          .fill(Color.primary.opacity(0.35))
          .frame(width: 10, height: 10)

        Image("StatusBarIcon")
          .renderingMode(.template)
          .foregroundStyle(.primary)
          .frame(width: 24, height: 20)
          .background(OnboardingPalette.cardBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(OnboardingPalette.accent, lineWidth: 1.5)
          )

        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(Color.primary.opacity(0.35))
          .frame(width: 10, height: 10)

        Capsule()
          .fill(Color.primary.opacity(0.35))
          .frame(width: 28, height: 6)
      }
      .padding(.horizontal, 10)
      .frame(height: 26)
      .background(Color.primary.opacity(0.1))

      VStack(alignment: .leading, spacing: 8) {
        VStack(spacing: 0) {
          menuItem(L10n.string("Open ClipBook"), shortcut: OnboardingShortcut.displayText(for: shortcut), isHighlighted: true)
          menuItem(L10n.string("Settings..."))
          menuItem(L10n.string("Quit"))
        }
        .padding(4)
        .background(OnboardingPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(.leading, 30)

        Text(L10n.string("ClipBook lives in the menu bar, not in the Dock."))
          .font(.system(size: 12))
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 10)
      .padding(.top, 4)
      .padding(.bottom, 12)
    }
    .background(OnboardingPalette.fill)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08))
    )
  }

  private func menuItem(_ title: String, shortcut: String? = nil, isHighlighted: Bool = false) -> some View {
    HStack {
      Text(title)
      Spacer()
      if let shortcut {
        Text(shortcut)
      }
    }
    .font(.system(size: 12))
    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(isHighlighted ? OnboardingPalette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
  }
}

enum OnboardingLanguage: String, CaseIterable, Identifiable {
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
