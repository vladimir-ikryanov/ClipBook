import SwiftUI

private struct DividedVStack: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id

        return VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last {
                    Color(NSColor(name: nil) { appearance in
                        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        return isDark
                            ? NSColor(white: 0x2F / 255.0, alpha: 1.0)
                            : NSColor.separatorColor
                    })
                    .frame(height: 0.5)
                    .padding(.leading, 2)
                }
            }
        }
    }
}

struct SettingsSectionGroup<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 11)
            }
            _VariadicView.Tree(DividedVStack()) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
