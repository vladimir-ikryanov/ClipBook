import AppKit

final class EmptyHistory: NSView {
  init(title: String, message: String? = nil, symbolName: String) {
    super.init(frame: .zero)

    let imageView = NSImageView()
    imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
    imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
    imageView.contentTintColor = .secondaryLabelColor

    let titleField = NSTextField(labelWithString: title)
    titleField.font = .systemFont(ofSize: NSFont.systemFontSize + 8, weight: .semibold)
    titleField.textColor = .secondaryLabelColor
    titleField.alignment = .center

    var views: [NSView] = [imageView, titleField]
    if let message {
      let messageField = NSTextField(wrappingLabelWithString: message)
      messageField.textColor = .secondaryLabelColor
      messageField.alignment = .center
      views.append(messageField)
    }

    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.spacing = 8
    stack.alignment = .centerX
    stack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(stack)

    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: 56),
      imageView.heightAnchor.constraint(equalToConstant: 56),
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
