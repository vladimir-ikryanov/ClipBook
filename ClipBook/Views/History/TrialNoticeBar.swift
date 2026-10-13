import AppKit
import Combine
import SwiftUI

/// Shows the trial notice right below the toolbar of the history window. As a
/// titlebar accessory it sits outside of the list, so it is never selected or
/// scrolled away, and the list makes room for it through its safe area.
@MainActor
final class TrialNoticeAccessoryController: NSTitlebarAccessoryViewController {
  private static let height: CGFloat = 46

  private let coordinator: AppCoordinator
  private var cancellables: Set<AnyCancellable> = []
  /// Called when the notice shows up or goes away, which changes the safe area
  /// of the content below the toolbar.
  var onVisibilityChange: (() -> Void)?

  init(coordinator: AppCoordinator) {
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
    layoutAttribute = .bottom
    // Sized to fit, the accessory would only be as tall as the text and the
    // buttons, without the space around the strip.
    automaticallyAdjustsSize = false
    isHidden = coordinator.trialNotice == nil

    coordinator.$trialNotice
      .map { $0 == nil }
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] isHidden in
        guard let self, self.isHidden != isHidden else {
          return
        }

        self.isHidden = isHidden
        self.onVisibilityChange?()
      }
      .store(in: &cancellables)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let hostingView = NSHostingView(rootView: TrialNoticeBar(coordinator: coordinator))
    hostingView.sizingOptions = []
    hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: Self.height)
    view = hostingView
  }
}

private struct TrialNoticeBar: View {
  @ObservedObject var coordinator: AppCoordinator
  @State private var isHighlighted = false

  var body: some View {
    Group {
      if let notice = coordinator.trialNotice {
        if case .discount = notice {
          // The time left in the offer is kept current while the window is
          // open, and the notice falls back to the plain one once it is over.
          TimelineView(.periodic(from: .now, by: 60)) { context in
            content(for: notice, now: context.date)
          }
        } else {
          content(for: notice, now: Date())
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onReceive(coordinator.readOnlyHistoryActionAttempts) { _ in
      highlight()
    }
  }

  private func content(for notice: TrialNotice, now: Date) -> some View {
    let presentation = TrialNoticePresentation(notice: notice, now: now)
    return HStack(spacing: 10) {
      message(presentation)

      Spacer(minLength: 8)

      Group {
        Button(L10n.string("Activate License")) {
          coordinator.openSettings(section: .license)
        }

        Button(presentation.buyTitle) {
          coordinator.openBuyLicenseURL()
        }
        .buttonStyle(.borderedProminent)
      }
      .controlSize(.small)
      .capsuleButtonShape()

      if notice.isDismissible {
        Button {
          coordinator.dismissTrialNotice()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.string("Close"))
        .accessibilityLabel(L10n.string("Close"))
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, notice.isDismissible ? 12 : 16)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // The strip runs from one edge of the window to the other, like a bar of
    // the window rather than a card in the list.
    .background {
      Rectangle()
        .fill(.regularMaterial)
      Rectangle()
        .fill(presentation.tint.opacity(isHighlighted ? 0.32 : 0.12))
    }
  }

  /// The icon and the text. While the discount runs, clicking them shows the
  /// offer again, code and all.
  @ViewBuilder
  private func message(_ presentation: TrialNoticePresentation) -> some View {
    let label = HStack(spacing: 10) {
      Image(systemName: presentation.systemImageName)
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(presentation.tint)
        .frame(width: 24)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 1) {
        Text(presentation.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Text(presentation.message)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      // Lines the text up with the placeholder of the search field above it.
      .padding(.leading, 1)
    }
    .help("\(presentation.title)\n\(presentation.message)")

    if presentation.showsOffer {
      Button {
        coordinator.showTrialDiscountOffer()
      } label: {
        label.contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    } else {
      label.accessibilityElement(children: .combine)
    }
  }

  // An item that can't be used while the history is read-only flashes the
  // notice, which says why.
  private func highlight() {
    withAnimation(.easeOut(duration: 0.12)) {
      isHighlighted = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      withAnimation(.easeIn(duration: 0.4)) {
        isHighlighted = false
      }
    }
  }
}

private struct TrialNoticePresentation {
  let systemImageName: String
  let tint: Color
  let title: String
  let message: String
  let buyTitle: String
  var showsOffer = false

  init(notice: TrialNotice, now: Date) {
    switch notice {
    case .endingSoon(let daysLeft):
      systemImageName = "hourglass.bottomhalf.filled"
      tint = .orange
      title = daysLeft <= 1
        ? L10n.string("Last day of your trial")
        : L10n.string("%@ days left in your trial", String(daysLeft))
      message = L10n.string("Buy a license to keep using ClipBook.")
      buyTitle = L10n.string("Buy License")
    case .discount(let endsAt) where now < endsAt:
      let discount = "\(TrialOffer.discountPercent)%"
      let hoursLeft = Int(endsAt.timeIntervalSince(now) / 3600)
      systemImageName = "tag.fill"
      tint = .accentColor
      title = L10n.string("%@ off with code %@", discount, TrialOffer.discountCode)
      switch hoursLeft {
      case 2...:
        message = L10n.string("The offer ends in %@ hours.", String(hoursLeft))
      case 1:
        message = L10n.string("The offer ends in about an hour.")
      default:
        message = L10n.string("The offer ends in less than an hour.")
      }
      buyTitle = L10n.string("Buy with %@ Off", discount)
      showsOffer = true
    case .ended, .discount:
      systemImageName = "lock.fill"
      tint = .orange
      title = L10n.string("Your trial has ended")
      message = L10n.string("The history is read-only now.")
      buyTitle = L10n.string("Buy License")
    }
  }
}

private extension View {
  // The buttons are fully rounded, as they already are by default on macOS 26.
  @ViewBuilder
  func capsuleButtonShape() -> some View {
    if #available(macOS 14.0, *) {
      buttonBorderShape(.capsule)
    } else {
      self
    }
  }
}
