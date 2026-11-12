import SwiftUI

/// The two list modes of the history as large pictures with their names under
/// them, like the appearance choice in the macOS setup assistant. The
/// pictures are the ones the List mode setting shows, drawn bigger.
struct OnboardingListModePicker: View {
  let isCompact: Bool
  let select: (Bool) -> Void

  var body: some View {
    HStack(spacing: 24) {
      OnboardingListModeOption(title: L10n.string("Comfortable"), isCompact: false, isSelected: !isCompact) {
        select(false)
      }
      OnboardingListModeOption(title: L10n.string("Compact"), isCompact: true, isSelected: isCompact) {
        select(true)
      }
    }
  }
}

private struct OnboardingListModeOption: View {
  let title: String
  let isCompact: Bool
  let isSelected: Bool
  let action: () -> Void

  /// The size the setting draws its preview at, which is scaled up here so
  /// the drawing keeps its proportions.
  private static let settingsPreviewSize = CGSize(width: 93, height: 58.5)
  private static let scale: CGFloat = 1.6
  private static let cornerRadius: CGFloat = 10
  private static let selectionWidth: CGFloat = 3
  private static let selectionGap: CGFloat = 3

  var body: some View {
    let size = CGSize(
      width: Self.settingsPreviewSize.width * Self.scale,
      height: Self.settingsPreviewSize.height * Self.scale
    )
    Button(action: action) {
      VStack(spacing: 10) {
        HistoryDensityPreview(isCompact: isCompact, isSelected: isSelected)
          .frame(width: Self.settingsPreviewSize.width, height: Self.settingsPreviewSize.height)
          .scaleEffect(Self.scale)
          .frame(width: size.width, height: size.height)
          // Like the setting, an unselected picture loses its color.
          .saturation(isSelected ? 1 : 0)
          .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
          .overlay {
            if isSelected {
              let outset = Self.selectionWidth + Self.selectionGap
              RoundedRectangle(cornerRadius: Self.cornerRadius + outset, style: .continuous)
                .strokeBorder(OnboardingPalette.buttonAccent, lineWidth: Self.selectionWidth)
                .padding(-outset)
            }
          }

        Text(title)
          .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .primary : .secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(PreviewOptionButtonStyle())
    .focusable(false)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
