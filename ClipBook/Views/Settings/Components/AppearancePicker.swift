import SwiftUI

struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(L10n.string("Theme"))

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { appearance in
                    AppearancePickerOption(
                        appearance: appearance,
                        isSelected: selection == appearance
                    ) {
                        selection = appearance
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct AppearancePickerOption: View {
    let appearance: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(decorative: appearance.previewImageName)
                    .resizable()
                    .aspectRatio(316.0 / 200.0, contentMode: .fit)
                    .frame(width: 93, height: 58.5)
                    .saturation(isSelected ? 1 : 0)
                    .opacity(isSelected ? 1 : 0.72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 3)
                                .padding(-5)
                        }
                    }

                Text(appearance.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: 105)
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityValue(isSelected ? L10n.string("Selected") : "")
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
