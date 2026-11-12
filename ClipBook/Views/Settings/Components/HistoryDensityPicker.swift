import SwiftUI

/// Picks the height of the rows in the history list. Compact rows show one
/// line per item, so more items fit in the window.
struct HistoryDensityPicker: View {
    @Binding var isCompact: Bool

    var body: some View {
        PreviewOptionPicker(title: L10n.string("List mode")) {
            PreviewOption(title: L10n.string("Comfortable"), isSelected: !isCompact, fadesWhenUnselected: false) {
                isCompact = false
            } preview: {
                HistoryDensityPreview(isCompact: false, isSelected: !isCompact)
            }
            PreviewOption(title: L10n.string("Compact"), isSelected: isCompact, fadesWhenUnselected: false) {
                isCompact = true
            } preview: {
                HistoryDensityPreview(isCompact: true, isSelected: isCompact)
            }
        }
    }
}

/// A small drawing of the history window with regular or compact rows,
/// zoomed in so the difference in row height is easy to see.
private struct HistoryDensityPreview: View {
    let isCompact: Bool
    /// An unselected preview keeps its window opaque and paints it gray
    /// instead of fading it into the settings background.
    let isSelected: Bool

    private let windowSize = CGSize(width: 58, height: 40)
    /// The same inset on every side of the list inside the window.
    private let windowPadding: CGFloat = 4
    private let lineWidthFractions: [CGFloat] = [0.9, 0.65, 1, 0.75, 0.85, 0.6]

    private var rowCount: Int { isCompact ? 5 : 3 }
    private var iconSize: CGFloat { isCompact ? 4.5 : 7 }
    private var lineHeight: CGFloat { isCompact ? 1.5 : 2 }
    private var listSize: CGSize {
        CGSize(width: windowSize.width - windowPadding * 2, height: windowSize.height - windowPadding * 2)
    }
    private var rowHeight: CGFloat { listSize.height / CGFloat(rowCount) }
    /// Like the real rows, the icon is as far from the left edge as from the top and bottom.
    private var iconInset: CGFloat { (rowHeight - iconSize) / 2 }
    private var iconSpacing: CGFloat { isCompact ? 2.5 : 3 }
    private var textWidth: CGFloat { listSize.width - iconInset * 2 - iconSize - iconSpacing }

    var body: some View {
        ZStack {
            Image(decorative: "HistoryDensityPreviewBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(isSelected ? 1 : 0.72)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { index in
                    row(index: index)
                }
            }
            .padding(windowPadding)
            .frame(width: windowSize.width, height: windowSize.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color(nsColor: .windowBackgroundColor) : Self.unselectedWindowColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private static let unselectedWindowColor = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(white: isDark ? 0.3 : 0.82, alpha: 1)
    })

    private func row(index: Int) -> some View {
        HStack(spacing: iconSpacing) {
            RoundedRectangle(cornerRadius: iconSize / 4, style: .continuous)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Capsule()
                    .fill(Color.primary.opacity(0.45))
                    .frame(width: textWidth * lineWidthFractions[index % lineWidthFractions.count], height: lineHeight)
                if !isCompact {
                    Capsule()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: textWidth * lineWidthFractions[(index + 3) % lineWidthFractions.count] * 0.7, height: lineHeight)
                }
            }
        }
        .padding(.leading, iconInset)
        .frame(width: listSize.width, height: rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 2.5 : 3.5, style: .continuous)
                .fill(index == 0 ? Color.primary.opacity(0.1) : Color.clear)
        )
    }
}
