import SwiftUI

struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        PreviewOptionPicker(title: L10n.string("Theme")) {
            ForEach(AppAppearance.allCases) { appearance in
                PreviewOption(title: appearance.title, isSelected: selection == appearance) {
                    selection = appearance
                } preview: {
                    Image(decorative: appearance.previewImageName)
                        .resizable()
                        .aspectRatio(316.0 / 200.0, contentMode: .fit)
                }
            }
        }
    }
}

/// A settings row that offers its choices as small pictures, like the theme
/// picker in System Settings.
struct PreviewOptionPicker<Options: View>: View {
    let title: String
    @ViewBuilder let options: () -> Options

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                options()
            }
        }
        .padding(.vertical, 8)
    }
}

struct PreviewOption<Preview: View>: View {
    let title: String
    let isSelected: Bool
    /// Fades an unselected preview into the background. A preview that
    /// dims itself when unselected turns this off.
    var fadesWhenUnselected = true
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                preview()
                    .frame(width: 93, height: 58.5)
                    .saturation(isSelected ? 1 : 0)
                    .opacity(isSelected || !fadesWhenUnselected ? 1 : 0.72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 3)
                                .padding(-5)
                        }
                    }

                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: 105)
        .buttonStyle(PreviewOptionButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? L10n.string("Selected") : "")
    }
}

/// Shows the label as it is while the mouse is held down. The plain style
/// dims it, which looks like the selection is being taken away.
struct PreviewOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension AppAppearance {
    fileprivate var previewImageName: String {
        switch self {
        case .system: "AppearancePreviewSystem"
        case .light: "AppearancePreviewLight"
        case .dark: "AppearancePreviewDark"
        }
    }
}
