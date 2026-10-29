import AppKit
import SwiftUI

enum OnboardingPalette {
  static let accent = Color(red: 0.25, green: 0.36, blue: 0.89)
  static let accentTint = accent.opacity(0.1)
  /// The color of the primary button: the system accent color of the glass
  /// buttons on macOS 26 and later, and the onboarding accent before that.
  static var buttonAccent: Color {
    if #available(macOS 26.0, *) {
      return .accentColor
    }
    return accent
  }
  static let success = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark
      ? NSColor(red: 0.45, green: 0.78, blue: 0.47, alpha: 1)
      : NSColor(red: 0.22, green: 0.45, blue: 0.24, alpha: 1)
  })
  static let successTint = Color(red: 0.3, green: 0.65, blue: 0.33).opacity(0.18)
  static let windowBackground = NSColor(name: nil) { appearance in
    appearance.isDark ? .windowBackgroundColor : .white
  }
  static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0.17, alpha: 1) : .white
  })
  static let fill = Color.primary.opacity(0.05)
  static let placeholder = Color.primary.opacity(0.12)
  static let border = Color.primary.opacity(0.14)
  // The keys of the keyboard the history shortcut is drawn with: the dark
  // keys of a Mac keyboard in dark mode, light keys in light mode.
  static let keyTop = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0x1E / 255, alpha: 1) : .white
  })
  static let keyBottom = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0x16 / 255, alpha: 1) : NSColor(white: 0.955, alpha: 1)
  })
  static let keyBorder = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0x4A / 255, alpha: 1) : NSColor(white: 0.82, alpha: 1)
  })
  static let keyHighlight = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 1, alpha: 0.07) : NSColor(white: 1, alpha: 0.9)
  })
  static let keyShade = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0, alpha: 0.35) : NSColor(white: 0, alpha: 0.035)
  })
  static let keyLabel = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.isDark ? NSColor(white: 0xF4 / 255, alpha: 1) : NSColor(white: 0.36, alpha: 1)
  })
}

private extension NSAppearance {
  var isDark: Bool {
    bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
  }
}

struct OnboardingAppIcon: View {
  let size: CGFloat

  var body: some View {
    Image(nsImage: NSApp.applicationIconImage)
      .resizable()
      .interpolation(.high)
      .frame(width: size, height: size)
  }
}

struct OnboardingTitle: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.system(size: 30, weight: .bold))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct OnboardingSubtitle: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.system(size: 15))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct OnboardingSuccessBadge: View {
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 22, weight: .bold))
      .foregroundStyle(OnboardingPalette.success)
      .frame(width: 54, height: 54)
      .background(OnboardingPalette.successTint, in: Circle())
  }
}

/// A key of a keyboard shortcut drawn as a key cap.
struct OnboardingKeyCap: View {
  let text: String
  var size: CGFloat = 46

  var body: some View {
    Text(text)
      .font(.system(size: size * 0.4, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(minWidth: size, minHeight: size)
      .padding(.horizontal, text.count > 1 ? size * 0.3 : 0)
      .background(OnboardingPalette.cardBackground, in: RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
      .shadow(color: .black.opacity(0.16), radius: 0.5, y: 1)
      .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
  }
}

struct OnboardingShortcutKeys: View {
  let shortcut: String
  var keySize: CGFloat = 46

  var body: some View {
    HStack(spacing: keySize * 0.2) {
      ForEach(Array(OnboardingShortcut.displayParts(for: shortcut).enumerated()), id: \.offset) { _, part in
        OnboardingKeyCap(text: part, size: keySize)
      }
    }
  }
}

enum OnboardingShortcut {
  static func displayParts(for shortcut: String) -> [String] {
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
    result.append(KeyboardShortcutParser.keyDisplayText(for: key))
    return result
  }

  static func displayText(for shortcut: String) -> String {
    displayParts(for: shortcut).joined()
  }
}

/// A drawing of the System Settings Accessibility list with ClipBook in it.
struct OnboardingAccessibilityList: View {
  let isClipBookSwitchedOn: Bool
  var showsPlaceholderName = false
  var outlinesClipBook = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(OnboardingPalette.placeholder)
          .frame(width: 22, height: 22)

        if showsPlaceholderName {
          Text(L10n.string("Another app"))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        } else {
          Capsule()
            .fill(OnboardingPalette.placeholder)
            .frame(width: 110, height: 7)
        }

        Spacer(minLength: 0)

        OnboardingSwitch(isOn: false)
      }
      .padding(.horizontal, 12)
      .frame(height: 42)

      Divider()
        .opacity(outlinesClipBook ? 0 : 1)

      HStack(spacing: 12) {
        OnboardingAppIcon(size: 24)

        Text("ClipBook")
          .font(.system(size: 13, weight: .semibold))

        Spacer(minLength: 0)

        OnboardingSwitch(isOn: isClipBookSwitchedOn, isEmphasized: true)
      }
      .padding(.horizontal, 12)
      .frame(height: 42)
      .background(OnboardingPalette.accentTint)
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(OnboardingPalette.accent, lineWidth: 1.5)
          .opacity(outlinesClipBook ? 1 : 0)
      )
    }
    .background(OnboardingPalette.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(OnboardingPalette.border.opacity(0.7))
    )
  }
}

struct OnboardingSwitch: View {
  let isOn: Bool
  var isEmphasized = false

  var body: some View {
    Capsule()
      .fill(isOn ? OnboardingPalette.accent : Color.primary.opacity(isEmphasized ? 0.45 : 0.16))
      .frame(width: 34, height: 20)
      .overlay(alignment: isOn ? .trailing : .leading) {
        Circle()
          .fill(.white)
          .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
          .padding(2)
      }
  }
}

enum OnboardingButtonMetrics {
  /// The height of the onboarding buttons, which the glass buttons of
  /// macOS 26 get from their control size and the older styles match.
  static let height: CGFloat = 36
}

extension View {
  /// The accent colored button that moves onboarding on: a prominent glass
  /// button on macOS 26 and later, like the system's own apps.
  @ViewBuilder
  func onboardingPrimaryButtonStyle() -> some View {
    if #available(macOS 26.0, *) {
      buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
    } else {
      buttonStyle(OnboardingPrimaryButtonStyle())
    }
  }

  @ViewBuilder
  func onboardingSecondaryButtonStyle() -> some View {
    if #available(macOS 26.0, *) {
      buttonStyle(.glass)
        .controlSize(.extraLarge)
    } else {
      buttonStyle(OnboardingSecondaryButtonStyle())
    }
  }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 22)
      .frame(minHeight: OnboardingButtonMetrics.height)
      .background(OnboardingPalette.accent, in: Capsule())
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
      .contentShape(Capsule())
  }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15))
      .foregroundStyle(.primary)
      .padding(.horizontal, 20)
      .frame(minHeight: OnboardingButtonMetrics.height)
      .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0), in: Capsule())
      .overlay(Capsule().strokeBorder(OnboardingPalette.border))
      .contentShape(Capsule())
  }
}

struct OnboardingTextButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .frame(minHeight: OnboardingButtonMetrics.height)
      .opacity(configuration.isPressed ? 0.6 : 1)
      .contentShape(Rectangle())
  }
}

struct OnboardingCopyButtonStyle: ButtonStyle {
  let height: CGFloat
  let cornerRadius: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.primary)
      .padding(.horizontal, 12)
      .frame(minHeight: height)
      .background(OnboardingPalette.cardBackground, in: shape)
      .overlay(shape.strokeBorder(OnboardingPalette.border))
      .opacity(configuration.isPressed ? 0.7 : 1)
      .contentShape(Rectangle())
  }
}

/// An indeterminate progress ring, drawn rather than taken from
/// ProgressView so it matches the accent color in both appearances.
struct OnboardingSpinner: View {
  @State private var isRotating = false

  var body: some View {
    ZStack {
      Circle()
        .stroke(OnboardingPalette.accent.opacity(0.18), lineWidth: 3)
      Circle()
        .trim(from: 0, to: 0.22)
        .stroke(OnboardingPalette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(isRotating ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
    }
    .frame(width: 54, height: 54)
    .onAppear {
      isRotating = true
    }
  }
}

/// The field onboarding pastes into. AppKit's own text field, so a paste from
/// the history goes through the regular paste action of its field editor.
struct OnboardingPasteField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let isEditable: Bool
  let onMake: (NSTextField) -> Void

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField()
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 15)
    field.lineBreakMode = .byTruncatingTail
    field.cell?.usesSingleLineMode = true
    field.delegate = context.coordinator
    onMake(field)
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    if field.stringValue != text {
      field.stringValue = text
    }
    field.placeholderString = placeholder
    field.isEditable = isEditable
    field.isSelectable = true
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else {
        return
      }
      text.wrappedValue = field.stringValue
    }
  }
}
