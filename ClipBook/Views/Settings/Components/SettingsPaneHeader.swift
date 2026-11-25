import SwiftUI

/// The card at the top of a settings pane, with the pane's icon, title and a
/// one-line summary, like the pane headers in System Settings.
struct SettingsPaneHeader: View {
    let section: SettingsSection

    var body: some View {
        VStack(spacing: 6) {
            SettingsIconTile(section: section, size: 52)
                .padding(.bottom, 4)

            Text(section.detailTitle)
                .font(.system(size: 17, weight: .bold))

            Text(section.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
