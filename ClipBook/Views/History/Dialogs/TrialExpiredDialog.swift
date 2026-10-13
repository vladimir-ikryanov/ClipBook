import AppKit
import SwiftUI

struct TrialExpiredFeedback {
  let reasons: [String]
  let message: String
  let email: String
}

/// The dialogs that follow the trial: the one about its end, and the discount
/// offered a week later.
enum TrialSheet {
  case trialExpired
  case discount(endsAt: Date)
}

/// How a trial dialog was left. Closing it leaves the history open to be
/// looked through read-only.
enum TrialSheetAction {
  case close
  case activateLicense
  case buyLicense
}

// The dialog is measured once and the sheet keeps that size. Sized from its
// content, the sheet would be resized in the middle of a layout pass, which
// AppKit stops with an exception.
private final class TrialSheetController: NSHostingController<AnyView> {
  var onCancel: (() -> Void)?

  override init(rootView: AnyView) {
    super.init(rootView: rootView)
    sizingOptions = []
    let unboundedSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    preferredContentSize = sizeThatFits(in: unboundedSize)
  }

  @available(*, unavailable)
  @MainActor required dynamic init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }
}

extension HistoryWindow {
  @discardableResult
  func showTrialSheet(
    _ sheet: TrialSheet,
    hasProvidedFeedback: Bool,
    onSendFeedback: @escaping (TrialExpiredFeedback) -> Void,
    onCopyDiscountCode: @escaping () -> Void,
    onDismiss: @escaping (TrialSheetAction) -> Void
  ) -> Bool {
    guard window.attachedSheet == nil else {
      return false
    }

    var action = TrialSheetAction.close
    weak var dialogWindow: NSWindow?
    let finish = { [weak self] (finishingAction: TrialSheetAction) in
      guard let self, let dialogWindow else {
        return
      }

      action = finishingAction
      self.window.endSheet(dialogWindow)
    }

    let rootView: AnyView
    switch sheet {
    case .trialExpired:
      rootView = AnyView(TrialExpiredDialogView(
        showsFeedbackControls: !hasProvidedFeedback,
        onSendFeedback: { feedback in
          onSendFeedback(feedback)
          finish(.close)
        },
        onActivateLicense: { finish(.activateLicense) },
        onBuyLicense: { finish(.buyLicense) },
        onClose: { finish(.close) }
      ))
    case .discount(let endsAt):
      rootView = AnyView(TrialDiscountDialogView(
        endsAt: endsAt,
        onCopyCode: onCopyDiscountCode,
        onActivateLicense: { finish(.activateLicense) },
        onBuyLicense: { finish(.buyLicense) },
        onClose: { finish(.close) }
      ))
    }

    let dialogController = TrialSheetController(rootView: rootView)
    dialogController.onCancel = { finish(.close) }
    let sheetWindow = NSWindow(contentViewController: dialogController)
    sheetWindow.styleMask = [.titled]
    sheetWindow.titleVisibility = .hidden
    sheetWindow.titlebarAppearsTransparent = true
    sheetWindow.backgroundColor = .windowBackgroundColor
    sheetWindow.isReleasedWhenClosed = false
    sheetWindow.standardWindowButton(.closeButton)?.isHidden = true
    sheetWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
    sheetWindow.standardWindowButton(.zoomButton)?.isHidden = true
    dialogWindow = sheetWindow

    window.beginSheet(sheetWindow) { _ in
      onDismiss(action)
    }
    return true
  }
}

private struct TrialExpiredDialogView: View {
  private static func width(showsFeedbackControls: Bool) -> CGFloat {
    showsFeedbackControls ? 608 : 520
  }

  private let reasons = [
    L10n.string("Missing features"),
    L10n.string("Don't need it right now"),
    L10n.string("Wasn't useful for me"),
    L10n.string("Other (please specify)")
  ]

  let showsFeedbackControls: Bool
  let onSendFeedback: (TrialExpiredFeedback) -> Void
  let onActivateLicense: () -> Void
  let onBuyLicense: () -> Void
  let onClose: () -> Void

  @State private var selectedReasons: Set<String> = []
  @State private var feedback = ""
  @State private var email = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .center) {
          Text(L10n.string("Your trial has ended :("))
            .font(.title2.weight(.semibold))
          Spacer()
          TrialSheetCloseButton(action: onClose)
        }

        Text(L10n.string("I hope you enjoyed using ClipBook. If you like it, please consider supporting the development by purchasing a license."))
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.bottom, 14)

      VStack(alignment: .leading, spacing: 8) {
        TrialSheetFact(
          systemImageName: "eye",
          text: L10n.string("Your history is kept and stays visible in read-only mode. Activate a license to copy, paste and edit your items again.")
        )
        TrialSheetFact(
          systemImageName: "checkmark.shield",
          text: L10n.string("Every license comes with a %@-day money-back guarantee.", String(TrialOffer.moneyBackGuaranteeDays))
        )
      }
      .padding(.bottom, 20)

      if showsFeedbackControls {
        Text(L10n.string("If you don't like it, please let me know why."))
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 10)

        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(reasons, id: \.self) { reason in
              Toggle(reason, isOn: binding(for: reason))
                .toggleStyle(.checkbox)
            }
          }
          .frame(width: 180, alignment: .leading)

          VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
              TextEditor(text: $feedback)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

              if feedback.isEmpty {
                Text(L10n.string("Your feedback"))
                  .font(.body)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 8)
                  .allowsHitTesting(false)
              }
            }
            .frame(height: 80)
            .background {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            }

            TextField(L10n.string("Email for response (optional)"), text: $email)
              .textFieldStyle(.roundedBorder)
              .font(.body)
          }
          .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 20)
      }

      HStack(alignment: .bottom, spacing: 14) {
        TrialSheetSignature()

        Spacer()

        HStack(spacing: 8) {
          if showsFeedbackControls {
            Button(L10n.string("Send Feedback")) {
              sendFeedback()
            }
            .controlSize(.large)
          }

          Button(L10n.string("Activate License")) {
            onActivateLicense()
          }
          .controlSize(.large)

          Button(L10n.string("Buy License")) {
            onBuyLicense()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 22)
    .frame(width: Self.width(showsFeedbackControls: showsFeedbackControls), alignment: .topLeading)
    .fixedSize(horizontal: false, vertical: true)
    .onExitCommand(perform: onClose)
  }

  private func binding(for reason: String) -> Binding<Bool> {
    Binding(
      get: {
        selectedReasons.contains(reason)
      },
      set: { isSelected in
        if isSelected {
          selectedReasons.insert(reason)
        } else {
          selectedReasons.remove(reason)
        }
      }
    )
  }

  private func sendFeedback() {
    onSendFeedback(
      TrialExpiredFeedback(
        reasons: reasons.filter(selectedReasons.contains),
        message: feedback.trimmingCharacters(in: .whitespacesAndNewlines),
        email: email.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    )
  }
}

private struct TrialDiscountDialogView: View {
  let endsAt: Date
  let onCopyCode: () -> Void
  let onActivateLicense: () -> Void
  let onBuyLicense: () -> Void
  let onClose: () -> Void

  @State private var didCopyCode = false

  private var discount: String {
    "\(TrialOffer.discountPercent)%"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Text(L10n.string("Here's %@ off ClipBook", discount))
          .font(.title2.weight(.semibold))

        Text(L10n.string("Your trial ended a week ago, and your clipboard history is still here, waiting. Use this code at checkout to get %@ off a license.", discount))
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.bottom, 16)

      HStack(spacing: 12) {
        Text(TrialOffer.discountCode)
          .font(.system(size: 22, weight: .semibold, design: .monospaced))
          .textSelection(.enabled)

        Spacer()

        Button {
          onCopyCode()
          didCopyCode = true
        } label: {
          Label(
            didCopyCode ? L10n.string("Copied") : L10n.string("Copy Code"),
            systemImage: didCopyCode ? "checkmark" : "doc.on.doc"
          )
        }
        .controlSize(.large)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.accentColor.opacity(0.08))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
      }
      .padding(.bottom, 14)

      VStack(alignment: .leading, spacing: 8) {
        TrialSheetFact(
          systemImageName: "clock",
          text: L10n.string("The offer ends %@.", endsAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened).locale(L10n.currentLocale)
          ))
        )
        TrialSheetFact(
          systemImageName: "checkmark.shield",
          text: L10n.string("Every license comes with a %@-day money-back guarantee.", String(TrialOffer.moneyBackGuaranteeDays))
        )
      }
      .padding(.bottom, 20)

      HStack(alignment: .center, spacing: 14) {
        // Closes the offer, the way setup assistants let a step be skipped.
        Button(L10n.string("Not Interested"), action: onClose)
          .buttonStyle(.link)

        Spacer()

        HStack(spacing: 8) {
          Button(L10n.string("Activate License")) {
            onActivateLicense()
          }
          .controlSize(.large)

          Button(L10n.string("Buy with %@ Off", discount)) {
            onBuyLicense()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 22)
    .frame(width: 520, alignment: .topLeading)
    .fixedSize(horizontal: false, vertical: true)
    .onExitCommand(perform: onClose)
  }
}

private struct TrialSheetFact: View {
  let systemImageName: String
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: systemImageName)
        .foregroundStyle(.secondary)
        .frame(width: 18)
        .accessibilityHidden(true)
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(.body)
  }
}

private struct TrialSheetCloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 22)
        .background(Circle().fill(Color.secondary.opacity(0.12)))
    }
    .buttonStyle(.plain)
    .help(L10n.string("Close"))
    .accessibilityLabel(L10n.string("Close"))
    // Raised a little above the middle of the title, toward the corner of the
    // dialog it closes.
    .offset(y: -4)
  }
}

private struct TrialSheetSignature: View {
  var body: some View {
    HStack(spacing: 10) {
      Group {
        if let photo = NSImage(named: "photo48x48") {
          Image(nsImage: photo)
            .resizable()
            .scaledToFill()
        } else {
          Color.secondary.opacity(0.18)
        }
      }
      .frame(width: 32, height: 32)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text("Vladimir Ikryanov")
          .font(.headline)
          .fontWeight(.semibold)
        Text(L10n.string("Founder of ClipBook"))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}
