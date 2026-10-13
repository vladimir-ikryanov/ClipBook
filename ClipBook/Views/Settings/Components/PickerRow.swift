import SwiftUI

struct PickerRow<Content: View>: View {
    let title: String
    let description: String
    let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        SettingsRow(title: title, description: description) {
            pickerContent
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if #available(macOS 26.0, *) {
            content
        } else {
            content
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
