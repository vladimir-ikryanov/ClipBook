import SwiftUI

struct SettingsToggle: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool

    init(title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        self._isOn = isOn
    }

    var body: some View {
        SettingsRow(title: title, description: description) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .frame(width: 40, height: 10)
        }
    }
}
