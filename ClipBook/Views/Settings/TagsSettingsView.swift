import AppKit
import SwiftUI

struct TagsSettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var settingsWindow: NSWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Create, edit, or remove tags used to organize clipboard history items."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            SettingsSectionGroup {
                if model.availableTags.isEmpty {
                    EmptyTagsSettingsRow()
                } else {
                    ForEach(model.availableTags) { tag in
                        TagSettingsRow(
                            tag: tag,
                            itemCount: tagItemCounts[tag.id, default: 0],
                            onEdit: {
                                showTagDialog(for: tag)
                            },
                            onDelete: {
                                coordinator.deleteTag(tag)
                            }
                        )
                    }
                }
            }

            HStack {
                Spacer()
                Button(L10n.string("New Tag...")) {
                    showTagDialog()
                }
            }
        }
        .background(SettingsWindowAccessor(window: $settingsWindow))
    }

    private var tagItemCounts: [Tag.ID: Int] {
        model.items.reduce(into: [:]) { counts, item in
            for tagID in item.tags {
                counts[tagID, default: 0] += 1
            }
        }
    }

    private func showTagDialog(for tag: Tag? = nil) {
        guard let window = settingsWindow ?? NSApp.keyWindow else {
            return
        }

        let sheetController = NewTagDialog(tag: tag)
        let sheetWindow = NSWindow(contentViewController: sheetController)
        sheetWindow.styleMask = [.titled]
        sheetWindow.titleVisibility = .hidden
        sheetWindow.titlebarAppearsTransparent = true
        sheetWindow.backgroundColor = .windowBackgroundColor
        sheetWindow.isReleasedWhenClosed = false

        sheetController.onCancel = { [weak sheetWindow] in
            guard let sheetWindow else {
                return
            }

            window.endSheet(sheetWindow)
        }
        sheetController.onCreate = { [weak sheetWindow] tagName, color in
            guard let sheetWindow else {
                return
            }

            if let tag {
                coordinator.updateTag(tag, name: tagName, color: color)
            } else {
                coordinator.createTag(name: tagName, color: color)
            }
            window.endSheet(sheetWindow)
        }

        window.beginSheet(sheetWindow)
    }
}

private struct EmptyTagsSettingsRow: View {
    var body: some View {
        HStack {
            Spacer()
            Text(L10n.string("No tags"))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
    }
}

private struct TagSettingsRow: View {
    let tag: Tag
    let itemCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(nsColor: NSColor(tagHexString: tag.color) ?? .labelColor))
                .frame(width: 18, height: 18)

            Text(tag.name)
                .lineLimit(1)

            Spacer(minLength: 18)

            Text(itemCountText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)

            TagActionsMenuButton(onEdit: onEdit, onDelete: onDelete)
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 9)
    }

    private var itemCountText: String {
        itemCount == 1 ? L10n.string("1 item") : L10n.string("%d items", itemCount)
    }
}

private extension NSColor {
    convenience init?(tagHexString: String) {
        let hex = tagHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = Int(hex, radix: 16) else {
            return nil
        }

        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

private struct TagActionsMenuButton: NSViewRepresentable {
    let onEdit: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        configure(button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.onEdit = onEdit
        context.coordinator.onDelete = onDelete
        configure(button)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onEdit: onEdit, onDelete: onDelete)
    }

    private func configure(_ button: NSButton) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: L10n.string("Tag actions"))?
            .withSymbolConfiguration(configuration)
        button.toolTip = L10n.string("Tag actions")
    }

    final class Coordinator: NSObject {
        var onEdit: () -> Void
        var onDelete: () -> Void

        init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
            self.onEdit = onEdit
            self.onDelete = onDelete
        }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: L10n.string("Edit..."), action: #selector(edit), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: L10n.string("Delete"), action: #selector(delete), keyEquivalent: ""))
            menu.items.forEach { $0.target = self }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
        }

        @objc private func edit() {
            onEdit()
        }

        @objc private func delete() {
            onDelete()
        }
    }
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> SettingsWindowReportingView {
        let view = SettingsWindowReportingView()
        view.onWindowChange = { window = $0 }
        return view
    }

    func updateNSView(_ nsView: SettingsWindowReportingView, context: Context) {
        nsView.onWindowChange = { window = $0 }
    }
}

private final class SettingsWindowReportingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
