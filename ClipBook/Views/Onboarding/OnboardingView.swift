import AppKit
import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingModel
  @ObservedObject var appModel: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  init(model: OnboardingModel) {
    self.model = model
    self.appModel = model.appModel
  }

  var body: some View {
    VStack(spacing: 0) {
      stepContent
        .id(model.step)
        .transition(stepTransition)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 28)

      bottomBar
    }
    .animation(stepAnimation, value: model.step)
    .id(appModel.localizationRevision)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: OnboardingPalette.windowBackground))
    .ignoresSafeArea()
  }

  private static let stepSlideDistance: CGFloat = 80

  // The next step comes in from the side it lies on: from the right going
  // forward, from the left going back. With Reduce Motion the steps only fade.
  private var stepTransition: AnyTransition {
    guard !reduceMotion else {
      return .opacity
    }

    let distance = model.navigationDirection == .forward ? Self.stepSlideDistance : -Self.stepSlideDistance
    return .asymmetric(
      insertion: .offset(x: distance).combined(with: .opacity),
      removal: .offset(x: -distance).combined(with: .opacity)
    )
  }

  private var stepAnimation: Animation {
    reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.36, dampingFraction: 0.9)
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
      pasteBackStep
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
      OnboardingAppIcon(size: 100)

      OnboardingTitle(L10n.string("Welcome to ClipBook"))
        .padding(.top, 16)

      OnboardingSubtitle(L10n.string("Keep, organize, find, and reuse everything you copy."))
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 18) {
        OnboardingFeatureRow(
          systemImage: "keyboard",
          title: L10n.string("Keyboard first"),
          description: L10n.string(
            "Press %@, type to search, and press Return to paste. You never need to reach for the mouse.",
            OnboardingShortcut.displayText(for: model.showHistoryShortcut)
          )
        )
        OnboardingFeatureRow(
          systemImage: "lock.shield",
          // The shield is narrow and tall, so it needs a larger size to look
          // as big as the other icons.
          iconSize: 24,
          title: L10n.string("Private by design"),
          description: L10n.string("Your history stays on this Mac. Passwords are masked, the history is hidden during screen sharing, and you can ignore specific apps. You decide what is kept and for how long.")
        )
        OnboardingFeatureRow(
          systemImage: "square.stack.3d.up",
          title: L10n.string("Built for power users"),
          description: L10n.string("Copy and merge, paste a copy sequence without opening the history, paste several items at once with separators, filters, a trash, and more.")
        )
      }
      .frame(maxWidth: 400)
      .padding(.top, 44)
    }
  }

  private var copyItemsStep: some View {
    VStack(spacing: 0) {
      OnboardingClipKindsIllustration()

      OnboardingTitle(L10n.string("Copy these four things"))
        .padding(.top, 14)

      OnboardingSubtitle(L10n.string("ClipBook runs in the background and remembers everything you copy, so you can find and copy/paste it again."))
        .padding(.top, 8)

      VStack(spacing: 8) {
        ForEach(OnboardingSample.allCases) { sample in
          sampleRow(sample)
        }
      }
      .padding(.top, 18)

      Text(L10n.string("%@ of %@ saved", String(model.savedSamples.count), String(OnboardingSample.allCases.count)))
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.top, 12)
    }
  }

  private func sampleRow(_ sample: OnboardingSample) -> some View {
    HStack(spacing: 12) {
      sampleIcon(sample)

      // The screenshot speaks for itself; its name is only read out by
      // VoiceOver.
      if sample != .image {
        Text(sample.text)
          .font(.system(size: 14))
          .lineLimit(1)
          .textSelection(.enabled)
      }

      Spacer(minLength: 8)

      if model.savedSamples.contains(sample) {
        HStack(spacing: 6) {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
          Text(L10n.string("Saved"))
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(OnboardingPalette.success)
        .padding(.horizontal, 8)
        .frame(minHeight: SampleRowMetrics.controlHeight)
        .transition(.opacity)
      } else {
        Button(L10n.string("Copy")) {
          model.copy(sample)
        }
        .buttonStyle(OnboardingCopyButtonStyle(
          height: SampleRowMetrics.controlHeight,
          cornerRadius: SampleRowMetrics.innerCornerRadius
        ))
        .focusable(false)
      }
    }
    .padding(SampleRowMetrics.inset)
    .background(OnboardingPalette.fill, in: RoundedRectangle(cornerRadius: SampleRowMetrics.cornerRadius, style: .continuous))
    .frame(maxWidth: 420)
  }

  @ViewBuilder
  private func sampleIcon(_ sample: OnboardingSample) -> some View {
    let shape = RoundedRectangle(cornerRadius: SampleRowMetrics.innerCornerRadius, style: .continuous)
    let size = SampleRowMetrics.controlHeight
    switch sample {
    case .image:
      Image(OnboardingSample.screenshotImageName(isDark: colorScheme == .dark))
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: SampleRowMetrics.imageHeight * 1.58, height: SampleRowMetrics.imageHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.1)))
        .accessibilityLabel(sample.text)
    case .color:
      Circle()
        .fill(Color(red: 0x3B / 255, green: 0x6C / 255, blue: 0xF6 / 255))
        .frame(width: size, height: size)
    case .note, .link:
      Image(systemName: sample.systemImage ?? "doc")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: size, height: size)
        .background(OnboardingPalette.placeholder, in: shape)
    }
  }

  private var openHistoryStep: some View {
    VStack(spacing: 0) {
      OnboardingTitle(L10n.string("Open your clipboard history"))

      OnboardingSubtitle(L10n.string("Press this shortcut to open your clipboard history."))
        .padding(.top, 10)

      OnboardingWaitingShortcut(shortcut: model.showHistoryShortcut)
        .padding(.top, 36)

      OnboardingShimmeringText(L10n.string("Waiting for you to press it…"))
        .padding(.top, 30)
    }
  }

  private var pasteBackStep: some View {
    let isPasted = model.pastedText != nil
    return VStack(spacing: 0) {
      // Its place is kept from the start, so nothing moves when it appears.
      OnboardingSuccessBadge()
        .opacity(isPasted ? 1 : 0)
        .scaleEffect(isPasted || reduceMotion ? 1 : 0.7)
        .accessibilityHidden(!isPasted)

      OnboardingTitle(isPasted ? L10n.string("That's the whole idea") : L10n.string("Paste one back"))
        .padding(.top, 16)

      OnboardingSubtitle(
        isPasted
          ? L10n.string("Open your history anytime, find what you copied, and copy or paste it again.")
          : L10n.string("Choose any item in the history and press Return. It will be pasted here.")
      )
      .padding(.top, 10)

      pasteArea(isPasted: isPasted)
        .padding(.top, 24)
    }
  }

  // Three rows of text, which keeps its size once something is pasted. A
  // pasted image sits at the top left of it like text does.
  private func pasteArea(isPasted: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    return Group {
      if let image = model.pastedImage {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        OnboardingPasteField(
          text: $model.pasteFieldText,
          placeholder: L10n.string("Your pasted item appears here"),
          isEditable: !isPasted
        ) { field in
          model.pasteField = field
          guard !isPasted else {
            return
          }
          // The field is where the paste lands, so it holds the focus from the
          // start, even while the history window is the key window.
          DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(height: 84)
    .frame(maxWidth: 380)
    .background(OnboardingPalette.cardBackground, in: shape)
    .overlay(
      shape.strokeBorder(isPasted ? OnboardingPalette.border : OnboardingPalette.accent, lineWidth: isPasted ? 1 : 2)
    )
  }

  private var accessibilityRequestStep: some View {
    VStack(spacing: 0) {
      Image(systemName: "accessibility")
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(OnboardingPalette.keyLabel)
        .frame(width: 64, height: 64)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)

      OnboardingTitle(L10n.string("Paste like that in any app"))
        .padding(.top, 16)

      OnboardingSubtitle(L10n.string("ClipBook needs Accessibility permission to paste into other apps. In System Settings, switch on ClipBook in this list:"))
        .padding(.top, 10)

      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.string("Privacy & Security › Accessibility"))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        Image("OnboardingAccessibilityPermission")
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .frame(width: 340)
          .accessibilityHidden(true)
      }
      .padding(.top, 30)

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
        .padding(.top, 32)

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

/// The rows of the things to copy. The controls inside a row are inset the
/// same distance from every edge, and their corners are concentric with the
/// row's.
private enum SampleRowMetrics {
  static let cornerRadius: CGFloat = 16
  static let inset: CGFloat = 10
  static let innerCornerRadius: CGFloat = cornerRadius - inset
  static let controlHeight: CGFloat = 26
  static let imageHeight: CGFloat = 58
}

/// Cards of the kinds of things ClipBook remembers: text, images, links,
/// colors and files.
private struct OnboardingClipKindsIllustration: View {
  var body: some View {
    Image("OnboardingClipKinds")
      .resizable()
      .interpolation(.high)
      .aspectRatio(contentMode: .fit)
      .frame(width: 240)
      // The cards' shadow fills the bottom of the picture, so the title moves
      // up into it rather than leaving a gap.
      .padding(.bottom, -14)
      .accessibilityHidden(true)
  }
}

/// One of the features the welcome step introduces ClipBook with.
private struct OnboardingFeatureRow: View {
  let systemImage: String
  var iconSize: CGFloat = 20
  let title: String
  let description: String

  var body: some View {
    // Each icon is centered on the line of its title, whatever its height.
    HStack(alignment: .featureTitleCenter, spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: iconSize, weight: .medium))
        .foregroundStyle(OnboardingPalette.buttonAccent)
        .frame(width: 28)
        .alignmentGuide(.featureTitleCenter) { $0[VerticalAlignment.center] }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .alignmentGuide(.featureTitleCenter) { $0[VerticalAlignment.center] }

        Text(description)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }
}

private extension VerticalAlignment {
  private enum FeatureTitleCenter: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
      dimensions[VerticalAlignment.center]
    }
  }

  static let featureTitleCenter = VerticalAlignment(FeatureTitleCenter.self)
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

/// The keys of the history shortcut: a picture for the default shortcut, and
/// keys drawn the same way for a shortcut that was changed.
private struct OnboardingWaitingShortcut: View {
  let shortcut: String

  // The keys' proportions follow a keyboard: everything is a share of the
  // height of a key, and the whole row shrinks to fit the window.
  private static let maximumKeyHeight: CGFloat = 62
  private static let maximumWidth: CGFloat = 400
  private static let gap: CGFloat = 0.16

  var body: some View {
    if shortcut == AppPreferences.defaultShowHistoryShortcut {
      Image("OnboardingHistoryShortcut")
        .resizable()
        .interpolation(.high)
        .aspectRatio(contentMode: .fit)
        .frame(width: 340)
        .accessibilityLabel(OnboardingShortcut.displayText(for: shortcut))
    } else {
      drawnKeys
    }
  }

  private var drawnKeys: some View {
    let keys = OnboardingKeyboardKey.keys(for: shortcut)
    let units = keys.reduce(0) { $0 + $1.width } + Self.gap * CGFloat(max(keys.count - 1, 0))
    let keyHeight = min(Self.maximumKeyHeight, Self.maximumWidth / units)

    return HStack(spacing: keyHeight * Self.gap) {
      ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
        OnboardingKeyCapView(key: key, height: keyHeight)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(OnboardingShortcut.displayText(for: shortcut))
  }
}

/// Gray text with a highlight that sweeps across it from left to right,
/// to show that something is waiting. With Reduce Motion it stays still.
private struct OnboardingShimmeringText: View {
  let text: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: CGFloat = 0

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    label
      .foregroundStyle(.secondary)
      .overlay {
        if !reduceMotion {
          GeometryReader { geometry in
            let bandWidth = geometry.size.width * 0.35
            LinearGradient(
              colors: [.clear, Color.primary.opacity(0.85), .clear],
              startPoint: .leading,
              endPoint: .trailing
            )
            .frame(width: bandWidth)
            .offset(x: -bandWidth + progress * (geometry.size.width + bandWidth))
          }
          .mask(label)
        }
      }
      .onAppear {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
          progress = 1
        }
      }
  }

  private var label: some View {
    Text(text)
      .font(.system(size: 13, weight: .medium))
  }
}

/// A key of a Mac keyboard: a modifier shows its word at the bottom left and
/// its symbol at the top right, any other key its label in the middle.
struct OnboardingKeyboardKey {
  let word: String?
  let symbol: String?
  /// The width as a share of the key's height.
  let width: CGFloat

  static func keys(for shortcut: String) -> [OnboardingKeyboardKey] {
    let parts = shortcut.lowercased().split(separator: "+").map(String.init)
    guard let key = parts.last, !shortcut.isEmpty else {
      return [OnboardingKeyboardKey(word: nil, symbol: L10n.string("Not set"), width: 1.6)]
    }

    // In the order macOS lists modifiers in.
    var keys: [OnboardingKeyboardKey] = []
    if parts.contains("control") || parts.contains("ctrl") {
      keys.append(OnboardingKeyboardKey(word: "control", symbol: "⌃", width: 1.3))
    }
    if parts.contains("option") || parts.contains("alt") {
      keys.append(OnboardingKeyboardKey(word: "option", symbol: "⌥", width: 1.3))
    }
    if parts.contains("shift") {
      keys.append(OnboardingKeyboardKey(word: "shift", symbol: nil, width: 2.2))
    }
    if parts.contains("cmd") || parts.contains("command") {
      keys.append(OnboardingKeyboardKey(word: "command", symbol: "⌘", width: 1.3))
    }
    let label = KeyboardShortcutParser.keyDisplayText(for: key)
    keys.append(OnboardingKeyboardKey(word: nil, symbol: label, width: label.count > 1 ? 1.6 : 1))
    return keys
  }
}

struct OnboardingKeyCapView: View {
  static let cornerRadiusRatio: CGFloat = 0.095

  let key: OnboardingKeyboardKey
  let height: CGFloat

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: height * Self.cornerRadiusRatio, style: .continuous)
    ZStack {
      if let word = key.word {
        VStack(alignment: .leading, spacing: 0) {
          if let symbol = key.symbol {
            Text(symbol)
              .font(.system(size: height * 0.24, weight: .medium))
              .frame(maxWidth: .infinity, alignment: .trailing)
              .padding(.top, height * 0.02)
          }
          Spacer(minLength: 0)
          Text(word)
            .font(.system(size: height * 0.22))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.top, height * 0.116)
        .padding(.horizontal, height * 0.126)
        .padding(.bottom, height * 0.126)
      } else if let symbol = key.symbol {
        Text(symbol)
          .font(.system(size: height * 0.25))
          .lineLimit(1)
      }
    }
    .foregroundStyle(OnboardingPalette.keyLabel)
    .frame(width: height * key.width, height: height)
    .background(
      LinearGradient(colors: [OnboardingPalette.keyTop, OnboardingPalette.keyBottom], startPoint: .top, endPoint: .bottom),
      in: shape
    )
    // The light catching the top edge and the shade at the bottom of a key.
    .overlay(
      shape
        .strokeBorder(
          LinearGradient(colors: [OnboardingPalette.keyHighlight, .clear], startPoint: .top, endPoint: .center),
          lineWidth: 1
        )
        .padding(1)
    )
    .overlay(
      LinearGradient(colors: [.clear, OnboardingPalette.keyShade], startPoint: .init(x: 0.5, y: 0.7), endPoint: .bottom)
        .clipShape(shape)
    )
    .overlay(shape.strokeBorder(OnboardingPalette.keyBorder, lineWidth: 1))
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
