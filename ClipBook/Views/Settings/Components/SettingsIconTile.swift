import SwiftUI

/// A rounded tile with a symbol, like the pane icons in System Settings: in
/// light mode a white symbol on a tile of the section's color, in dark mode a
/// symbol of the section's color on a dark tile.
struct SettingsIconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 20

    @Environment(\.colorScheme) private var colorScheme

    private static let darkTileFill = LinearGradient(
        colors: [Color(white: 0.17), Color(white: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    private var cornerRadius: CGFloat {
        size * 0.27
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark

        shape
            .fill(isDark ? AnyShapeStyle(Self.darkTileFill) : AnyShapeStyle(color.gradient))
            .overlay(shape.strokeBorder(Color.white.opacity(isDark ? 0.14 : 0.18), lineWidth: 0.5))
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .foregroundStyle(isDark ? color : Color.white)
            )
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.15), radius: 0.5, y: 0.5)
            .accessibilityHidden(true)
    }
}

extension SettingsIconTile {
    init(section: SettingsSection, size: CGFloat = 20) {
        self.init(systemImage: section.systemImage, color: section.tileColor, size: size)
    }
}
