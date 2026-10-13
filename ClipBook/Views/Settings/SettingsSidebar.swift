import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    @FocusState private var isFocused: Bool

    private static let selectionCornerRadius: CGFloat = 8
    private static let selectionHorizontalInset: CGFloat = 10

    var body: some View {
        List(SettingsSection.visibleSections, selection: $selection) { section in
            row(for: section)
                .tag(section)
        }
        .listStyle(.sidebar)
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
    }

    // On macOS 27 the sidebar list only draws the selected row with the
    // accent color while it is the first responder; once focus moves into the
    // detail column the highlight turns gray. System Settings keeps the accent
    // highlight regardless of focus, so the row draws its own accent
    // background on top of the list's selection highlight and forces white
    // content, which is what the list does itself while focused. Earlier
    // systems keep the accent highlight on their own and use the plain label.
    @ViewBuilder
    private func row(for section: SettingsSection) -> some View {
        if #available(macOS 27.0, *) {
            let isSelected = section == selection

            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 20)
                Text(section.title)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .listRowBackground(
                RoundedRectangle(cornerRadius: Self.selectionCornerRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .padding(.horizontal, Self.selectionHorizontalInset)
            )
        } else {
            Label(section.title, systemImage: section.systemImage)
        }
    }
}
